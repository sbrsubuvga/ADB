import '../runner/adb_runner.dart';

/// `adb backup` / `adb restore` — deprecated on Android 12+ but still useful
/// for older devices.
class BackupService {
  BackupService(this._runner);
  final AdbRunner _runner;

  Future<String> backup(
    String serial,
    String localPath, {
    bool includeApk = false,
    bool includeObb = false,
    bool includeShared = false,
    bool includeSystem = true,
    bool all = false,
    List<String> packages = const [],
  }) =>
      _runner.runOk(
        [
          'backup',
          '-f', localPath,
          if (includeApk) '-apk' else '-noapk',
          if (includeObb) '-obb' else '-noobb',
          if (includeShared) '-shared' else '-noshared',
          if (includeSystem) '-system' else '-nosystem',
          if (all) '-all',
          ...packages,
        ],
        serial: serial,
        timeout: const Duration(minutes: 30),
      );

  Future<String> restore(String serial, String localPath) => _runner.runOk(
        ['restore', localPath],
        serial: serial,
        timeout: const Duration(minutes: 30),
      );
}
