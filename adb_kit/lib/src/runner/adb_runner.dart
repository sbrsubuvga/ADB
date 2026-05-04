import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'adb_result.dart';

/// A callback fired every time an adb command is started, finished, or streams
/// a line.
typedef AdbObserver = void Function(AdbEvent event);

/// Base class for events emitted by [AdbObserver].
sealed class AdbEvent {
  /// Creates an [AdbEvent].
  const AdbEvent(this.command, this.serial);

  /// Argv that was launched (including `-s serial` if any).
  final List<String> command;

  /// Target device serial, if one was provided.
  final String? serial;
}

/// Fired when an adb process is launched.
class AdbEventStart extends AdbEvent {
  /// Creates an [AdbEventStart].
  const AdbEventStart(super.command, super.serial, this.pid);

  /// OS pid of the spawned process (0 before exec).
  final int pid;
}

/// Fired for each line of streaming stdout.
class AdbEventStdout extends AdbEvent {
  /// Creates an [AdbEventStdout].
  const AdbEventStdout(super.command, super.serial, this.line);

  /// One line of stdout.
  final String line;
}

/// Fired for each line of streaming stderr.
class AdbEventStderr extends AdbEvent {
  /// Creates an [AdbEventStderr].
  const AdbEventStderr(super.command, super.serial, this.line);

  /// One line of stderr.
  final String line;
}

/// Fired when an adb process exits.
class AdbEventEnd extends AdbEvent {
  /// Creates an [AdbEventEnd].
  const AdbEventEnd(super.command, super.serial, this.exitCode, this.duration);

  /// Process exit code.
  final int exitCode;

  /// Wall-clock time the process ran.
  final Duration duration;
}

/// A handle to a running adb streaming process (logcat, screenrecord, shell…).
class AdbStreamHandle {
  AdbStreamHandle._(this._process, this.stdout, this.stderr, this.command);

  final Process _process;

  /// Line-buffered stdout from the underlying process.
  final Stream<String> stdout;

  /// Line-buffered stderr from the underlying process.
  final Stream<String> stderr;

  /// Argv used to start the process.
  final List<String> command;

  /// OS pid of the underlying process.
  int get pid => _process.pid;

  /// Future that completes with the process exit code.
  Future<int> get exitCode => _process.exitCode;

  /// Writes [line] followed by a newline to the process's stdin.
  void writeLine(String line) {
    _process.stdin.writeln(line);
  }

  /// Writes raw [bytes] to the process's stdin and flushes.
  Future<void> stdin(List<int> bytes) async {
    _process.stdin.add(bytes);
    await _process.stdin.flush();
  }

  /// Closes the process's stdin (signalling EOF).
  Future<void> close() async {
    try {
      await _process.stdin.close();
    } catch (_) {}
  }

  /// Sends [signal] to the process and escalates to SIGKILL after 2s.
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
  /// Creates an [AdbRunner].
  AdbRunner({
    this.adbPath = 'adb',
    this.defaultTimeout = const Duration(seconds: 15),
    this.observer,
  });

  /// Path to the `adb` binary to invoke.
  String adbPath;

  /// Default timeout applied to [run] when none is supplied.
  final Duration defaultTimeout;

  /// Optional callback invoked for every adb lifecycle event.
  AdbObserver? observer;

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
      adbPath,
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
      adbPath,
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
    final process = await Process.start(adbPath, cmd);
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
        'Could not execute adb at "$adbPath". Set a valid path in settings.',
        result: r,
      );
    }
    return r.stdout.trim();
  }
}
