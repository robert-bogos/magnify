# magnify

## TL;DR

A magnifying glass that follows your cursor anywhere on macOS.
Perfect if you need to pinpoint stuff while screen sharing.

To install, run this in your terminal:
```sh
brew trust robert-bogos/magnify && brew install robert-bogos/magnify/
```
To use, run this in your terminal:
```sh
magnify
```

<img width="1038" height="534" alt="Screenshot 2026-09-05 at 22 40 54" src="https://github.com/user-attachments/assets/bfe7ce2d-5ed9-453f-bbcf-90d5d7e993b9" />


## Requirements

- macOS 13+ (Apple Silicon).
- Xcode **not** required — builds with Command Line Tools using `swiftc`.
  (`swift build` / `swift test` need full Xcode; the scripts below use `swiftc`.)

## Install

```sh
brew trust robert-bogos/magnify && brew install robert-bogos/magnify/magnify
```

The `trust` step is a one-time grant Homebrew requires for third-party taps
(this repo isn't in Homebrew's official cask index) — doing it first means
`install` taps and installs in one shot instead of failing and asking you to
retry.

Magnify is ad-hoc signed, not notarized by Apple — the cask automatically
clears the Gatekeeper quarantine flag on install, so no separate "right-click
▸ Open" workaround is needed. You'll still need to grant Screen Recording
permission on first launch (see below).

Upgrade later with `brew upgrade --cask magnify`.

## Build from source

```sh
./scripts/build.sh
```

Compiles, assembles `Magnify.app`, and ad-hoc signs it.

## Run

```sh
./magnify --zoom 2 --size 320
```

`./magnify` launches `Magnify.app` via LaunchServices (`open -n`) so it gets its
own identity in the permission lists. It runs in the background — **quit it from
the 🔍 icon in the menu bar**, or `killall magnify`.

### First launch: grant Screen Recording

The first run triggers a **Screen Recording** permission prompt. Until it's
granted, **no lens is shown** (so it can't block you from clicking) — the 🔍 menu
bar reads "Waiting for Screen Recording permission…". Enable it here:

> System Settings ▸ Privacy & Security ▸ Screen Recording ▸ enable **Magnify**

The lens then appears on its own within ~2s — no relaunch needed.

If **Magnify** doesn't appear in the list, force a clean prompt:

```sh
killall magnify 2>/dev/null; tccutil reset ScreenCapture com.rbogos.magnify
./magnify
```

### Options

| Flag | Default | Meaning |
|------|---------|---------|
| `--zoom <n>` | `2` | Magnification (1–20) |
| `--size <pt>` | `300` | Lens side length in points (100–800) |
| `--shape <s>` | `square` | `square` or `circle` |
| `--fps <n>` | `60` | Capture frame rate (15–120) |
| `--filter <f>` | `nearest` | `nearest` (crisp pixels) or `linear` (smooth) |
| `--flip-y` | off | Flip vertical sampling — rarely needed (see Troubleshooting) |
| `-h`, `--help` | | Show help |

### Controls

- **Quit:** Ctrl-C in the terminal (always works).
- **Show / hide the lens:** `⌃⌥M`, or the 🔍 menu-bar item. Hiding stops capture
  so it idles cheaply. Neither needs any extra permission.
- **Live zoom / resize / Esc-to-quit:** need **Accessibility** permission
  (System Settings ▸ Privacy & Security ▸ Accessibility ▸ enable **Magnify**).
  Then: scroll or `+`/`-` to zoom, `[` / `]` to resize, `Esc` to quit.

## How it works

- A borderless, transparent, click-through `NSWindow` at the shielding window level
  floats above everything and is excluded from capture (`sharingType = .none`), so
  it never captures itself (no "hall of mirrors").
- **ScreenCaptureKit** streams the display the cursor is on; the latest frame is
  stored as a `CGImage`.
- A `CVDisplayLink` drives a per-frame update: the frame is set as a `CALayer`'s
  `contents` and a normalized `contentsRect` (computed in `MagnifyCore/Geometry`)
  selects the region under the cursor, which the layer scales up — GPU-cheap, no
  per-frame CPU cropping.
- Crossing to another monitor rebuilds the stream for that display.

## Test

```sh
./scripts/test.sh   # geometry checks via swiftc (no Xcode needed)
```

The same assertions live in `Tests/MagnifyCoreTests/` for `swift test` once Xcode
is installed.

## Troubleshooting

- **No lens appears:** Screen Recording isn't granted yet — the lens stays hidden
  until it is. Grant it (see above) and the lens shows up within ~2s; the 🔍 menu
  bar shows current status.
- **"Magnify" isn't in the Screen Recording list:** it only shows up once it has
  requested capture *and* was launched via `open` (the `./magnify` wrapper does
  this). Running the raw binary from a shell attributes the request to your
  terminal app instead. If it's still missing, run
  `tccutil reset ScreenCapture com.rbogos.magnify` then `./magnify`.
- **Lens pans vertically the wrong way** (moving the cursor up shows lower
  content): your setup samples top-down — run with `--flip-y`.
- **Scroll / keyboard controls do nothing:** grant Accessibility (see Controls).
  Ctrl-C still quits regardless.
- **Re-prompted for Screen Recording after rebuilding — or the toggle is *on* but
  the lens never appears:** ad-hoc signatures change on every rebuild, so macOS
  stops honoring the old grant. Reset it and grant once more:
  `tccutil reset ScreenCapture com.rbogos.magnify`, then run `./magnify` again.
  (You only hit this if you rebuild; a build-once install grants once and stays put.)
