import '../models/display.dart';
import '../runner/adb_runner.dart';

/// Wraps `wm` and `cmd display` for size/density/rotation control.
class DisplayService {
  /// Creates a [DisplayService] backed by [_runner].
  DisplayService(this._runner);
  final AdbRunner _runner;

  /// Enumerate displays. Combines results from `dumpsys display`,
  /// `cmd display list-displays`, and `wm size` so virtual / overlay
  /// displays aren't missed when one of the parsers returns nothing.
  Future<List<AdbDisplay>> list(String serial) async {
    final byId = <int, AdbDisplay>{};

    Future<String> run(List<String> args) async {
      final r = await _runner.run(
        args,
        serial: serial,
        timeout: const Duration(seconds: 30),
      );
      return r.isSuccess ? r.stdout : '';
    }

    final dump = await run(['shell', 'dumpsys', 'display']);
    for (final d in AdbDisplay.parseDumpsysDisplay(dump)) {
      byId[d.id] = d;
    }

    // Make sure every id reported by `cmd display list-displays` is present,
    // even if the dumpsys parser missed it.
    final cmdOut = await run(['shell', 'cmd', 'display', 'list-displays']);
    for (final id in AdbDisplay.parseCmdDisplayList(cmdOut)) {
      byId.putIfAbsent(
        id,
        () => AdbDisplay(
          id: id,
          width: 1080,
          height: 1920,
          isPrimary: id == 0,
        ),
      );
    }

    // If we still have nothing, fall back to `wm size`/`wm density`.
    if (byId.isEmpty) {
      final size = await run(['shell', 'wm', 'size']);
      final density = await run(['shell', 'wm', 'density']);
      final sz = AdbDisplay.parseWmSize(size);
      if (sz != null) {
        byId[0] = AdbDisplay(
          id: 0,
          width: sz.$1,
          height: sz.$2,
          densityDpi: AdbDisplay.parseWmDensity(density),
          isPrimary: true,
        );
      }
    }

    final list = byId.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    return list;
  }

  /// Sets the override display resolution to [width]x[height].
  Future<void> setSize(String serial, int width, int height) => _runner
      .runOk(['shell', 'wm', 'size', '${width}x$height'], serial: serial);

  /// Clears any size override and restores the physical resolution.
  Future<void> resetSize(String serial) =>
      _runner.runOk(['shell', 'wm', 'size', 'reset'], serial: serial);

  /// Sets the override display density to [dpi].
  Future<void> setDensity(String serial, int dpi) =>
      _runner.runOk(['shell', 'wm', 'density', '$dpi'], serial: serial);

  /// Clears any density override and restores the physical dpi.
  Future<void> resetDensity(String serial) =>
      _runner.runOk(['shell', 'wm', 'density', 'reset'], serial: serial);

  /// Locks user rotation to [quarter] (0..3).
  Future<void> setRotation(String serial, int quarter) => _runner.runOk(
        ['shell', 'wm', 'user-rotation', 'lock', '$quarter'],
        serial: serial,
      );

  /// Releases the user-rotation lock.
  Future<void> unfreezeRotation(String serial) =>
      _runner.runOk(['shell', 'wm', 'user-rotation', 'free'], serial: serial);

  /// Android 10+ secondary display simulation.
  /// [spec] is e.g. `1080x1920/320` or several joined by `;`.
  Future<void> setOverlayDisplays(String serial, String spec) => _runner.runOk(
        ['shell', 'settings', 'put', 'global', 'overlay_display_devices', spec],
        serial: serial,
      );

  /// Read the current value (may be null).
  Future<String?> getOverlayDisplays(String serial) async {
    final r = await _runner.run(
      ['shell', 'settings', 'get', 'global', 'overlay_display_devices'],
      serial: serial,
    );
    final out = r.stdout.trim();
    if (!r.isSuccess || out.isEmpty || out == 'null') return null;
    return out;
  }

  /// Removes any overlay display configuration.
  Future<void> clearOverlayDisplays(String serial) => _runner.runOk(
        ['shell', 'settings', 'delete', 'global', 'overlay_display_devices'],
        serial: serial,
      );

  /// Sets the screen brightness (0..255).
  Future<void> setBrightness(String serial, int value) => _runner.runOk(
        ['shell', 'settings', 'put', 'system', 'screen_brightness', '$value'],
        serial: serial,
      );

  /// Configures the `svc power stayon` mode (e.g. `true`, `usb`, `ac`).
  Future<void> stayOn(String serial, String mode) =>
      _runner.runOk(['shell', 'svc', 'power', 'stayon', mode], serial: serial);
}
