import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'adb_result.dart';

/// A callback fired every time an adb command is started, finished, or streams
/// a line.
typedef AdbObserver = void Function(AdbEvent event);

sealed class AdbEvent {
  const AdbEvent(this.command, this.serial);
  final List<String> command;
  final String? serial;
}

class AdbEventStart extends AdbEvent {
  const AdbEventStart(super.command, super.serial, this.pid);
  final int pid;
}

class AdbEventStdout extends AdbEvent {
  const AdbEventStdout(super.command, super.serial, this.line);
  final String line;
}

class AdbEventStderr extends AdbEvent {
  const AdbEventStderr(super.command, super.serial, this.line);
  final String line;
}

class AdbEventEnd extends AdbEvent {
  const AdbEventEnd(super.command, super.serial, this.exitCode, this.duration);
  final int exitCode;
  final Duration duration;
}

/// A handle to a running adb streaming process (logcat, screenrecord, shell…).
class AdbStreamHandle {
  AdbStreamHandle._(this._process, this.stdout, this.stderr, this.command);

  final Process _process;
  final Stream<String> stdout;
  final Stream<String> stderr;
  final List<String> command;

  int get pid => _process.pid;

  Future<int> get exitCode => _process.exitCode;

  /// Writes to the process's stdin (e.g. interactive shell).
  void writeLine(String line) {
    _process.stdin.writeln(line);
  }

  Future<void> stdin(List<int> bytes) async {
    _process.stdin.add(bytes);
    await _process.stdin.flush();
  }

  Future<void> close() async {
    try {
      await _process.stdin.close();
    } catch (_) {}
  }

  Future<void> kill([ProcessSignal signal = ProcessSignal.sigterm]) async {
    _process.kill(signal);
    try {
      await exitCode.timeout(const Duration(seconds: 2));
    } catch (_) {
      _process.kill(ProcessSignal.sigkill);
    }
  }
}

/// Centralised adb invoker. Wraps a single `adb` binary path and is safe to
/// use concurrently. Serialised per-device queuing can be layered on top via
/// [AdbRunner.withSerialQueue].
class AdbRunner {
  AdbRunner({
    String adbPath = 'adb',
    this.defaultTimeout = const Duration(seconds: 15),
    this.observer,
  }) : _adbPath = adbPath;

  String _adbPath;
  final Duration defaultTimeout;
  AdbObserver? observer;

  String get adbPath => _adbPath;
  set adbPath(String value) => _adbPath = value;

  /// Locate an adb binary in common install locations if [adbPath] fails.
  static List<String> candidatePaths() {
    final home = Platform.environment['HOME'] ?? '';
    final localAppData = Platform.environment['LOCALAPPDATA'] ?? '';
    final programFiles = Platform.environment['ProgramFiles'] ?? '';
    return [
      'adb',
      if (Platform.isMacOS) '/opt/homebrew/bin/adb',
      if (Platform.isMacOS) '/usr/local/bin/adb',
      if (Platform.isMacOS) '$home/Library/Android/sdk/platform-tools/adb',
      if (Platform.isLinux) '/usr/bin/adb',
      if (Platform.isLinux) '$home/Android/Sdk/platform-tools/adb',
      if (Platform.isWindows)
        '$localAppData\\Android\\Sdk\\platform-tools\\adb.exe',
      if (Platform.isWindows)
        '$programFiles\\Android\\android-sdk\\platform-tools\\adb.exe',
    ];
  }

  /// Run adb and wait for completion.
  Future<AdbResult> run(
    List<String> args, {
    String? serial,
    Duration? timeout,
    List<int>? stdin,
    Map<String, String>? environment,
  }) async {
    final cmd = [
      if (serial != null) ...['-s', serial],
      ...args,
    ];
    final sw = Stopwatch()..start();
    observer?.call(AdbEventStart(cmd, serial, 0));
    final process = await Process.start(
      _adbPath,
      cmd,
      environment: environment,
      runInShell: false,
    );
    observer?.call(AdbEventStart(cmd, serial, process.pid));

    if (stdin != null) {
      process.stdin.add(stdin);
      await process.stdin.close();
    }

    final outBuf = StringBuffer();
    final errBuf = StringBuffer();
    final outFuture = process.stdout
        .transform(utf8.decoder)
        .listen((s) => outBuf.write(s))
        .asFuture<void>();
    final errFuture = process.stderr
        .transform(utf8.decoder)
        .listen((s) => errBuf.write(s))
        .asFuture<void>();

    final effective = timeout ?? defaultTimeout;
    Timer? killTimer;
    if (effective > Duration.zero) {
      killTimer = Timer(effective, () {
        process.kill(ProcessSignal.sigkill);
      });
    }

    final exit = await process.exitCode;
    killTimer?.cancel();
    await Future.wait([outFuture, errFuture]);
    sw.stop();

    final result = AdbResult(
      command: cmd,
      exitCode: exit,
      stdout: outBuf.toString(),
      stderr: errBuf.toString(),
      duration: sw.elapsed,
    );
    observer?.call(AdbEventEnd(cmd, serial, exit, sw.elapsed));
    return result;
  }

  /// Run adb and return stdout or throw on non-zero exit.
  Future<String> runOk(
    List<String> args, {
    String? serial,
    Duration? timeout,
  }) async {
    final r = await run(args, serial: serial, timeout: timeout);
    if (!r.isSuccess) {
      throw AdbException(
        'adb ${args.join(' ')} failed (exit ${r.exitCode})',
        result: r,
      );
    }
    return r.stdout;
  }

  /// Start an adb process and hand back a streaming handle. Does not time out.
  Future<AdbStreamHandle> stream(
    List<String> args, {
    String? serial,
    Map<String, String>? environment,
  }) async {
    final cmd = [
      if (serial != null) ...['-s', serial],
      ...args,
    ];
    final process = await Process.start(
      _adbPath,
      cmd,
      environment: environment,
      runInShell: false,
    );
    observer?.call(AdbEventStart(cmd, serial, process.pid));

    final outCtrl = StreamController<String>.broadcast();
    final errCtrl = StreamController<String>.broadcast();

    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) {
        outCtrl.add(line);
        observer?.call(AdbEventStdout(cmd, serial, line));
      },
      onDone: outCtrl.close,
      onError: outCtrl.addError,
    );
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) {
        errCtrl.add(line);
        observer?.call(AdbEventStderr(cmd, serial, line));
      },
      onDone: errCtrl.close,
      onError: errCtrl.addError,
    );

    unawaited(process.exitCode.then((code) {
      observer?.call(AdbEventEnd(cmd, serial, code, Duration.zero));
    }));

    return AdbStreamHandle._(process, outCtrl.stream, errCtrl.stream, cmd);
  }

  /// Exec-out captures raw binary stdout (e.g. screencap -p). This is the only
  /// API that yields bytes, not text.
  Future<List<int>> execOut(
    List<String> shellArgs, {
    String? serial,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final cmd = [
      if (serial != null) ...['-s', serial],
      'exec-out',
      ...shellArgs,
    ];
    observer?.call(AdbEventStart(cmd, serial, 0));
    final sw = Stopwatch()..start();
    final process = await Process.start(_adbPath, cmd);
    observer?.call(AdbEventStart(cmd, serial, process.pid));
    final bytes = <int>[];
    final errBuf = StringBuffer();
    final outFuture = process.stdout.listen(bytes.addAll).asFuture<void>();
    final errFuture = process.stderr
        .transform(utf8.decoder)
        .listen(errBuf.write)
        .asFuture<void>();

    final killTimer = Timer(timeout, () {
      process.kill(ProcessSignal.sigkill);
    });
    final exit = await process.exitCode;
    killTimer.cancel();
    await Future.wait([outFuture, errFuture]);
    sw.stop();
    observer?.call(AdbEventEnd(cmd, serial, exit, sw.elapsed));
    if (exit != 0) {
      throw AdbException(
        'exec-out failed (exit $exit): ${errBuf.toString().trim()}',
      );
    }
    return bytes;
  }

  /// Verify the adb binary works and return the reported version string.
  Future<String> version() async {
    final r = await run(['--version']);
    if (!r.isSuccess) {
      throw AdbException(
        'Could not execute adb at "$_adbPath". Set a valid path in settings.',
        result: r,
      );
    }
    return r.stdout.trim();
  }
}
