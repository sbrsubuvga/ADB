import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';

class ActionLogPane extends ConsumerWidget {
  const ActionLogPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(actionLogProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(6),
          child: Row(
            children: [
              const Text(
                'Every adb command executed by the app appears here.',
                style: TextStyle(fontSize: 12),
              ),
              const Spacer(),
              IconButton(
                onPressed: () =>
                    ref.read(actionLogProvider.notifier).clear(),
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Clear',
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Container(
            color: Colors.black,
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: entries.length,
              itemBuilder: (ctx, i) {
                final e = entries[i];
                final color = e.kind == 'end'
                    ? (e.exitCode == 0
                        ? Colors.greenAccent
                        : Colors.redAccent)
                    : Colors.lightBlueAccent;
                final ts = e.timestamp.toIso8601String().substring(11, 23);
                final kindTag = e.kind == 'end'
                    ? 'exit=${e.exitCode} (${e.message})'
                    : 'start ${e.message ?? ''}';
                return InkWell(
                  onTap: () {
                    Clipboard.setData(
                        ClipboardData(text: 'adb ${e.commandLine}'));
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Text(
                      '$ts ${e.serial?.padRight(20) ?? '-'.padRight(20)} $kindTag\n  adb ${e.commandLine}',
                      style: TextStyle(
                        color: color,
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
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
