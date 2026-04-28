import 'dart:async';
import 'dart:io';

import '../models/intent_spec.dart';
import '../models/script.dart';
import 'activity_service.dart';
import 'input_service.dart';
import 'logcat_service.dart';
import 'screen_service.dart';
import 'shell_service.dart';

/// Emitted during script playback.
sealed class ScriptEvent {
  const ScriptEvent(this.index, this.step);
  final int index;
  final ScriptStep step;
}

class ScriptStepStarted extends ScriptEvent {
  const ScriptStepStarted(super.index, super.step);
}

class ScriptStepCompleted extends ScriptEvent {
  const ScriptStepCompleted(super.index, super.step, this.message);
  final String? message;
}

class ScriptStepFailed extends ScriptEvent {
  const ScriptStepFailed(super.index, super.step, this.error);
  final Object error;
}

class ScriptFinished extends ScriptEvent {
  const ScriptFinished() : super(-1, const ScriptStep(type: ScriptStepType.wait));
}

/// A ScriptRecorder observes manual input and writes out a replayable Script.
class ScriptRecorder {
  ScriptRecorder({required this.name, String? device, int display = 0})
      : _script = Script(
          name: name,
          device: device,
          display: display,
          created: DateTime.now(),
          steps: const [],
        );

  final String name;
  Script _script;
  DateTime? _lastStepAt;

  Script get script => _script;

  void tap(int x, int y) => _push(ScriptStep(
        type: ScriptStepType.tap,
        args: {'x': x, 'y': y, 'delay_ms': _elapsedMs()},
      ));

  void swipe(int x1, int y1, int x2, int y2, int durationMs) => _push(
        ScriptStep(
          type: ScriptStepType.swipe,
          args: {
            'x1': x1,
            'y1': y1,
            'x2': x2,
            'y2': y2,
            'duration_ms': durationMs,
            'delay_ms': _elapsedMs(),
          },
        ),
      );

  void text(String value) => _push(ScriptStep(
        type: ScriptStepType.text,
        args: {'value': value, 'delay_ms': _elapsedMs()},
      ));

  void key(String keycode) => _push(ScriptStep(
        type: ScriptStepType.key,
        args: {'keycode': keycode, 'delay_ms': _elapsedMs()},
      ));

  void intent(IntentSpec spec) => _push(ScriptStep(
        type: ScriptStepType.intent,
        args: {
          if (spec.action != null) 'action': spec.action,
          if (spec.data != null) 'data': spec.data,
          if (spec.component != null) 'component': spec.component,
          'delay_ms': _elapsedMs(),
        },
      ));

  void shell(String cmd) => _push(ScriptStep(
        type: ScriptStepType.shell,
        args: {'cmd': cmd, 'delay_ms': _elapsedMs()},
      ));

  int _elapsedMs() {
    final now = DateTime.now();
    final prev = _lastStepAt;
    _lastStepAt = now;
    if (prev == null) return 0;
    return now.difference(prev).inMilliseconds;
  }

  void _push(ScriptStep s) {
    _script = _script.copyWith(steps: [..._script.steps, s]);
  }

  void clear() {
    _lastStepAt = null;
    _script = _script.copyWith(steps: []);
  }
}

/// Orchestrates script replay.
class ScriptPlayer {
  ScriptPlayer({
    required this.input,
    required this.activity,
    required this.screen,
    required this.shell,
    required this.logcat,
  });

  final InputService input;
  final ActivityService activity;
  final ScreenService screen;
  final ShellService shell;
  final LogcatService logcat;

  /// Playback. [speed] > 1 is faster. `stopOnError` aborts on the first
  /// failing step; otherwise failed steps are reported and skipped.
  Stream<ScriptEvent> play(
    String serial,
    Script script, {
    double speed = 1.0,
    int loops = 1,
    bool stopOnError = true,
    Map<String, String> variables = const {},
    bool Function()? shouldPause,
  }) async* {
    final allVars = {...script.variables, ...variables};

    for (var loop = 0; loop < loops; loop++) {
      for (var i = 0; i < script.steps.length; i++) {
        final step = script.steps[i];
        if (!step.enabled) continue;

        yield ScriptStepStarted(i, step);

        // honour delay_ms between steps
        final delayMs = (step.args['delay_ms'] as num?)?.toInt() ?? 0;
        if (delayMs > 0) {
          await Future<void>.delayed(
              Duration(milliseconds: (delayMs / speed).round()));
        }

        while (shouldPause?.call() == true) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }

        try {
          String? message;
          switch (step.type) {
            case ScriptStepType.tap:
              await input.tap(
                serial,
                x: _iv(step.args['x'], allVars)!,
                y: _iv(step.args['y'], allVars)!,
                displayId: _iv(step.args['display'], allVars),
              );
            case ScriptStepType.swipe:
              final duration =
                  _iv(step.args['duration_ms'], allVars) ?? 300;
              await input.swipe(
                serial,
                x1: _iv(step.args['x1'], allVars)!,
                y1: _iv(step.args['y1'], allVars)!,
                x2: _iv(step.args['x2'], allVars)!,
                y2: _iv(step.args['y2'], allVars)!,
                durationMs: (duration / speed).round(),
                displayId: _iv(step.args['display'], allVars),
              );
            case ScriptStepType.dragAndDrop:
              await input.dragAndDrop(
                serial,
                x1: _iv(step.args['x1'], allVars)!,
                y1: _iv(step.args['y1'], allVars)!,
                x2: _iv(step.args['x2'], allVars)!,
                y2: _iv(step.args['y2'], allVars)!,
                durationMs: _iv(step.args['duration_ms'], allVars) ?? 400,
              );
            case ScriptStepType.text:
              await input.text(serial,
                  _interp(step.args['value'] as String, allVars));
            case ScriptStepType.key:
              await input.keyEvent(
                  serial, step.args['keycode'] as String);
            case ScriptStepType.wait:
              final ms =
                  (_iv(step.args['ms'], allVars) ?? 0) ~/ speed.round();
              await Future<void>.delayed(Duration(milliseconds: ms));
            case ScriptStepType.waitFor:
              message = await _waitFor(serial, step);
            case ScriptStepType.screenshot:
              final path = _interp(
                  step.args['path'] as String? ?? 'step_$i.png', allVars);
              await screen.screenshotTo(serial, path);
              message = 'saved $path';
            case ScriptStepType.shell:
              final r = await shell.exec(
                  serial, _interp(step.args['cmd'] as String, allVars));
              message = 'exit=${r.exitCode}';
            case ScriptStepType.intent:
              final spec = IntentSpec(
                action: step.args['action'] as String?,
                data: step.args['data'] as String?,
                component: step.args['component'] as String?,
              );
              await activity.start(serial, spec);
            case ScriptStepType.assertion:
              message = await _assert(serial, step);
          }
          yield ScriptStepCompleted(i, step, message);
        } catch (e) {
          yield ScriptStepFailed(i, step, e);
          if (stopOnError) {
            yield const ScriptFinished();
            return;
          }
        }
      }
    }
    yield const ScriptFinished();
  }

  Future<String> _waitFor(String serial, ScriptStep step) async {
    final timeout =
        Duration(milliseconds: (step.args['timeout_ms'] as num?)?.toInt() ?? 10000);
    final deadline = DateTime.now().add(timeout);
    final condition = step.args['condition'] as String?;
    final value = step.args['value'] as String?;
    if (condition == null || value == null) {
      throw ArgumentError('wait_for requires condition + value');
    }
    switch (condition) {
      case 'activity':
        while (DateTime.now().isBefore(deadline)) {
          final now = await activity.currentFocusedActivity(serial);
          if (now != null && now.contains(value)) return 'matched $now';
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        throw TimeoutException('activity "$value" not found');
      case 'logcat_regex':
        final re = RegExp(value);
        final snapshot = await logcat.snapshot(serial);
        if (re.hasMatch(snapshot)) return 'matched (snapshot)';
        throw TimeoutException('logcat pattern "$value" not found');
      default:
        throw ArgumentError('unknown wait_for condition "$condition"');
    }
  }

  Future<String> _assert(String serial, ScriptStep step) async {
    final kind = step.args['kind'];
    switch (kind) {
      case 'shell_exit':
        final r =
            await shell.exec(serial, step.args['cmd']! as String);
        final expected = (step.args['exit'] as num?)?.toInt() ?? 0;
        if (r.exitCode != expected) {
          throw StateError('exit=${r.exitCode} expected $expected');
        }
        return 'exit=${r.exitCode}';
      case 'activity_equals':
        final focused = await activity.currentFocusedActivity(serial);
        if (focused != step.args['value']) {
          throw StateError('focused=$focused');
        }
        return 'ok';
      default:
        throw ArgumentError('unknown assert kind "$kind"');
    }
  }

  int? _iv(Object? raw, Map<String, String> vars) {
    if (raw == null) return null;
    if (raw is num) return raw.toInt();
    if (raw is String) {
      final interpolated = _interp(raw, vars);
      return int.tryParse(interpolated);
    }
    return null;
  }

  String _interp(String src, Map<String, String> vars) {
    return src.replaceAllMapped(RegExp(r'\$\{([^}]+)\}'), (m) {
      final key = m.group(1)!;
      if (vars.containsKey(key)) return vars[key]!;
      if (key.startsWith('env.')) {
        return Platform.environment[key.substring(4)] ?? '';
      }
      return m.group(0)!;
    });
  }
}
