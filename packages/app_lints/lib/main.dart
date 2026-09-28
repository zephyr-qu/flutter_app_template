import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/rules.dart';

/// 分析服务器加载这个文件、读取这个顶层变量，名字必须是 `plugin`。
final plugin = AppLintsPlugin();

class AppLintsPlugin extends Plugin {
  @override
  String get name => 'app_lints';

  @override
  void register(PluginRegistry registry) {
    // 全部注册为 warning 规则（默认开）。它们在 `dart analyze` 里输出诊断；
    // 根 `justfile` 的 analyze 步骤带 `--fatal-infos`，所以不会漏。
    registry
      ..registerWarningRule(CoreImportsRule())
      ..registerWarningRule(CrossFeatureImportsRule())
      ..registerWarningRule(ServiceLocatorInLogicRule())
      ..registerWarningRule(PageInjectionPointRule())
      ..registerWarningRule(AvoidAsyncStateMapRule())
      ..registerWarningRule(CommentBlockTooLongRule())
      ..registerWarningRule(LogicImportsMaterialRule());
  }
}
