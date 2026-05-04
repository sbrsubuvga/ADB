import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Thrown when the device fundamentally cannot deliver capture for the
/// requested display (Samsung overlay restrictions, codec exhaustion, …).
/// The message is user-facing.
class NotCapturableException implements Exception {
  const NotCapturableException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Why scrcpy with a window (and not `--no-window`)?
///
/// On Samsung One UI on Android 14+, the `--no-window` recording path uses
/// a different SurfaceFlinger surface than the live-display path. The
/// recording surface is subject to the protected-buffers check that
/// overlay/virtual displays fail; the display surface isn't. So when scrcpy
/// has a real window pulling frames, the device produces frames; when it
/// doesn't, the recording stays empty.
///
/// Workaround: spawn scrcpy with a tiny offscreen window, hide it via OS
/// tricks (AppleScript on macOS), and let it record to a growing .mkv that
/// we play with libmpv inside our own Flutter window.
class EmbeddedMirrorSession {
  EmbeddedMirrorSession();

  String? _scrcpyPath;
  String? _serial;
  int? _displayId;

  Process? _process;
  String? _filePath;
  Timer? _restartTimer;

  final _logBuffer = StringBuffer();
  final _filePathController = StreamController<String>.broadcast();

  /// Emits each new file path whenever the recording rotates. The widget
  /// listens to this and re-opens the player.
  Stream<String> get onFileChanged => _filePathController.stream;

  String? get filePath => _filePath;
  String get log => _logBuffer.toString();

  /// Start recording. Resolves once the first frames have been written.
  Future<String> start({
    required String scrcpyPath,
    required String serial,
    int? displayId,
    Duration startupTimeout = const Duration(seconds: 12),
  }) async {
    await stop();
    _scrcpyPath = scrcpyPath;
    _serial = serial;
    _displayId = displayId;
    return _spawn(startupTimeout: startupTimeout);
  }

  Future<String> _spawn({
    Duration startupTimeout = const Duration(seconds: 12),
  }) async {
    final dir = await Directory.systemTemp.createTemp('adb_vision_mirror_');
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final id = _displayId ?? 0;
    // .mkv is the only format playable while still growing — mp4's moov
    // atom is only flushed at end-of-file.
    final path = '${dir.path}/mirror_${_serial}_${id}_$stamp.mkv';

    final args = <String>[
      '--serial=$_serial',
      '--no-audio',
      '--no-control', // Input is injected through adb directly.
      // Keep scrcpy's window real (so its display surface is active and
      // produces frames) but place it 1×1 px far off-screen so the user
      // doesn't see it. We additionally hide it via AppleScript on macOS.
      '--window-borderless',
      '--window-width=1',
      '--window-height=1',
      '--window-x=-2000',
      '--window-y=-2000',
      if (_displayId != null && _displayId != 0)
        '--display-id=$_displayId',
      '--max-fps=60',
      '--record=$path',
    ];
    _logBuffer.writeln('\$ $_scrcpyPath ${args.join(' ')}');
    _logBuffer.writeln('output → $path');

    final proc = await Process.start(_scrcpyPath!, args);
    _process = proc;
    _filePath = path;

    // Capture stdout/stderr lines for diagnostics.
    proc.stdout
        .transform(utf8.decoder)
        .listen((s) => _logBuffer.write(s));
    proc.stderr
        .transform(utf8.decoder)
        .listen((s) => _logBuffer.write(s));

    unawaited(proc.exitCode.then((code) {
      _logBuffer.writeln('\nscrcpy exit=$code');
    }));

    // On macOS try to hide the scrcpy window via AppleScript (best-effort).
    if (Platform.isMacOS) {
      unawaited(_hideScrcpyWindowMacOs());
    }

    // Wait for the recording file to actually start growing — that's our
    // signal scrcpy got past the connection / capture handshake.
    final deadline = DateTime.now().add(startupTimeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final code =
            await proc.exitCode.timeout(const Duration(milliseconds: 50));
        _detectKnownFailure();
        throw StateError(
          'scrcpy exited (code $code) before producing output.\n\n$_logBuffer',
        );
      } on TimeoutException {
        // Still running — that's good.
      }
      final f = File(path);
      if (await f.exists() && (await f.length()) > 4 * 1024) {
        // scrcpy doesn't have screenrecord's hard 3-min limit, so no
        // restart timer is needed.
        _filePathController.add(path);
        return path;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    _detectKnownFailure();
    await stop();
    throw TimeoutException(
      'scrcpy did not produce any output within '
      '${startupTimeout.inSeconds}s.\n\n$_logBuffer',
    );
  }

  Future<void> _hideScrcpyWindowMacOs() async {
    // Wait briefly for scrcpy's window to actually appear, otherwise the
    // tell-process command fails with "process not found".
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    try {
      // Hides the application (equivalent to ⌘H). The window stops drawing
      // on screen but the process keeps running and recording to the file.
      await Process.run('osascript', [
        '-e',
        'tell application "System Events" to set visible of '
            '(every process whose name is "scrcpy") to false',
      ]);
    } catch (_) {}
  }

  /// Recognise common, permanent failure signatures and throw a friendlier
  /// error than the raw exit-code dump.
  void _detectKnownFailure() {
    final log = _logBuffer.toString();
    if (log.contains('Invalid physical display ID')) {
      throw const NotCapturableException(
        'This display can\'t be recorded from outside the device.\n\n'
        'It exists only as a logical/overlay display on Android. scrcpy '
        'needs a physical display backing, which Samsung\'s OS doesn\'t '
        'expose for simulated/overlay displays. AnyDesk works because it '
        'runs on the device itself and uses MediaProjection with an '
        'on-device permission popup we can\'t trigger from a desktop adb '
        'session.\n\nWhat still works: input (taps, swipes, keys) is '
        'routed to this display correctly — switch to input-only mode to '
        'use the primary-display fallback view.',
      );
    }
    if (log.contains('ERROR: Failed to open output file')) {
      throw const NotCapturableException(
        'scrcpy could not open the recording file. Check that the disk '
        'has free space and that the OS isn\'t blocking writes to the '
        'temporary directory.',
      );
    }
  }

  Future<void> stop() async {
    _restartTimer?.cancel();
    _restartTimer = null;

    final p = _process;
    final f = _filePath;
    _process = null;
    _filePath = null;
    if (p != null) {
      try {
        p.kill();
        await p.exitCode.timeout(const Duration(seconds: 2));
      } catch (_) {
        try {
          p.kill(ProcessSignal.sigkill);
        } catch (_) {}
      }
    }
    if (f != null) {
      try {
        final file = File(f);
        if (await file.exists()) await file.delete();
        final parent = file.parent;
        if (await parent.exists()) {
          final remaining = parent.listSync();
          if (remaining.isEmpty) await parent.delete();
        }
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    await stop();
    await _filePathController.close();
  }
}
