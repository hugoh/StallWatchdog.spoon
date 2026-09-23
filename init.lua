-- vim: set ft=lua:

--- === StallWatchdog ===
---
--- A Hammerspoon Spoon that logs when Hammerspoon's main thread stalls.
---
--- Hotkeys, timers and watchers all run on the main thread, so any blocking
--- call (a slow accessibility query, `hs.execute`, a synchronous search) delays
--- everything queued behind it. StallWatchdog runs a short repeating timer and
--- warns in the Console whenever a tick arrives late, so the latency you feel
--- can be matched to whatever was running at that moment.
---
--- Download: https://github.com/hugoh/StallWatchdog.spoon/releases/latest

local obj = {}
obj.__index = obj

obj.name = "StallWatchdog"
obj.version = "dev"
obj.author = "Hugo Haas"
obj.license = "MIT"
obj.homepage = "https://github.com/hugoh/StallWatchdog.spoon"

--- StallWatchdog.interval
--- Variable
--- Seconds between watchdog ticks (default: 0.05).
obj.interval = 0.05

--- StallWatchdog.threshold
--- Variable
--- Seconds a tick may arrive late before it is logged as a stall (default: 0.1).
obj.threshold = 0.1

obj.log = hs.logger.new("StallWatchdog", "info")

--- StallWatchdog:init()
--- Method
--- Called automatically by `hs.loadSpoon()`. Logs the loaded version.
function obj:init()
	self.log.f("Loaded %s v%s", self.name, self.version)
	return self
end

obj._timer = nil
obj._lastTick = nil

local NS_PER_SECOND = 1e9

function obj:_tick()
	local now = hs.timer.absoluteTime()
	local late = (now - self._lastTick) / NS_PER_SECOND - self.interval
	if late > self.threshold then self.log.wf("Main thread stalled %.0f ms", late * 1000) end
	self._lastTick = now
end

--- StallWatchdog:isRunning() -> boolean
--- Method
--- Returns whether the watchdog is currently running.
function obj:isRunning() return self._timer ~= nil and self._timer:running() end

--- StallWatchdog:start() -> StallWatchdog
--- Method
--- Starts the watchdog. Time spent stopped is never reported as a stall.
---
--- Returns:
---  * The StallWatchdog object, for method chaining
function obj:start()
	if self:isRunning() then return self end
	self._lastTick = hs.timer.absoluteTime()
	self._timer = hs.timer.new(self.interval, function() self:_tick() end):start()
	return self
end

--- StallWatchdog:stop() -> StallWatchdog
--- Method
--- Stops the watchdog.
---
--- Returns:
---  * The StallWatchdog object, for method chaining
function obj:stop()
	if self._timer then
		self._timer:stop()
		self._timer = nil
	end
	return self
end

--- StallWatchdog:toggle() -> boolean
--- Method
--- Starts the watchdog if it is stopped, stops it otherwise, and logs the new state.
--- Handy from the Hammerspoon Console: `spoon.StallWatchdog:toggle()`.
---
--- Returns:
---  * true if the watchdog is now running
function obj:toggle()
	if self:isRunning() then
		self:stop()
	else
		self:start()
	end
	local running = self:isRunning()
	self.log.f("Watchdog %s", running and "on" or "off")
	return running
end

--- StallWatchdog:configure(opts) -> StallWatchdog
--- Method
--- Sets `interval` and/or `threshold` from a table. A running watchdog is
--- restarted so a new interval takes effect.
---
--- Parameters:
---  * opts - a table with `interval` and/or `threshold` keys, in seconds
---
--- Returns:
---  * The StallWatchdog object, for method chaining
function obj:configure(opts)
	for _, key in ipairs({ "interval", "threshold" }) do
		if opts[key] ~= nil then self[key] = opts[key] end
	end
	if self:isRunning() then self:stop():start() end
	return self
end

return obj
