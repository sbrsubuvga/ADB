import '../runner/adb_runner.dart';
import '../util/shell_quote.dart';

enum SettingsNamespace { system, secure, global }

extension SettingsNamespaceX on SettingsNamespace {
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

class SettingsService {
  SettingsService(this._runner);
  final AdbRunner _runner;

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

  Future<void> disableAnimations(String serial) async {
    await put(serial, SettingsNamespace.global, 'window_animation_scale', '0');
    await put(
        serial, SettingsNamespace.global, 'transition_animation_scale', '0');
    await put(
        serial, SettingsNamespace.global, 'animator_duration_scale', '0');
  }

  Future<void> restoreAnimations(String serial) async {
    await put(serial, SettingsNamespace.global, 'window_animation_scale', '1');
    await put(
        serial, SettingsNamespace.global, 'transition_animation_scale', '1');
    await put(
        serial, SettingsNamespace.global, 'animator_duration_scale', '1');
  }

  Future<void> setDarkMode(String serial, bool enabled) => _runner.runOk(
        ['shell', 'cmd', 'uimode', 'night', enabled ? 'yes' : 'no'],
        serial: serial,
      );

  Future<void> setFontScale(String serial, double scale) => put(
        serial,
        SettingsNamespace.system,
        'font_scale',
        scale.toString(),
      );

  Future<void> setForceRtl(String serial, bool enabled) => put(
        serial,
        SettingsNamespace.global,
        'debug.force_rtl',
        enabled ? '1' : '0',
      );
}
