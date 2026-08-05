# Changelog

All notable changes to Pomodoro. Versions follow [semantic versioning](https://semver.org):
a minor bump for new features, a patch bump for fixes.

## Unreleased

- A landing page at [kossa.github.io/pomodoro](https://kossa.github.io/pomodoro/),
  served by GitHub Pages from `docs/`.

## [1.5.0] — 2026-08-05

- Start the next session straight from the notification. When auto-start is off, the
  end-of-session banner carries a **Start Focus** / **Start Break** button, and clicking
  the banner itself does the same.
- The banner is no longer suppressed while the app happens to be the active one.
- README: a comparison table, a centred header leading with the app icon, and a
  screenshot showing the tabbed settings.

## [1.4.1] — 2026-08-04

- Cut the cost of the per-second update and of the popover layout, so the menu bar
  item no longer re-lays-out on every tick.

## [1.4.0] — 2026-08-04

- Settings split into **Timer / Sounds / Shortcuts / General** tabs, keeping the
  popover short.
- The tomato, the minutes and the seconds in the menu bar can each be shown or hidden
  on their own.

## [1.3.0] — 2026-08-04

- Self-updating: a daily (or on-demand) check against GitHub releases, then a
  verified in-place install of the new version.

## [1.2.0] — 2026-08-04

- Durations can be typed directly, not only stepped.
- The whole settings row is clickable.

## [1.1.1] — 2026-08-04

- Keep AppleDouble `._*` files out of the release zip, which had been breaking the
  code signature on unpack.
- Document `ditto` rather than `unzip` in the install steps.

## [1.1.0] — 2026-08-04

- The menu bar can show the tomato, the time, or both.
- Drop `--sequesterRsrc` so the release zip has no `__MACOSX` folder.

## [1.0.0] — 2026-08-04

First release: a native macOS menu bar Pomodoro timer.

- Focus / short break / long break with a configurable long-break interval, and long
  breaks that can be turned off entirely.
- A different chime per phase, chosen from the system sounds, with a preview button.
- Global shortcuts for start/pause, force focus and force break, registered through
  Carbon so no Accessibility permission is needed.
- Auto-start the next session, force start into any phase, and daily/weekly
  completed-session counts kept for 30 days.

[1.5.0]: https://github.com/kossa/pomodoro/releases/tag/v1.5.0
[1.4.1]: https://github.com/kossa/pomodoro/releases/tag/v1.4.1
[1.4.0]: https://github.com/kossa/pomodoro/releases/tag/v1.4.0
[1.3.0]: https://github.com/kossa/pomodoro/releases/tag/v1.3.0
[1.2.0]: https://github.com/kossa/pomodoro/releases/tag/v1.2.0
[1.1.1]: https://github.com/kossa/pomodoro/releases/tag/v1.1.1
[1.1.0]: https://github.com/kossa/pomodoro/releases/tag/v1.1.0
[1.0.0]: https://github.com/kossa/pomodoro/releases/tag/v1.0.0
