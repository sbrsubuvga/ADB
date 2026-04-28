# ADB Vision

A cross-platform **Flutter desktop** front-end for the Android Debug Bridge, built on top of the [`adb_kit`](../adb_kit) Dart package.

> Following the spec in [`docs/ADB_VISION_PROMPT.md`](../docs/ADB_VISION_PROMPT.md). This is the example app for `adb_kit` and exercises every service the package exposes.

## What's in here

| Pane | Capabilities |
|---|---|
| Device picker | Lists `adb devices -l` every 2 s, shows model/state/transport, popup actions for reboot variants and disconnect, dialogs for `connect host:port`, `pair host:port code`, and `tcpip <port>`. |
| Mirror view | Screencap-based live mirror (1–15 fps configurable, FPS counter), per-display dropdown, click → tap, drag → swipe (auto-duration), right click → BACK, middle click → HOME, mouse fwd/back → APP_SWITCH/MENU, scroll wheel → vertical swipe, keyboard forwarding (DPAD/text/special keys), tap-pulse overlay, coordinate HUD. |
| Hotbar | Back / Home / Recents / Power / Sleep / Wake / Vol± / Mute / Rotate / Screenshot / **Record** (full screenrecord + pull) / Lock. |
| Command panel | Tabs: **Input** (text + Unicode broadcast + searchable KEYCODE picker), **Apps** (full `pm list packages` browser + APK install + force-stop / clear / disable / enable / uninstall / dump), **Files** (browser + push + pull + mkdir + rename + delete), **Shell** (interactive command runner with history), **Intents** (full `am start/broadcast/startservice` composer with extras + presets), **Settings** (`settings list` editor + animation/dark-mode/RTL presets), **Network** (Wi-Fi/data/BT/airplane toggles + ip/route/netstat/ping), **Diag** (one-click dumpsys/getprop/top). |
| Logcat dock | Streaming tail with priority filter, regex/substring filter, run/pause, clear-view, clear-device-buffer, color-coded by priority. |
| Action Log dock | Every `adb` command the app runs, with start/end events, exit code, duration, and click-to-copy. |
| Scripts dock | Load/save JSON scripts; add/edit/disable/reorder steps; play/stop with speed slider and loop count; live event log. |
| Settings dialog | Configure `adb` binary path with auto-detect across standard install locations. |

## Run

```bash
flutter pub get
flutter run -d macos    # or -d windows / -d linux
```

`adb` must be installed locally and either on `PATH` or pointed to via the in-app Settings dialog.

## Tested

```bash
flutter analyze
flutter test
```

## Architecture

```
lib/
├── main.dart                        # ProviderScope + MaterialApp
├── state/providers.dart             # Riverpod providers (adbKit, devices, action log…)
└── ui/
    ├── home_shell.dart              # 3-column layout + bottom dock
    ├── widgets/hotbar.dart
    └── panes/
        ├── device_picker.dart
        ├── mirror_view.dart
        ├── action_log_pane.dart
        ├── logcat_pane.dart
        ├── scripts_pane.dart
        ├── command_panel.dart
        ├── settings_pane.dart
        └── cmd/
            ├── input_tab.dart
            ├── apps_tab.dart
            ├── files_tab.dart
            ├── shell_tab.dart
            ├── intents_tab.dart
            ├── settings_tab.dart
            ├── network_tab.dart
            └── diag_tab.dart
```

All ADB calls go through `adb_kit`; no shell-string concatenation lives in the UI layer.

## Known limitations

- **scrcpy H.264 backend not wired** — the screencap fallback runs at 1–15 fps. Wiring an scrcpy native-decoder plugin is the natural next step.
- **No multi-device tabs** — there's one mirror view bound to the selected serial. The package supports parallel sessions; the UI just doesn't open multiple at once yet.
- **No view-hierarchy inspector / OCR / element picker** — these are listed as nice-to-haves in the spec; `uiautomator dump` is reachable through the Shell tab.
- **No CI workflow / installers** — out of scope for this initial cut.
