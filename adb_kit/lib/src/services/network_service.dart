import '../runner/adb_runner.dart';

/// `svc` / `cmd` / `ip` / `ping` wrappers.
class NetworkService {
  /// Creates a [NetworkService] backed by [_runner].
  NetworkService(this._runner);
  final AdbRunner _runner;

  /// Toggles Wi-Fi.
  Future<void> wifi(String serial, {required bool enabled}) =>
      _runner.runOk(['shell', 'svc', 'wifi', enabled ? 'enable' : 'disable'],
          serial: serial);

  /// Toggles cellular data.
  Future<void> data(String serial, {required bool enabled}) =>
      _runner.runOk(['shell', 'svc', 'data', enabled ? 'enable' : 'disable'],
          serial: serial);

  /// Toggles Bluetooth.
  Future<void> bluetooth(String serial, {required bool enabled}) => _runner
      .runOk(['shell', 'svc', 'bluetooth', enabled ? 'enable' : 'disable'],
          serial: serial);

  /// Toggles NFC.
  Future<void> nfc(String serial, {required bool enabled}) => _runner.runOk(
        ['shell', 'svc', 'nfc', enabled ? 'enable' : 'disable'],
        serial: serial,
      );

  /// Sets the active USB function set (e.g. `mtp`, `ptp`, `none`).
  Future<void> usbFunctions(String serial, String mode) => _runner
      .runOk(['shell', 'svc', 'usb', 'setFunctions', mode], serial: serial);

  /// Toggles airplane mode.
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

  /// Returns raw `ip addr` output.
  Future<String> ipAddr(String serial) =>
      _runner.runOk(['shell', 'ip', 'addr'], serial: serial);

  /// Returns raw `ip route` output.
  Future<String> ipRoute(String serial) =>
      _runner.runOk(['shell', 'ip', 'route'], serial: serial);

  /// Pings [host] [count] times.
  Future<String> ping(String serial, String host, {int count = 4}) =>
      _runner.runOk(
        ['shell', 'ping', '-c', '$count', host],
        serial: serial,
        timeout: const Duration(seconds: 30),
      );

  /// Returns raw `netstat` output.
  Future<String> netstat(String serial) =>
      _runner.runOk(['shell', 'netstat'], serial: serial);
}
