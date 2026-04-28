# adb_kit

A typed Dart wrapper around the **Android Debug Bridge** (`adb`). Built so Flutter desktop apps, CLI tools, or test harnesses can drive any feature of `adb` without dropping into shell-string concatenation.

> Used by the [`adb_vision`](../adb_vision) example Flutter desktop app — a full GUI for ADB.

## Features

- **Process runner** — `AdbRunner` spawns `adb` once per call, streams stdout/stderr line-by-line, supports cancellation, timeouts, and per-device `-s <serial>` binding. Every invocation is observable through an `AdbObserver` callback.
- **Device management** — `adb devices -l` parsing, polling stream, `connect`, `disconnect`, `pair`, `tcpip`, `wait-for-*`, `reconnect`, `root`/`unroot`, `remount`, `sideload`.
- **Connection** — `forward` / `reverse` lists and edits, `mdns`.
- **Packages** — `pm list packages` with the full flag set, `install` / `install-multiple` / `uninstall` with typed `InstallOptions`, `clear`, `enable`/`disable`/`hide`/`suspend`, `grant`/`revoke`, AOT compile.
- **Activity manager** — `am start` / `broadcast` / `startservice` driven by a typed `IntentSpec`, plus `force-stop`, `kill`, `kill-all`, user switching, current focused activity/window, stack/task lists.
- **Input injection** — typed `InputService` with `tap`, `swipe`, `dragAndDrop`, `text`, `keyEvent`, `motionEvent`, plus a `CoordinateMapper` that translates widget-space coordinates to device-space respecting orientation. `KEYCODE_*` constants on `KeyCode`.
- **Screen** — `screencap` (single PNG and continuous stream), `screenrecord` with all flags, save-to-file helpers. Mirror loop is the **fallback backend** for live mirroring; an scrcpy backend is left as an integration point because it requires a native H.264 decoder.
- **Displays** — `dumpsys display` parser, secondary-display simulation via `overlay_display_devices`, `wm size`/`wm density`/`wm rotation`.
- **Logcat** — streaming tail with `LogcatFilter` (buffers, priority, tags, format, pid, uid), parsed `LogLine` records, snapshot, clear, buffer-size APIs.
- **Files** — `ls -la` parser, `push` / `pull`, `mkdir`, `rm`, `mv`, `cp`, `chmod`, `chown`, `cat`, `find`, `df`, `du`.
- **Shell** — one-shot exec with timeouts and an interactive shell handle for PTY-style use.
- **Settings** — `settings list/get/put/delete` for `system|secure|global` plus convenience presets (disable animations, dark mode, force RTL).
- **Props** — `getprop` (parsed map), `setprop`.
- **Network** — `svc wifi`/`data`/`bluetooth`/`nfc`, `cmd connectivity airplane-mode`, `ip addr`/`route`, `ping`, `netstat`.
- **Power** — typed reboot targets (normal / bootloader / recovery / sideload / fastboot), screen on/off, wake, deviceidle.
- **Dumpsys** — typed `BatteryInfo` plus convenience wrappers for window/activity/meminfo/cpuinfo/gfxinfo/netstats/connectivity/wifi/telephony/location/notification/input/package/usagestats/thermal/alarm/dropbox.
- **Scripts** — JSON-serialisable `Script` model, `ScriptRecorder` for capturing manual interactions, `ScriptPlayer` with playback events, speed control, loops, `wait_for`, `assert`, and `${var}` interpolation.
- **Backup / restore** — `adb backup`/`adb restore` (legacy).

## Install

```yaml
dependencies:
  adb_kit:
    path: ../adb_kit  # or the published version
```

## Usage

```dart
import 'package:adb_kit/adb_kit.dart';

final adb = AdbKit(adbPath: 'adb', observer: (e) => print(e.runtimeType));

await adb.version();              // throws if adb is not on PATH
final devs = await adb.devices.list();
final serial = devs.first.serial;

// Tap on the screen.
await adb.input.tap(serial, x: 540, y: 1200);

// Stream logcat.
final stream = adb.logcat.tail(serial);
final sub = stream.listen(print);
await Future<void>.delayed(const Duration(seconds: 5));
await sub.cancel();

// Run a JSON script.
const json = '''
{
  "name": "demo",
  "steps": [
    {"type": "tap", "x": 540, "y": 1200, "delay_ms": 0},
    {"type": "wait", "ms": 500},
    {"type": "text", "value": "hello"}
  ]
}''';
await for (final event in adb.scripts.play(serial, Script.decode(json))) {
  print(event);
}
```

## Tests

```
dart test
```

The unit tests cover device parsing, package parsing, coordinate mapping, script roundtrip, shell quoting, and intent argument rendering.

## Coverage map

The full ADB surface from the [ADB Vision spec](../docs/ADB_VISION_PROMPT.md) is implemented as follows:

| Spec section | Service |
|---|---|
| 4.1 / 4.2 Connection | `DeviceService`, `ConnectionService` |
| 4.3 / 4.4 Packages | `PackageService` |
| 4.5 Activity manager | `ActivityService` |
| 4.6 Input | `InputService` (+ `CoordinateMapper`) |
| 4.7 Screen capture/record | `ScreenService` |
| 4.8 Displays / orientation | `DisplayService` |
| 4.9 Files / shell | `FileService`, `ShellService` |
| 4.10 Logcat | `LogcatService` |
| 4.11 Diagnostics / props | `DumpsysService`, `PropsService` |
| 4.12 Settings | `SettingsService` |
| 4.13 Intents | `ActivityService` (`IntentSpec`) |
| 4.14 Network | `NetworkService` |
| 4.15 Power / reboot | `PowerService` |
| 4.16 Root / sideload | `DeviceService` |
| 4.17 Backup / restore | `BackupService` |

## Out of scope (yet)

- **scrcpy H.264 backend** — needs a native decoder plugin. Use `ScreenService.mirror()` (screencap polling) for a portable fallback.
- **OCR / view-hierarchy / pixel-RGB asserts** — stubbed, expand `ScriptPlayer._assert` to add more kinds.
