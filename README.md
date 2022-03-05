# freja-frp

Simplified frp system extracted from [freja](https://github.com/saikyun/freja) by [saikyun](https://github.com/saikyun)

## Quickstart

* Via a terminal, start by: `janet main.janet`

* Move mouse in the window that should have appeared, type keys, etc.
while examining terminal output.

## Some Explanation

Inside `main.janet` is a typical loop setup for a
[jaylib](https://github.com/janet-lang/jaylib) program.

Specific to the frp system are:

* A call to `frp/init-chans` which initializes the frp system.
* Calls to `frp/subscribe!` which arrange for things to happen based on certain types of events (e.g. mouse movements, keys typed, etc.) which are typically captured in channels.
* A call to `frp/trigger` that sits in an infnite loop.  Each time it is called, it collects events since the last time through the loop and once gathered, processes the events.

## Details

There is an edited version of the official documentation [here](frp.md).

## Credits

* saikyun

