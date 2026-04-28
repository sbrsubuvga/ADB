# ADB VISION — Master Build Prompt

> Use this prompt to instruct an AI coding agent (or yourself) to build a complete **Flutter Desktop** application that wraps the **Android Debug Bridge (adb)** with a live-mirrored display, full UI for every ADB function, multi-display support, and record / replay automation. Copy the entire document below the `=== PROMPT START ===` marker and paste it into your coding agent.

---

## === PROMPT START ===

You are building **ADB Vision**, a cross-platform Flutter Desktop application (Windows, macOS, Linux) that provides a complete graphical front-end for the Android Debug Bridge. It must let the user **see** any display of any connected Android device in real time and **do anything adb can do** — tap, swipe, scroll, type, install, uninstall, record, broadcast intents, read logcat, manage files, control settings, reboot, sideload, and more — all through a polished GUI, with optional scripting and record-replay.

Do **not** stop at a minimum viable product. Implement every feature listed below. Treat this document as the specification.

---

### 1. HARD REQUIREMENTS

1. **Stack**: Flutter 3.x, Dart 3.x, desktop embeddings enabled for Windows/macOS/Linux. No mobile target.
2. **ADB dependency**: bundle or detect `adb` (Android SDK Platform-Tools) at runtime. Fallback: let the user point to a custom `adb` binary in settings. Detect `adb --version` on startup.
3. **No rooting required** on target devices. USB debugging must be the only precondition.
4. **Live mirroring**: two backends, selectable at runtime.
   - **Fast backend (default)**: spawn a bundled `scrcpy` binary with `--no-window --no-audio --max-fps=60` and consume its H.264 stream (decode via FFmpeg / `video_player` / a native decoder plugin). Target 30–60 fps, sub-100 ms latency.
   - **Fallback backend**: `adb exec-out screencap -p` polled at ~5 fps, decoded as PNG. Must work on any device with adb alone.
   - The user can switch backends per session.
5. **Multi-display**: enumerate every display on the device (`dumpsys SurfaceFlinger --display-id`, `dumpsys display`) and allow the user to mirror/control any of them. Support Android 10+ virtual displays created via `adb shell settings put global overlay_display_devices "..."`.
6. **Full input coordinate mapping**: mouse → device coordinates, with aware handling of orientation, device density, and secondary displays.
7. **Three use cases, all in one app**:
   - **Manual mode** — user clicks/drags/types in the mirror and it is injected into the device live.
   - **Scripted mode** — user writes / edits / loads a JSON script of actions and runs it.
   - **Record-replay mode** — every manual action is recorded into a JSON timeline that can be replayed with configurable speed, loop count, and per-step delay.
8. **Multi-device**: list all attached devices/emulators, connect to TCP/IP devices (`adb connect host:port`), pair Android 11+ wireless devices (`adb pair host:port`), and show an independent mirror tab per device.
9. **Never block the UI thread**. All `adb` calls go through a worker isolate / `Process.start`. Use streaming APIs, not buffered ones, for logcat and screen capture.
10. **Observable**: a persistent Action Log pane shows every adb command executed and its exit code, plus stdout/stderr.

---

### 2. ARCHITECTURE

Build the following layered architecture:

```
┌────────────────────────────────────────────────────────┐
│  UI (Flutter widgets, Riverpod/Bloc state)             │
│  ├─ DevicePicker      ├─ MirrorView     ├─ CommandPanel│
│  ├─ ActionLog         ├─ Logcat         ├─ FileManager │
│  ├─ PackageManager    ├─ Scripts        ├─ Settings    │
├────────────────────────────────────────────────────────┤
│  Services (Dart, pure logic, unit-testable)            │
│  ├─ AdbService        ── wraps every adb subcommand    │
│  ├─ ScreenMirrorService  (scrcpy + screencap backends) │
│  ├─ InputInjectionService (tap/swipe/text/key/motion)  │
│  ├─ DisplayService    ── enumerate + control displays  │
│  ├─ LogcatService     ── streaming tail + filters      │
│  ├─ PackageService    ── install/uninstall/query apps  │
│  ├─ FileService       ── push/pull/ls/rm/mkdir         │
│  ├─ ScriptService     ── record/save/load/play JSON    │
│  ├─ DeviceInfoService ── getprop, dumpsys, battery…    │
│  └─ SettingsService   ── adb path, prefs, theme        │
├────────────────────────────────────────────────────────┤
│  Process layer (Dart Isolate)                          │
│  └─ AdbProcessRunner  ── spawn, stream, cancel, queue  │
├────────────────────────────────────────────────────────┤
│  adb / scrcpy binaries                                 │
└────────────────────────────────────────────────────────┘
```

- **AdbProcessRunner** must support: spawn, stream stdout/stderr line-by-line, kill, queue, timeout, per-device binding (`-s <serial>`).
- **AdbService** exposes a typed method per adb subcommand (see Section 4).
- Use `freezed` + `json_serializable` for all data models (Device, Display, Package, LogLine, ScriptStep…).
- Use **Riverpod** for state management. Expose providers for each service.

---

### 3. UI LAYOUT

Single main window split into resizable panes:

```
┌──────────┬────────────────────────┬──────────────┐
│  Device  │                        │  Command     │
│  Picker  │     MIRROR VIEW        │  Panel       │
│  + tabs  │  (live device screen)  │  (tabs:      │
│          │                        │   Input,     │
│          │                        │   Apps,      │
│          │                        │   Files,     │
│          │                        │   Shell,     │
│          │                        │   Settings,  │
│          │                        │   Intents,   │
│          │                        │   Media,     │
│          │                        │   Network)   │
├──────────┴────────────────────────┴──────────────┤
│  Bottom dock (tabbed):                           │
│  Logcat │ Action Log │ Scripts │ Perf │ Events   │
└──────────────────────────────────────────────────┘
```

- **Top bar**: global device indicator, mirror backend toggle, FPS counter, record button, play button, stop-all button.
- **Left rail**: device tree — one node per device, expandable to show per-device displays, users, running apps.
- **Context menu** on the mirror: copy pixel, save screenshot, start recording, inspect view hierarchy (`uiautomator dump`), toggle touch visualization, rotate virtual orientation.
- **Hotbar** docked above the mirror: Back, Home, Recents, Power, Volume±, Mute, Rotate, Wake, Lock, Screenshot, Record.
- **Drag-and-drop**:
  - Drop an `.apk` onto the mirror → install (with flags dialog).
  - Drop any file onto the mirror → `adb push` to `/sdcard/Download/`.
  - Drag from the device file manager pane to the OS desktop → `adb pull`.

---

### 4. COMPLETE ADB COMMAND COVERAGE

Implement a UI control for **every** item below. Group them into the tabs shown in Section 3. No command should be hidden behind "advanced only" — just organize sensibly with search.

#### 4.1 Global / server
- `adb --version`, `adb help`
- `adb start-server`, `adb kill-server`
- `adb devices`, `adb devices -l` (verbose)
- `adb -s <serial> <cmd>`, `adb -d`, `adb -e`, `adb -t <transport-id>`
- `adb wait-for-device`, `adb wait-for-<state>` (device/recovery/sideload/bootloader)
- `adb reconnect`, `adb reconnect device`, `adb reconnect offline`

#### 4.2 Connection
- `adb connect <host>[:port]`
- `adb disconnect [<host>[:port]]`
- `adb pair <host>:<port>` (Android 11+ wireless pairing)
- `adb tcpip <port>` / `adb usb`
- `adb forward --list`, `adb forward <local> <remote>`, `adb forward --remove <local>`, `adb forward --remove-all`
- `adb reverse --list`, `adb reverse <remote> <local>`, `adb reverse --remove`, `adb reverse --remove-all`
- `adb mdns check`, `adb mdns services`

#### 4.3 App install / uninstall
- `adb install <apk>` with all flags: `-r` (reinstall), `-t` (allow test), `-d` (downgrade), `-g` (grant all perms), `-s` (to sd), `--user <id>`, `--abi <abi>`, `--no-streaming`, `--instant`
- `adb install-multiple <apks...>` (split APKs)
- `adb install-multi-package <apks...>`
- `adb uninstall [-k] <package>` (keep data flag)
- `adb shell pm install`, `pm install-create`, `pm install-write`, `pm install-commit`, `pm install-abandon`
- `adb shell pm uninstall [-k] [--user <id>] <package>`
- `adb shell cmd package install-existing <package>`

#### 4.4 Package manager (UI list with search, filter, actions)
- `pm list packages` with flags: `-f` (path), `-d` (disabled), `-e` (enabled), `-s` (system), `-3` (third-party), `-i` (installer), `-u` (include uninstalled), `-U` (UID), `--show-versioncode`, `--apex-only`, `--user <id>`, `--uid <uid>`
- `pm list permissions [-g][-f][-d][-u]`
- `pm list instrumentation`, `pm list features`, `pm list libraries`, `pm list users`
- `pm path <package>`
- `pm dump <package>`
- `pm clear <package>` (clear app data)
- `pm enable <pkg|component>` / `pm disable <pkg|component>` / `pm disable-user --user 0 <pkg>`
- `pm hide` / `pm unhide` / `pm suspend` / `pm unsuspend`
- `pm grant <pkg> <perm>` / `pm revoke <pkg> <perm>`
- `pm reset-permissions`
- `pm set-home-activity <component>`
- `pm set-app-link <pkg> <state>`
- `pm trim-caches <size>`
- `pm create-user`, `pm remove-user`, `pm switch-user`
- `cmd package compile -m speed -f <pkg>` (force AOT compile)

#### 4.5 Activity Manager (`am`)
- `am start [-a ACTION] [-d URI] [-t MIME] [-c CATEGORY] [-n COMPONENT] [-f FLAGS] [-W] [--user <id>] [--display <id>]`
- `am start-activity`, `am startservice`, `am start-foreground-service`, `am stopservice`
- `am broadcast [-a ACTION] [--ei|--es|--ez|--el <key> <val>] -p <pkg>`
- `am force-stop <package>`
- `am kill <package>`, `am kill-all`
- `am crash <package>` (fuzz / simulate crash, root only)
- `am instrument [-w] [-r] [-e <key> <val>] <component>`
- `am monitor`, `am hang`, `am restart`
- `am idle-maintenance`
- `am to-uri`, `am to-intent-uri`, `am to-app-uri`
- `am get-current-user`, `am switch-user <id>`
- `am stack list`, `am stack info`, `am task list`, `am task focus`, `am task lock`
- `am display move-stack <stack> <display>`
- `am set-debug-app [-w] [--persistent] <pkg>` / `am clear-debug-app`
- `am set-watch-heap <pkg> <size>`
- `am get-config`, `am resize-stack`

#### 4.6 Input injection (the heart of the app)
- `input [<source>] tap <x> <y>` — sources: `touchscreen`, `touchpad`, `mouse`, `stylus`, `dpad`, `keyboard`, `gamepad`, `trackball`, `joystick`, `touchnavigation`
- `input swipe <x1> <y1> <x2> <y2> [duration_ms]` — also used for scroll and long-press (same start/end + duration)
- `input draganddrop <x1> <y1> <x2> <y2> [duration_ms]`
- `input text <string>` (ASCII only — warn the user; ship the **ADBKeyboard** IME as an optional companion for Unicode/emoji/CJK input via broadcast intent `ADB_INPUT_TEXT`)
- `input keyevent [--longpress] <keycode|name>` — expose the **entire** `KEYCODE_*` list as a searchable picker (POWER, HOME, BACK, MENU, RECENTS, VOLUME_UP/DOWN/MUTE, BRIGHTNESS_UP/DOWN, MEDIA_PLAY_PAUSE, CAMERA, CALL, ENDCALL, SEARCH, ENTER, TAB, ESC, F1-F12, NUMPAD_*, CTRL/SHIFT/ALT/META modifiers, DPAD_UP/DOWN/LEFT/RIGHT/CENTER, APP_SWITCH, SLEEP, WAKEUP, ASSIST, VOICE_ASSIST, NOTIFICATION, etc.)
- `input press` (trackball)
- `input roll <dx> <dy>` (trackball)
- `input motionevent <action> <x> <y>` (DOWN/UP/MOVE — enable multi-touch composition)
- All input commands accept `--display <displayId>` — wire this to the selected display.
- Provide a **gesture composer** UI: draw a path with the mouse → emit a sequence of `motionevent`s or a high-density `swipe` chain.

#### 4.7 Screenshot / screen recording
- `adb exec-out screencap -p [-d <displayId>]` → save PNG
- `adb shell screencap -p /sdcard/shot.png` then `adb pull`
- `adb shell screenrecord [--size WxH] [--bit-rate N] [--time-limit S] [--verbose] [--rotate] [--bugreport] [--display-id <id>] [--output-format mp4|h264|frames] /sdcard/out.mp4`
- Offer a "continuous" recorder that rotates files every N minutes (bypassing the 3-minute cap).
- Save screenshots with EXIF-like metadata (device, app in foreground, display id, timestamp).

#### 4.8 Displays & orientation
- `dumpsys SurfaceFlinger --display-id` — list every display with its unique id
- `dumpsys display` — full display info
- `wm size [WxH] [reset]` — change resolution
- `wm density [dpi] [reset]` — change DPI
- `wm overscan <l,t,r,b>`
- `wm rotation [freeze <0|1|2|3>] [unfreeze]`
- `settings put system user_rotation <0-3>`
- `settings put global overlay_display_devices "1080x1920/320;..."` (simulate secondary displays, Android 10+)
- `cmd display get-displays` / `cmd display list-displays`
- `adb shell settings put system screen_brightness <0-255>`
- `adb shell svc power stayon true|false|usb|ac|wireless`

#### 4.9 Shell & file management
- Interactive shell tab (PTY via `adb shell`, with command history, ANSI rendering, tab-completion best-effort)
- File explorer: `ls -la`, `stat`, `cd`, `pwd`, `cat`, `mkdir`, `rm`, `rm -rf`, `mv`, `cp`, `chmod`, `chown`, `ln -s`, `touch`, `find`, `grep`, `df -h`, `du -sh`
- `adb push <local> <remote>` with progress
- `adb pull <remote> <local>` with progress
- `adb sync [all|data|odm|oem|product|system|system_ext|vendor]`
- Preview common files inline: txt, json, xml, png, jpg, apk (manifest + permissions via `aapt dump badging`).

#### 4.10 Logcat
- Full streaming tail with: buffer selection (`main`, `system`, `crash`, `events`, `radio`, `kernel`, `all`), priority filter (V/D/I/W/E/F/S), tag filter, regex filter, PID filter (`--pid`), package filter (`--uid`), format selector (`brief`, `time`, `threadtime`, `long`, `raw`, `tag`, `process`, `color`).
- `logcat -c` (clear), `logcat -g` (buffer sizes), `logcat -G <size>` (resize)
- `logcat -d` snapshot, `logcat -f <file>` save-to-device, `logcat -r <kb>` rotate
- Highlight crashes (AndroidRuntime, libc, tombstone). Auto-link ANR traces.
- Save filtered view to local `.log`.

#### 4.11 Diagnostics / system info
- `adb shell getprop` (full list with search) + `getprop ro.build.version.release`, `ro.product.model`, `ro.serialno`, `ro.product.manufacturer`, etc.
- `adb shell setprop <key> <value>` (root only, warn user)
- `adb shell dumpsys` — expose common subcommands as dedicated views:
  - `dumpsys battery` (+ `set level`, `set status`, `unplug`, `reset`)
  - `dumpsys power`
  - `dumpsys activity activities` / `dumpsys activity services`
  - `dumpsys activity top` (current focused activity)
  - `dumpsys window windows | grep mCurrentFocus`
  - `dumpsys window displays`
  - `dumpsys meminfo <pkg|pid>`
  - `dumpsys cpuinfo`
  - `dumpsys gfxinfo <pkg> [framestats]`
  - `dumpsys netstats`, `dumpsys connectivity`, `dumpsys wifi`
  - `dumpsys telephony.registry`, `dumpsys phone`
  - `dumpsys location`, `dumpsys sensorservice`
  - `dumpsys notification`
  - `dumpsys input`, `dumpsys input_method`
  - `dumpsys package <pkg>`
  - `dumpsys usagestats`
  - `dumpsys deviceidle`
  - `dumpsys thermalservice`
  - `dumpsys SurfaceFlinger`
  - `dumpsys alarm`
  - `dumpsys dropbox`
- `adb shell dumpstate` (full state dump)
- `adb bugreport [path]` (compressed zip, Android 7+)
- `adb shell top -n 1`, `ps -A`, `ps -T <pid>`

#### 4.12 Settings (`settings`)
- `settings list <namespace>` where namespace ∈ `system` | `secure` | `global`
- `settings get <namespace> <key>`
- `settings put <namespace> <key> <value>`
- `settings delete <namespace> <key>`
- Ship presets: toggle dark mode, set accessibility scale, change default browser, set Wi-Fi scan throttle, disable animations (`window_animation_scale`, `transition_animation_scale`, `animator_duration_scale`), force RTL, change font scale, switch locale.

#### 4.13 Intents (full composer)
- UI builder with fields: action, data URI, mime type, categories (multi-select), component (pkg/class), flags (bitmask picker), extras (typed key/value list: `--ei`, `--es`, `--ez`, `--el`, `--ef`, `--eu`, `--ecn`, `--eia`, `--esa`, `--eza`).
- One-click templates: Open URL (`VIEW`), Dial (`DIAL`), Send SMS, Send email (`SENDTO`), Share text/file, Pick image, Capture photo, Open settings sub-screens (`android.settings.WIFI_SETTINGS`, `BLUETOOTH_SETTINGS`, `DEVELOPMENT_SETTINGS`, etc.), Open app info, Open notification panel (`service call statusbar 1`), Toggle airplane mode, Open battery saver.

#### 4.14 Network (`svc`, `cmd`, `ip`)
- `svc wifi enable|disable`
- `svc data enable|disable`
- `svc bluetooth enable|disable`
- `svc nfc enable|disable`
- `svc usb setFunctions [mtp|ptp|rndis|midi|none]`
- `cmd wifi set-wifi-enabled enabled|disabled`
- `cmd wifi connect-network <ssid> <security> <password>`
- `cmd connectivity airplane-mode [enable|disable]`
- `ip addr`, `ip route`, `ifconfig`
- `ping -c <n> <host>`
- `netstat`, `ss`

#### 4.15 Power / reboot
- `adb reboot`
- `adb reboot bootloader`
- `adb reboot recovery`
- `adb reboot sideload` / `adb reboot sideload-auto-reboot`
- `adb reboot fastboot`
- `adb shell svc power reboot`
- `adb shell input keyevent 26` (power / screen off/on)
- `adb shell dumpsys deviceidle force-idle|unforce|step|disable`

#### 4.16 Root / security
- `adb root` / `adb unroot` (userdebug builds only)
- `adb remount` / `adb disable-verity` / `adb enable-verity`
- `adb sideload <zip>`
- `adb shell su -c <cmd>` (if root available)
- Detect and show root status prominently; never silently fail.
- `adb shell cmd statusbar expand-notifications|expand-settings|collapse`

#### 4.17 Backup / restore (deprecated but still useful)
- `adb backup [-f file] [-apk|-noapk] [-obb|-noobb] [-shared|-noshared] [-all] [-system|-nosystem] [<packages>]`
- `adb restore <file>`
- Warn that Android 12+ deprecates this.

#### 4.18 Screen mirroring controls (when using scrcpy backend)
Expose scrcpy flags in a settings panel: `--max-size`, `--max-fps`, `--bit-rate`, `--video-codec h264|h265|av1`, `--audio-codec opus|aac|raw`, `--turn-screen-off`, `--stay-awake`, `--show-touches`, `--disable-screensaver`, `--no-audio`, `--record <file>`, `--new-display`, `--display-id <id>`, `--otg`, `--camera`, `--rotation`, `--crop WxH:x:y`, `--window-borderless`, `--always-on-top`, `--keyboard=uhid|aoa|sdk`.

---

### 5. MIRROR VIEW — PRECISE BEHAVIOR

- Render the mirror in a `CustomPaint` with a `FittedBox(BoxFit.contain)` so the aspect ratio is preserved regardless of window size.
- Transform **widget-space** coordinates `(wx, wy)` to **device-space** `(dx, dy)` on every pointer event using the current `displayWidth × displayHeight` and the widget's rendered rectangle.
- Inject via `adb shell input ... --display <id>`.
- Pointer handling:
  - Left click → `input tap`.
  - Left drag → `input swipe` with computed duration (use mouse velocity; clamp 80–1000 ms).
  - Right click → `input keyevent KEYCODE_BACK`.
  - Middle click → `input keyevent KEYCODE_HOME`.
  - Scroll wheel → `input swipe` with short vertical delta (customize sensitivity in settings).
  - Mouse forward/back buttons → `KEYCODE_APP_SWITCH`, `KEYCODE_MENU`.
- Keyboard forwarding:
  - Regular keys → `input text` (batched; flush on idle > 30 ms).
  - Non-ASCII, emoji → if **ADBKeyboard** companion app is installed and set as IME (`ime set com.android.adbkeyboard/.AdbIME`), send via `am broadcast -a ADB_INPUT_TEXT --es msg "<text>"`.
  - Modifiers + key → proper `KEYCODE_*` with `--metaState`.
- **Tap pulse overlay**: paint an animated expanding circle (≈600 ms) at every outgoing tap location, in the widget-space coordinate.
- **Touch visualization**: toggle `settings put system show_touches 1` on the device to mirror system touch feedback.
- **Coordinate HUD**: small always-visible label showing current `(x, y)` in device pixels.
- **Zoom / pan**: Ctrl+scroll zooms, middle-drag pans, `0` key resets.

---

### 6. SCRIPTING & RECORD-REPLAY

Define this JSON schema and implement a full editor + runner:

```json
{
  "name": "Login flow",
  "device": "emulator-5554",
  "display": 0,
  "created": "2026-04-20T10:00:00Z",
  "steps": [
    { "type": "tap",      "x": 540, "y": 1200, "delay_ms": 500 },
    { "type": "swipe",    "x1": 100, "y1": 1500, "x2": 100, "y2": 300, "duration_ms": 300 },
    { "type": "text",     "value": "hello world" },
    { "type": "key",      "keycode": "KEYCODE_ENTER" },
    { "type": "wait",     "ms": 1000 },
    { "type": "wait_for", "condition": "activity", "value": "com.foo/.Main", "timeout_ms": 5000 },
    { "type": "wait_for", "condition": "logcat_regex", "value": "Login successful", "timeout_ms": 10000 },
    { "type": "screenshot", "path": "step5.png" },
    { "type": "shell",    "cmd": "input keyevent KEYCODE_BACK" },
    { "type": "intent",   "action": "android.intent.action.VIEW", "data": "https://example.com" },
    { "type": "assert",   "kind": "pixel_rgb", "x": 100, "y": 200, "rgb": [255,0,0], "tolerance": 10 },
    { "type": "assert",   "kind": "ocr_contains", "region": [0,0,1080,200], "text": "Welcome" }
  ]
}
```

- **Recorder** captures every manual action (tap, swipe, text, key, scroll) with real timings. Timestamps become `delay_ms` between steps.
- **Player** runs a script with: play, pause, step-over, step-back, breakpoints on step index, speed 0.25×–4×, loop N times, stop-on-error toggle.
- **Editor**: tree view on the left, form panel on the right per step, drag-reorder, duplicate, disable step, inline comments.
- **Import/Export**: JSON, plus a .scrcpy-events format for interop.
- **Assertions**: pixel color, OCR on a region (bundle `tesseract` optionally), `dumpsys window` focus equals, logcat regex match.
- **Variables** and simple `${var}` interpolation (e.g., `${device.serial}`, `${env.HOME}`, user-defined).

---

### 7. DEVICE PICKER / MULTI-DEVICE

- Poll `adb devices -l` every 2 s.
- Per device show: serial, model, product, transport (USB/TCP), state (device/offline/unauthorized/sideload/recovery/bootloader), Android version, battery %, foreground app, active display count.
- Actions per device: mirror, open shell, open logcat, reboot ▸ submenu, disconnect, pair wireless, authorize (prompt user).
- Allow multiple simultaneous mirror tabs (up to device count × display count).

---

### 8. NON-FUNCTIONAL REQUIREMENTS

- **Performance**: mirror ≥30 fps on Full-HD devices with scrcpy backend; ≤150 MB RAM per device tab.
- **Startup**: cold start ≤2 s on a mid-range desktop.
- **Resilience**: every adb call is cancellable; the UI never freezes on a hung adb.
- **Logging**: write a rotating `adb_vision.log` to the OS app-support dir. Include command, duration, exit code, stderr tail.
- **Persistence**: remember window layout, last selected device, recent scripts, adb path, scrcpy flags, user-created settings presets, theme.
- **Internationalization**: English first, but wrap all strings in `AppLocalizations` so more locales can be added.
- **Theming**: Material 3, light / dark / system, high-contrast mode.
- **Accessibility**: every interactive widget has a `Semantics` label; keyboard shortcuts documented and remappable.

---

### 9. ERROR HANDLING & SAFETY

- Never execute a destructive command (uninstall, clear data, factory-like settings, pm disable system app, reboot bootloader, wipe data) without a modal confirmation that shows the exact shell command being run.
- For `adb shell su` / root-required commands, detect non-root early and surface a clear inline error rather than a cryptic adb failure.
- Sanitize all user-provided strings going into the shell (quote with single quotes, escape `'` correctly) — do not use naive string concatenation.
- Timeout every non-streaming adb call (default 15 s, configurable).
- Show authorization dialog reminders if `adb devices` returns `unauthorized`.

---

### 10. NICE-TO-HAVES (implement if time permits)

- **Wireless auto-discovery** via `adb mdns services`.
- **QR pairing** for Android 11+ wireless debugging — generate QR on screen.
- **View hierarchy inspector**: parse `uiautomator dump`, render node tree, highlight selected node on the mirror.
- **Element picker**: click in the mirror, get `resource-id`, class, bounds, text — one-click insert into script.
- **OCR overlay**: run Tesseract on the current frame, click a recognized word to copy it.
- **Performance HUD**: live graphs of CPU / GPU / memory / frame time using `dumpsys gfxinfo` and `/proc/stat` deltas.
- **APK inspector**: drop an apk, show manifest, permissions, signatures (`apksigner verify`), dex method count.
- **Network throttle**: toggle `cmd netpolicy` to simulate metered / restricted backgrounds.
- **Emulator control**: detect `emulator-*` serials and expose `telnet localhost <port>` geo, sensor, battery commands.
- **Recording to GIF**: `screenrecord` → `ffmpeg -i ... palette + paletteuse`.
- **Plugin system**: allow user to drop Dart scripts in `~/.adb_vision/plugins/` that register new commands in the Command Palette.
- **Command Palette** (Ctrl+P): fuzzy-search every action in the app and every adb subcommand, Raycast-style.
- **Session export**: zip containing the recorded script, screenshots, logcat, and a markdown replay summary.

---

### 11. DELIVERABLES

1. Full Flutter project rooted at `adb_vision/` with `pubspec.yaml`, `analysis_options.yaml`, platform folders (`windows/`, `macos/`, `linux/`) generated and buildable.
2. One Dart file per service under `lib/services/`.
3. One Dart file per UI pane under `lib/ui/`.
4. Models under `lib/models/` (freezed).
5. State providers under `lib/state/`.
6. Unit tests under `test/` covering `AdbService` argument construction and `InputInjectionService` coordinate mapping, plus at least one integration test that mocks `adb` via a fake `ProcessRunner`.
7. `README.md` with setup, adb/scrcpy installation, screenshots, keyboard shortcuts, and a roadmap.
8. `CHANGELOG.md` starting at `0.1.0`.
9. GitHub-Actions workflow building Windows / macOS / Linux artifacts.

---

### 12. IMPLEMENTATION ORDER

Work through phases strictly in order. Do not jump ahead.

**Phase 1 — Foundation**
- Scaffold Flutter desktop app, enable all three desktop platforms, add Riverpod, freezed, `process_run`, `path_provider`, `window_manager`.
- Implement `AdbProcessRunner` + `AdbService.devices()` + `DevicePicker` UI.

**Phase 2 — Mirror (fallback backend)**
- `ScreenMirrorService` polling `exec-out screencap -p`; render in `MirrorView`; show FPS.

**Phase 3 — Input**
- `InputInjectionService` with tap, swipe, text, keyevent. Full coordinate mapping. Tap-pulse overlay. Hotbar (Back/Home/Recents/Power/Volume).

**Phase 4 — Multi-device + multi-display**
- Tabs per device; display enumeration; per-display mirror and input.

**Phase 5 — Mirror (scrcpy backend)**
- Bundle scrcpy detection, spawn with `--no-display`, decode H.264 via FFmpeg plugin or `video_player` with local HTTP relay. Runtime backend switch.

**Phase 6 — Logcat + Action Log**
- Streaming logcat with filters; persistent Action Log dock.

**Phase 7 — Package manager UI**
- Full `pm list packages` browser, install / uninstall / clear / grant perms / enable / disable.

**Phase 8 — File manager**
- `ls` browser, push/pull with progress, drag-and-drop.

**Phase 9 — Shell / intents / settings / dumpsys tabs**
- All Command Panel tabs from Section 4.

**Phase 10 — Scripts + Recorder**
- JSON schema, editor, recorder, player with asserts and breakpoints.

**Phase 11 — Polish**
- Command Palette, theming, shortcuts, i18n scaffolding, error modals, settings persistence, CI, docs.

**Phase 12 — Nice-to-haves** (Section 10).

---

### 13. CODE STYLE

- Lint: `flutter_lints` + `very_good_analysis`.
- Null-safety everywhere; no `!` unless justified with a comment.
- Every service method returns `Future<Result<T, AdbError>>` — never throw across a service boundary.
- No dynamic typing for adb payloads — model everything.
- Commit in small, reviewable units; every commit builds.

---

### 14. ACCEPTANCE CRITERIA

The build is complete when, on a fresh machine with only Flutter + adb installed, a user can:

1. Launch the app and see every connected Android device.
2. Open a live mirror of any display of any device and drive it with the mouse and keyboard with no perceptible lag.
3. Install an apk by drag-and-drop, then uninstall it from the Packages tab.
4. Record a 30-second interaction, save it as JSON, close the device, reconnect it, and replay the script with asserts passing.
5. Tail logcat with a regex filter while executing an intent from the Intents tab.
6. Simulate a second display via `overlay_display_devices`, open it in a new tab, and tap on it independently of the primary display.
7. Run any adb command listed in Section 4 through the GUI and see the exact shell invocation + result in the Action Log.

If any of the seven is not achievable, keep working.

## === PROMPT END ===

---

## HOW TO USE THIS PROMPT

1. Copy everything between the `=== PROMPT START ===` and `=== PROMPT END ===` markers.
2. Paste it as the first message to your coding agent (Claude Code, Cursor, Aider, etc.).
3. Follow up with: *"Begin Phase 1. Produce the full file tree and the code for each file in that phase before moving on."*
4. After each phase, review and ask the agent to continue with the next phase.

---

## APPENDIX A — Quick adb command index (covered in the prompt)

Global · server · devices · connect · disconnect · pair · tcpip · usb · forward · reverse · mdns · install · install-multiple · uninstall · pm (list / path / dump / clear / enable / disable / grant / revoke / hide / suspend / users) · am (start / broadcast / force-stop / kill / instrument / monitor / stack / task) · input (tap / swipe / text / keyevent / motionevent / draganddrop / press / roll) · screencap · screenrecord · wm (size / density / rotation / overscan) · settings (list / get / put / delete) · getprop · setprop · dumpsys (battery / power / activity / window / meminfo / cpuinfo / gfxinfo / netstats / wifi / telephony / location / notification / input / package / usagestats / deviceidle / thermalservice / SurfaceFlinger / alarm / dropbox) · dumpstate · bugreport · logcat (buffers / priorities / tags / formats / rotate / clear / resize) · svc (wifi / data / bluetooth / nfc / usb / power) · cmd (wifi / connectivity / package / statusbar / display) · ip · ping · netstat · reboot (bootloader / recovery / sideload / fastboot) · root · unroot · remount · disable-verity · sideload · backup · restore · push · pull · sync · shell · exec-out · wait-for-* · reconnect

## APPENDIX B — Android Input sources (for `input <source> …`)

`touchscreen` · `touchpad` · `mouse` · `stylus` · `dpad` · `keyboard` · `gamepad` · `trackball` · `joystick` · `touchnavigation`

## APPENDIX C — Key event categories to expose in the picker

- Navigation: HOME, BACK, MENU, APP_SWITCH, ASSIST, SEARCH, NOTIFICATION
- Media: MEDIA_PLAY_PAUSE, MEDIA_NEXT, MEDIA_PREVIOUS, MEDIA_STOP, MEDIA_REWIND, MEDIA_FAST_FORWARD, MEDIA_RECORD
- Volume: VOLUME_UP, VOLUME_DOWN, VOLUME_MUTE
- Power & wake: POWER, SLEEP, WAKEUP, SOFT_SLEEP
- Telephony: CALL, ENDCALL, VOICE_ASSIST, HEADSETHOOK
- Camera: CAMERA, FOCUS
- Editing: ENTER, TAB, SPACE, DEL, FORWARD_DEL, ESCAPE, CUT, COPY, PASTE, UNDO, REDO
- Navigation keys: DPAD_UP/DOWN/LEFT/RIGHT/CENTER, PAGE_UP, PAGE_DOWN, MOVE_HOME, MOVE_END
- Modifiers: CTRL_LEFT/RIGHT, SHIFT_LEFT/RIGHT, ALT_LEFT/RIGHT, META_LEFT/RIGHT, FN, CAPS_LOCK, NUM_LOCK, SCROLL_LOCK
- Letters / digits / numpad: full set
- Function: F1–F12
- System: SYSRQ, BREAK, ZOOM_IN, ZOOM_OUT, BRIGHTNESS_UP/DOWN, KEYBOARD_BACKLIGHT_UP/DOWN
- Accessibility: SLEEP, WAKEUP, STEM_1/2/3, NAVIGATE_IN/OUT/NEXT/PREVIOUS
