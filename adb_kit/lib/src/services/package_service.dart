import '../models/package.dart';
import '../runner/adb_runner.dart';

class InstallOptions {
  const InstallOptions({
    this.reinstall = true,
    this.allowDowngrade = false,
    this.allowTest = false,
    this.grantRuntimePerms = false,
    this.onSdCard = false,
    this.instant = false,
    this.user,
    this.abi,
    this.installerPackage,
  });

  final bool reinstall;
  final bool allowDowngrade;
  final bool allowTest;
  final bool grantRuntimePerms;
  final bool onSdCard;
  final bool instant;
  final int? user;
  final String? abi;
  final String? installerPackage;

  List<String> toFlags() => [
        if (reinstall) '-r',
        if (allowDowngrade) '-d',
        if (allowTest) '-t',
        if (grantRuntimePerms) '-g',
        if (onSdCard) '-s',
        if (instant) '--instant',
        if (user != null) ...['--user', '$user'],
        if (abi != null) ...['--abi', abi!],
        if (installerPackage != null) ...['-i', installerPackage!],
      ];
}

class PackageListFilter {
  const PackageListFilter({
    this.showPath = true,
    this.showVersionCode = true,
    this.showInstaller = false,
    this.showUid = false,
    this.thirdPartyOnly = false,
    this.systemOnly = false,
    this.disabledOnly = false,
    this.enabledOnly = false,
    this.user,
  });

  final bool showPath;
  final bool showVersionCode;
  final bool showInstaller;
  final bool showUid;
  final bool thirdPartyOnly;
  final bool systemOnly;
  final bool disabledOnly;
  final bool enabledOnly;
  final int? user;

  List<String> toArgs() => [
        'list', 'packages',
        if (showPath) '-f',
        if (showVersionCode) '--show-versioncode',
        if (showInstaller) '-i',
        if (showUid) '-U',
        if (thirdPartyOnly) '-3',
        if (systemOnly) '-s',
        if (disabledOnly) '-d',
        if (enabledOnly) '-e',
        if (user != null) ...['--user', '$user'],
      ];
}

class PackageService {
  PackageService(this._runner);
  final AdbRunner _runner;

  Future<List<AdbPackage>> list(
    String serial, {
    PackageListFilter filter = const PackageListFilter(),
  }) async {
    final out = await _runner.runOk(
      ['shell', 'pm', ...filter.toArgs()],
      serial: serial,
      timeout: const Duration(seconds: 30),
    );
    return AdbPackage.parseList(out);
  }

  Future<String> install(
    String serial,
    String apkPath, {
    InstallOptions options = const InstallOptions(),
  }) async =>
      _runner.runOk(
        ['install', ...options.toFlags(), apkPath],
        serial: serial,
        timeout: const Duration(minutes: 5),
      );

  Future<String> installMultiple(
    String serial,
    List<String> apkPaths, {
    InstallOptions options = const InstallOptions(),
  }) async =>
      _runner.runOk(
        ['install-multiple', ...options.toFlags(), ...apkPaths],
        serial: serial,
        timeout: const Duration(minutes: 10),
      );

  Future<String> uninstall(
    String serial,
    String packageName, {
    bool keepData = false,
    int? user,
  }) =>
      _runner.runOk(
        [
          'uninstall',
          if (keepData) '-k',
          if (user != null) ...['--user', '$user'],
          packageName,
        ],
        serial: serial,
        timeout: const Duration(seconds: 60),
      );

  Future<void> clearData(String serial, String packageName) =>
      _runner.runOk(['shell', 'pm', 'clear', packageName], serial: serial);

  Future<void> enable(String serial, String target) =>
      _runner.runOk(['shell', 'pm', 'enable', target], serial: serial);
  Future<void> disable(String serial, String target) =>
      _runner.runOk(['shell', 'pm', 'disable-user', '--user', '0', target],
          serial: serial);

  Future<void> hide(String serial, String target) =>
      _runner.runOk(['shell', 'pm', 'hide', target], serial: serial);
  Future<void> unhide(String serial, String target) =>
      _runner.runOk(['shell', 'pm', 'unhide', target], serial: serial);

  Future<void> suspend(String serial, String target) =>
      _runner.runOk(['shell', 'pm', 'suspend', target], serial: serial);
  Future<void> unsuspend(String serial, String target) =>
      _runner.runOk(['shell', 'pm', 'unsuspend', target], serial: serial);

  Future<void> grant(String serial, String pkg, String permission) =>
      _runner.runOk(['shell', 'pm', 'grant', pkg, permission], serial: serial);
  Future<void> revoke(String serial, String pkg, String permission) =>
      _runner.runOk(['shell', 'pm', 'revoke', pkg, permission], serial: serial);
  Future<void> resetPermissions(String serial) =>
      _runner.runOk(['shell', 'pm', 'reset-permissions'], serial: serial);

  Future<String> path(String serial, String pkg) =>
      _runner.runOk(['shell', 'pm', 'path', pkg], serial: serial);
  Future<String> dump(String serial, String pkg) => _runner.runOk(
        ['shell', 'pm', 'dump', pkg],
        serial: serial,
        timeout: const Duration(seconds: 60),
      );

  Future<String> listPermissions(String serial) =>
      _runner.runOk(['shell', 'pm', 'list', 'permissions', '-g'],
          serial: serial);
  Future<String> listFeatures(String serial) =>
      _runner.runOk(['shell', 'pm', 'list', 'features'], serial: serial);
  Future<String> listLibraries(String serial) =>
      _runner.runOk(['shell', 'pm', 'list', 'libraries'], serial: serial);
  Future<String> listUsers(String serial) =>
      _runner.runOk(['shell', 'pm', 'list', 'users'], serial: serial);
  Future<String> listInstrumentation(String serial) =>
      _runner.runOk(['shell', 'pm', 'list', 'instrumentation'], serial: serial);

  Future<String> compile(String serial, String pkg,
          {String mode = 'speed', bool force = true}) =>
      _runner.runOk(
        [
          'shell',
          'cmd',
          'package',
          'compile',
          '-m',
          mode,
          if (force) '-f',
          pkg,
        ],
        serial: serial,
        timeout: const Duration(minutes: 3),
      );

  Future<String> trimCaches(String serial, int bytes) => _runner.runOk(
        ['shell', 'pm', 'trim-caches', '$bytes'],
        serial: serial,
      );
}
