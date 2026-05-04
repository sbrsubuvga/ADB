import 'dart:convert';

/// Result of running a single adb command.
class AdbResult {
  /// Creates an [AdbResult].
  AdbResult({
    required this.command,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.duration,
  });

  /// Argv that was passed to adb (including any `-s serial`).
  final List<String> command;

  /// Process exit code (0 means success).
  final int exitCode;

  /// Captured standard output.
  final String stdout;

  /// Captured standard error.
  final String stderr;

  /// Elapsed wall-clock time.
  final Duration duration;

  /// True when [exitCode] is zero.
  bool get isSuccess => exitCode == 0;

  /// Quoted, copy-paste-able representation of [command].
  String get commandLine => command.map(_quote).join(' ');

  static String _quote(String s) {
    if (RegExp(r'^[A-Za-z0-9_\-:/\.@,=\+]+$').hasMatch(s)) return s;
    return "'${s.replaceAll("'", r"'\''")}'";
  }

  @override
  String toString() {
    final out = stdout.trim();
    final err = stderr.trim();
    final sb = StringBuffer('\$ $commandLine\n');
    if (out.isNotEmpty) sb.writeln(out);
    if (err.isNotEmpty) sb.writeln('stderr: $err');
    sb.writeln('[exit=$exitCode, ${duration.inMilliseconds}ms]');
    return sb.toString();
  }

  /// Serialises this result to a JSON-compatible map.
  Map<String, Object?> toJson() => {
        'command': command,
        'exitCode': exitCode,
        'stdout': stdout,
        'stderr': stderr,
        'durationMs': duration.inMilliseconds,
      };

  /// Encodes [r] as a JSON string via [toJson].
  static String encode(AdbResult r) => const JsonEncoder().convert(r.toJson());
}

/// Thrown when an adb invocation fails and the caller opted into exceptions.
class AdbException implements Exception {
  /// Creates an [AdbException].
  AdbException(this.message, {this.result});

  /// Human-readable error message.
  final String message;

  /// The failing [AdbResult], when available.
  final AdbResult? result;

  @override
  String toString() => 'AdbException: $message'
      '${result == null ? '' : '\n${result!}'}';
}
