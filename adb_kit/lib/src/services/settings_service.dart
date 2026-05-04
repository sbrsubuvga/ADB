import '../runner/adb_runner.dart';
import '../util/shell_quote.dart';

/// `settings` namespaces understood by `settings get|put|...`.
enum SettingsNamespace { system, secure, global }

/// Helpers for [SettingsNamespace].
extension SettingsNamespaceX on SettingsNamespace {
  /// CLI token passed to `settings`.
  String get token {
    switch (this) {
      case SettingsNamespace.system:
        return 'system';
      case SettingsNamespace.secure:
        return 'secure';
      case SettingsNamespace.global:
        return 'global';
    }
  }
}

/// Wraps the `settings` shell command and a few common presets.
class SettingsService {
  /// Creates a [SettingsService] backed by [_runner].
  SettingsService(this._runner);
  final AdbRunner _runner;

  /// Returns every key/value pair in [ns].
  Future<Map<String, String>> list(
    String serial,
    SettingsNamespace ns,
  ) async {
    final out = await _runner.runOk(
      ['shell', 'settings', 'list', ns.token],
      serial: serial,
    );
    final map = <String, String>{};
    for (final line in out.split('\n')) {
      final idx = line.indexOf('=');
      if (idx <= 0) continue;
      map[line.substring(0, idx)] = line.substring(idx + 1);
    }
    return map;
  }

  /// Reads `settings get [ns] [key]`.
  Future<String> get(
    String serial,
    SettingsNamespace ns,
    String key,
  ) async =>
      (await _runner.runOk(
        ['shell', 'settings', 'get', ns.token, key],
        serial: serial,
      ))
          .trim();

  /// Writes `settings put [ns] [key] [value]`.
  Future<void> put(
    String serial,
    SettingsNamespace ns,
    String key,
    String value,
  ) =>
      _runner.runOk(
        ['shell', 'settings', 'put', ns.token, key, shellQuote(value)],
        serial: serial,
      );

  /// Deletes a settings key.
  Future<void> delete(
    String serial,
    SettingsNamespace ns,
    String key,
  ) =>
      _runner.runOk(
        ['shell', 'settings', 'delete', ns.token, key],
        serial: serial,
      );

  // -- presets --

  /// Sets every animation scale to 0.
  Future<void> disableAnimations(String serial) async {
    await put(serial, SettingsNamespace.global, 'window_animation_scale', '0');
    await put(
        serial, SettingsNamespace.global, 'transition_animation_scale', '0');
    await put(serial, SettingsNamespace.global, 'animator_duration_scale', '0');
  }

  /// Resets every animation scale to 1.
  Future<void> restoreAnimations(String serial) async {
    await put(serial, SettingsNamespace.global, 'window_animation_scale', '1');
    await put(
        serial, SettingsNamespace.global, 'transition_animation_scale', '1');
    await put(serial, SettingsNamespace.global, 'animator_duration_scale', '1');
  }

  /// Toggles system dark mode.
  Future<void> setDarkMode(String serial, bool enabled) => _runner.runOk(
        ['shell', 'cmd', 'uimode', 'night', enabled ? 'yes' : 'no'],
        serial: serial,
      );

  /// Sets the system font scale (1.0 = 100%).
  Future<void> setFontScale(String serial, double scale) => put(
        serial,
        SettingsNamespace.system,
        'font_scale',
        scale.toString(),
      );

  /// Toggles `debug.force_rtl`.
  Future<void> setForceRtl(String serial, bool enabled) => put(
        serial,
        SettingsNamespace.global,
        'debug.force_rtl',
        enabled ? '1' : '0',
      );
}
