# 🍅 Pomodoro

A native macOS menu bar Pomodoro timer. SwiftUI, no dependencies, no Dock icon.

```
  🍅 24:13          ← live countdown in the menu bar
 ┌──────────────────────┐
 │   🍅  Focus          │
 │       24:13          │
 │  ▓▓▓▓▓░░░░░░░░░░░░   │
 │  Start  Reset  Skip  │
 │  Force start         │
 │  🍅 Focus ☕️ Break 🌴 │
 │  3 today · 11 week   │
 │  ▸ Settings          │
 │  Quit Pomodoro       │
 └──────────────────────┘
```

## Features

- Live countdown in the menu bar (emoji changes with the phase)
- Configurable focus / short break / long break lengths and long-break interval
- Notification + chime when a session ends
- Auto-start the next session (toggleable)
- **Force start** — jump straight into a focus or break at any point in the cycle
- Daily and weekly completed-session counts, kept for 30 days

## Build & install

Requires macOS 14+ and the Swift toolchain (Command Line Tools are enough).

```sh
./scripts/build-app.sh     # produces ./Pomodoro.app
./scripts/install.sh       # copies it to /Applications and launches it
```

`Package.swift` is included for building with a full Xcode install. The build script
compiles with `swiftc` directly, because the SwiftPM manifest library shipped with the
Command Line Tools is version-mismatched and cannot compile the manifest.

The app is ad-hoc signed — fine on the machine that built it. On another Mac, right-click
→ Open the first time.

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
| `Sources/Pomodoro/MenuView.swift` | The popover UI |

## License

MIT — see [LICENSE](LICENSE).
