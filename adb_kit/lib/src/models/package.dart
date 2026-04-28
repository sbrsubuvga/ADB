class AdbPackage {
  const AdbPackage({
    required this.packageName,
    this.apkPath,
    this.versionCode,
    this.installerPackage,
    this.uid,
    this.isSystem = false,
    this.isEnabled = true,
  });

  final String packageName;
  final String? apkPath;
  final int? versionCode;
  final String? installerPackage;
  final int? uid;
  final bool isSystem;
  final bool isEnabled;

  /// Parse lines from `pm list packages [-f] [-i] [--show-versioncode] [-U]`.
  /// Each line looks like:
  ///   package:com.example
  ///   package:/data/app/com.example/base.apk=com.example
  ///   package:com.example installer=com.android.vending
  ///   package:com.example versionCode:123
  ///   package:com.example uid:10234
  static List<AdbPackage> parseList(String stdout) {
    final packages = <AdbPackage>[];
    for (final raw in stdout.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || !line.startsWith('package:')) continue;
      final body = line.substring('package:'.length);

      String? apkPath;
      var packageName = body;
      if (body.contains('=')) {
        final idx = body.indexOf('=');
        apkPath = body.substring(0, idx);
        packageName = body.substring(idx + 1);
      }
      final tokens = packageName.split(RegExp(r'\s+'));
      packageName = tokens.first;

      String? installer;
      int? versionCode;
      int? uid;
      for (final t in tokens.skip(1)) {
        if (t.startsWith('installer=')) {
          installer = t.substring('installer='.length);
        } else if (t.startsWith('versionCode:')) {
          versionCode = int.tryParse(t.substring('versionCode:'.length));
        } else if (t.startsWith('uid:')) {
          uid = int.tryParse(t.substring('uid:'.length));
        }
      }

      packages.add(AdbPackage(
        packageName: packageName,
        apkPath: apkPath,
        installerPackage: installer,
        versionCode: versionCode,
        uid: uid,
        isSystem: apkPath?.startsWith('/system/') == true ||
            apkPath?.startsWith('/vendor/') == true ||
            apkPath?.startsWith('/product/') == true,
      ));
    }
    return packages;
  }

  AdbPackage copyWith({bool? isEnabled}) => AdbPackage(
        packageName: packageName,
        apkPath: apkPath,
        versionCode: versionCode,
        installerPackage: installerPackage,
        uid: uid,
        isSystem: isSystem,
        isEnabled: isEnabled ?? this.isEnabled,
      );

  @override
  String toString() =>
      'AdbPackage($packageName, v=$versionCode, system=$isSystem)';
}
