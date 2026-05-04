import 'package:adb_kit/adb_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/providers.dart';

class InputTab extends ConsumerStatefulWidget {
  const InputTab({required this.device, super.key});
  final AdbDevice device;

  @override
  ConsumerState<InputTab> createState() => _InputTabState();
}

class _InputTabState extends ConsumerState<InputTab> {
  final _textCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  bool _broadcastMode = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kit = ref.watch(adbKitProvider);
    final query = _searchCtrl.text.toLowerCase();
    final keys = KeyCode.all
        .where((k) => k.name.toLowerCase().contains(query))
        .toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('Text input', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textCtrl,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  hintText: 'type to send to device',
                ),
                onSubmitted: _sendText,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => _sendText(_textCtrl.text),
              child: const Text('Send'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Use ADBKeyboard broadcast (Unicode)'),
          subtitle: const Text(
            'Requires ADBKeyboard IME app to be installed and selected as input method.',
          ),
          value: _broadcastMode,
          onChanged: (v) => setState(() => _broadcastMode = v),
        ),
        const Divider(height: 24),
        const Text('Key events', style: TextStyle(fontWeight: FontWeight.bold)),
        TextField(
          controller: _searchCtrl,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            isDense: true,
            prefixIcon: Icon(Icons.search),
            hintText: 'filter keycodes',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final k in keys.take(80))
              ActionChip(
                label: Text(
                  k.name.replaceFirst('KEYCODE_', ''),
                  style: const TextStyle(fontSize: 11),
                ),
                onPressed: () => kit.input.keyEvent(widget.device.serial, k),
              ),
          ],
        ),
        const Divider(height: 24),
        const Text(
          'Tap, swipe, motion',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Use the mirror to tap and swipe.\n'
          '• Left click: tap\n'
          '• Drag: swipe (duration auto-computed)\n'
          '• Right click: BACK\n'
          '• Middle click: HOME\n'
          '• Mouse forward: APP_SWITCH\n'
          '• Scroll wheel: vertical scroll',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Future<void> _sendText(String text) async {
    if (text.isEmpty) return;
    final kit = ref.read(adbKitProvider);
    try {
      if (_broadcastMode) {
        await kit.input.broadcastText(widget.device.serial, text);
      } else {
        await kit.input.text(widget.device.serial, text);
      }
      _textCtrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('text failed: $e')));
      }
    }
  }
}
