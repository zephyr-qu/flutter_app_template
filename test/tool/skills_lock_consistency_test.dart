import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// 为什么有这个测试（vendored skill 的漂移防线）：
// `.agents/skills/**` 是随仓库分发的第三方资产，来源与路径记在 `skills-lock.json`
// （README 承诺「来源与每个 skill 的路径见 lock」）。两边漂移不会报错：lock 里多出
// 指向不存在目录的条目（改名 / 打补丁后遗留），或磁盘多了没登记的目录，都只在人
// 翻文档时才发现。

void main() {
  test('lock 的每个 skill 都有对应的磁盘目录', () {
    final missing = [
      for (final name in _readLock().keys)
        if (!Directory('.agents/skills/$name').existsSync()) name,
    ];

    expect(missing, isEmpty, reason: 'lock 登记了但磁盘没有这些目录：$missing');
  });

  test('磁盘上的每个 skill 目录都登记在 lock 里', () {
    final registered = _readLock().keys.toSet();
    final onDisk = Directory('.agents/skills')
        .listSync()
        .whereType<Directory>()
        .map((dir) => dir.path.split(RegExp(r'[\\/]')).last)
        .toSet();

    expect(
      onDisk.difference(registered),
      isEmpty,
      reason: '磁盘上这些 skill 没登记进 lock，README 的「来源见 lock」会失真',
    );
  });

  test('skillPath 用上游相对路径 `skills/<name>/SKILL.md`', () {
    final wrong = [
      for (final entry in _readLock().entries)
        if (entry.value != 'skills/${entry.key}/SKILL.md')
          '${entry.key} → ${entry.value}',
    ];

    expect(wrong, isEmpty, reason: 'skillPath 不是上游相对路径：$wrong');
  });
}

/// `skills-lock.json` → {skill 名: skillPath}
Map<String, String> _readLock() {
  final raw = jsonDecode(File('skills-lock.json').readAsStringSync());
  final skills =
      (raw as Map<String, dynamic>)['skills'] as Map<String, dynamic>;
  return {
    for (final entry in skills.entries)
      entry.key: (entry.value as Map<String, dynamic>)['skillPath'] as String,
  };
}
