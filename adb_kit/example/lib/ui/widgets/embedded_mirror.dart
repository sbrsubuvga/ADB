import 'dart:async';

import 'package:adb_kit/adb_kit.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../state/embedded_mirror_session.dart';
import '../../state/providers.dart';

const _logFontStyle = TextStyle(
  fontFamily: 'monospace',
  fontSize: 11,
  color: Colors.lightGreenAccent,
);

/// Renders a target display N inside the same Flutter window using
/// `scrcpy --no-window --record=<file>` + media_kit playback. Input is
/// still injected via `adb input --display=N`, so taps/swipes/keys land on
/// the correct (possibly virtual) display.
class EmbeddedMirror extends ConsumerStatefulWidget {
  const EmbeddedMirror({
    required this.device,
    required this.display,
    super.key,
  });

  final AdbDevice device;
  final AdbDisplay display;

  @override
  ConsumerState<EmbeddedMirror> createState() => _EmbeddedMirrorState();
}

class _EmbeddedMirrorState extends ConsumerState<EmbeddedMirror> {
  final _session = EmbeddedMirrorSession();
  late final Player _player;
  late final VideoController _controller;
  String? _error;
  bool _starting = true;
  bool _notCapturable = false;
  StreamSubscription<String>? _rotationSub;

  Offset? _dragStart;
  DateTime? _dragStartTime;
  Offset? _lastHover;

  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _player = Player(
      configuration: const PlayerConfiguration(
        // Small ring buffer for low-latency live mirror.
        bufferSize: 32 * 1024 * 1024,
        // Treat the growing file like a stream.
        protocolWhitelist: ['file', 'tcp', 'udp'],
      ),
    );
    _controller = VideoController(_player);
    _start();
  }

  Future<void> _applyLowLatencyMpvHints() async {
    final platform = _player.platform;
    if (platform is! NativePlayer) return;
    // libmpv-specific hints to play screenrecord's raw h264 elementary
    // stream (no container, growing file).
    Future<void> set(String key, String value) =>
        platform.setProperty(key, value);
    try {
      // Tell ffmpeg the input is a raw h264 elementary stream.
      await set('demuxer-lavf-format', 'h264');
      await set('cache', 'yes');
      await set('demuxer-readahead-secs', '0.2');
      await set('cache-secs', '0.5');
      await set('untimed', 'no');
      await set('hr-seek', 'no');
      await set('vd-lavc-fast', 'yes');
      await set('vd-lavc-skiploopfilter', 'all');
      await set('audio', 'no');
    } catch (_) {
      // setProperty on an unsupported key just gets ignored — safe to swallow.
    }
  }

  @override
  void didUpdateWidget(covariant EmbeddedMirror old) {
    super.didUpdateWidget(old);
    if (old.device.serial != widget.device.serial ||
        old.display.id != widget.display.id) {
      _restart();
    }
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _error = null;
      _notCapturable = false;
    });
    final scrcpyPath = ref.read(scrcpyPathProvider);
    try {
      final path = await _session.start(
        scrcpyPath: scrcpyPath,
        serial: widget.device.serial,
        displayId: widget.display.id == 0 ? null : widget.display.id,
      );
      await _applyLowLatencyMpvHints();
      await _player.open(Media('file://$path'), play: true);
      // When screenrecord rotates to a new file (every ~165s, before the
      // device's 180s cap), reopen the player on the new path.
      await _rotationSub?.cancel();
      _rotationSub = _session.onFileChanged.listen((newPath) async {
        if (newPath == path) return;
        try {
          await _player.open(Media('file://$newPath'), play: true);
        } catch (_) {}
      });
      if (mounted) setState(() => _starting = false);
    } on NotCapturableException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _notCapturable = true;
          _starting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _starting = false;
        });
      }
    }
  }

  Future<void> _restart() async {
    await _rotationSub?.cancel();
    _rotationSub = null;
    await _player.stop();
    await _session.stop();
    await _start();
  }

  @override
  void dispose() {
    _rotationSub?.cancel();
    _player.dispose();
    _session.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _notCapturable) {
      // Friendly user-facing failure: this display can't be captured at all
      // on this device. Offer to switch off the "embed" toggle so the mirror
      // falls back to the primary-display view (input still routes to N).
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 28,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'This display can\'t be mirrored',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: () async {
                        ref.read(embedSecondaryProvider.notifier).state = false;
                        await ref
                            .read(sharedPrefsProvider)
                            .setBool('embed_secondary', false);
                      },
                      icon: const Icon(Icons.visibility_off, size: 16),
                      label: const Text('Switch to input-only mode'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _start,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Embedded mirror failed',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _start,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    final messenger = ScaffoldMessenger.of(context);
                    Clipboard.setData(ClipboardData(text: _error!));
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Log copied')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy log'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                color: Colors.black,
                padding: const EdgeInsets.all(8),
                child: Scrollbar(
                  child: SingleChildScrollView(
                    child: SelectableText(_error!, style: _logFontStyle),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (_starting) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Starting scrcpy + libmpv…'),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (ctx, constraints) {
        // Stream resolution is reported by libmpv once frames start flowing;
        // until then fall back to the display's logical dims.
        final streamW = _player.state.width ?? widget.display.width;
        final streamH = _player.state.height ?? widget.display.height;
        final widgetSize = _fittedSize(
          constraints.biggest,
          Size(streamW.toDouble(), streamH.toDouble()),
        );
        final mapper = CoordinateMapper(
          displayWidth: streamW.toDouble(),
          displayHeight: streamH.toDouble(),
          widgetWidth: widgetSize.width,
          widgetHeight: widgetSize.height,
        );

        return Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: (node, event) => _handleKey(event),
          child: GestureDetector(
            onTap: _focusNode.requestFocus,
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
                      Video(
                        controller: _controller,
                        controls: NoVideoControls,
                        fit: BoxFit.fill,
                      ),
                      _buildInputLayer(mapper),
                      if (_lastHover != null)
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: _Hud(mapper: mapper, position: _lastHover!),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputLayer(CoordinateMapper mapper) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        _focusNode.requestFocus();
        if (e.buttons == kMiddleMouseButton) {
          _sendKey(KeyCode.home);
        } else if (e.buttons == kSecondaryMouseButton) {
          _sendKey(KeyCode.back);
        } else if (e.buttons == kBackMouseButton) {
          _sendKey(KeyCode.appSwitch);
        } else if (e.buttons == kForwardMouseButton) {
          _sendKey(KeyCode.menu);
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
          await _tap(x1, y1);
        } else {
          final duration = CoordinateMapper.estimateSwipeDuration(
            x1,
            y1,
            x2,
            y2,
            DateTime.now().difference(startTime),
          );
          await _swipe(x1, y1, x2, y2, duration);
        }
      },
      onPointerSignal: (signal) {
        if (signal is PointerScrollEvent) {
          final (cx, cy) = mapper.map(
            signal.localPosition.dx,
            signal.localPosition.dy,
          );
          final dy = signal.scrollDelta.dy;
          final target = (dy * 2).clamp(-400.0, 400.0).round();
          _swipe(cx, cy, cx, cy - target, 150);
        }
      },
      child: const SizedBox.expand(),
    );
  }

  Future<void> _tap(int x, int y) async {
    final kit = ref.read(adbKitProvider);
    try {
      await kit.input.tap(
        widget.device.serial,
        x: x,
        y: y,
        displayId: widget.display.isPrimary ? null : widget.display.id,
      );
    } catch (_) {}
  }

  Future<void> _swipe(int x1, int y1, int x2, int y2, int durationMs) async {
    final kit = ref.read(adbKitProvider);
    try {
      await kit.input.swipe(
        widget.device.serial,
        x1: x1,
        y1: y1,
        x2: x2,
        y2: y2,
        durationMs: durationMs,
        displayId: widget.display.isPrimary ? null : widget.display.id,
      );
    } catch (_) {}
  }

  Future<void> _sendKey(KeyCode k) async {
    final kit = ref.read(adbKitProvider);
    try {
      await kit.input.keyEvent(
        widget.device.serial,
        k,
        displayId: widget.display.isPrimary ? null : widget.display.id,
      );
    } catch (_) {}
  }

  KeyEventResult _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final kit = ref.read(adbKitProvider);
    final ch = event.character;
    final physicalMap = <LogicalKeyboardKey, KeyCode>{
      LogicalKeyboardKey.enter: KeyCode.enter,
      LogicalKeyboardKey.tab: KeyCode.tab,
      LogicalKeyboardKey.backspace: KeyCode.del,
      LogicalKeyboardKey.escape: KeyCode.back,
      LogicalKeyboardKey.arrowUp: KeyCode.dpadUp,
      LogicalKeyboardKey.arrowDown: KeyCode.dpadDown,
      LogicalKeyboardKey.arrowLeft: KeyCode.dpadLeft,
      LogicalKeyboardKey.arrowRight: KeyCode.dpadRight,
    };
    final mapped = physicalMap[event.logicalKey];
    final dispId = widget.display.isPrimary ? null : widget.display.id;
    if (mapped != null) {
      unawaited(
        kit.input.keyEvent(widget.device.serial, mapped, displayId: dispId),
      );
      return KeyEventResult.handled;
    }
    if (ch != null && ch.isNotEmpty) {
      unawaited(kit.input.text(widget.device.serial, ch, displayId: dispId));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Size _fittedSize(Size avail, Size content) {
    final scale = (avail.width / content.width).clamp(
      0.0,
      avail.height / content.height,
    );
    return Size(content.width * scale, content.height * scale);
  }
}

class _Hud extends StatelessWidget {
  const _Hud({required this.mapper, required this.position});
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
