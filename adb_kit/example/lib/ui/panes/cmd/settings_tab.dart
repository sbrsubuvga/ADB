import 'package:adb_kit/adb_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/providers.dart';

class SettingsTab extends ConsumerStatefulWidget {
  const SettingsTab({required this.device, super.key});
  final AdbDevice device;

  @override
  ConsumerState<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<SettingsTab> {
  SettingsNamespace _ns = SettingsNamespace.global;
  Future<Map<String, String>>? _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    final kit = ref.read(adbKitProvider);
    setState(() {
      _future = kit.settings.list(widget.device.serial, _ns);
    });
  }

  @override
  Widget build(BuildContext context) {
    final kit = ref.watch(adbKitProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Wrap(
                spacing: 8,
                children: [
                  for (final ns in SettingsNamespace.values)
                    ChoiceChip(
                      label: Text(ns.token),
                      selected: _ns == ns,
                      onSelected: (_) {
                        setState(() => _ns = ns);
                        _refresh();
                      },
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh'),
                    onPressed: _refresh,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Disable animations'),
                    onPressed: () =>
                        kit.settings.disableAnimations(widget.device.serial),
                  ),
                  ActionChip(
                    label: const Text('Restore animations'),
                    onPressed: () =>
                        kit.settings.restoreAnimations(widget.device.serial),
                  ),
                  ActionChip(
                    label: const Text('Dark mode on'),
                    onPressed: () =>
                        kit.settings.setDarkMode(widget.device.serial, true),
                  ),
                  ActionChip(
                    label: const Text('Dark mode off'),
                    onPressed: () =>
                        kit.settings.setDarkMode(widget.device.serial, false),
                  ),
                  ActionChip(
                    label: const Text('Force RTL'),
                    onPressed: () =>
                        kit.settings.setForceRtl(widget.device.serial, true),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search),
                  hintText: 'filter keys',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<Map<String, String>>(
            future: _future,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) return Center(child: Text('${snap.error}'));
              final keys = (snap.data ?? const <String, String>{})
                  .entries
                  .where((e) => e.key.toLowerCase().contains(_query))
                  .toList();
              return ListView.builder(
                itemCount: keys.length,
                itemBuilder: (ctx, i) {
                  final e = keys[i];
                  return ListTile(
                    dense: true,
                    title: SelectableText(
                      e.key,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12),
                    ),
                    subtitle: SelectableText(
                      e.value,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 11),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: () => _edit(e.key, e.value),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _edit(String key, String current) async {
    final ctrl = TextEditingController(text: current);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${_ns.token} / $key'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    final kit = ref.read(adbKitProvider);
    await kit.settings.put(widget.device.serial, _ns, key, ctrl.text);
    _refresh();
  }
}
