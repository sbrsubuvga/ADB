import 'package:adb_kit/adb_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/providers.dart';

class NetworkTab extends ConsumerStatefulWidget {
  const NetworkTab({required this.device, super.key});
  final AdbDevice device;

  @override
  ConsumerState<NetworkTab> createState() => _NetworkTabState();
}

class _NetworkTabState extends ConsumerState<NetworkTab> {
  String _output = '';
  final _pingHost = TextEditingController(text: '8.8.8.8');

  @override
  void dispose() {
    _pingHost.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String> Function() task) async {
    try {
      final r = await task();
      setState(() => _output = r);
    } catch (e) {
      setState(() => _output = 'error: $e');
    }
  }

  Future<void> _toggle(Future<void> Function() task, String name) async {
    try {
      await task();
      _snack('$name ok');
    } catch (e) {
      _snack('$name failed: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final kit = ref.watch(adbKitProvider);
    final s = widget.device.serial;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('Toggles', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.wifi, size: 18),
              label: const Text('Wi-Fi on'),
              onPressed: () => _toggle(
                  () => kit.network.wifi(s, enabled: true), 'wifi on'),
            ),
            ActionChip(
              avatar: const Icon(Icons.wifi_off, size: 18),
              label: const Text('Wi-Fi off'),
              onPressed: () => _toggle(
                  () => kit.network.wifi(s, enabled: false), 'wifi off'),
            ),
            ActionChip(
              avatar: const Icon(Icons.signal_cellular_alt, size: 18),
              label: const Text('Cellular on'),
              onPressed: () => _toggle(
                  () => kit.network.data(s, enabled: true), 'data on'),
            ),
            ActionChip(
              avatar: const Icon(Icons.signal_cellular_off, size: 18),
              label: const Text('Cellular off'),
              onPressed: () => _toggle(
                  () => kit.network.data(s, enabled: false), 'data off'),
            ),
            ActionChip(
              avatar: const Icon(Icons.bluetooth, size: 18),
              label: const Text('Bluetooth on'),
              onPressed: () => _toggle(
                  () => kit.network.bluetooth(s, enabled: true), 'bt on'),
            ),
            ActionChip(
              avatar: const Icon(Icons.bluetooth_disabled, size: 18),
              label: const Text('Bluetooth off'),
              onPressed: () => _toggle(
                  () => kit.network.bluetooth(s, enabled: false), 'bt off'),
            ),
            ActionChip(
              avatar: const Icon(Icons.flight, size: 18),
              label: const Text('Airplane on'),
              onPressed: () => _toggle(
                  () => kit.network.airplaneMode(s, enabled: true),
                  'airplane on'),
            ),
            ActionChip(
              avatar: const Icon(Icons.flight_takeoff, size: 18),
              label: const Text('Airplane off'),
              onPressed: () => _toggle(
                  () => kit.network.airplaneMode(s, enabled: false),
                  'airplane off'),
            ),
          ],
        ),
        const Divider(height: 24),
        const Text('Diagnostics', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            ActionChip(
              label: const Text('ip addr'),
              onPressed: () => _run(() => kit.network.ipAddr(s)),
            ),
            ActionChip(
              label: const Text('ip route'),
              onPressed: () => _run(() => kit.network.ipRoute(s)),
            ),
            ActionChip(
              label: const Text('netstat'),
              onPressed: () => _run(() => kit.network.netstat(s)),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pingHost,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    labelText: 'ping host',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () =>
                    _run(() => kit.network.ping(s, _pingHost.text)),
                child: const Text('ping'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_output.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.black,
            child: SelectableText(
              _output,
              style: const TextStyle(
                color: Colors.greenAccent,
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          ),
      ],
    );
  }
}
