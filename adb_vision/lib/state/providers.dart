import 'package:adb_kit/adb_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferences instance. Overridden in main() once the shared prefs handle
/// is available.
final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in main()');
});

/// The path to the adb binary. Persisted between launches.
final adbPathProvider = StateProvider<String>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return prefs.getString('adb_path') ?? 'adb';
});

/// The path to the scrcpy binary (used for capturing overlay/secondary
/// displays that adb screencap can't read). Persisted between launches.
final scrcpyPathProvider = StateProvider<String>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return prefs.getString('scrcpy_path') ?? 'scrcpy';
});

/// When true, non-primary displays are mirrored in-app via scrcpy + libmpv
/// instead of using `adb screencap` (which can't see overlay/virtual
/// displays). Persisted between launches.
final embedSecondaryProvider = StateProvider<bool>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return prefs.getBool('embed_secondary') ?? true;
});

/// The AdbKit singleton. Re-created when [adbPathProvider] changes.
final adbKitProvider = Provider<AdbKit>((ref) {
  final path = ref.watch(adbPathProvider);
  final log = ref.read(actionLogProvider.notifier);
  final kit = AdbKit(adbPath: path, observer: log.observe);
  ref.onDispose(() {});
  return kit;
});

/// The version string reported by adb, or null while loading.
final adbVersionProvider = FutureProvider<String>((ref) async {
  final kit = ref.watch(adbKitProvider);
  return kit.version();
});

/// Device list, polled every 2s.
final devicesProvider = StreamProvider<List<AdbDevice>>((ref) {
  final kit = ref.watch(adbKitProvider);
  return kit.devices.watch();
});

/// The serial of the currently-selected device. May be null.
final selectedSerialProvider = StateProvider<String?>((ref) => null);

/// The selected device object (derived from devicesProvider).
final selectedDeviceProvider = Provider<AdbDevice?>((ref) {
  final serial = ref.watch(selectedSerialProvider);
  final devices = ref.watch(devicesProvider).maybeWhen(
        data: (d) => d,
        orElse: () => const <AdbDevice>[],
      );
  if (serial == null) return null;
  try {
    return devices.firstWhere((d) => d.serial == serial);
  } catch (_) {
    return null;
  }
});

/// Displays for the currently-selected device.
final displaysProvider = FutureProvider<List<AdbDisplay>>((ref) async {
  final device = ref.watch(selectedDeviceProvider);
  if (device == null || !device.isReady) return const [];
  final kit = ref.watch(adbKitProvider);
  return kit.displays.list(device.serial);
});

/// The currently-selected display id.
final selectedDisplayIdProvider = StateProvider<int>((ref) => 0);

// ---------------------------------------------------------------------------
// Action Log
// ---------------------------------------------------------------------------

class ActionLogEntry {
  ActionLogEntry({
    required this.timestamp,
    required this.command,
    required this.serial,
    required this.kind,
    this.exitCode,
    this.message,
  });

  final DateTime timestamp;
  final List<String> command;
  final String? serial;
  final String kind;
  final int? exitCode;
  final String? message;

  String get commandLine => command.join(' ');
}

class ActionLogNotifier extends StateNotifier<List<ActionLogEntry>> {
  ActionLogNotifier() : super(const []);

  static const _cap = 500;

  void observe(AdbEvent event) {
    switch (event) {
      case AdbEventStart(:final pid):
        if (pid == 0) break; // duplicate start
        _push(ActionLogEntry(
          timestamp: DateTime.now(),
          command: event.command,
          serial: event.serial,
          kind: 'start',
          message: 'pid=$pid',
        ));
      case AdbEventEnd(:final exitCode, :final duration):
        _push(ActionLogEntry(
          timestamp: DateTime.now(),
          command: event.command,
          serial: event.serial,
          kind: 'end',
          exitCode: exitCode,
          message: '${duration.inMilliseconds}ms',
        ));
      case AdbEventStdout():
      case AdbEventStderr():
        // suppress per-line spam
        break;
    }
  }

  void _push(ActionLogEntry entry) {
    final next = [entry, ...state];
    state = next.length > _cap ? next.sublist(0, _cap) : next;
  }

  void clear() => state = const [];
}

final actionLogProvider =
    StateNotifierProvider<ActionLogNotifier, List<ActionLogEntry>>(
        (ref) => ActionLogNotifier());

// ---------------------------------------------------------------------------
// Mirror config
// ---------------------------------------------------------------------------

class MirrorConfig {
  const MirrorConfig({
    this.fps = 5,
    this.enabled = true,
  });

  final double fps;
  final bool enabled;

  MirrorConfig copyWith({double? fps, bool? enabled}) =>
      MirrorConfig(fps: fps ?? this.fps, enabled: enabled ?? this.enabled);
}

final mirrorConfigProvider =
    StateProvider<MirrorConfig>((ref) => const MirrorConfig());
