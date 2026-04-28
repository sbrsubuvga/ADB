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

class ScriptStep {
  const ScriptStep({
    required this.type,
    this.args = const {},
    this.enabled = true,
    this.comment,
  });

  final ScriptStepType type;
  final Map<String, Object?> args;
  final bool enabled;
  final String? comment;

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

  Map<String, Object?> toJson() => {
        'type': type.toJson(),
        ...args,
        if (!enabled) 'disabled': true,
        if (comment != null) 'comment': comment,
      };

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

class Script {
  const Script({
    required this.name,
    required this.steps,
    this.device,
    this.display = 0,
    this.created,
    this.variables = const {},
  });

  final String name;
  final String? device;
  final int display;
  final DateTime? created;
  final Map<String, String> variables;
  final List<ScriptStep> steps;

  Map<String, Object?> toJson() => {
        'name': name,
        if (device != null) 'device': device,
        'display': display,
        'created': (created ?? DateTime.now()).toUtc().toIso8601String(),
        if (variables.isNotEmpty) 'variables': variables,
        'steps': steps.map((s) => s.toJson()).toList(),
      };

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

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
