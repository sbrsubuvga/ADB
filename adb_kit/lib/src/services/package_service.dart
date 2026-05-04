import '../models/package.dart';
import '../runner/adb_runner.dart';

/// Options for `adb install`.
class InstallOptions {
  /// Creates an [InstallOptions].
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

  /// Pass `-r` to reinstall over an existing package.
  final bool reinstall;

  /// Pass `-d` to allow version downgrade.
  final bool allowDowngrade;

  /// Pass `-t` to allow test packages.
  final bool allowTest;

  /// Pass `-g` to grant all runtime permissions.
  final bool grantRuntimePerms;

  /// Pass `-s` to install on the SD card.
  final bool onSdCard;

  /// Pass `--instant` to install as an instant app.
  final bool instant;

  /// Target user id (`--user`).
  final int? user;

  /// Force a specific ABI (`--abi`).
  final String? abi;

  /// Installer package id (`-i`).
  final String? installerPackage;

  /// Renders these options as the install flag list.
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

/// Options for `pm list packages`.
class PackageListFilter {
  /// Creates a [PackageListFilter].
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

  /// Include APK paths in output (`-f`).
  final bool showPath;

  /// Include manifest version codes (`--show-versioncode`).
  final bool showVersionCode;

  /// Include installer package id (`-i`).
  final bool showInstaller;

  /// Include uid (`-U`).
  final bool showUid;

  /// Restrict to third-party packages (`-3`).
  final bool thirdPartyOnly;

  /// Restrict to system packages (`-s`).
  final bool systemOnly;

  /// Restrict to disabled packages (`-d`).
  final bool disabledOnly;

  /// Restrict to enabled packages (`-e`).
  final bool enabledOnly;

  /// Target user id (`--user`).
  final int? user;

  /// Renders these options as the `pm list packages` argv tail.
  List<String> toArgs() => [
        'list',
        'packages',
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

/// Wraps the `pm` package manager commands.
class PackageService {
  /// Creates a [PackageService] backed by [_runner].
  PackageService(this._runner);
  final AdbRunner _runner;

  /// Lists installed packages on [serial].
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

  /// Installs a single APK from [apkPath].
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

  /// Installs a split-APK set in a single session.
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

  /// Uninstalls [packageName] from [serial].
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

  /// Clears the data directory of [packageName].
  Future<void> clearData(String serial, String packageName) =>
      _runner.runOk(['shell', 'pm', 'clear', packageName], serial: serial);

  /// Enables [target] (a package or `pkg/component`).
  Future<void> enable(String serial, String target) =>
      _runner.runOk(['shell', 'pm', 'enable', target], serial: serial);

  /// Disables [target] for user 0.
  Future<void> disable(String serial, String target) =>
      _runner.runOk(['shell', 'pm', 'disable-user', '--user', '0', target],
          serial: serial);

  /// Marks [target] as hidden.
  Future<void> hide(String serial, String target) =>
      _runner.runOk(['shell', 'pm', 'hide', target], serial: serial);

  /// Reverses [hide].
  Future<void> unhide(String serial, String target) =>
      _runner.runOk(['shell', 'pm', 'unhide', target], serial: serial);

  /// Suspends [target] (Android 7+).
  Future<void> suspend(String serial, String target) =>
      _runner.runOk(['shell', 'pm', 'suspend', target], serial: serial);

  /// Reverses [suspend].
  Future<void> unsuspend(String serial, String target) =>
      _runner.runOk(['shell', 'pm', 'unsuspend', target], serial: serial);

  /// Grants a runtime permission to [pkg].
  Future<void> grant(String serial, String pkg, String permission) =>
      _runner.runOk(['shell', 'pm', 'grant', pkg, permission], serial: serial);

  /// Revokes a runtime permission from [pkg].
  Future<void> revoke(String serial, String pkg, String permission) =>
      _runner.runOk(['shell', 'pm', 'revoke', pkg, permission], serial: serial);

  /// Resets every runtime permission grant on the device.
  Future<void> resetPermissions(String serial) =>
      _runner.runOk(['shell', 'pm', 'reset-permissions'], serial: serial);

  /// Returns the on-device APK path of [pkg].
  Future<String> path(String serial, String pkg) =>
      _runner.runOk(['shell', 'pm', 'path', pkg], serial: serial);

  /// Returns the raw `pm dump` output for [pkg].
  Future<String> dump(String serial, String pkg) => _runner.runOk(
        ['shell', 'pm', 'dump', pkg],
        serial: serial,
        timeout: const Duration(seconds: 60),
      );

  /// Lists every permission known to the system.
  Future<String> listPermissions(String serial) => _runner
      .runOk(['shell', 'pm', 'list', 'permissions', '-g'], serial: serial);

  /// Lists every system feature exposed by the device.
  Future<String> listFeatures(String serial) =>
      _runner.runOk(['shell', 'pm', 'list', 'features'], serial: serial);

  /// Lists every shared library available to apps.
  Future<String> listLibraries(String serial) =>
      _runner.runOk(['shell', 'pm', 'list', 'libraries'], serial: serial);

  /// Lists every user profile.
  Future<String> listUsers(String serial) =>
      _runner.runOk(['shell', 'pm', 'list', 'users'], serial: serial);

  /// Lists registered instrumentation runners.
  Future<String> listInstrumentation(String serial) =>
      _runner.runOk(['shell', 'pm', 'list', 'instrumentation'], serial: serial);

  /// Triggers an AOT compile of [pkg] using profile [mode].
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

  /// Trims package manager caches down to [bytes].
  Future<String> trimCaches(String serial, int bytes) => _runner.runOk(
        ['shell', 'pm', 'trim-caches', '$bytes'],
        serial: serial,
      );
}
