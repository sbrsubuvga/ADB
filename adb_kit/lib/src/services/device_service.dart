import 'dart:async';

import '../models/device.dart';
import '../runner/adb_runner.dart';

class DeviceService {
  DeviceService(this._runner);
  final AdbRunner _runner;

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

  Future<void> startServer() => _runner.runOk(['start-server']);
  Future<void> killServer() => _runner.runOk(['kill-server']);

  Future<void> waitForDevice({String? state}) => _runner.run(
        state == null ? ['wait-for-device'] : ['wait-for-$state'],
        timeout: Duration.zero,
      );

  Future<void> reconnect({String? mode}) =>
      _runner.runOk(['reconnect', if (mode != null) mode]);

  Future<void> connect(String host, {int port = 5555}) =>
      _runner.runOk(['connect', '$host:$port']);

  Future<void> disconnect([String? host]) =>
      _runner.runOk(['disconnect', if (host != null) host]);

  /// Android 11+ wireless pairing.
  Future<void> pair(String host, int port, String code) =>
      _runner.runOk(['pair', '$host:$port', code]);

  Future<void> tcpIp(int port) => _runner.runOk(['tcpip', '$port']);
  Future<void> usb() => _runner.runOk(['usb']);

  Future<String> getState(String serial) async =>
      (await _runner.runOk(['get-state'], serial: serial)).trim();

  Future<void> root(String serial) => _runner
      .runOk(['root'], serial: serial, timeout: const Duration(seconds: 30));

  Future<void> unroot(String serial) =>
      _runner.runOk(['unroot'], serial: serial);
  Future<void> remount(String serial) =>
      _runner.runOk(['remount'], serial: serial);
  Future<void> disableVerity(String serial) =>
      _runner.runOk(['disable-verity'], serial: serial);
  Future<void> enableVerity(String serial) =>
      _runner.runOk(['enable-verity'], serial: serial);
  Future<void> sideload(String serial, String zipPath) => _runner.runOk(
        ['sideload', zipPath],
        serial: serial,
        timeout: const Duration(minutes: 20),
      );
}
