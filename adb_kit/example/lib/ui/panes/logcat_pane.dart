import 'dart:async';

import 'package:adb_kit/adb_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';

class LogcatPane extends ConsumerStatefulWidget {
  const LogcatPane({required this.device, super.key});
  final AdbDevice device;

  @override
  ConsumerState<LogcatPane> createState() => _LogcatPaneState();
}

class _LogcatPaneState extends ConsumerState<LogcatPane> {
  final _lines = <LogLine>[];
  static const _capacity = 5000;
  StreamSubscription<LogLine>? _sub;
  AdbStreamHandle? _handle;
  String _query = '';
  LogPriority _minPriority = LogPriority.info;
  bool _running = false;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant LogcatPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.device.serial != widget.device.serial) {
      _stop();
      _start();
    }
  }

  @override
  void dispose() {
    _stop();
    _scroll.dispose();
    super.dispose();
  }

  void _start() {
    final kit = ref.read(adbKitProvider);
    setState(() {
      _running = true;
      _lines.clear();
    });
    _sub = kit.logcat
        .tail(
          widget.device.serial,
          filter: const LogcatFilter(
            defaultPriority: LogPriority.verbose,
            buffers: [LogBuffer.main, LogBuffer.system, LogBuffer.crash],
          ),
          onHandle: (h) {
            _handle = h;
            return h;
          },
        )
        .listen((line) {
          if (!mounted) return;
          setState(() {
            _lines.add(line);
            if (_lines.length > _capacity) {
              _lines.removeRange(0, _lines.length - _capacity);
            }
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scroll.hasClients) {
              _scroll.jumpTo(_scroll.position.maxScrollExtent);
            }
          });
        });
  }

  void _stop() {
    _sub?.cancel();
    _sub = null;
    _handle?.kill();
    _handle = null;
    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _lines.where((l) {
      if (!l.priority.atLeast(_minPriority) &&
          l.priority != LogPriority.unknown) {
        return false;
      }
      if (_query.isEmpty) return true;
      return l.raw.toLowerCase().contains(_query);
    }).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(6),
          child: Row(
            children: [
              IconButton(
                onPressed: _running ? _stop : _start,
                icon: Icon(_running ? Icons.stop_circle : Icons.play_circle),
                tooltip: _running ? 'Pause' : 'Resume',
              ),
              IconButton(
                onPressed: () => setState(_lines.clear),
                tooltip: 'Clear view',
                icon: const Icon(Icons.clear_all),
              ),
              IconButton(
                onPressed: () =>
                    ref.read(adbKitProvider).logcat.clear(widget.device.serial),
                tooltip: 'Clear device buffer',
                icon: const Icon(Icons.delete_sweep),
              ),
              const SizedBox(width: 8),
              DropdownButton<LogPriority>(
                value: _minPriority,
                onChanged: (v) =>
                    setState(() => _minPriority = v ?? LogPriority.verbose),
                items: [
                  for (final p in LogPriority.values.where(
                    (p) => p != LogPriority.unknown,
                  ))
                    DropdownMenuItem(value: p, child: Text(p.letter)),
                ],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search),
                    hintText: 'filter',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _query = v.toLowerCase()),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Container(
            color: Colors.black,
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                final l = filtered[i];
                return Text(
                  l.raw,
                  style: TextStyle(
                    color: _colorFor(l.priority),
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Color _colorFor(LogPriority p) {
    switch (p) {
      case LogPriority.error:
      case LogPriority.fatal:
        return Colors.redAccent;
      case LogPriority.warn:
        return Colors.amberAccent;
      case LogPriority.info:
        return Colors.lightBlueAccent;
      case LogPriority.debug:
        return Colors.greenAccent;
      case LogPriority.verbose:
        return Colors.grey.shade400;
      default:
        return Colors.white70;
    }
  }
}
