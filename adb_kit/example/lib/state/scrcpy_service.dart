import 'dart:io';

/// Spawns scrcpy as an external process (its own native window). Pure
/// convenience over `Process.start`.
class ScrcpyService {
  const ScrcpyService(this.path);
  final String path;

  /// Returns the version line on success, throws otherwise.
  Future<String> version() async {
    final r = await Process.run(path, ['--version']);
    if (r.exitCode != 0) {
      throw ProcessException(path, [
        '--version',
      ], 'scrcpy --version exit=${r.exitCode}: ${r.stderr}');
    }
    final out = (r.stdout as String).trim();
    return out.split('\n').first;
  }

  /// Launch scrcpy bound to a specific device + display id. Does not block.
  Future<Process> launch({
    required String serial,
    int? displayId,
    bool stayAwake = true,
    bool turnScreenOff = false,
    bool noAudio = true,
    int? maxFps,
    String? title,
  }) {
    final args = <String>[
      '--serial=$serial',
      if (displayId != null) '--display-id=$displayId',
      if (stayAwake) '--stay-awake',
      if (turnScreenOff) '--turn-screen-off',
      if (noAudio) '--no-audio',
      if (maxFps != null) '--max-fps=$maxFps',
      if (title != null) '--window-title=$title',
    ];
    return Process.start(path, args, mode: ProcessStartMode.detachedWithStdio);
  }
}
