class FileEntry {
  const FileEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.isLink,
    this.size = 0,
    this.permissions,
    this.owner,
    this.group,
    this.modified,
    this.linkTarget,
  });

  final String name;
  final String path;
  final bool isDirectory;
  final bool isLink;
  final int size;
  final String? permissions;
  final String? owner;
  final String? group;
  final DateTime? modified;
  final String? linkTarget;

  /// Parse a line of `ls -la` output. Android's toybox ls:
  ///   drwxr-xr-x   2 root root        4096 2023-01-01 00:00 bin
  /// Symlinks: `lrwxrwxrwx 1 root root 7 2023-01-01 00:00 d -> /sdcard`.
  static FileEntry? parseLsLine(String line, String parent) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length < 8) return null;
    final perms = parts[0];
    if (perms.length < 10) return null;
    final isDir = perms.startsWith('d');
    final isLink = perms.startsWith('l');
    final size = int.tryParse(parts[4]) ?? 0;
    // name may contain spaces and arrow for symlinks.
    final nameParts = parts.sublist(7);
    var nameStr = nameParts.join(' ');
    String? target;
    if (isLink && nameStr.contains(' -> ')) {
      final idx = nameStr.indexOf(' -> ');
      target = nameStr.substring(idx + 4);
      nameStr = nameStr.substring(0, idx);
    }
    DateTime? modified;
    try {
      modified = DateTime.parse('${parts[5]} ${parts[6]}');
    } catch (_) {}
    final normalizedParent = parent.endsWith('/') ? parent : '$parent/';
    return FileEntry(
      name: nameStr,
      path: '$normalizedParent$nameStr',
      isDirectory: isDir,
      isLink: isLink,
      size: size,
      permissions: perms,
      owner: parts[2],
      group: parts[3],
      modified: modified,
      linkTarget: target,
    );
  }

  static List<FileEntry> parseLs(String stdout, String parent) {
    final out = <FileEntry>[];
    for (final raw in stdout.split('\n')) {
      final line = raw.trimRight();
      if (line.isEmpty) continue;
      if (line.startsWith('total ')) continue;
      final entry = parseLsLine(line, parent);
      if (entry != null && entry.name != '.' && entry.name != '..') {
        out.add(entry);
      }
    }
    out.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return out;
  }
}
