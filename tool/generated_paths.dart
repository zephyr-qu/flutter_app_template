// 「哪些文件是生成物」的判定：目录树门禁（`tool/check_readme_tree.dart`）复用。
//
// 口径必须与根 `.gitignore`、`packages/app_lints/lib/src/paths.dart` 的同名函数
// 一致 —— 三处改动要同步，否则「豁免谁」会出现两套真相。

/// 生成的文件不参与检查：里面的违规没法手工修（要改的是注解 / 源文件），
/// 而且它们经常跨层引用（如 DI 注册文件必须 import 每个 feature 的 logic）。
///
/// 目录树里也不必列出它们：生成物的条目不是人能守的。
bool isGeneratedPath(String path) =>
    path.endsWith('.g.dart') ||
    path.endsWith('.freezed.dart') ||
    path.endsWith('.gr.dart') ||
    path.endsWith('.config.dart') ||
    path.endsWith('.gen.dart') ||
    path.contains('/gen/') ||
    path.contains('app_localizations');
