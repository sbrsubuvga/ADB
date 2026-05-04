import 'dart:async';

import '../models/log_line.dart';
import '../runner/adb_runner.dart';

/// Logcat ring buffers selectable via `-b`.
enum LogBuffer {
  main('main'),
  system('system'),
  crash('crash'),
  events('events'),
  radio('radio'),
  kernel('kernel'),
  all('all');

  const LogBuffer(this.token);

  /// CLI token passed to `logcat -b`.
  final String token;
}

/// Filter / format options passed to `logcat`.
class LogcatFilter {
  /// Creates a [LogcatFilter].
  const LogcatFilter({
    this.tagPriority = const {},
    this.defaultPriority = LogPriority.verbose,
    this.buffers = const [LogBuffer.main, LogBuffer.system],
    this.format = 'threadtime',
    this.pid,
    this.uid,
  });

  /// Per-tag minimum priority (e.g. `MyTag: I`).
  final Map<String, LogPriority> tagPriority;

  /// Default priority for tags not in [tagPriority].
  final LogPriority defaultPriority;

  /// Ring buffers to read.
  final List<LogBuffer> buffers;

  /// Output format token (`threadtime`, `time`, `tag`, ...).
  final String format;

  /// Restrict to this pid (`--pid`).
  final int? pid;

  /// Restrict to this uid (`--uid`).
  final String? uid;

  /// Renders these options as the `logcat` argv tail.
  List<String> toArgs() => [
        'logcat',
        for (final b in buffers) ...['-b', b.token],
        '-v',
        format,
        if (pid != null) ...['--pid=$pid'],
        if (uid != null) ...['--uid=$uid'],
        for (final e in tagPriority.entries) '${e.key}:${e.value.letter}',
        '*:${defaultPriority.letter}',
      ];
}

/// Wraps `logcat` for both streaming tails and snapshot reads.
class LogcatService {
  /// Creates a [LogcatService] backed by [_runner].
  LogcatService(this._runner);
  final AdbRunner _runner;

  /// Stream parsed log lines. The returned future completes when the caller
  /// kills the stream handle stored on the receiver side.
  Stream<LogLine> tail(
    String serial, {
    LogcatFilter filter = const LogcatFilter(),
    AdbStreamHandle Function(AdbStreamHandle)? onHandle,
  }) async* {
    final handle = await _runner.stream(filter.toArgs(), serial: serial);
    onHandle?.call(handle);
    try {
      await for (final line in handle.stdout) {
        yield LogLine.parseThreadtime(line);
      }
    } finally {
      await handle.kill();
    }
  }

  /// Snapshot the current buffer and return it as a single string.
  Future<String> snapshot(
    String serial, {
    LogcatFilter filter = const LogcatFilter(),
  }) async {
    return _runner.runOk(
      [...filter.toArgs(), '-d'],
      serial: serial,
      timeout: const Duration(seconds: 60),
    );
  }

  /// Clears the logcat buffers.
  Future<void> clear(String serial) =>
      _runner.runOk(['logcat', '-c'], serial: serial);

  /// Returns the current buffer sizes (`logcat -g`).
  Future<String> bufferSizes(String serial) =>
      _runner.runOk(['logcat', '-g'], serial: serial);

  /// Resizes the logcat buffer to [size] (e.g. `4M`).
  Future<void> setBufferSize(String serial, String size) =>
      _runner.runOk(['logcat', '-G', size], serial: serial);
}
