# Hover

A macOS menu bar app that brings focus-follows-mouse to macOS, the way Omarchy
and Hyprland do it: point at a window and it's focused. No clicking to switch.

## How it works

- Watches global mouse movement. Each time the cursor moves (after an optional
  delay), it finds the frontmost normal window under the cursor with
  `CGWindowListCopyWindowInfo`.
- Matches that window to its Accessibility element via `_AXUIElementGetWindow`,
  marks it main, raises it, and makes its app frontmost.
- If anything above the normal window layer is under the cursor (the menu bar,
  Dock, an open menu, Spotlight, a notification), nothing happens. Menus and
  popovers never get dismissed by a stray mouse movement.
- Never switches while a mouse button is held, so dragging and text selection
  work normally.
- Keyboard focus changes (⌘-Tab, window-manager shortcuts) stick until the
  mouse moves again.
- AX calls time out after 250 ms, so a hung app can't freeze Hover.

## Menu

- **Focus Follows Mouse**: master on/off (⌘F)
- **Raise Focused Window**: bring the hovered window to the front (on by
  default, since macOS windows overlap). Off makes it main without raising.
- **Hover Delay**: Instant (default) up to 400 ms. A small delay stops
  windows you sweep across from grabbing focus.
- **Launch at Login**

## Requirements / notes

- macOS 14+.
- Needs **Accessibility** permission (System Settings ▸ Privacy & Security ▸
  Accessibility). The menu offers a shortcut when it's missing.
- The build is ad-hoc signed, so macOS treats every rebuild as a new app:
  remove and re-add Hover in the Accessibility list after rebuilding.

## Build

```sh
./build_app.sh          # builds and ad-hoc signs dist/Hover.app
ditto dist/Hover.app /Applications/Hover.app
open /Applications/Hover.app
```
