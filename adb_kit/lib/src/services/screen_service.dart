import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../runner/adb_runner.dart';

class ScreencapOptions {
  const ScreencapOptions({this.displayId});
  final int? displayId;

  List<String> toArgs() => [
        'screencap',
        '-p',
        if (displayId != null) ...['-d', '$displayId'],
      ];
}

class ScreenrecordOptions {
  const ScreenrecordOptions({
    this.size,
    this.bitRate,
    this.timeLimitSeconds,
    this.verbose = false,
    this.rotate = false,
    this.displayId,
    this.outputFormat,
  });

  /// "WxH"
  final String? size;
  final int? bitRate;
  final int? timeLimitSeconds;
  final bool verbose;
  final bool rotate;
  final int? displayId;

  /// mp4 | h264 | frames
  final String? outputFormat;

  List<String> toArgs() => [
        if (size != null) ...['--size', size!],
        if (bitRate != null) ...['--bit-rate', '$bitRate'],
        if (timeLimitSeconds != null) ...['--time-limit', '$timeLimitSeconds'],
        if (rotate) '--rotate',
        if (displayId != null) ...['--display-id', '$displayId'],
        if (outputFormat != null) ...['--output-format', outputFormat!],
        if (verbose) '--verbose',
      ];
}

/// Screencap + screenrecord convenience wrapper. This is the **fallback**
/// mirror backend. The scrcpy backend lives in the host app (requires a
/// native H.264 decoder).
class ScreenService {
  ScreenService(this._runner);
  final AdbRunner _runner;

  /// PNG magic header — `89 50 4E 47 0D 0A 1A 0A`.
  static const _pngSignature = [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  ];

  /// Returns true if the given bytes start with the PNG signature.
  static bool isPng(List<int> bytes) {
    if (bytes.length < _pngSignature.length) return false;
    for (var i = 0; i < _pngSignature.length; i++) {
      if (bytes[i] != _pngSignature[i]) return false;
    }
    return true;
  }

  /// Read the width × height from a PNG byte buffer by inspecting the
  /// IHDR chunk (the first chunk after the signature, fixed offsets 16..23).
  /// Returns null if the buffer is too short or not a PNG.
  static (int, int)? readPngDimensions(List<int> bytes) {
    if (!isPng(bytes) || bytes.length < 24) return null;
    final w = (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
    final h = (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
    if (w <= 0 || h <= 0) return null;
    return (w, h);
  }

  /// Capture a PNG of the current frame.
  ///
  /// Returns an empty list if the device responded but the bytes are not a
  /// valid PNG (which happens, for example, when targeting a display id that
  /// no longer exists). The caller should treat empty as "skip frame".
  Future<Uint8List> screencapPng(
    String serial, {
    ScreencapOptions options = const ScreencapOptions(),
  }) async {
    try {
      final bytes = await _runner.execOut(options.toArgs(), serial: serial);
      if (!isPng(bytes)) return Uint8List(0);
      return Uint8List.fromList(bytes);
    } catch (_) {
      return Uint8List(0);
    }
  }

  /// Continuously capture frames using `exec-out screencap -p`.
  /// Emits one PNG per tick. `fps` is the target polling rate.
  Stream<Uint8List> mirror(
    String serial, {
    double fps = 5,
    ScreencapOptions options = const ScreencapOptions(),
  }) async* {
    final period = Duration(milliseconds: (1000 / fps).round());
    while (true) {
      final start = DateTime.now();
      try {
        yield await screencapPng(serial, options: options);
      } catch (e) {
        yield Uint8List(0);
      }
      final elapsed = DateTime.now().difference(start);
      final remaining = period - elapsed;
      if (remaining > Duration.zero) {
        await Future<void>.delayed(remaining);
      }
    }
  }

  /// On-device screenrecord. Returns the [AdbStreamHandle] so the caller can
  /// kill it. After termination, use [saveRecordingTo] to pull the file.
  Future<AdbStreamHandle> screenrecord(
    String serial,
    String remotePath, {
    ScreenrecordOptions options = const ScreenrecordOptions(),
  }) {
    return _runner.stream(
      ['shell', 'screenrecord', ...options.toArgs(), remotePath],
      serial: serial,
    );
  }

  /// Pull a recording from device to host.
  Future<void> saveRecordingTo(
    String serial,
    String remotePath,
    String localPath,
  ) async {
    await _runner.runOk(
      ['pull', remotePath, localPath],
      serial: serial,
      timeout: const Duration(minutes: 5),
    );
  }

  /// Save a screenshot PNG to the given path.
  Future<File> screenshotTo(
    String serial,
    String path, {
    ScreencapOptions options = const ScreencapOptions(),
  }) async {
    final bytes = await screencapPng(serial, options: options);
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return file;
  }
}
