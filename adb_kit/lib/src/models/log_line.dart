/// Logcat priority levels.
enum LogPriority {
  verbose('V'),
  debug('D'),
  info('I'),
  warn('W'),
  error('E'),
  fatal('F'),
  silent('S'),
  unknown('?');

  const LogPriority(this.letter);

  /// Single-letter form used by `logcat`.
  final String letter;

  /// Returns the priority matching the single-letter token [s].
  static LogPriority fromLetter(String s) {
    for (final p in values) {
      if (p.letter == s) return p;
    }
    return LogPriority.unknown;
  }

  /// True if this priority is at least as severe as [other].
  bool atLeast(LogPriority other) => index >= other.index;
}

/// One parsed line of `logcat` output.
class LogLine {
  /// Creates a [LogLine].
  const LogLine({
    required this.raw,
    this.timestamp,
    this.pid,
    this.tid,
    this.priority = LogPriority.unknown,
    this.tag,
    this.message,
  });

  /// Original unparsed line.
  final String raw;

  /// Wall-clock timestamp parsed from the line, when available.
  final DateTime? timestamp;

  /// Process id.
  final int? pid;

  /// Thread id.
  final int? tid;

  /// Log priority.
  final LogPriority priority;

  /// Log tag.
  final String? tag;

  /// Log message body.
  final String? message;

  /// Parse a line in the `threadtime` format:
  ///   MM-DD HH:mm:ss.SSS  PID  TID P TAG: msg
  ///
  /// Falls back to raw if the pattern does not match.
  static LogLine parseThreadtime(String line) {
    final m = RegExp(
      r'^(\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3})\s+(\d+)\s+(\d+)\s+([VDIWEFS])\s+([^:]*?):\s?(.*)$',
    ).firstMatch(line);
    if (m == null) {
      return LogLine(raw: line);
    }
    final now = DateTime.now();
    final dt = _parseMmddTs(m.group(1)!, now.year);
    return LogLine(
      raw: line,
      timestamp: dt,
      pid: int.tryParse(m.group(2)!),
      tid: int.tryParse(m.group(3)!),
      priority: LogPriority.fromLetter(m.group(4)!),
      tag: m.group(5)!.trim(),
      message: m.group(6),
    );
  }

  static DateTime? _parseMmddTs(String s, int year) {
    try {
      final parts = s.split(RegExp(r'[\s\-:\.]+'));
      if (parts.length < 6) return null;
      return DateTime(
        year,
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
        int.parse(parts[3]),
        int.parse(parts[4]),
        int.parse(parts[5]),
      );
    } catch (_) {
      return null;
    }
  }
}
