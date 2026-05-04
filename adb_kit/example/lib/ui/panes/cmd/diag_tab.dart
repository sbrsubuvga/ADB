import 'package:adb_kit/adb_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/providers.dart';

class DiagTab extends ConsumerStatefulWidget {
  const DiagTab({required this.device, super.key});
  final AdbDevice device;

  @override
  ConsumerState<DiagTab> createState() => _DiagTabState();
}

class _DiagTabState extends ConsumerState<DiagTab> {
  String _output = '';
  bool _busy = false;

  Future<void> _run(Future<String> Function() task) async {
    setState(() => _busy = true);
    try {
      final r = await task();
      setState(() => _output = r);
    } catch (e) {
      setState(() => _output = 'error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kit = ref.watch(adbKitProvider);
    final s = widget.device.serial;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip('battery', () => kit.dumpsys.raw(s, ['battery'])),
              _chip('power', () => kit.dumpsys.raw(s, ['power'])),
              _chip('window', () => kit.dumpsys.window(s)),
              _chip('activity', () => kit.dumpsys.activity(s)),
              _chip('cpuinfo', () => kit.dumpsys.cpuInfo(s)),
              _chip('netstats', () => kit.dumpsys.netstats(s)),
              _chip('connectivity', () => kit.dumpsys.connectivity(s)),
              _chip('wifi', () => kit.dumpsys.wifi(s)),
              _chip('input', () => kit.dumpsys.input(s)),
              _chip('thermal', () => kit.dumpsys.thermal(s)),
              _chip('alarm', () => kit.dumpsys.alarm(s)),
              _chip('notification', () => kit.dumpsys.notification(s)),
              _chip('usagestats', () => kit.dumpsys.usageStats(s)),
              _chip('getprop', () async {
                final all = await kit.props.getAll(s);
                return all.entries.map((e) => '${e.key}=${e.value}').join('\n');
              }),
              _chip('top', () async {
                final r = await kit.shell.exec(s, 'top -n 1 -b');
                return r.stdout;
              }),
              _chip('focused window', () async {
                final w = await kit.activity.focusedWindow(s);
                return 'mCurrentFocus=$w';
              }),
            ],
          ),
        ),
        if (_busy) const LinearProgressIndicator(),
        const Divider(height: 1),
        Expanded(
          child: Container(
            color: Colors.black,
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(
              child: SelectableText(
                _output,
                style: const TextStyle(
                  color: Colors.lightGreenAccent,
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, Future<String> Function() task) =>
      ActionChip(label: Text(label), onPressed: () => _run(task));
}
