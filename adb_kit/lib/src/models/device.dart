/// Connection / authorisation state reported by `adb devices`.
enum DeviceState {
  device,
  offline,
  unauthorized,
  sideload,
  recovery,
  bootloader,
  fastboot,
  host,
  noPermissions,
  unknown;

  /// Parses a single state token from `adb devices` output.
  static DeviceState parse(String s) {
    switch (s.trim()) {
      case 'device':
        return DeviceState.device;
      case 'offline':
        return DeviceState.offline;
      case 'unauthorized':
        return DeviceState.unauthorized;
      case 'sideload':
        return DeviceState.sideload;
      case 'recovery':
        return DeviceState.recovery;
      case 'bootloader':
        return DeviceState.bootloader;
      case 'fastboot':
        return DeviceState.fastboot;
      case 'host':
        return DeviceState.host;
      case 'no permissions':
        return DeviceState.noPermissions;
      default:
        return DeviceState.unknown;
    }
  }
}

/// Physical connection medium for a device.
enum DeviceTransport { usb, tcp, unknown }

/// A single Android device or emulator visible to adb.
class AdbDevice {
  /// Creates an [AdbDevice].
  const AdbDevice({
    required this.serial,
    required this.state,
    this.product,
    this.model,
    this.deviceName,
    this.transportId,
    this.usb,
    this.transport = DeviceTransport.unknown,
  });

  /// The device serial reported by `adb devices`.
  final String serial;

  /// Current connection / authorisation state.
  final DeviceState state;

  /// Build product name (e.g. `sdk_gphone64_arm64`).
  final String? product;

  /// Marketing model name (e.g. `Pixel 7`).
  final String? model;

  /// Internal device codename.
  final String? deviceName;

  /// Stable adb-side transport id.
  final String? transportId;

  /// USB bus path when connected over USB.
  final String? usb;

  /// Whether this device is reached over USB or TCP.
  final DeviceTransport transport;

  /// True when [state] is [DeviceState.device] (ready for commands).
  bool get isReady => state == DeviceState.device;

  /// Parse output of `adb devices -l`.
  ///
  /// Example line: `emulator-5554 device product:sdk_gphone64_arm64 model:sdk_gphone64_arm64 device:emu64a transport_id:1`
  static List<AdbDevice> parseList(String stdout) {
    final lines = stdout.split('\n');
    final result = <AdbDevice>[];
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('List of devices')) continue;
      if (line.startsWith('*')) continue;
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length < 2) continue;
      final serial = parts[0];
      final state = DeviceState.parse(parts[1]);
      String? product;
      String? model;
      String? deviceName;
      String? transportId;
      String? usb;
      for (var i = 2; i < parts.length; i++) {
        final kv = parts[i].split(':');
        if (kv.length != 2) continue;
        switch (kv[0]) {
          case 'product':
            product = kv[1];
          case 'model':
            model = kv[1];
          case 'device':
            deviceName = kv[1];
          case 'transport_id':
            transportId = kv[1];
          case 'usb':
            usb = kv[1];
        }
      }
      final transport = serial.contains(':')
          ? DeviceTransport.tcp
          : (usb != null ? DeviceTransport.usb : DeviceTransport.unknown);
      result.add(AdbDevice(
        serial: serial,
        state: state,
        product: product,
        model: model,
        deviceName: deviceName,
        transportId: transportId,
        usb: usb,
        transport: transport,
      ));
    }
    return result;
  }

  /// Returns a copy with [state] replaced.
  AdbDevice copyWith({DeviceState? state}) => AdbDevice(
        serial: serial,
        state: state ?? this.state,
        product: product,
        model: model,
        deviceName: deviceName,
        transportId: transportId,
        usb: usb,
        transport: transport,
      );

  @override
  String toString() =>
      'AdbDevice($serial, $state, model=$model, transport=$transport)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AdbDevice && other.serial == serial);

  @override
  int get hashCode => serial.hashCode;
}
