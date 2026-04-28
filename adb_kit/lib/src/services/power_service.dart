import '../runner/adb_runner.dart';

enum RebootTarget { normal, bootloader, recovery, sideload, sideloadAutoReboot, fastboot }

class PowerService {
  PowerService(this._runner);
  final AdbRunner _runner;

  Future<void> reboot(String serial, {RebootTarget target = RebootTarget.normal}) {
    String? arg;
    switch (target) {
      case RebootTarget.normal:
        arg = null;
      case RebootTarget.bootloader:
        arg = 'bootloader';
      case RebootTarget.recovery:
        arg = 'recovery';
      case RebootTarget.sideload:
        arg = 'sideload';
      case RebootTarget.sideloadAutoReboot:
        arg = 'sideload-auto-reboot';
      case RebootTarget.fastboot:
        arg = 'fastboot';
    }
    return _runner.runOk(
      ['reboot', if (arg != null) arg],
      serial: serial,
      timeout: const Duration(seconds: 30),
    );
  }

  Future<void> screenOff(String serial) =>
      _runner.runOk(['shell', 'input', 'keyevent', '26'], serial: serial);

  Future<void> wake(String serial) =>
      _runner.runOk(['shell', 'input', 'keyevent', 'KEYCODE_WAKEUP'],
          serial: serial);

  Future<void> forceIdle(String serial) => _runner.runOk(
        ['shell', 'dumpsys', 'deviceidle', 'force-idle'],
        serial: serial,
      );

  Future<void> unforceIdle(String serial) => _runner.runOk(
        ['shell', 'dumpsys', 'deviceidle', 'unforce'],
        serial: serial,
      );
}
