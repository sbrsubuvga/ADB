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

  final AdbRunner runner;
  late final DeviceService devices;
  late final ConnectionService connection;
  late final PackageService packages;
  late final ActivityService activity;
  late final InputService input;
  late final ScreenService screen;
  late final DisplayService displays;
  late final LogcatService logcat;
  late final ShellService shell;
  late final FileService files;
  late final SettingsService settings;
  late final PropsService props;
  late final NetworkService network;
  late final PowerService power;
  late final DumpsysService dumpsys;
  late final BackupService backup;
  late final ScriptPlayer scripts;

  /// Convenience: detect the adb version string. Throws if adb is missing.
  Future<String> version() => runner.version();

  String get adbPath => runner.adbPath;
  set adbPath(String value) => runner.adbPath = value;

  AdbObserver? get observer => runner.observer;
  set observer(AdbObserver? value) => runner.observer = value;
}
