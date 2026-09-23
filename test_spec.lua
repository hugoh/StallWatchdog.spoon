-- Busted tests for the StallWatchdog Spoon using a mock hs environment.

local mock_hs
local StallWatchdog

local MS = 1e6 -- hs.timer.absoluteTime() is in nanoseconds

local function makeLogger()
	local l = { _infos = {}, _warnings = {} }
	l.f = function(fmt, ...) table.insert(l._infos, string.format(fmt, ...)) end
	l.wf = function(fmt, ...) table.insert(l._warnings, string.format(fmt, ...)) end
	return l
end

before_each(function()
	mock_hs = { _now = 0, _timers = {} }
	mock_hs.logger = { new = function() return makeLogger() end }
	mock_hs.timer = {
		absoluteTime = function() return mock_hs._now end,
		new = function(interval, fn)
			local t = { _interval = interval, _fn = fn, _running = false }
			function t:start()
				self._running = true
				return self
			end
			function t:stop()
				self._running = false
				return self
			end
			function t:running() return self._running end
			table.insert(mock_hs._timers, t)
			return t
		end,
	}

	package.loaded.hs = nil
	_G.hs = mock_hs

	StallWatchdog = dofile("init.lua")
end)

after_each(function() StallWatchdog:stop() end)

local function latestTimer() return mock_hs._timers[#mock_hs._timers] end

-- Advance the clock by `ms` milliseconds, then deliver one timer tick.
local function tickAfter(ms)
	mock_hs._now = mock_hs._now + ms * MS
	local t = latestTimer()
	if t and t._running then t._fn() end
end

describe("start/stop", function()
	it("is not running until started", function() assert.is_false(StallWatchdog:isRunning()) end)

	it("start() runs a timer at the configured interval", function()
		StallWatchdog:start()
		assert.is_true(StallWatchdog:isRunning())
		assert.are.equal(0.05, latestTimer()._interval)
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
		assert.are.same({ "Watchdog on", "Watchdog off" }, StallWatchdog.log._infos)
	end)
end)

describe("stall detection", function()
	it("warns when a tick arrives later than interval + threshold", function()
		StallWatchdog:start()
		tickAfter(50 + 150)
		assert.are.same({ "Main thread stalled 150 ms" }, StallWatchdog.log._warnings)
	end)

	it("stays quiet for ticks within the threshold", function()
		StallWatchdog:start()
		tickAfter(50)
		tickAfter(50 + 100)
		assert.are.same({}, StallWatchdog.log._warnings)
	end)

	it("measures each tick from the previous one", function()
		StallWatchdog:start()
		tickAfter(50 + 300)
		tickAfter(50)
		assert.are.equal(1, #StallWatchdog.log._warnings)
	end)

	it("does not count the time it was stopped as a stall", function()
		StallWatchdog:start():stop()
		mock_hs._now = mock_hs._now + 10000 * MS
		StallWatchdog:start()
		tickAfter(50)
		assert.are.same({}, StallWatchdog.log._warnings)
	end)
end)

describe("configure", function()
	it("overrides interval and threshold", function()
		StallWatchdog:configure({ interval = 0.1, threshold = 0.5 }):start()
		assert.are.equal(0.1, latestTimer()._interval)
		tickAfter(100 + 400)
		assert.are.same({}, StallWatchdog.log._warnings)
		tickAfter(100 + 600)
		assert.are.same({ "Main thread stalled 600 ms" }, StallWatchdog.log._warnings)
	end)

	it("restarts a running watchdog so a new interval takes effect", function()
		StallWatchdog:start()
		local old = latestTimer()
		StallWatchdog:configure({ interval = 0.2 })
		assert.is_false(old._running)
		assert.is_true(StallWatchdog:isRunning())
		assert.are.equal(0.2, latestTimer()._interval)
	end)
end)
