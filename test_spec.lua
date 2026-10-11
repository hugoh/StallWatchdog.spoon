-- Busted tests for the StallWatchdog Spoon using the shared hs_mock from spoon-tools.

local hs_mock = require("hs_mock")

local ctl
local StallWatchdog

before_each(function()
	local hs
	hs, ctl = hs_mock.new()
	_G.hs = hs

	StallWatchdog = dofile("init.lua")
end)

after_each(function() StallWatchdog:stop() end)

-- Jump the clock by `ms` milliseconds without the tick timer firing (a stalled
-- main thread), then deliver one tick.
local function tickAfter(ms)
	ctl.now = ctl.now + ms / 1000
	local t = StallWatchdog._timer
	if t and t:running() then t:fire() end
end

describe("start/stop", function()
	it("is not running until started", function() assert.is_false(StallWatchdog:isRunning()) end)

	it("start() runs a timer at the configured interval", function()
		StallWatchdog:start()
		assert.is_true(StallWatchdog:isRunning())
		assert.are.equal(0.05, StallWatchdog._timer._interval)
	end)

	it("stop() stops the timer", function()
		StallWatchdog:start():stop()
		assert.is_false(StallWatchdog:isRunning())
	end)

	it("toggle() flips the state and returns whether it is now running", function()
		assert.is_true(StallWatchdog:toggle())
		assert.is_false(StallWatchdog:toggle())
		assert.is_false(StallWatchdog:isRunning())
	end)

	it("logs when it is switched on or off", function()
		StallWatchdog:toggle()
		StallWatchdog:toggle()
		assert.are.same({ "Watchdog on", "Watchdog off" }, ctl.logged("info"))
	end)
end)

describe("stall detection", function()
	it("warns when a tick arrives later than interval + threshold", function()
		StallWatchdog:start()
		tickAfter(50 + 150)
		assert.are.same({ "Main thread stalled 150 ms" }, ctl.logged("warning"))
	end)

	it("stays quiet for ticks within the threshold", function()
		StallWatchdog:start()
		tickAfter(50)
		tickAfter(50 + 100)
		assert.are.same({}, ctl.logged("warning"))
	end)

	it("measures each tick from the previous one", function()
		StallWatchdog:start()
		tickAfter(50 + 300)
		tickAfter(50)
		assert.are.equal(1, #ctl.logged("warning"))
	end)

	it("does not count the time it was stopped as a stall", function()
		StallWatchdog:start():stop()
		ctl.now = ctl.now + 10
		StallWatchdog:start()
		tickAfter(50)
		assert.are.same({}, ctl.logged("warning"))
	end)
end)

describe("configure", function()
	it("overrides interval and threshold", function()
		StallWatchdog:configure({ interval = 0.1, threshold = 0.5 }):start()
		assert.are.equal(0.1, StallWatchdog._timer._interval)
		tickAfter(100 + 400)
		assert.are.same({}, ctl.logged("warning"))
		tickAfter(100 + 600)
		assert.are.same({ "Main thread stalled 600 ms" }, ctl.logged("warning"))
	end)

	it("restarts a running watchdog so a new interval takes effect", function()
		StallWatchdog:start()
		local old = StallWatchdog._timer
		StallWatchdog:configure({ interval = 0.2 })
		assert.is_false(old:running())
		assert.is_true(StallWatchdog:isRunning())
		assert.are.equal(0.2, StallWatchdog._timer._interval)
	end)
end)

describe("periodic report", function()
	it("defaults to 60s and can be disabled with false", function()
		StallWatchdog:start()
		assert.are.equal(60, StallWatchdog._reportTimer._interval)
		StallWatchdog:stop():configure({ reportInterval = false }):start()
		assert.are.same({ StallWatchdog._timer }, ctl.timers())
	end)

	it("logs tick stats and Lua memory, then resets the counters", function()
		StallWatchdog:configure({ reportInterval = 60 }):start()
		tickAfter(50)
		tickAfter(50 + 200)
		local report = StallWatchdog._reportTimer
		report:fire()
		assert.are.equal(1, #ctl.logged("info"))
		assert.is_truthy(
			ctl.logged("info")[1]:match("^60s: ticks=2 stalls=1 worst=200ms lua=%d+%.%d%d%dMB %([+-]%d+%.%dkB%)$")
		)
		report:fire()
		assert.is_truthy(ctl.logged("info")[2]:match("ticks=0 stalls=0 worst=0ms"))
	end)

	it("stops reporting when the watchdog stops", function()
		StallWatchdog:configure({ reportInterval = 60 }):start():stop()
		assert.are.same({}, ctl.timers())
	end)
end)

describe("init", function()
	it("logs the loaded version", function()
		assert.are.equal(StallWatchdog, StallWatchdog:init())
		assert.are.same({ "Loaded StallWatchdog vdev" }, ctl.logged("info"))
	end)
end)
