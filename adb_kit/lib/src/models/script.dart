import 'dart:convert';

/// JSON-serialisable automation step types.
enum ScriptStepType {
  tap,
  swipe,
  dragAndDrop,
  text,
  key,
  wait,
  waitFor,
  screenshot,
  shell,
  intent,
  assertion;

  /// Stable JSON token for this step type.
  String toJson() {
    switch (this) {
      case ScriptStepType.tap:
        return 'tap';
      case ScriptStepType.swipe:
        return 'swipe';
      case ScriptStepType.dragAndDrop:
        return 'draganddrop';
      case ScriptStepType.text:
        return 'text';
      case ScriptStepType.key:
        return 'key';
      case ScriptStepType.wait:
        return 'wait';
      case ScriptStepType.waitFor:
        return 'wait_for';
      case ScriptStepType.screenshot:
        return 'screenshot';
      case ScriptStepType.shell:
        return 'shell';
      case ScriptStepType.intent:
        return 'intent';
      case ScriptStepType.assertion:
        return 'assert';
    }
  }

  /// Parses the JSON token written by [toJson].
  static ScriptStepType fromJson(String s) {
    switch (s) {
      case 'tap':
        return ScriptStepType.tap;
      case 'swipe':
        return ScriptStepType.swipe;
      case 'draganddrop':
        return ScriptStepType.dragAndDrop;
      case 'text':
        return ScriptStepType.text;
      case 'key':
        return ScriptStepType.key;
      case 'wait':
        return ScriptStepType.wait;
      case 'wait_for':
        return ScriptStepType.waitFor;
      case 'screenshot':
        return ScriptStepType.screenshot;
      case 'shell':
        return ScriptStepType.shell;
      case 'intent':
        return ScriptStepType.intent;
      case 'assert':
        return ScriptStepType.assertion;
    }
    throw FormatException('Unknown step type "$s"');
  }
}

/// One step inside a [Script].
class ScriptStep {
  /// Creates a [ScriptStep].
  const ScriptStep({
    required this.type,
    this.args = const {},
    this.enabled = true,
    this.comment,
  });

  /// What action this step performs.
  final ScriptStepType type;

  /// Step-specific arguments (e.g. `x`, `y`, `cmd`).
  final Map<String, Object?> args;

  /// Disabled steps are skipped during playback.
  final bool enabled;

  /// Optional human-readable comment.
  final String? comment;

  /// Returns a copy with the given fields replaced.
  ScriptStep copyWith({
    ScriptStepType? type,
    Map<String, Object?>? args,
    bool? enabled,
    String? comment,
  }) =>
      ScriptStep(
        type: type ?? this.type,
        args: args ?? this.args,
        enabled: enabled ?? this.enabled,
        comment: comment ?? this.comment,
      );

  /// Serialises this step to a JSON-compatible map.
  Map<String, Object?> toJson() => {
        'type': type.toJson(),
        ...args,
        if (!enabled) 'disabled': true,
        if (comment != null) 'comment': comment,
      };

  /// Parses a step from its JSON representation.
  static ScriptStep fromJson(Map<String, Object?> json) {
    final type = ScriptStepType.fromJson(json['type']! as String);
    final args = Map<String, Object?>.from(json)
      ..remove('type')
      ..remove('disabled')
      ..remove('comment');
    return ScriptStep(
      type: type,
      args: args,
      enabled: json['disabled'] != true,
      comment: json['comment'] as String?,
    );
  }
}

/// A named, ordered sequence of [ScriptStep]s.
class Script {
  /// Creates a [Script].
  const Script({
    required this.name,
    required this.steps,
    this.device,
    this.display = 0,
    this.created,
    this.variables = const {},
  });

  /// Display name of the script.
  final String name;

  /// Optional device serial this script was authored against.
  final String? device;

  /// Default display id steps target.
  final int display;

  /// Creation timestamp, when known.
  final DateTime? created;

  /// Default `${name}` interpolation values.
  final Map<String, String> variables;

  /// Ordered steps to execute.
  final List<ScriptStep> steps;

  /// Serialises the script to a JSON-compatible map.
  Map<String, Object?> toJson() => {
        'name': name,
        if (device != null) 'device': device,
        'display': display,
        'created': (created ?? DateTime.now()).toUtc().toIso8601String(),
        if (variables.isNotEmpty) 'variables': variables,
        'steps': steps.map((s) => s.toJson()).toList(),
      };

  /// Encodes the script as a pretty-printed JSON string.
  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Decodes a script from the JSON [source] produced by [encode].
  static Script decode(String source) {
    final j = jsonDecode(source) as Map<String, Object?>;
    return Script(
      name: j['name'] as String? ?? 'untitled',
      device: j['device'] as String?,
      display: (j['display'] as num?)?.toInt() ?? 0,
      created: j['created'] == null
          ? null
          : DateTime.tryParse(j['created']! as String),
      variables: (j['variables'] as Map?)?.cast<String, String>() ?? const {},
      steps: ((j['steps'] as List?) ?? const [])
          .cast<Map<String, Object?>>()
          .map(ScriptStep.fromJson)
          .toList(),
    );
  }

  /// Returns a copy with the given fields replaced.
  Script copyWith({
    String? name,
    String? device,
    int? display,
    List<ScriptStep>? steps,
    Map<String, String>? variables,
  }) =>
      Script(
        name: name ?? this.name,
        device: device ?? this.device,
        display: display ?? this.display,
        created: created,
        variables: variables ?? this.variables,
        steps: steps ?? this.steps,
      );
}
