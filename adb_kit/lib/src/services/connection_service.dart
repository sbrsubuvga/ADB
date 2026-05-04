import '../runner/adb_runner.dart';

/// One row from `adb forward --list` or `adb reverse --list`.
class PortForward {
  /// Creates a [PortForward].
  const PortForward(this.serial, this.local, this.remote);

  /// Device serial the rule belongs to.
  final String serial;

  /// Host-side endpoint (e.g. `tcp:8080`).
  final String local;

  /// Device-side endpoint (e.g. `tcp:8080`).
  final String remote;

  @override
  String toString() => '$serial $local -> $remote';
}

/// Wraps `adb forward`, `adb reverse`, and `adb mdns` commands.
class ConnectionService {
  /// Creates a [ConnectionService] backed by [_runner].
  ConnectionService(this._runner);
  final AdbRunner _runner;

  /// Lists active host -> device port forwards.
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

  /// Adds a host -> device port forward rule.
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

  /// Removes a single forward rule for [serial].
  Future<void> forwardRemove(String serial, String local) =>
      _runner.runOk(['forward', '--remove', local], serial: serial);

  /// Removes every host -> device forward rule.
  Future<void> forwardRemoveAll() => _runner.runOk(['forward', '--remove-all']);

  /// Lists active device -> host reverse rules for [serial].
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

  /// Adds a device -> host reverse rule.
  Future<void> reverseAdd({
    required String serial,
    required String remote,
    required String local,
  }) =>
      _runner.runOk(['reverse', remote, local], serial: serial);

  /// Removes a single reverse rule for [serial].
  Future<void> reverseRemove(String serial, String remote) =>
      _runner.runOk(['reverse', '--remove', remote], serial: serial);

  /// Removes every reverse rule for [serial].
  Future<void> reverseRemoveAll(String serial) =>
      _runner.runOk(['reverse', '--remove-all'], serial: serial);

  /// Returns the raw output of `adb mdns services`.
  Future<String> mdnsServices() => _runner.runOk(['mdns', 'services']);

  /// Returns the raw output of `adb mdns check`.
  Future<String> mdnsCheck() => _runner.runOk(['mdns', 'check']);
}
