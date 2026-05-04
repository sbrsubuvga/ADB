import 'dart:async';

import '../models/device.dart';
import '../runner/adb_runner.dart';

/// High-level wrapper around `adb devices` and server lifecycle commands.
class DeviceService {
  /// Creates a [DeviceService] backed by [_runner].
  DeviceService(this._runner);
  final AdbRunner _runner;

  /// Returns the current list of devices known to adb.
  Future<List<AdbDevice>> list() async {
    final out = await _runner.runOk(['devices', '-l']);
    return AdbDevice.parseList(out);
  }

  /// Polls every [interval] and emits the latest device list.
  Stream<List<AdbDevice>> watch({
    Duration interval = const Duration(seconds: 2),
  }) async* {
    while (true) {
      try {
        yield await list();
      } catch (_) {
        yield const [];
      }
      await Future<void>.delayed(interval);
    }
  }

  /// Starts the local adb server.
  Future<void> startServer() => _runner.runOk(['start-server']);

  /// Stops the local adb server.
  Future<void> killServer() => _runner.runOk(['kill-server']);

  /// Blocks until any device (or one in the optional [state]) appears.
  Future<void> waitForDevice({String? state}) => _runner.run(
        state == null ? ['wait-for-device'] : ['wait-for-$state'],
        timeout: Duration.zero,
      );

  /// Forces adb to reconnect (`offline`, `device`, or unset).
  Future<void> reconnect({String? mode}) =>
      _runner.runOk(['reconnect', if (mode != null) mode]);

  /// Connects to a TCP/IP device at [host]:[port].
  Future<void> connect(String host, {int port = 5555}) =>
      _runner.runOk(['connect', '$host:$port']);

  /// Disconnects [host] (or all TCP devices when null).
  Future<void> disconnect([String? host]) =>
      _runner.runOk(['disconnect', if (host != null) host]);

  /// Android 11+ wireless pairing.
  Future<void> pair(String host, int port, String code) =>
      _runner.runOk(['pair', '$host:$port', code]);

  /// Restarts adbd in TCP/IP mode listening on [port].
  Future<void> tcpIp(int port) => _runner.runOk(['tcpip', '$port']);

  /// Restarts adbd in USB mode.
  Future<void> usb() => _runner.runOk(['usb']);

  /// Returns the current `get-state` token for [serial].
  Future<String> getState(String serial) async =>
      (await _runner.runOk(['get-state'], serial: serial)).trim();

  /// Restarts adbd as root on [serial].
  Future<void> root(String serial) => _runner
      .runOk(['root'], serial: serial, timeout: const Duration(seconds: 30));

  /// Restarts adbd as the shell user on [serial].
  Future<void> unroot(String serial) =>
      _runner.runOk(['unroot'], serial: serial);

  /// Remounts system partitions read-write on [serial].
  Future<void> remount(String serial) =>
      _runner.runOk(['remount'], serial: serial);

  /// Disables dm-verity on [serial] (root required, reboots).
  Future<void> disableVerity(String serial) =>
      _runner.runOk(['disable-verity'], serial: serial);

  /// Re-enables dm-verity on [serial] (root required, reboots).
  Future<void> enableVerity(String serial) =>
      _runner.runOk(['enable-verity'], serial: serial);

  /// Sideloads an OTA zip from [zipPath] to [serial].
  Future<void> sideload(String serial, String zipPath) => _runner.runOk(
        ['sideload', zipPath],
        serial: serial,
        timeout: const Duration(minutes: 20),
      );
}
