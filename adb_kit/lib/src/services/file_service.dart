import '../models/file_entry.dart';
import '../runner/adb_runner.dart';
import '../util/shell_quote.dart';

/// Wraps device-side filesystem commands and `adb push`/`pull`.
class FileService {
  /// Creates a [FileService] backed by [_runner].
  FileService(this._runner);
  final AdbRunner _runner;

  /// Lists [path] on the device.
  Future<List<FileEntry>> listDir(String serial, String path) async {
    final quoted = shellQuote(path);
    final out = await _runner.runOk(
      ['shell', 'ls', '-la', quoted],
      serial: serial,
      timeout: const Duration(seconds: 15),
    );
    return FileEntry.parseLs(out, path);
  }

  /// Returns raw `stat` output for [path].
  Future<String> stat(String serial, String path) => _runner.runOk(
        ['shell', 'stat', shellQuote(path)],
        serial: serial,
      );

  /// Creates [path] on the device.
  Future<void> mkdir(String serial, String path, {bool parents = true}) =>
      _runner.runOk(
        ['shell', 'mkdir', if (parents) '-p', shellQuote(path)],
        serial: serial,
      );

  /// Removes [path] from the device.
  Future<void> remove(String serial, String path, {bool recursive = false}) =>
      _runner.runOk(
        ['shell', 'rm', if (recursive) '-rf' else '-f', shellQuote(path)],
        serial: serial,
      );

  /// Moves [src] to [dst] on the device.
  Future<void> move(String serial, String src, String dst) => _runner.runOk(
        ['shell', 'mv', shellQuote(src), shellQuote(dst)],
        serial: serial,
      );

  /// Copies [src] to [dst] on the device, preserving attributes.
  Future<void> copy(String serial, String src, String dst) => _runner.runOk(
        ['shell', 'cp', '-a', shellQuote(src), shellQuote(dst)],
        serial: serial,
      );

  /// Runs `chmod [mode] [path]`.
  Future<void> chmod(String serial, String path, String mode) =>
      _runner.runOk(['shell', 'chmod', mode, shellQuote(path)], serial: serial);

  /// Runs `chown [owner] [path]`.
  Future<void> chown(String serial, String path, String owner) => _runner
      .runOk(['shell', 'chown', owner, shellQuote(path)], serial: serial);

  /// Returns the contents of [path] as a string.
  Future<String> cat(String serial, String path) => _runner.runOk(
        ['shell', 'cat', shellQuote(path)],
        serial: serial,
        timeout: const Duration(seconds: 30),
      );

  /// Runs `find [path] [-name name]`.
  Future<String> find(String serial, String path, {String? name}) =>
      _runner.runOk(
        [
          'shell',
          'find',
          shellQuote(path),
          if (name != null) ...['-name', shellQuote(name)],
        ],
        serial: serial,
        timeout: const Duration(seconds: 60),
      );

  /// Returns the raw `df -h` output.
  Future<String> diskFree(String serial) =>
      _runner.runOk(['shell', 'df', '-h'], serial: serial);

  /// Returns the raw `du -sh [path]` output.
  Future<String> diskUsage(String serial, String path) =>
      _runner.runOk(['shell', 'du', '-sh', shellQuote(path)], serial: serial);

  /// Uploads [localPath] from the host to [remotePath] on the device.
  Future<String> push(
    String serial,
    String localPath,
    String remotePath,
  ) =>
      _runner.runOk(
        ['push', localPath, remotePath],
        serial: serial,
        timeout: const Duration(minutes: 10),
      );

  /// Downloads [remotePath] from the device to [localPath] on the host.
  Future<String> pull(
    String serial,
    String remotePath,
    String localPath,
  ) =>
      _runner.runOk(
        ['pull', remotePath, localPath],
        serial: serial,
        timeout: const Duration(minutes: 10),
      );
}
