import '../runner/adb_runner.dart';

class PortForward {
  const PortForward(this.serial, this.local, this.remote);
  final String serial;
  final String local;
  final String remote;

  @override
  String toString() => '$serial $local -> $remote';
}

class ConnectionService {
  ConnectionService(this._runner);
  final AdbRunner _runner;

  Future<List<PortForward>> forwardList() async {
    final out = await _runner.runOk(['forward', '--list']);
    return out
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .map((l) {
          final parts = l.trim().split(RegExp(r'\s+'));
          if (parts.length < 3) return null;
          return PortForward(parts[0], parts[1], parts[2]);
        })
        .whereType<PortForward>()
        .toList();
  }

  Future<void> forwardAdd({
    required String serial,
    required String local,
    required String remote,
    bool noRebind = false,
  }) =>
      _runner.runOk(
        ['forward', if (noRebind) '--no-rebind', local, remote],
        serial: serial,
      );

  Future<void> forwardRemove(String serial, String local) =>
      _runner.runOk(['forward', '--remove', local], serial: serial);

  Future<void> forwardRemoveAll() =>
      _runner.runOk(['forward', '--remove-all']);

  Future<List<PortForward>> reverseList(String serial) async {
    final out = await _runner.runOk(['reverse', '--list'], serial: serial);
    return out
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .map((l) {
          final parts = l.trim().split(RegExp(r'\s+'));
          if (parts.length < 3) return null;
          return PortForward(parts[0], parts[1], parts[2]);
        })
        .whereType<PortForward>()
        .toList();
  }

  Future<void> reverseAdd({
    required String serial,
    required String remote,
    required String local,
  }) =>
      _runner.runOk(['reverse', remote, local], serial: serial);

  Future<void> reverseRemove(String serial, String remote) =>
      _runner.runOk(['reverse', '--remove', remote], serial: serial);

  Future<void> reverseRemoveAll(String serial) =>
      _runner.runOk(['reverse', '--remove-all'], serial: serial);

  Future<String> mdnsServices() => _runner.runOk(['mdns', 'services']);
  Future<String> mdnsCheck() => _runner.runOk(['mdns', 'check']);
}
