import 'runner/adb_runner.dart';
import 'services/activity_service.dart';
import 'services/backup_service.dart';
import 'services/connection_service.dart';
import 'services/device_service.dart';
import 'services/display_service.dart';
import 'services/dumpsys_service.dart';
import 'services/file_service.dart';
import 'services/input_service.dart';
import 'services/logcat_service.dart';
import 'services/network_service.dart';
import 'services/package_service.dart';
import 'services/power_service.dart';
import 'services/props_service.dart';
import 'services/screen_service.dart';
import 'services/script_service.dart';
import 'services/settings_service.dart';
import 'services/shell_service.dart';

/// Single-entry API. Construct one [AdbKit] and reuse its services.
class AdbKit {
  /// Creates an [AdbKit] that invokes adb at [adbPath].
  AdbKit({String adbPath = 'adb', AdbObserver? observer})
      : runner = AdbRunner(adbPath: adbPath, observer: observer) {
    devices = DeviceService(runner);
    connection = ConnectionService(runner);
    packages = PackageService(runner);
    activity = ActivityService(runner);
    input = InputService(runner);
    screen = ScreenService(runner);
    displays = DisplayService(runner);
    logcat = LogcatService(runner);
    shell = ShellService(runner);
    files = FileService(runner);
    settings = SettingsService(runner);
    props = PropsService(runner);
    network = NetworkService(runner);
    power = PowerService(runner);
    dumpsys = DumpsysService(runner);
    backup = BackupService(runner);
    scripts = ScriptPlayer(
      input: input,
      activity: activity,
      screen: screen,
      shell: shell,
      logcat: logcat,
    );
  }

  /// Underlying process runner shared by every service.
  final AdbRunner runner;

  /// Device discovery and lifecycle.
  late final DeviceService devices;

  /// `forward`, `reverse`, and `mdns`.
  late final ConnectionService connection;

  /// `pm` package manager wrapper.
  late final PackageService packages;

  /// `am` activity manager wrapper.
  late final ActivityService activity;

  /// `input` taps, swipes, and key events.
  late final InputService input;

  /// `screencap` / `screenrecord` capture.
  late final ScreenService screen;

  /// `wm` and `cmd display` for size, density, and rotation.
  late final DisplayService displays;

  /// `logcat` reader.
  late final LogcatService logcat;

  /// `adb shell` execution.
  late final ShellService shell;

  /// Filesystem and `push` / `pull` helpers.
  late final FileService files;

  /// `settings` namespace access.
  late final SettingsService settings;

  /// `getprop` / `setprop`.
  late final PropsService props;

  /// `svc` / `cmd` networking toggles.
  late final NetworkService network;

  /// `reboot` and screen / idle controls.
  late final PowerService power;

  /// `dumpsys` and `bugreport`.
  late final DumpsysService dumpsys;

  /// `adb backup` / `adb restore`.
  late final BackupService backup;

  /// Script recorder/player built on the other services.
  late final ScriptPlayer scripts;

  /// Convenience: detect the adb version string. Throws if adb is missing.
  Future<String> version() => runner.version();

  /// Path to the underlying adb binary.
  String get adbPath => runner.adbPath;
  set adbPath(String value) => runner.adbPath = value;

  /// Optional observer for adb lifecycle events.
  AdbObserver? get observer => runner.observer;
  set observer(AdbObserver? value) => runner.observer = value;
}
