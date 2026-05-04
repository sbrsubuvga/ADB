import '../runner/adb_runner.dart';

/// Targets accepted by `adb reboot`.
enum RebootTarget {
  normal,
  bootloader,
  recovery,
  sideload,
  sideloadAutoReboot,
  fastboot
}

/// Wraps reboot, screen, and idle-mode commands.
class PowerService {
  /// Creates a [PowerService] backed by [_runner].
  PowerService(this._runner);
  final AdbRunner _runner;

  /// Reboots the device into [target].
  Future<void> reboot(String serial,
      {RebootTarget target = RebootTarget.normal}) {
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

  /// Sends KEYCODE_POWER to put the screen to sleep.
  Future<void> screenOff(String serial) =>
      _runner.runOk(['shell', 'input', 'keyevent', '26'], serial: serial);

  /// Sends KEYCODE_WAKEUP to wake the screen.
  Future<void> wake(String serial) => _runner
      .runOk(['shell', 'input', 'keyevent', 'KEYCODE_WAKEUP'], serial: serial);

  /// Forces the device into doze idle mode.
  Future<void> forceIdle(String serial) => _runner.runOk(
        ['shell', 'dumpsys', 'deviceidle', 'force-idle'],
        serial: serial,
      );

  /// Reverses [forceIdle].
  Future<void> unforceIdle(String serial) => _runner.runOk(
        ['shell', 'dumpsys', 'deviceidle', 'unforce'],
        serial: serial,
      );
}
