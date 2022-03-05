## Overview

frp is used to:

* display things on screen
* react to input from keyboard and mouse
* prioritize which ui elements get inputs

frp works by going through a table of:

* "things that can happen", and
* "things that want to know what happened"

e.g.

```
@{mouse [flash-cursor-position]}
```
This means "whenever something mouse related happens, tell `flash-cursor-position` what happened".

In this context, `mouse` is an "emitter" as in "`mouse` emits things that happen".

`flash-cursor-position` is a "subscriber" as in "`flash-cursor-position` subscribes to things that happen".

## Example usage

If freja is installed, the easiest way to figure out what "things that can happen" actually are, is to call:
```
(import freja/frp)

(frp/subscribe! frp/mouse pp)
```

If you are reading this in freja, you can put the cursor after each `)` and hit Ctrl+Enter. Then try clicking somewhere and look in your terminal.

This means "the subscriber `pp` will be run whenever `frp/mouse` emits something".

In the above case, you would see these sorts of things in the terminal:
```
@[:press (234 472)]
@[:release (234 472)]
```

The above describes what the physical mouse did, like pressing a button, and at what pixel relative to the window the mouse did what it did.
So `@[:press (234 472)]` means "the mouse button was pressed at x position 234 and y position 472". `(0 0)` would be the top left corner.

A "thing that can happen" is called an "event".

## Available emitters

Freja's built-in emitters are listed below.

### `mouse`

Emits events related to the physical mouse.

In the form of `@[kind-of-event mouse-position]` if not specified otherwise.

`kind-of-event` can be one of the following:
* `:press`
* `:release`
* `:drag`
* `:double-click`
* `:triple-click`
* `:scroll` - in the form of `@[:scroll scroll-amount mouse-position]`, where scroll amount is how many pixels of scrolling occured and `mouse-position` is a tuple of the x/y coordinates relative to the window's top left corner.

#### Example

```
(import freja/frp)

(frp/subscribe! frp/mouse pp)
```


### `keyboard`

Emits events related to the physical keyboard.

Always in the form of `@[kind-of-event key]`

`kind-of-event` can be one of the following:
* :key-down - is emitted when a key is pressed, or repeatedly when held for a certain period of time

`key` is a keyword corresponding to the physical button. This will not account for locale, e.g. if using dvorak and hitting physical n, you will get `:n`, not `:b`. This is due to how Raylib works internally.

#### Example

```
(import freja/frp)

(frp/subscribe! frp/keyboard pp)
```

### `chars`

Emits events related to physical keyboard presses, respecting the locale of the user.

Always in the form of `@[:char char]`

`char` is a number corresponding to an ascii character. E.g. typing `a` emits `@[:char 97]`.

#### Example

```
(import freja/frp)

(frp/subscribe! frp/chars pp)
```

### `callbacks`
A stack of key -> callbacks, which will always only call the last callback for each key.

### `frame-chan`
Emits an event each new frame.

### `rerender`
Emits events when rerendering is needed.
