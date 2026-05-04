import '../models/file_entry.dart';
import '../runner/adb_runner.dart';
import '../util/shell_quote.dart';

class FileService {
  FileService(this._runner);
  final AdbRunner _runner;

  Future<List<FileEntry>> listDir(String serial, String path) async {
    final quoted = shellQuote(path);
    final out = await _runner.runOk(
      ['shell', 'ls', '-la', quoted],
      serial: serial,
      timeout: const Duration(seconds: 15),
    );
    return FileEntry.parseLs(out, path);
  }

  Future<String> stat(String serial, String path) => _runner.runOk(
        ['shell', 'stat', shellQuote(path)],
        serial: serial,
      );

  Future<void> mkdir(String serial, String path, {bool parents = true}) =>
      _runner.runOk(
        ['shell', 'mkdir', if (parents) '-p', shellQuote(path)],
        serial: serial,
      );

  Future<void> remove(String serial, String path, {bool recursive = false}) =>
      _runner.runOk(
        ['shell', 'rm', if (recursive) '-rf' else '-f', shellQuote(path)],
        serial: serial,
      );

  Future<void> move(String serial, String src, String dst) => _runner.runOk(
        ['shell', 'mv', shellQuote(src), shellQuote(dst)],
        serial: serial,
      );

  Future<void> copy(String serial, String src, String dst) => _runner.runOk(
        ['shell', 'cp', '-a', shellQuote(src), shellQuote(dst)],
        serial: serial,
      );

  Future<void> chmod(String serial, String path, String mode) =>
      _runner.runOk(['shell', 'chmod', mode, shellQuote(path)], serial: serial);

  Future<void> chown(String serial, String path, String owner) => _runner
      .runOk(['shell', 'chown', owner, shellQuote(path)], serial: serial);

  Future<String> cat(String serial, String path) => _runner.runOk(
        ['shell', 'cat', shellQuote(path)],
        serial: serial,
        timeout: const Duration(seconds: 30),
      );

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

  Future<String> diskFree(String serial) =>
      _runner.runOk(['shell', 'df', '-h'], serial: serial);

  Future<String> diskUsage(String serial, String path) =>
      _runner.runOk(['shell', 'du', '-sh', shellQuote(path)], serial: serial);

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
