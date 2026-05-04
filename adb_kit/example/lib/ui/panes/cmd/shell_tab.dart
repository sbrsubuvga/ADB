import 'package:adb_kit/adb_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/providers.dart';

class ShellTab extends ConsumerStatefulWidget {
  const ShellTab({required this.device, super.key});
  final AdbDevice device;

  @override
  ConsumerState<ShellTab> createState() => _ShellTabState();
}

class _ShellTabState extends ConsumerState<ShellTab> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _history = <String>[];
  final _outputBuffer = StringBuffer();
  int _historyIndex = -1;

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final cmd = _ctrl.text.trim();
    if (cmd.isEmpty) return;
    _history.add(cmd);
    _historyIndex = _history.length;
    _ctrl.clear();
    final kit = ref.read(adbKitProvider);
    setState(() {
      _outputBuffer.writeln('\$ $cmd');
    });
    try {
      final r = await kit.shell.exec(
        widget.device.serial,
        cmd,
        timeout: const Duration(seconds: 30),
      );
      setState(() {
        if (r.stdout.isNotEmpty) _outputBuffer.writeln(r.stdout.trimRight());
        if (r.stderr.isNotEmpty) _outputBuffer.writeln(r.stderr.trimRight());
        _outputBuffer.writeln('[exit=${r.exitCode}, ${r.duration.inMilliseconds}ms]');
      });
    } catch (e) {
      setState(() => _outputBuffer.writeln('error: $e'));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  void _navigateHistory(int delta) {
    if (_history.isEmpty) return;
    _historyIndex = (_historyIndex + delta).clamp(0, _history.length);
    final value = _historyIndex >= _history.length
        ? ''
        : _history[_historyIndex];
    _ctrl
      ..text = value
      ..selection = TextSelection.collapsed(offset: value.length);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            color: Colors.black,
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.all(8),
              child: SelectableText(
                _outputBuffer.toString(),
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: Shortcuts(
                  shortcuts: const {
                    SingleActivator(LogicalKeyboardKey.arrowUp):
                        _HistoryIntent(-1),
                    SingleActivator(LogicalKeyboardKey.arrowDown):
                        _HistoryIntent(1),
                  },
                  child: Actions(
                    actions: <Type, Action<Intent>>{
                      _HistoryIntent: CallbackAction<_HistoryIntent>(
                        onInvoke: (i) {
                          _navigateHistory(i.delta);
                          return null;
                        },
                      ),
                    },
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        prefixText: r'$ ',
                        border: OutlineInputBorder(),
                        hintText: 'shell command…',
                      ),
                      style: const TextStyle(fontFamily: 'monospace'),
                      onSubmitted: (_) => _run(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _run, child: const Text('Run')),
              IconButton(
                onPressed: () => setState(_outputBuffer.clear),
                tooltip: 'Clear output',
                icon: const Icon(Icons.clear_all),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HistoryIntent extends Intent {
  const _HistoryIntent(this.delta);
  final int delta;
}
