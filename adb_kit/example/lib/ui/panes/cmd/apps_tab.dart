import 'package:adb_kit/adb_kit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/providers.dart';

class AppsTab extends ConsumerStatefulWidget {
  const AppsTab({required this.device, super.key});
  final AdbDevice device;

  @override
  ConsumerState<AppsTab> createState() => _AppsTabState();
}

class _AppsTabState extends ConsumerState<AppsTab> {
  PackageListFilter _filter = const PackageListFilter(thirdPartyOnly: true);
  String _query = '';
  Future<List<AdbPackage>>? _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant AppsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.device.serial != widget.device.serial) _refresh();
  }

  void _refresh() {
    final kit = ref.read(adbKitProvider);
    setState(() {
      _future = kit.packages.list(widget.device.serial, filter: _filter);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(Icons.search),
                        hintText: 'filter packages',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) =>
                          setState(() => _query = v.toLowerCase()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                  IconButton(
                    onPressed: _installApk,
                    tooltip: 'Install APK',
                    icon: const Icon(Icons.upload_file),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('3rd party'),
                    selected: _filter.thirdPartyOnly,
                    onSelected: (v) {
                      setState(() {
                        _filter = PackageListFilter(
                          thirdPartyOnly: v,
                          systemOnly: v ? false : _filter.systemOnly,
                        );
                      });
                      _refresh();
                    },
                  ),
                  FilterChip(
                    label: const Text('system'),
                    selected: _filter.systemOnly,
                    onSelected: (v) {
                      setState(() {
                        _filter = PackageListFilter(
                          systemOnly: v,
                          thirdPartyOnly: v ? false : _filter.thirdPartyOnly,
                        );
                      });
                      _refresh();
                    },
                  ),
                  FilterChip(
                    label: const Text('disabled'),
                    selected: _filter.disabledOnly,
                    onSelected: (v) {
                      setState(() {
                        _filter = PackageListFilter(
                          disabledOnly: v,
                        );
                      });
                      _refresh();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<List<AdbPackage>>(
            future: _future,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) return Center(child: Text('${snap.error}'));
              final pkgs = (snap.data ?? const <AdbPackage>[])
                  .where((p) => p.packageName.toLowerCase().contains(_query))
                  .toList();
              if (pkgs.isEmpty) {
                return const Center(child: Text('No packages match.'));
              }
              return ListView.builder(
                itemCount: pkgs.length,
                itemBuilder: (ctx, i) {
                  final p = pkgs[i];
                  return ListTile(
                    dense: true,
                    title: Text(
                      p.packageName,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                    subtitle: Text(
                      'v${p.versionCode ?? '?'} · ${p.isSystem ? "system" : "user"}'
                      '${p.installerPackage != null ? " · ${p.installerPackage}" : ""}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) => _action(p, v),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'launch', child: Text('Launch')),
                        PopupMenuItem(
                            value: 'force-stop', child: Text('Force-stop')),
                        PopupMenuItem(value: 'clear', child: Text('Clear data')),
                        PopupMenuItem(value: 'disable', child: Text('Disable')),
                        PopupMenuItem(value: 'enable', child: Text('Enable')),
                        PopupMenuItem(
                            value: 'uninstall', child: Text('Uninstall')),
                        PopupMenuItem(value: 'dump', child: Text('Dump info')),
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

  Future<void> _installApk() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['apk'],
    );
    final apk = res?.files.single.path;
    if (apk == null) return;
    final kit = ref.read(adbKitProvider);
    try {
      final out = await kit.packages.install(widget.device.serial, apk);
      _snack(out.trim());
      _refresh();
    } catch (e) {
      _snack('install failed: $e');
    }
  }

  Future<void> _action(AdbPackage p, String act) async {
    final kit = ref.read(adbKitProvider);
    final s = widget.device.serial;
    try {
      switch (act) {
        case 'launch':
          await kit.shell.exec(
            s,
            'monkey -p ${p.packageName} -c android.intent.category.LAUNCHER 1',
          );
        case 'force-stop':
          await kit.activity.forceStop(s, p.packageName);
        case 'clear':
          if (await _confirm('Clear all data for ${p.packageName}?')) {
            await kit.packages.clearData(s, p.packageName);
          }
        case 'disable':
          await kit.packages.disable(s, p.packageName);
        case 'enable':
          await kit.packages.enable(s, p.packageName);
        case 'uninstall':
          if (await _confirm('Uninstall ${p.packageName}?')) {
            await kit.packages.uninstall(s, p.packageName);
            _refresh();
          }
        case 'dump':
          final dump = await kit.packages.dump(s, p.packageName);
          if (mounted) {
            await showDialog<void>(
              context: context,
              builder: (ctx) => Dialog(
                child: SizedBox(
                  width: 700,
                  height: 600,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(dump,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 11)),
                  ),
                ),
              ),
            );
          }
      }
      _snack('$act ok');
    } catch (e) {
      _snack('$act failed: $e');
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
              child: const Text('Run')),
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
