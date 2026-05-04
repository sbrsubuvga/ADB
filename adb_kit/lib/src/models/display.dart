class AdbDisplay {
  const AdbDisplay({
    required this.id,
    required this.width,
    required this.height,
    this.densityDpi,
    this.rotation = 0,
    this.isPrimary = false,
    this.isOverlay = false,
    this.name,
  });

  final int id;
  final int width;
  final int height;
  final int? densityDpi;

  /// Rotation in quarters: 0,1,2,3.
  final int rotation;
  final bool isPrimary;
  final bool isOverlay;
  final String? name;

  /// Parses display entries from `dumpsys display`.
  /// Tries multiple regex shapes seen across Android 7..14:
  ///   * `Display Device: displayId=N "Name", 1080 x 1920, density 320`
  ///   * `mDisplayId=N` followed by `app NNN x NNN` / `real NNN x NNN`
  ///   * `Display N: ... 1080x1920 ...`
  ///   * `OverlayDisplayAdapter` blocks for simulated secondary displays.
  static List<AdbDisplay> parseDumpsysDisplay(String stdout) {
    final result = <AdbDisplay>[];
    final seen = <int>{};

    void add(AdbDisplay d) {
      if (seen.contains(d.id)) return;
      seen.add(d.id);
      result.add(d);
    }

    // Variant 1: classic `Display Device: displayId=...`
    final v1 = RegExp(
      r'Display Device:\s*displayId=(-?\d+)[^\n]*?(?:"([^"]*)")?[^\n]*?(\d+)\s*x\s*(\d+)(?:[^\n]*?density\s*(\d+))?',
    );
    for (final m in v1.allMatches(stdout)) {
      final id = int.parse(m.group(1)!);
      add(AdbDisplay(
        id: id,
        width: int.parse(m.group(3)!),
        height: int.parse(m.group(4)!),
        densityDpi: m.group(5) == null ? null : int.tryParse(m.group(5)!),
        name: m.group(2),
        isPrimary: id == 0,
      ));
    }

    // Variant 2: LogicalDisplay blocks with `mDisplayId=N` + `real WxH`.
    final v2 = RegExp(
      r'mDisplayId\s*=\s*(-?\d+)[\s\S]{0,2000}?'
      r'real\s+(\d+)\s*x\s*(\d+)'
      r'(?:[\s\S]{0,2000}?density(?:Dpi)?\s*[=:]?\s*(\d+))?',
    );
    for (final m in v2.allMatches(stdout)) {
      final id = int.parse(m.group(1)!);
      add(AdbDisplay(
        id: id,
        width: int.parse(m.group(2)!),
        height: int.parse(m.group(3)!),
        densityDpi: m.group(4) == null ? null : int.tryParse(m.group(4)!),
        isPrimary: id == 0,
      ));
    }

    // Variant 3 (the over-permissive `Display N:` form) was removed
    // because it matched unrelated text in dumpsys output and produced
    // phantom display IDs that screenrecord rejected with "Invalid
    // physical display ID". Variants v1 + v2 now handle every real form
    // we've encountered on Pixel/Samsung/emulator builds.

    // Variant 4: tag entries that look like overlay displays. We never
    // fabricate IDs — overlays appear in v1/v2 with their real displayId
    // and we just decorate them via name matching.
    for (var i = 0; i < result.length; i++) {
      final d = result[i];
      final n = d.name?.toLowerCase() ?? '';
      if (n.contains('overlay') || n.contains('virtual')) {
        result[i] = AdbDisplay(
          id: d.id,
          width: d.width,
          height: d.height,
          densityDpi: d.densityDpi,
          rotation: d.rotation,
          name: d.name,
          isPrimary: d.isPrimary,
          isOverlay: true,
        );
      }
    }

    return result;
  }

  /// Parse `cmd display list-displays` output.
  /// The format varies, but each non-empty line typically starts with
  /// `Display id N` or `Display N`.
  static List<int> parseCmdDisplayList(String stdout) {
    final ids = <int>{};
    final regex = RegExp(r'^\s*Display\s+(?:id\s+)?(-?\d+)', multiLine: true);
    for (final m in regex.allMatches(stdout)) {
      final id = int.tryParse(m.group(1)!);
      if (id != null) ids.add(id);
    }
    return ids.toList()..sort();
  }

  /// Parse `wm size` output: either `Physical size: 1080x1920` or
  /// `Override size: 1080x1920`.
  static (int, int)? parseWmSize(String stdout) {
    final m = RegExp(
      r'(?:Override|Physical) size:\s*(\d+)x(\d+)',
    ).firstMatch(stdout);
    if (m == null) return null;
    return (int.parse(m.group(1)!), int.parse(m.group(2)!));
  }

  static int? parseWmDensity(String stdout) {
    final m =
        RegExp(r'(?:Override|Physical) density:\s*(\d+)').firstMatch(stdout);
    if (m == null) return null;
    return int.tryParse(m.group(1)!);
  }

  AdbDisplay copyWith({int? rotation, int? width, int? height}) => AdbDisplay(
        id: id,
        width: width ?? this.width,
        height: height ?? this.height,
        densityDpi: densityDpi,
        rotation: rotation ?? this.rotation,
        isPrimary: isPrimary,
        isOverlay: isOverlay,
        name: name,
      );

  @override
  String toString() =>
      'AdbDisplay(id=$id${isOverlay ? "/overlay" : ""}, ${width}x$height '
      '@$densityDpi dpi, rot=$rotation)';
}
