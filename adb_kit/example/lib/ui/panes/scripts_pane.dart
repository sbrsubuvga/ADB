import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:adb_kit/adb_kit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';

class ScriptsPane extends ConsumerStatefulWidget {
  const ScriptsPane({required this.device, super.key});
  final AdbDevice device;

  @override
  ConsumerState<ScriptsPane> createState() => _ScriptsPaneState();
}

class _ScriptsPaneState extends ConsumerState<ScriptsPane> {
  Script _script = Script(
    name: 'New script',
    steps: const [],
    created: DateTime.now(),
  );
  final _events = <ScriptEvent>[];
  StreamSubscription<ScriptEvent>? _playSub;
  bool _playing = false;
  double _speed = 1;
  int _loops = 1;

  @override
  void dispose() {
    _playSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = res?.files.single.path;
    if (path == null) return;
    final text = await File(path).readAsString();
    setState(() {
      _script = Script.decode(text);
      _events.clear();
    });
  }

  Future<void> _save() async {
    final dest = await FilePicker.platform.saveFile(
      dialogTitle: 'Save script',
      fileName: '${_script.name}.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (dest == null) return;
    await File(dest).writeAsString(_script.encode());
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved $dest')));
    }
  }

  void _addStep(ScriptStepType type) {
    final args = switch (type) {
      ScriptStepType.tap => {'x': 540, 'y': 1200, 'delay_ms': 0},
      ScriptStepType.swipe => {
        'x1': 540,
        'y1': 1500,
        'x2': 540,
        'y2': 500,
        'duration_ms': 300,
      },
      ScriptStepType.text => {'value': 'hello'},
      ScriptStepType.key => {'keycode': 'KEYCODE_ENTER'},
      ScriptStepType.wait => {'ms': 500},
      ScriptStepType.shell => {'cmd': 'pm list packages -3'},
      ScriptStepType.screenshot => {'path': 'step.png'},
      ScriptStepType.intent => {'action': 'android.intent.action.VIEW'},
      ScriptStepType.waitFor => {
        'condition': 'activity',
        'value': 'com.example/.Main',
        'timeout_ms': 5000,
      },
      ScriptStepType.assertion => {
        'kind': 'shell_exit',
        'cmd': 'true',
        'exit': 0,
      },
      ScriptStepType.dragAndDrop => {
        'x1': 100,
        'y1': 100,
        'x2': 500,
        'y2': 500,
        'duration_ms': 300,
      },
    };
    setState(() {
      _script = _script.copyWith(
        steps: [
          ..._script.steps,
          ScriptStep(type: type, args: args),
        ],
      );
    });
  }

  void _editStep(int index) async {
    final step = _script.steps[index];
    final ctrl = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(step.args),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${step.type.toJson()} step'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: TextField(
            controller: ctrl,
            maxLines: 12,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final parsed = jsonDecode(ctrl.text) as Map<String, Object?>;
    setState(() {
      final steps = [..._script.steps];
      steps[index] = step.copyWith(args: parsed);
      _script = _script.copyWith(steps: steps);
    });
  }

  Future<void> _play() async {
    if (_playing) {
      await _playSub?.cancel();
      setState(() => _playing = false);
      return;
    }
    final kit = ref.read(adbKitProvider);
    setState(() {
      _playing = true;
      _events.clear();
    });
    _playSub = kit.scripts
        .play(
          widget.device.serial,
          _script,
          speed: _speed,
          loops: _loops,
          stopOnError: false,
        )
        .listen((evt) {
          if (!mounted) return;
          setState(() => _events.add(evt));
          if (evt is ScriptFinished) {
            _playing = false;
            _playSub?.cancel();
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(6),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _load,
                      icon: const Icon(Icons.folder_open, size: 16),
                      label: const Text('Load'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _save,
                      icon: const Icon(Icons.save, size: 16),
                      label: const Text('Save'),
                    ),
                    PopupMenuButton<ScriptStepType>(
                      tooltip: 'Add step',
                      onSelected: _addStep,
                      itemBuilder: (_) => [
                        for (final t in ScriptStepType.values)
                          PopupMenuItem(value: t, child: Text(t.toJson())),
                      ],
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [Icon(Icons.add, size: 16), Text(' Step')],
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _script.steps.isEmpty ? null : _play,
                      icon: Icon(
                        _playing ? Icons.stop : Icons.play_arrow,
                        size: 16,
                      ),
                      label: Text(_playing ? 'Stop' : 'Play'),
                    ),
                    const SizedBox(width: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Speed'),
                        SizedBox(
                          width: 100,
                          child: Slider(
                            min: 0.25,
                            max: 4,
                            value: _speed,
                            onChanged: (v) => setState(() => _speed = v),
                          ),
                        ),
                        Text('${_speed.toStringAsFixed(2)}x'),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Loops'),
                        SizedBox(
                          width: 60,
                          child: TextFormField(
                            initialValue: '$_loops',
                            keyboardType: TextInputType.number,
                            onChanged: (v) => _loops = int.tryParse(v) ?? 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ReorderableListView.builder(
                  itemCount: _script.steps.length,
                  onReorder: (oldI, newI) {
                    setState(() {
                      final steps = [..._script.steps];
                      final item = steps.removeAt(oldI);
                      steps.insert(newI > oldI ? newI - 1 : newI, item);
                      _script = _script.copyWith(steps: steps);
                    });
                  },
                  itemBuilder: (ctx, i) {
                    final s = _script.steps[i];
                    return ListTile(
                      key: ValueKey('step-$i'),
                      dense: true,
                      leading: Checkbox(
                        value: s.enabled,
                        onChanged: (v) {
                          setState(() {
                            final steps = [..._script.steps];
                            steps[i] = s.copyWith(enabled: v ?? true);
                            _script = _script.copyWith(steps: steps);
                          });
                        },
                      ),
                      title: Text('${i + 1}. ${s.type.toJson()}'),
                      subtitle: Text(
                        s.args.toString(),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 16),
                            onPressed: () => _editStep(i),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 16),
                            onPressed: () => setState(() {
                              final steps = [..._script.steps]..removeAt(i);
                              _script = _script.copyWith(steps: steps);
                            }),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 2,
          child: Container(
            color: Colors.black,
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _events.length,
              itemBuilder: (ctx, i) {
                final e = _events[i];
                final color = switch (e) {
                  ScriptStepFailed() => Colors.redAccent,
                  ScriptStepCompleted() => Colors.greenAccent,
                  ScriptFinished() => Colors.amberAccent,
                  _ => Colors.lightBlueAccent,
                };
                final label = switch (e) {
                  ScriptStepStarted() =>
                    'start ${e.index + 1} ${e.step.type.toJson()}',
                  ScriptStepCompleted(:final message) =>
                    'ok    ${e.index + 1} ${e.step.type.toJson()} ${message ?? ''}',
                  ScriptStepFailed(:final error) =>
                    'fail  ${e.index + 1} ${e.step.type.toJson()} $error',
                  ScriptFinished() => '— finished —',
                };
                return Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
