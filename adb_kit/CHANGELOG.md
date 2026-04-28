# Changelog

## 0.1.0

Initial release.

- `AdbRunner` process layer with streaming, cancellation, timeouts, observer hooks.
- `DeviceService`, `ConnectionService`, `PackageService`, `ActivityService`, `InputService`, `ScreenService`, `DisplayService`, `LogcatService`, `FileService`, `ShellService`, `SettingsService`, `PropsService`, `NetworkService`, `PowerService`, `DumpsysService`, `BackupService`.
- Typed models: `AdbDevice`, `AdbDisplay`, `AdbPackage`, `LogLine`, `FileEntry`, `IntentSpec`, `KeyCode`, `Script`/`ScriptStep`.
- `ScriptRecorder` + `ScriptPlayer` with `wait_for`, asserts, variable interpolation.
- Unit tests for parsing, coordinate mapping, script roundtripping, shell quoting, intent rendering.
