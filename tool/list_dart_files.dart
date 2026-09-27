// 列出门禁 analyze 要用的 Dart 文件（仓库相对路径，空格分隔，单行）。
//
// 用法：dart run tool/list_dart_files.dart lib test
//       dart run tool/list_dart_files.dart tool packages
//
// 只依赖 git 与 dart:io，Windows / macOS / Linux 同一条实现 —— justfile 不再
// 按 os() 分支拼 powershell / sh 两套管道。生成物走 .gitignore，git ls-files
// 天然列不到；再过滤一遍磁盘上已不存在的路径（index 里还留着的已删文件）。
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('用法: dart run tool/list_dart_files.dart <root>...');
    exit(64);
  }

  final result = Process.runSync(
    'git',
    ['ls-files', '--cached', '--others', '--exclude-standard', '--', ...args],
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );

  if (result.exitCode != 0) {
    stderr.write(result.stderr);
    exit(result.exitCode);
  }

  final files = LineSplitter.split(result.stdout as String)
      .where((path) => path.endsWith('.dart') && File(path).existsSync())
      .join(' ');

  stdout.write(files);
}
