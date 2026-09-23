# StallWatchdog Spoon

[![MIT License](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Hammerspoon Spoon](https://img.shields.io/badge/Hammerspoon-Spoon-FFA500.svg)](https://www.hammerspoon.org/docs/index.html)

A Hammerspoon Spoon that logs when Hammerspoon's main thread stalls, so you can find what's making your Hammerspoon setup sluggish.

**Repository**: [https://github.com/hugoh/StallWatchdog.spoon](https://github.com/hugoh/StallWatchdog.spoon)

## Why

Nearly all of Hammerspoon runs on a single main thread: hotkeys, timers, watchers (apps, Wi-Fi, USB, screens, sleep/wake), event taps, menu bar items, alerts, and `hs -c` from the terminal. When any piece of code blocks it (a slow accessibility query against a busy app, `hs.execute`, a synchronous search over every window), everything else waits:

- hotkeys fire late
- timers and watcher callbacks run late
- menu bar items and alerts don't update
- event taps respond late, which can delay the keys or clicks they intercept
- `hs -c` from a terminal times out

These stalls are often intermittent, such as a periodic check in some spoon, and the delay shows up wherever you happen to be using Hammerspoon at the time, not in the code that caused it. StallWatchdog runs a short repeating timer and warns in the Console whenever a tick arrives late:

```text
** Warning:   StallWatchdog: Main thread stalled 815 ms
```

The stall is logged after the blocking work returns, so read the lines logged just before it to see what was running. A regular rhythm in the timestamps (every 15 s, every 10 min) usually points at a periodic timer.

## Installation

Ensure you have [Hammerspoon](https://www.hammerspoon.org) installed, then choose a method:

### Release zip (recommended)

1. Download `StallWatchdog.spoon.zip` from the [latest release](https://github.com/hugoh/StallWatchdog.spoon/releases/latest)
2. Unzip — this produces a `StallWatchdog.spoon` folder
3. Move it to `~/.hammerspoon/Spoons/`
4. Reload Hammerspoon (menu bar icon → Reload Config, or run `hs.reload()` in the console)

### SpoonInstall (if you already use it)

```lua
spoon.SpoonInstall:installSpoonFromZip(
  "https://github.com/hugoh/StallWatchdog.spoon/releases/latest/download/StallWatchdog.spoon.zip"
)
```

### Clone from git (for development or latest changes)

```bash
cd ~/.hammerspoon/Spoons
git clone https://github.com/hugoh/StallWatchdog.spoon.git
```

## Configuration

The watchdog is off until you start it. Load it in `init.lua`:

```lua
hs.loadSpoon("StallWatchdog")
```

then switch it on and off from the Hammerspoon Console while you chase a problem:

```lua
spoon.StallWatchdog:toggle()
```

or from a terminal, with `hs.ipc` loaded:

```bash
hs -c 'spoon.StallWatchdog:toggle()'
```

To keep it always on, start it from `init.lua` instead:

```lua
hs.loadSpoon("StallWatchdog"):start()
```

Tune it with `configure()` (all optional, in seconds):

```lua
hs.loadSpoon("StallWatchdog"):configure({
  interval = 0.05,  -- time between ticks
  threshold = 0.1,  -- how late a tick may arrive before it is logged
})
```

## Cost

One timer callback every `interval` seconds (20 per second by default) that reads a clock and compares two numbers. It's cheap, but it isn't free, which is why the watchdog starts off.

## API documentation

Full [API reference](https://stallwatchdog-spoon.larve.net/) is generated from the docstrings in `init.lua` (`mise run docs`).
