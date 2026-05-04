import '../runner/adb_runner.dart';

/// `svc` / `cmd` / `ip` / `ping` wrappers.
class NetworkService {
  NetworkService(this._runner);
  final AdbRunner _runner;

  Future<void> wifi(String serial, {required bool enabled}) =>
      _runner.runOk(['shell', 'svc', 'wifi', enabled ? 'enable' : 'disable'],
          serial: serial);

  Future<void> data(String serial, {required bool enabled}) =>
      _runner.runOk(['shell', 'svc', 'data', enabled ? 'enable' : 'disable'],
          serial: serial);

  Future<void> bluetooth(String serial, {required bool enabled}) => _runner
      .runOk(['shell', 'svc', 'bluetooth', enabled ? 'enable' : 'disable'],
          serial: serial);

  Future<void> nfc(String serial, {required bool enabled}) => _runner.runOk(
        ['shell', 'svc', 'nfc', enabled ? 'enable' : 'disable'],
        serial: serial,
      );

  Future<void> usbFunctions(String serial, String mode) => _runner
      .runOk(['shell', 'svc', 'usb', 'setFunctions', mode], serial: serial);

  Future<void> airplaneMode(String serial, {required bool enabled}) =>
      _runner.runOk(
        [
          'shell',
          'cmd',
          'connectivity',
          'airplane-mode',
          enabled ? 'enable' : 'disable',
        ],
        serial: serial,
      );

  Future<String> ipAddr(String serial) =>
      _runner.runOk(['shell', 'ip', 'addr'], serial: serial);
  Future<String> ipRoute(String serial) =>
      _runner.runOk(['shell', 'ip', 'route'], serial: serial);

  Future<String> ping(String serial, String host, {int count = 4}) =>
      _runner.runOk(
        ['shell', 'ping', '-c', '$count', host],
        serial: serial,
        timeout: const Duration(seconds: 30),
      );

  Future<String> netstat(String serial) =>
      _runner.runOk(['shell', 'netstat'], serial: serial);
}
