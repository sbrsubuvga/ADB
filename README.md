# ADB — adb_kit + ADB Vision

This monorepo contains:

| Folder | Description |
|---|---|
| [`adb_kit/`](adb_kit/) | A typed Dart package that wraps every major Android Debug Bridge command — devices, packages, input, screen, files, logcat, intents, settings, dumpsys, scripts, etc. Pure Dart, unit-tested, no Flutter dependency. Published to pub.dev as [`adb_kit`](https://pub.dev/packages/adb_kit). |
| [`adb_kit/example/`](adb_kit/example/) | **ADB Vision** — a Flutter desktop example app (macOS / Windows / Linux) that uses `adb_kit` to provide a complete GUI for ADB: live mirror, input injection, package manager, file manager, logcat, intent composer, scripting/recording. |
| [`docs/`](docs/) | The original `ADB_VISION_PROMPT.md` spec that drove the design. |

## Get started

```bash
# Run the unit tests for the package.
cd adb_kit && dart pub get && dart test

# Run the example desktop app (macOS shown).
cd adb_kit/example && flutter pub get && flutter run -d macos
```

Make sure `adb` is installed locally — either on `$PATH` or configured via the in-app Settings dialog. The app auto-detects standard Android Platform-Tools install locations.

## What's covered vs. the original spec

The spec in [`docs/ADB_VISION_PROMPT.md`](docs/ADB_VISION_PROMPT.md) is large enough to fill weeks. This repo delivers:

- Every ADB subcommand from spec section 4.1–4.17 has a typed entry-point in `adb_kit`.
- Live device list, multi-display awareness, full input injection with coordinate mapping and rotation handling, hotbar, screenshot, screen recording.
- Streaming logcat with priority/text filters and an Action Log of every command the GUI runs.
- Package manager browser, APK install/uninstall/clear/disable, intent composer, settings editor with presets, network toggles, diagnostics dashboard.
- JSON-serialisable script model, `ScriptRecorder` / `ScriptPlayer` with speed/loops/`wait_for`/asserts/`${var}` interpolation, full editor UI.

Out of scope for the initial cut:
- scrcpy H.264 mirror backend — needs a native decoder plugin; the screencap fallback runs at 1–15 fps.
- View-hierarchy inspector / OCR / pixel-RGB asserts — `ScriptPlayer._assert` is the integration point.
- CI workflow / installers / i18n.

See each project's README for details.
