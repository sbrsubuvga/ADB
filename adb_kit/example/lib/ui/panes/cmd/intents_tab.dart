import 'package:adb_kit/adb_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/providers.dart';

class IntentsTab extends ConsumerStatefulWidget {
  const IntentsTab({required this.device, super.key});
  final AdbDevice device;

  @override
  ConsumerState<IntentsTab> createState() => _IntentsTabState();
}

class _IntentsTabState extends ConsumerState<IntentsTab> {
  final _action = TextEditingController(text: 'android.intent.action.VIEW');
  final _data = TextEditingController(text: 'https://example.com');
  final _component = TextEditingController();
  final _mime = TextEditingController();
  final _category = TextEditingController();
  final _packageCtrl = TextEditingController();
  String _kind = 'start';
  final _extras = <_Extra>[];
  String _output = '';

  @override
  void dispose() {
    _action.dispose();
    _data.dispose();
    _component.dispose();
    _mime.dispose();
    _category.dispose();
    _packageCtrl.dispose();
    super.dispose();
  }

  IntentSpec _spec() => IntentSpec(
        action: _action.text.trim().isEmpty ? null : _action.text.trim(),
        data: _data.text.trim().isEmpty ? null : _data.text.trim(),
        component: _component.text.trim().isEmpty
            ? null
            : _component.text.trim(),
        mimeType: _mime.text.trim().isEmpty ? null : _mime.text.trim(),
        categories: _category.text.trim().isEmpty
            ? const []
            : _category.text.trim().split(','),
        packageName: _packageCtrl.text.trim().isEmpty
            ? null
            : _packageCtrl.text.trim(),
        extras: [
          for (final e in _extras)
            IntentExtra(e.type, e.key.text, e.value.text),
        ],
      );

  Future<void> _send() async {
    final kit = ref.read(adbKitProvider);
    try {
      final spec = _spec();
      String result;
      switch (_kind) {
        case 'start':
          result = await kit.activity.start(widget.device.serial, spec);
        case 'broadcast':
          result = await kit.activity.broadcast(widget.device.serial, spec);
        case 'startservice':
          result = await kit.activity.startService(widget.device.serial, spec);
        default:
          result = '';
      }
      setState(() => _output = result);
    } catch (e) {
      setState(() => _output = 'error: $e');
    }
  }

  void _applyTemplate(String name) {
    setState(() {
      switch (name) {
        case 'view_url':
          _action.text = 'android.intent.action.VIEW';
          _data.text = 'https://flutter.dev';
        case 'dial':
          _action.text = 'android.intent.action.DIAL';
          _data.text = 'tel:5551234';
        case 'wifi':
          _action.text = 'android.settings.WIFI_SETTINGS';
          _data.text = '';
        case 'dev':
          _action.text = 'android.settings.DEVELOPMENT_SETTINGS';
          _data.text = '';
        case 'home':
          _action.text = 'android.intent.action.MAIN';
          _category.text = 'android.intent.category.HOME';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('start'),
              selected: _kind == 'start',
              onSelected: (_) => setState(() => _kind = 'start'),
            ),
            ChoiceChip(
              label: const Text('broadcast'),
              selected: _kind == 'broadcast',
              onSelected: (_) => setState(() => _kind = 'broadcast'),
            ),
            ChoiceChip(
              label: const Text('startservice'),
              selected: _kind == 'startservice',
              onSelected: (_) => setState(() => _kind = 'startservice'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _row('Action', _action),
        _row('Data URI', _data),
        _row('MIME', _mime),
        _row('Category (csv)', _category),
        _row('Component', _component),
        _row('Package', _packageCtrl),
        const Divider(),
        Row(
          children: [
            const Text('Extras', style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(
              onPressed: () => setState(() => _extras.add(_Extra())),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        for (final e in _extras)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                DropdownButton<IntentExtraType>(
                  value: e.type,
                  onChanged: (v) =>
                      setState(() => e.type = v ?? IntentExtraType.string),
                  items: [
                    for (final t in IntentExtraType.values)
                      DropdownMenuItem(value: t, child: Text(t.flag)),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: e.key,
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'key',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: e.value,
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'value',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _extras.remove(e)),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ActionChip(
              label: const Text('Open URL'),
              onPressed: () => _applyTemplate('view_url'),
            ),
            ActionChip(
              label: const Text('Dial'),
              onPressed: () => _applyTemplate('dial'),
            ),
            ActionChip(
              label: const Text('Wi-Fi settings'),
              onPressed: () => _applyTemplate('wifi'),
            ),
            ActionChip(
              label: const Text('Dev settings'),
              onPressed: () => _applyTemplate('dev'),
            ),
            ActionChip(
              label: const Text('Home'),
              onPressed: () => _applyTemplate('home'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _send,
          icon: const Icon(Icons.send),
          label: Text('Send (am $_kind)'),
        ),
        const SizedBox(height: 12),
        if (_output.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: SelectableText(
              _output,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
      ],
    );
  }

  Widget _row(String label, TextEditingController c) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            SizedBox(width: 110, child: Text(label)),
            Expanded(
              child: TextField(
                controller: c,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      );
}

class _Extra {
  IntentExtraType type = IntentExtraType.string;
  final TextEditingController key = TextEditingController();
  final TextEditingController value = TextEditingController();
}
