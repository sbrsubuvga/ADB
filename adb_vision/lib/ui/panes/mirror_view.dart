import 'dart:async';

import 'package:adb_kit/adb_kit.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../state/scrcpy_service.dart';
import '../widgets/embedded_mirror.dart';
import '../widgets/hotbar.dart';

class MirrorView extends ConsumerStatefulWidget {
  const MirrorView({super.key});

  @override
  ConsumerState<MirrorView> createState() => _MirrorViewState();
}

class _MirrorViewState extends ConsumerState<MirrorView> {
  Uint8List? _frame;
  int? _frameWidth;
  int? _frameHeight;
  StreamSubscription<Uint8List>? _sub;
  String? _activeSerial;
  int _activeDisplayId = 0;
  double _fps = 0;
  DateTime _lastFrameTs = DateTime.now();

  /// How many consecutive non-PNG responses we've seen for the currently
  /// selected display. Once this exceeds [_failBeforeFallback] we permanently
  /// fall back to mirroring display 0 (input still goes to the selected one).
  int _consecutiveBadFrames = 0;
  static const _failBeforeFallback = 3;
  bool _capturingFallback = false;

  final _tapPulses = <_TapPulse>[];

  Offset? _dragStart;
  DateTime? _dragStartTime;
  Offset? _lastHover;

  final _focusNode = FocusNode();

  @override
  void dispose() {
    _sub?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _ensureSubscription(String serial, int displayId, double targetFps) {
    if (_activeSerial == serial &&
        _activeDisplayId == displayId &&
        _sub != null) {
      return;
    }
    _sub?.cancel();
    _activeSerial = serial;
    _activeDisplayId = displayId;
    _consecutiveBadFrames = 0;
    _capturingFallback = false;
    _startCapture(serial, displayId, targetFps);
  }

  void _startCapture(String serial, int captureDisplayId, double targetFps) {
    final kit = ref.read(adbKitProvider);
    _sub?.cancel();
    _sub = kit.screen
        .mirror(
      serial,
      fps: targetFps,
      options: ScreencapOptions(
        displayId: captureDisplayId == 0 ? null : captureDisplayId,
      ),
    )
        .listen((bytes) {
      if (!mounted) return;
      final isGood = bytes.isNotEmpty && ScreenService.isPng(bytes);
      if (!isGood) {
        _consecutiveBadFrames++;
        setState(() => _fps = 0);
        if (!_capturingFallback &&
            _activeDisplayId != 0 &&
            _consecutiveBadFrames >= _failBeforeFallback) {
          // Selected display can't be screencap'd (typical for overlay
          // displays). Permanently fall back to capturing the primary
          // display, but keep routing input to the selected display id.
          _capturingFallback = true;
          _startCapture(serial, 0, targetFps);
        }
        return;
      }
      _consecutiveBadFrames = 0;
      final now = DateTime.now();
      final dt = now.difference(_lastFrameTs).inMilliseconds;
      _lastFrameTs = now;
      final dims = ScreenService.readPngDimensions(bytes);
      setState(() {
        _frame = bytes;
        _frameWidth = dims?.$1;
        _frameHeight = dims?.$2;
        _fps = dt > 0 ? 1000 / dt : 0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final device = ref.watch(selectedDeviceProvider);
    final config = ref.watch(mirrorConfigProvider);
    final displayId = ref.watch(selectedDisplayIdProvider);
    final displaysAsync = ref.watch(displaysProvider);

    if (device == null || !device.isReady) {
      _sub?.cancel();
      _sub = null;
      _activeSerial = null;
      return const Center(
        child: Text('Select a ready device to start mirroring.'),
      );
    }

    if (config.enabled) {
      _ensureSubscription(device.serial, displayId, config.fps);
    } else {
      _sub?.cancel();
      _sub = null;
      _activeSerial = null;
    }

    return Column(
      children: [
        Hotbar(device: device),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              displaysAsync.when(
                data: (d) => _buildDisplayDropdown(d, displayId),
                loading: () => const SizedBox(
                  width: 120,
                  child: LinearProgressIndicator(),
                ),
                error: (e, _) => Text('displays: $e'),
              ),
              Text('${_fps.toStringAsFixed(1)} fps'),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Rate'),
                  SizedBox(
                    width: 160,
                    child: Slider(
                      min: 1,
                      max: 15,
                      divisions: 14,
                      value: config.fps.clamp(1, 15),
                      label: '${config.fps.toStringAsFixed(0)} fps',
                      onChanged: (v) => ref
                          .read(mirrorConfigProvider.notifier)
                          .update((s) => s.copyWith(fps: v)),
                    ),
                  ),
                ],
              ),
              Switch(
                value: config.enabled,
                onChanged: (v) => ref
                    .read(mirrorConfigProvider.notifier)
                    .update((s) => s.copyWith(enabled: v)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: displaysAsync.when(
            data: (displays) {
              final display = _pickDisplay(displays, displayId);
              final embed = ref.watch(embedSecondaryProvider);
              if (embed && !display.isPrimary) {
                // Stop the screencap loop while the embedded mirror runs;
                // they would otherwise fight over adb.
                _sub?.cancel();
                _sub = null;
                _activeSerial = null;
                return EmbeddedMirror(
                  device: device,
                  display: display,
                  key: ValueKey('${device.serial}-${display.id}'),
                );
              }
              return _buildMirror(display, device);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('display error: $e')),
          ),
        ),
      ],
    );
  }

  AdbDisplay _pickDisplay(List<AdbDisplay> list, int selected) {
    if (list.isEmpty) {
      return const AdbDisplay(id: 0, width: 1080, height: 2400);
    }
    return list.firstWhere(
      (d) => d.id == selected,
      orElse: () => list.first,
    );
  }

  Widget _buildDisplayDropdown(List<AdbDisplay> displays, int selected) {
    final value = displays.any((d) => d.id == selected)
        ? selected
        : (displays.isEmpty ? -1 : displays.first.id);
    return Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DropdownButton<int>(
          value: displays.isEmpty ? null : value,
          hint: const Text('no displays'),
          onChanged: (v) {
            if (v != null) {
              ref.read(selectedDisplayIdProvider.notifier).state = v;
            }
          },
          items: [
            for (final d in displays)
              DropdownMenuItem(
                value: d.id,
                child: Text(
                  '#${d.id} ${d.width}×${d.height}'
                  '${d.isOverlay ? " (overlay)" : ""}'
                  '${d.isPrimary ? " (primary)" : ""}',
                ),
              ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.refresh, size: 18),
          tooltip: 'Rescan displays',
          onPressed: () => ref.invalidate(displaysProvider),
        ),
        IconButton(
          icon: const Icon(Icons.open_in_new, size: 18),
          tooltip: 'Open this display in scrcpy (real-time visual mirror, '
              'works for overlay/virtual displays)',
          onPressed: displays.isEmpty ? null : _launchInScrcpy,
        ),
        Tooltip(
          message: 'Embed non-primary displays in this window via scrcpy + '
              'libmpv. Turn off to use adb screencap (won\'t see overlays).',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('embed', style: TextStyle(fontSize: 12)),
              Switch(
                value: ref.watch(embedSecondaryProvider),
                onChanged: (v) async {
                  ref.read(embedSecondaryProvider.notifier).state = v;
                  await ref.read(sharedPrefsProvider).setBool(
                        'embed_secondary',
                        v,
                      );
                },
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.add_to_queue, size: 18),
          tooltip: 'Virtual display',
          onSelected: _handleOverlayAction,
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'add', child: Text('Add virtual display…')),
            PopupMenuItem(value: 'add-1080p', child: Text('Add 1080×1920 / 320 dpi')),
            PopupMenuItem(value: 'add-720p', child: Text('Add 720×1280 / 240 dpi')),
            PopupMenuItem(value: 'remove', child: Text('Remove virtual displays')),
          ],
        ),
      ],
    );
  }

  Future<void> _launchInScrcpy() async {
    final serial = ref.read(selectedSerialProvider);
    if (serial == null) return;
    final displayId = ref.read(selectedDisplayIdProvider);
    final scrcpyPath = ref.read(scrcpyPathProvider);
    final scrcpy = ScrcpyService(scrcpyPath);

    try {
      await scrcpy.version();
    } catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('scrcpy not found'),
          content: Text(
            'Could not run "$scrcpyPath --version".\n\n'
            'Install scrcpy (1.20 or newer for non-primary displays):\n'
            '  brew install scrcpy   # macOS\n'
            '  apt install scrcpy    # Debian/Ubuntu\n'
            '  winget install scrcpy # Windows\n\n'
            'Or open Settings to set a custom scrcpy path.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    try {
      await scrcpy.launch(
        serial: serial,
        displayId: displayId == 0 ? null : displayId,
        title: 'ADB Vision · display $displayId',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Opening display $displayId in scrcpy…')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('scrcpy failed to launch: $e')));
    }
  }

  Future<void> _handleOverlayAction(String action) async {
    final serial = ref.read(selectedSerialProvider);
    if (serial == null) return;
    final kit = ref.read(adbKitProvider);
    try {
      switch (action) {
        case 'add-1080p':
          await _appendOverlay(kit, serial, '1080x1920/320');
        case 'add-720p':
          await _appendOverlay(kit, serial, '720x1280/240');
        case 'add':
          if (!mounted) return;
          final spec = await _promptOverlaySpec();
          if (spec == null) return;
          await _appendOverlay(kit, serial, spec);
        case 'remove':
          await kit.displays.clearOverlayDisplays(serial);
      }
      // Give the device a moment to register the new display.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      ref.invalidate(displaysProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('overlay failed: $e')));
      }
    }
  }

  Future<void> _appendOverlay(AdbKit kit, String serial, String entry) async {
    final current = await kit.displays.getOverlayDisplays(serial);
    final next = current == null || current.isEmpty
        ? entry
        : '$current;$entry';
    await kit.displays.setOverlayDisplays(serial, next);
  }

  Future<String?> _promptOverlaySpec() async {
    final ctrl = TextEditingController(text: '1080x1920/320');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add virtual display'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                helperText: 'WxH/dpi  (e.g. 1080x1920/320)',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tip: for taps to land on a simulated display, enable\n'
              'Settings → System → Developer options → '
              '"Allow simulated displays" (or "Enable freeform windows" '
              'on some Android versions).\n\n'
              'screencap usually can\'t capture overlay displays; the '
              'mirror will fall back to the primary while input still '
              'targets the selected display.',
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Add')),
        ],
      ),
    );
    return ok == true && ctrl.text.trim().isNotEmpty
        ? ctrl.text.trim()
        : null;
  }

  Widget _buildMirror(AdbDisplay display, AdbDevice device) {
    return LayoutBuilder(builder: (ctx, constraints) {
      // Prefer the actual captured-frame dimensions over dumpsys's reported
      // ones — screencap returns the post-rotation PNG, so when the device
      // is in landscape the frame is 2400×1080 even though dumpsys still
      // reports 1080×2400. Falling back to display dims only until the
      // first frame arrives.
      final captureW = (_frameWidth ?? display.width).toDouble();
      final captureH = (_frameHeight ?? display.height).toDouble();
      final widgetSize = _fittedSize(
        constraints.biggest,
        Size(captureW, captureH),
      );
      // Coordinate mapper uses the same dimensions, with rotation=0 because
      // those dimensions already reflect any device rotation.
      final mapper = CoordinateMapper(
        displayWidth: captureW,
        displayHeight: captureH,
        widgetWidth: widgetSize.width,
        widgetHeight: widgetSize.height,
      );
      return Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (node, event) => _handleKey(event, display, device),
        child: GestureDetector(
          onTap: () => _focusNode.requestFocus(),
          child: MouseRegion(
            onHover: (e) => setState(() => _lastHover = e.localPosition),
            child: Center(
              child: SizedBox(
                width: widgetSize.width,
                height: widgetSize.height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: Theme.of(context).colorScheme.surface),
                    if (_frame != null)
                      Image.memory(
                        _frame!,
                        gaplessPlayback: true,
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (ctx, err, _) => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'screencap returned no usable image',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                      ),
                    if (_frame == null)
                      const Center(
                        child: Text(
                          'waiting for first frame…',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    _buildInputLayer(mapper, device, display),
                    if (_capturingFallback && _activeDisplayId != 0)
                      Positioned(
                        left: 8,
                        top: 8,
                        right: 8,
                        child: IgnorePointer(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.indigo.withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.info_outline,
                                    color: Colors.white, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Input → display $_activeDisplayId · '
                                    'visible mirror is primary because '
                                    'screencap can\'t capture overlay/virtual '
                                    'displays. Use "Open in scrcpy" to see '
                                    'display $_activeDisplayId.',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (_lastHover != null)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: _CoordinateHud(
                          mapper: mapper,
                          position: _lastHover!,
                        ),
                      ),
                    IgnorePointer(
                      child: CustomPaint(
                        painter: _PulsePainter(_tapPulses),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildInputLayer(
    CoordinateMapper mapper,
    AdbDevice device,
    AdbDisplay display,
  ) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        _focusNode.requestFocus();
        if (e.buttons == kMiddleMouseButton) {
          _sendKey(device, KeyCode.home);
        } else if (e.buttons == kSecondaryMouseButton) {
          _sendKey(device, KeyCode.back);
        } else if (e.buttons == kBackMouseButton) {
          _sendKey(device, KeyCode.appSwitch);
        } else if (e.buttons == kForwardMouseButton) {
          _sendKey(device, KeyCode.menu);
        } else {
          _dragStart = e.localPosition;
          _dragStartTime = DateTime.now();
        }
      },
      onPointerUp: (e) async {
        final start = _dragStart;
        final startTime = _dragStartTime;
        _dragStart = null;
        _dragStartTime = null;
        if (start == null || startTime == null) return;
        final delta = (e.localPosition - start).distance;
        final (x1, y1) = mapper.map(start.dx, start.dy);
        final (x2, y2) = mapper.map(e.localPosition.dx, e.localPosition.dy);
        if (delta < 6) {
          _pulseAt(e.localPosition);
          await _tap(device, display, x1, y1);
        } else {
          final duration = CoordinateMapper.estimateSwipeDuration(
            x1,
            y1,
            x2,
            y2,
            DateTime.now().difference(startTime),
          );
          await _swipe(device, display, x1, y1, x2, y2, duration);
        }
      },
      onPointerSignal: (signal) {
        if (signal is PointerScrollEvent) {
          final (cx, cy) =
              mapper.map(signal.localPosition.dx, signal.localPosition.dy);
          final dy = signal.scrollDelta.dy;
          final target = (dy * 2).clamp(-400.0, 400.0).round();
          _swipe(device, display, cx, cy, cx, cy - target, 150);
        }
      },
      child: const SizedBox.expand(),
    );
  }

  Future<void> _tap(
      AdbDevice device, AdbDisplay display, int x, int y) async {
    final kit = ref.read(adbKitProvider);
    try {
      await kit.input.tap(
        device.serial,
        x: x,
        y: y,
        displayId: display.isPrimary ? null : display.id,
      );
    } catch (_) {}
  }

  Future<void> _swipe(
    AdbDevice device,
    AdbDisplay display,
    int x1,
    int y1,
    int x2,
    int y2,
    int durationMs,
  ) async {
    final kit = ref.read(adbKitProvider);
    try {
      await kit.input.swipe(
        device.serial,
        x1: x1,
        y1: y1,
        x2: x2,
        y2: y2,
        durationMs: durationMs,
        displayId: display.isPrimary ? null : display.id,
      );
    } catch (_) {}
  }

  Future<void> _sendKey(AdbDevice device, KeyCode key) async {
    final kit = ref.read(adbKitProvider);
    try {
      await kit.input.keyEvent(device.serial, key);
    } catch (_) {}
  }

  void _pulseAt(Offset p) {
    setState(() {
      _tapPulses.add(_TapPulse(p, DateTime.now()));
    });
    Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        final now = DateTime.now();
        _tapPulses.removeWhere(
            (p) => now.difference(p.started).inMilliseconds > 650);
      });
    });
  }

  KeyEventResult _handleKey(
      KeyEvent event, AdbDisplay display, AdbDevice device) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final kit = ref.read(adbKitProvider);
    final ch = event.character;

    // Physical key mappings for common navigation.
    final physicalMap = <LogicalKeyboardKey, KeyCode>{
      LogicalKeyboardKey.enter: KeyCode.enter,
      LogicalKeyboardKey.tab: KeyCode.tab,
      LogicalKeyboardKey.backspace: KeyCode.del,
      LogicalKeyboardKey.escape: KeyCode.back,
      LogicalKeyboardKey.arrowUp: KeyCode.dpadUp,
      LogicalKeyboardKey.arrowDown: KeyCode.dpadDown,
      LogicalKeyboardKey.arrowLeft: KeyCode.dpadLeft,
      LogicalKeyboardKey.arrowRight: KeyCode.dpadRight,
      LogicalKeyboardKey.home: KeyCode.moveHome,
      LogicalKeyboardKey.end: KeyCode.moveEnd,
      LogicalKeyboardKey.pageUp: KeyCode.pageUp,
      LogicalKeyboardKey.pageDown: KeyCode.pageDown,
    };
    final mapped = physicalMap[event.logicalKey];
    if (mapped != null) {
      unawaited(kit.input.keyEvent(device.serial, mapped));
      return KeyEventResult.handled;
    }
    if (ch != null && ch.isNotEmpty) {
      unawaited(kit.input.text(device.serial, ch));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Size _fittedSize(Size available, Size content) {
    final scale = (available.width / content.width)
        .clamp(0.0, available.height / content.height);
    return Size(content.width * scale, content.height * scale);
  }
}

class _TapPulse {
  _TapPulse(this.position, this.started);
  final Offset position;
  final DateTime started;
}

class _PulsePainter extends CustomPainter {
  _PulsePainter(this.pulses);
  final List<_TapPulse> pulses;

  @override
  void paint(Canvas canvas, Size size) {
    final now = DateTime.now();
    for (final p in pulses) {
      final dt = now.difference(p.started).inMilliseconds;
      if (dt > 650) continue;
      final t = dt / 650;
      final paint = Paint()
        ..color = Colors.amberAccent.withValues(alpha: 1 - t)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(p.position, 8 + 32 * t, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PulsePainter oldDelegate) => true;
}

class _CoordinateHud extends StatelessWidget {
  const _CoordinateHud({required this.mapper, required this.position});
  final CoordinateMapper mapper;
  final Offset position;

  @override
  Widget build(BuildContext context) {
    final (dx, dy) = mapper.map(position.dx, position.dy);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '($dx, $dy)',
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }
}
