import 'package:adb_kit/adb_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';

class DevicePicker extends ConsumerWidget {
  const DevicePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(devicesProvider);
    final selected = ref.watch(selectedSerialProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              const Text('Devices', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => ref.invalidate(devicesProvider),
                icon: const Icon(Icons.refresh, size: 18),
              ),
              PopupMenuButton<String>(
                tooltip: 'Add device',
                icon: const Icon(Icons.add, size: 18),
                onSelected: (choice) => _handleAdd(context, ref, choice),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'connect', child: Text('Connect TCP/IP…')),
                  PopupMenuItem(value: 'pair', child: Text('Pair Wireless…')),
                  PopupMenuItem(value: 'tcpip', child: Text('Enable tcpip')),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: devicesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('adb error: $e'),
            ),
            data: (list) {
              if (list.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No devices detected.\n\n• Enable USB debugging\n• Plug in over USB, or\n• adb connect host:5555',
                  ),
                );
              }
              return ListView.separated(
                itemBuilder: (ctx, i) {
                  final d = list[i];
                  final sel = d.serial == selected;
                  return ListTile(
                    selected: sel,
                    dense: true,
                    leading: _stateIcon(d.state),
                    title: Text(d.model ?? d.serial, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${d.serial} · ${d.state.name}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz, size: 18),
                      onSelected: (action) =>
                          _handleDeviceAction(context, ref, d, action),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                            value: 'reboot', child: Text('Reboot')),
                        const PopupMenuItem(
                            value: 'reboot_bl',
                            child: Text('Reboot to bootloader')),
                        const PopupMenuItem(
                            value: 'reboot_rec',
                            child: Text('Reboot to recovery')),
                        const PopupMenuItem(
                            value: 'disconnect', child: Text('Disconnect')),
                      ],
                    ),
                    onTap: () {
                      ref.read(selectedSerialProvider.notifier).state =
                          d.serial;
                      ref.read(selectedDisplayIdProvider.notifier).state = 0;
                    },
                  );
                },
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemCount: list.length,
              );
            },
          ),
        ),
      ],
    );
  }

  Icon _stateIcon(DeviceState state) {
    switch (state) {
      case DeviceState.device:
        return const Icon(Icons.smartphone, color: Colors.green);
      case DeviceState.offline:
        return const Icon(Icons.smartphone, color: Colors.grey);
      case DeviceState.unauthorized:
        return const Icon(Icons.lock, color: Colors.orange);
      case DeviceState.recovery:
      case DeviceState.sideload:
      case DeviceState.bootloader:
      case DeviceState.fastboot:
        return const Icon(Icons.build, color: Colors.blueGrey);
      default:
        return const Icon(Icons.help_outline, color: Colors.grey);
    }
  }

  Future<void> _handleAdd(
      BuildContext context, WidgetRef ref, String choice) async {
    final kit = ref.read(adbKitProvider);
    switch (choice) {
      case 'connect':
        final addr = await _promptText(context, 'Host:port', 'e.g. 192.168.1.42:5555');
        if (addr == null) return;
        final parts = addr.split(':');
        if (parts.length != 2) return;
        await kit.devices.connect(parts[0], port: int.tryParse(parts[1]) ?? 5555);
      case 'pair':
        final addr = await _promptText(context, 'Pair host:port', '192.168.1.42:37421');
        if (addr == null) return;
        if (!context.mounted) return;
        final code = await _promptText(context, 'Pairing code', '6-digit code');
        if (code == null) return;
        final parts = addr.split(':');
        if (parts.length != 2) return;
        await kit.devices.pair(
            parts[0], int.tryParse(parts[1]) ?? 5555, code);
      case 'tcpip':
        final portStr = await _promptText(context, 'tcpip port', '5555');
        if (portStr == null) return;
        await kit.devices.tcpIp(int.tryParse(portStr) ?? 5555);
    }
    ref.invalidate(devicesProvider);
  }

  Future<void> _handleDeviceAction(
    BuildContext context,
    WidgetRef ref,
    AdbDevice device,
    String action,
  ) async {
    final kit = ref.read(adbKitProvider);
    if (!await _confirm(context, 'Run "$action" on ${device.serial}?')) return;
    try {
      switch (action) {
        case 'reboot':
          await kit.power.reboot(device.serial);
        case 'reboot_bl':
          await kit.power.reboot(device.serial, target: RebootTarget.bootloader);
        case 'reboot_rec':
          await kit.power.reboot(device.serial, target: RebootTarget.recovery);
        case 'disconnect':
          await kit.devices.disconnect(device.serial);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$action failed: $e')));
      }
    }
  }

  Future<String?> _promptText(
      BuildContext context, String title, String hint) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('OK')),
        ],
      ),
    );
    return result == null || result.isEmpty ? null : result;
  }

  Future<bool> _confirm(BuildContext context, String message) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm'),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Run')),
        ],
      ),
    );
    return r == true;
  }
}
