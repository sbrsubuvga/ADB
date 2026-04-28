import 'dart:convert';

/// Result of running a single adb command.
class AdbResult {
  AdbResult({
    required this.command,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.duration,
  });

  final List<String> command;
  final int exitCode;
  final String stdout;
  final String stderr;
  final Duration duration;

  bool get isSuccess => exitCode == 0;

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

  Map<String, Object?> toJson() => {
        'command': command,
        'exitCode': exitCode,
        'stdout': stdout,
        'stderr': stderr,
        'durationMs': duration.inMilliseconds,
      };

  static String encode(AdbResult r) => const JsonEncoder().convert(r.toJson());
}

/// Thrown when an adb invocation fails and the caller opted into exceptions.
class AdbException implements Exception {
  AdbException(this.message, {this.result});
  final String message;
  final AdbResult? result;

  @override
  String toString() => 'AdbException: $message'
      '${result == null ? '' : '\n${result!}'}';
}
