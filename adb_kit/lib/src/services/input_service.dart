import 'dart:math' as math;

import '../models/display.dart';
import '../models/keycode.dart';
import '../runner/adb_runner.dart';

/// Input source families understood by `input <source> ...`.
enum InputSource {
  touchscreen,
  touchpad,
  mouse,
  stylus,
  dpad,
  keyboard,
  gamepad,
  trackball,
  joystick,
  touchnavigation;

  /// CLI token passed to `input`.
  String get token {
    switch (this) {
      case InputSource.touchscreen:
        return 'touchscreen';
      case InputSource.touchpad:
        return 'touchpad';
      case InputSource.mouse:
        return 'mouse';
      case InputSource.stylus:
        return 'stylus';
      case InputSource.dpad:
        return 'dpad';
      case InputSource.keyboard:
        return 'keyboard';
      case InputSource.gamepad:
        return 'gamepad';
      case InputSource.trackball:
        return 'trackball';
      case InputSource.joystick:
        return 'joystick';
      case InputSource.touchnavigation:
        return 'touchnavigation';
    }
  }
}

/// Translates widget-space pixel coordinates to device-space.
class CoordinateMapper {
  /// Creates a [CoordinateMapper].
  const CoordinateMapper({
    required this.displayWidth,
    required this.displayHeight,
    required this.widgetWidth,
    required this.widgetHeight,
    this.rotation = 0,
  });

  /// Device display width in pixels.
  final double displayWidth;

  /// Device display height in pixels.
  final double displayHeight;

  /// Widget width in pixels.
  final double widgetWidth;

  /// Widget height in pixels.
  final double widgetHeight;

  /// Device rotation in quarters.
  final int rotation;

  /// Accepts a widget-space point and returns the corresponding
  /// device-pixel point, respecting rotation.
  (int, int) map(double wx, double wy) {
    final nx = (wx / widgetWidth).clamp(0.0, 1.0);
    final ny = (wy / widgetHeight).clamp(0.0, 1.0);

    switch (rotation % 4) {
      case 1:
        return (
          (ny * displayWidth).round(),
          ((1 - nx) * displayHeight).round(),
        );
      case 2:
        return (
          ((1 - nx) * displayWidth).round(),
          ((1 - ny) * displayHeight).round(),
        );
      case 3:
        return (
          ((1 - ny) * displayWidth).round(),
          (nx * displayHeight).round(),
        );
      default:
        return ((nx * displayWidth).round(), (ny * displayHeight).round());
    }
  }

  /// Estimate a natural swipe duration from movement distance (pixels) and
  /// elapsed time. Clamped to [80,1000] ms like scrcpy's input heuristics.
  static int estimateSwipeDuration(
    int x1,
    int y1,
    int x2,
    int y2,
    Duration elapsed,
  ) {
    final dist = math.sqrt(math.pow(x2 - x1, 2) + math.pow(y2 - y1, 2));
    final base = (dist * 1.4).clamp(80, 1000);
    final actual = elapsed.inMilliseconds.clamp(80, 1000);
    return math.max(base.toInt(), actual);
  }

  /// Creates a mapper sized from a known [AdbDisplay].
  static CoordinateMapper fromDisplay(
    AdbDisplay d, {
    required double widgetWidth,
    required double widgetHeight,
  }) =>
      CoordinateMapper(
        displayWidth: d.width.toDouble(),
        displayHeight: d.height.toDouble(),
        widgetWidth: widgetWidth,
        widgetHeight: widgetHeight,
        rotation: d.rotation,
      );
}

/// Wraps the `input` shell command for taps, swipes, text and key events.
class InputService {
  /// Creates an [InputService] backed by [_runner].
  InputService(this._runner);
  final AdbRunner _runner;

  /// Sends a single tap at ([x], [y]).
  Future<void> tap(
    String serial, {
    required int x,
    required int y,
    int? displayId,
    InputSource source = InputSource.touchscreen,
  }) =>
      _runner.runOk(
        [
          'shell',
          'input',
          source.token,
          if (displayId != null) ...['--display', '$displayId'],
          'tap',
          '$x',
          '$y',
        ],
        serial: serial,
        timeout: const Duration(seconds: 5),
      );

  /// Performs a swipe from ([x1], [y1]) to ([x2], [y2]) over [durationMs] ms.
  Future<void> swipe(
    String serial, {
    required int x1,
    required int y1,
    required int x2,
    required int y2,
    int durationMs = 300,
    int? displayId,
    InputSource source = InputSource.touchscreen,
  }) =>
      _runner.runOk(
        [
          'shell',
          'input',
          source.token,
          if (displayId != null) ...['--display', '$displayId'],
          'swipe',
          '$x1',
          '$y1',
          '$x2',
          '$y2',
          '$durationMs',
        ],
        serial: serial,
        timeout: Duration(milliseconds: durationMs + 4000),
      );

  /// Performs a long-press drag from ([x1], [y1]) to ([x2], [y2]).
  Future<void> dragAndDrop(
    String serial, {
    required int x1,
    required int y1,
    required int x2,
    required int y2,
    int durationMs = 400,
    int? displayId,
  }) =>
      _runner.runOk(
        [
          'shell',
          'input',
          if (displayId != null) ...['--display', '$displayId'],
          'draganddrop',
          '$x1',
          '$y1',
          '$x2',
          '$y2',
          '$durationMs',
        ],
        serial: serial,
        timeout: Duration(milliseconds: durationMs + 4000),
      );

  /// ASCII text only. For Unicode/CJK/emoji use [broadcastText] with the
  /// ADBKeyboard companion app.
  Future<void> text(
    String serial,
    String text, {
    int? displayId,
  }) =>
      _runner.runOk(
        [
          'shell',
          'input',
          if (displayId != null) ...['--display', '$displayId'],
          'text',
          text.replaceAll(' ', '%s'),
        ],
        serial: serial,
      );

  /// Broadcast to https://github.com/senzhk/ADBKeyBoard — supports Unicode.
  Future<void> broadcastText(String serial, String text) => _runner.runOk([
        'shell',
        'am',
        'broadcast',
        '-a',
        'ADB_INPUT_TEXT',
        '--es',
        'msg',
        text,
      ], serial: serial);

  /// Sends a key event for [key] (a [KeyCode], int, or string token).
  Future<void> keyEvent(
    String serial,
    Object key, {
    bool longPress = false,
    int? displayId,
  }) {
    final token = key is KeyCode
        ? key.name
        : key is int
            ? '$key'
            : key.toString();
    return _runner.runOk(
      [
        'shell',
        'input',
        if (displayId != null) ...['--display', '$displayId'],
        'keyevent',
        if (longPress) '--longpress',
        token,
      ],
      serial: serial,
    );
  }

  /// Sends a single motion event (`DOWN`, `UP`, `MOVE`) at ([x], [y]).
  Future<void> motionEvent(
    String serial, {
    required String action,
    required int x,
    required int y,
    int? displayId,
  }) =>
      _runner.runOk(
        [
          'shell',
          'input',
          if (displayId != null) ...['--display', '$displayId'],
          'motionevent',
          action,
          '$x',
          '$y',
        ],
        serial: serial,
      );

  /// Emits a trackball press event.
  Future<void> press(String serial) =>
      _runner.runOk(['shell', 'input', 'trackball', 'press'], serial: serial);

  /// Rolls the simulated trackball by ([dx], [dy]).
  Future<void> roll(String serial, int dx, int dy) => _runner.runOk(
        ['shell', 'input', 'trackball', 'roll', '$dx', '$dy'],
        serial: serial,
      );
}
