import 'dart:async';

import '../models/log_line.dart';
import '../runner/adb_runner.dart';

enum LogBuffer {
  main('main'),
  system('system'),
  crash('crash'),
  events('events'),
  radio('radio'),
  kernel('kernel'),
  all('all');

  const LogBuffer(this.token);
  final String token;
}

class LogcatFilter {
  const LogcatFilter({
    this.tagPriority = const {},
    this.defaultPriority = LogPriority.verbose,
    this.buffers = const [LogBuffer.main, LogBuffer.system],
    this.format = 'threadtime',
    this.pid,
    this.uid,
  });

  final Map<String, LogPriority> tagPriority;
  final LogPriority defaultPriority;
  final List<LogBuffer> buffers;
  final String format;
  final int? pid;
  final String? uid;

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

class LogcatService {
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

  Future<void> clear(String serial) =>
      _runner.runOk(['logcat', '-c'], serial: serial);

  Future<String> bufferSizes(String serial) =>
      _runner.runOk(['logcat', '-g'], serial: serial);

  Future<void> setBufferSize(String serial, String size) =>
      _runner.runOk(['logcat', '-G', size], serial: serial);
}
