# 🍅 Pomodoro

A native macOS menu bar Pomodoro timer. SwiftUI, no dependencies, no Dock icon.

<p align="center">
  <img src="docs/screenshot.png" alt="The countdown running in the macOS menu bar, with the popover open below it: timer, transport controls, force-start buttons, session stats and the expanded settings" width="380">
</p>

## Features

- Live countdown in the menu bar (emoji changes with the phase)
- Configurable focus / short break / long break lengths and long-break interval
- **Long breaks can be turned off** entirely — then every break is a short one
- **A different chime per phase** — pick any system sound (or none) for the end of a
  focus session, a break, and a long break, with a preview button
- **Global shortcuts** for start/pause, force focus, and force break — registered through
  Carbon, so no Accessibility permission is needed. Default: <kbd>⌃⌥Space</kbd> toggles the
  timer. A shortcut another app already owns is flagged with a warning triangle.
- Auto-start the next session (toggleable)
- **Force start** — jump straight into a focus or break at any point in the cycle
- Daily and weekly completed-session counts, kept for 30 days

## Install

Download the latest release (the repo is private, so use `gh`):

```sh
gh release download --repo kossa/pomodoro --pattern 'Pomodoro-*.zip'
unzip -q Pomodoro-*.zip
xattr -dr com.apple.quarantine Pomodoro.app   # it is ad-hoc signed, not notarized
mv Pomodoro.app /Applications/
open /Applications/Pomodoro.app
```

Requires macOS 14 or later, Apple silicon.

### Build from source

Needs the Swift toolchain — the Command Line Tools are enough.

```sh
./scripts/build-app.sh     # produces ./Pomodoro.app
./scripts/install.sh       # copies it to /Applications and launches it
./scripts/release.sh 1.1.0 # tag, build and publish a GitHub release
```

`Package.swift` is included for building with a full Xcode install. The build script
compiles with `swiftc` directly, because the SwiftPM manifest library shipped with the
Command Line Tools is version-mismatched and cannot compile the manifest.

The app is ad-hoc signed rather than notarized, which is why the `xattr` step above is
needed after downloading. Built locally, it just runs.

## Launch at login

System Settings → General → Login Items → **+** → `/Applications/Pomodoro.app`.

## Layout

| File | Role |
| --- | --- |
| `Sources/Pomodoro/PomodoroApp.swift` | `MenuBarExtra` scene, menu bar title |
| `Sources/Pomodoro/TimerEngine.swift` | Session state; countdown derived from an absolute end date so it survives sleep |
| `Sources/Pomodoro/Phase.swift` | Focus / short break / long break |
| `Sources/Pomodoro/Settings.swift` | Preferences (`@AppStorage`) |
| `Sources/Pomodoro/Stats.swift` | Per-day completed focus counts |
| `Sources/Pomodoro/Notifier.swift` | Notification + chime, with an `osascript` fallback |
| `Sources/Pomodoro/SoundLibrary.swift` | System alert sounds, discovered at runtime |
| `Sources/Pomodoro/HotKeys.swift` | Global shortcut bindings and Carbon registration |
| `Sources/Pomodoro/ShortcutRecorder.swift` | Click-to-record shortcut field |
| `Sources/Pomodoro/MenuView.swift` | The popover UI |

## Icon

`Resources/AppIcon.icns` is generated, not hand-drawn — `swift scripts/make-icon.swift`
redraws every size from code. Edit the drawing in that script to change the icon.

## License

MIT — see [LICENSE](LICENSE).
