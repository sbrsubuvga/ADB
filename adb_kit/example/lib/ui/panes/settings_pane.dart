import 'dart:io';

import 'package:adb_kit/adb_kit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../state/scrcpy_service.dart';

class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key});

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  late TextEditingController _adbPathCtrl;
  late TextEditingController _scrcpyPathCtrl;
  String? _adbVersion;
  String? _adbError;
  String? _scrcpyVersion;
  String? _scrcpyError;

  @override
  void initState() {
    super.initState();
    _adbPathCtrl = TextEditingController(text: ref.read(adbPathProvider));
    _scrcpyPathCtrl = TextEditingController(text: ref.read(scrcpyPathProvider));
  }

  @override
  void dispose() {
    _adbPathCtrl.dispose();
    _scrcpyPathCtrl.dispose();
    super.dispose();
  }

  Future<void> _detectAdb() async {
    setState(() {
      _adbVersion = null;
      _adbError = null;
    });
    for (final candidate in AdbRunner.candidatePaths()) {
      try {
        final runner = AdbRunner(adbPath: candidate);
        final v = await runner.version();
        setState(() {
          _adbPathCtrl.text = candidate;
          _adbVersion = v.split('\n').first;
        });
        return;
      } catch (_) {
        continue;
      }
    }
    setState(() => _adbError = 'No adb binary found in standard paths.');
  }

  Future<void> _detectScrcpy() async {
    setState(() {
      _scrcpyVersion = null;
      _scrcpyError = null;
    });
    final candidates = [
      'scrcpy',
      if (Platform.isMacOS) '/opt/homebrew/bin/scrcpy',
      if (Platform.isMacOS) '/usr/local/bin/scrcpy',
      if (Platform.isLinux) '/usr/bin/scrcpy',
      if (Platform.isLinux) '/usr/local/bin/scrcpy',
      if (Platform.isWindows) r'C:\scrcpy\scrcpy.exe',
    ];
    for (final candidate in candidates) {
      try {
        final v = await ScrcpyService(candidate).version();
        setState(() {
          _scrcpyPathCtrl.text = candidate;
          _scrcpyVersion = v;
        });
        return;
      } catch (_) {
        continue;
      }
    }
    setState(
      () => _scrcpyError =
          'scrcpy not found. Install with '
          '`brew install scrcpy`, `apt install scrcpy`, or '
          '`winget install scrcpy`.',
    );
  }

  Future<void> _browse(TextEditingController target) async {
    final res = await FilePicker.platform.pickFiles();
    final p = res?.files.single.path;
    if (p == null) return;
    setState(() => target.text = p);
  }

  Future<void> _save() async {
    final adbPath = _adbPathCtrl.text.trim();
    final scrcpyPath = _scrcpyPathCtrl.text.trim();
    if (adbPath.isEmpty) return;
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setString('adb_path', adbPath);
    if (scrcpyPath.isNotEmpty) {
      await prefs.setString('scrcpy_path', scrcpyPath);
      ref.read(scrcpyPathProvider.notifier).state = scrcpyPath;
    }
    ref.read(adbPathProvider.notifier).state = adbPath;
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Settings'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _binaryRow(
              label: 'adb binary path',
              controller: _adbPathCtrl,
              onDetect: _detectAdb,
              detected: _adbVersion,
              error: _adbError,
            ),
            const SizedBox(height: 16),
            _binaryRow(
              label:
                  'scrcpy binary path '
                  '(optional, used to mirror overlay/secondary displays)',
              controller: _scrcpyPathCtrl,
              onDetect: _detectScrcpy,
              detected: _scrcpyVersion,
              error: _scrcpyError,
            ),
            const SizedBox(height: 16),
            Text(
              'Platform: ${Platform.operatingSystem} '
              '${Platform.operatingSystemVersion}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  Widget _binaryRow({
    required String label,
    required TextEditingController controller,
    required Future<void> Function() onDetect,
    required String? detected,
    required String? error,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: () => _browse(controller),
              icon: const Icon(Icons.folder_open),
              tooltip: 'Browse',
            ),
            IconButton(
              onPressed: onDetect,
              icon: const Icon(Icons.search),
              tooltip: 'Auto-detect',
            ),
          ],
        ),
        if (detected != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Detected: $detected',
              style: const TextStyle(color: Colors.green, fontSize: 12),
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              error,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
