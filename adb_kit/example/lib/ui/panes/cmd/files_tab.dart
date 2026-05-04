import 'package:adb_kit/adb_kit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/providers.dart';

class FilesTab extends ConsumerStatefulWidget {
  const FilesTab({required this.device, super.key});
  final AdbDevice device;

  @override
  ConsumerState<FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends ConsumerState<FilesTab> {
  String _path = '/sdcard';
  Future<List<FileEntry>>? _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    final kit = ref.read(adbKitProvider);
    setState(() {
      _future = kit.files.listDir(widget.device.serial, _path);
    });
  }

  void _navigate(String path) {
    setState(() => _path = path);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              IconButton(
                onPressed: _path == '/'
                    ? null
                    : () {
                        final segs = _path.split('/').where((s) => s.isNotEmpty).toList();
                        if (segs.isEmpty) return;
                        segs.removeLast();
                        _navigate('/${segs.join('/')}');
                      },
                icon: const Icon(Icons.arrow_upward),
                tooltip: 'Up',
              ),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  controller: TextEditingController(text: _path)
                    ..selection = TextSelection.collapsed(offset: _path.length),
                  onSubmitted: _navigate,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                onPressed: _push,
                tooltip: 'Push file',
                icon: const Icon(Icons.upload),
              ),
              IconButton(
                onPressed: _mkdir,
                tooltip: 'New folder',
                icon: const Icon(Icons.create_new_folder),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<List<FileEntry>>(
            future: _future,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('${snap.error}'),
                );
              }
              final entries = snap.data ?? const <FileEntry>[];
              if (entries.isEmpty) {
                return const Center(child: Text('Empty.'));
              }
              return ListView.builder(
                itemCount: entries.length,
                itemBuilder: (ctx, i) {
                  final e = entries[i];
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      e.isDirectory
                          ? Icons.folder
                          : (e.isLink ? Icons.link : Icons.insert_drive_file),
                    ),
                    title: Text(e.name),
                    subtitle: Text(
                      [e.permissions, e.owner, _fmtSize(e.size)].join(' · '),
                      style: const TextStyle(fontSize: 11),
                    ),
                    onTap: () {
                      if (e.isDirectory) _navigate(e.path);
                    },
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) => _action(e, v),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'pull', child: Text('Pull…')),
                        PopupMenuItem(
                            value: 'delete', child: Text('Delete')),
                        PopupMenuItem(
                            value: 'rename', child: Text('Rename')),
                      ],
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

  String _fmtSize(int b) {
    if (b < 1024) return '${b}B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)}K';
    if (b < 1024 * 1024 * 1024) return '${(b / 1048576).toStringAsFixed(1)}M';
    return '${(b / 1073741824).toStringAsFixed(2)}G';
  }

  Future<void> _push() async {
    final src = await FilePicker.platform.pickFiles();
    final local = src?.files.single.path;
    if (local == null) return;
    final kit = ref.read(adbKitProvider);
    try {
      await kit.files.push(widget.device.serial, local, _path);
      _refresh();
      _snack('pushed');
    } catch (e) {
      _snack('push failed: $e');
    }
  }

  Future<void> _mkdir() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New folder'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Create')),
        ],
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty) return;
    final kit = ref.read(adbKitProvider);
    await kit.files.mkdir(widget.device.serial, '$_path/${ctrl.text.trim()}');
    _refresh();
  }

  Future<void> _action(FileEntry e, String act) async {
    final kit = ref.read(adbKitProvider);
    final s = widget.device.serial;
    try {
      switch (act) {
        case 'pull':
          final dest = await FilePicker.platform.saveFile(fileName: e.name);
          if (dest == null) return;
          await kit.files.pull(s, e.path, dest);
          _snack('pulled to $dest');
        case 'delete':
          if (await _confirm('Delete ${e.path}?')) {
            await kit.files.remove(s, e.path, recursive: e.isDirectory);
            _refresh();
          }
        case 'rename':
          final ctrl = TextEditingController(text: e.name);
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Rename'),
              content: TextField(controller: ctrl, autofocus: true),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Rename')),
              ],
            ),
          );
          if (ok != true) return;
          final dst = '$_path/${ctrl.text}';
          await kit.files.move(s, e.path, dst);
          _refresh();
      }
    } catch (err) {
      _snack('$act failed: $err');
    }
  }

  Future<bool> _confirm(String message) async {
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
              child: const Text('Delete')),
        ],
      ),
    );
    return r == true;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}
