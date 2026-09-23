import 'package:app_core/base/failure.dart';
import 'package:app_core/base/result.dart';
import 'package:my_app/features/sample/data/models/sample_item.dart';

/// 示例条目的数据能力抽象：返回 `Result`，不抛异常。
///
/// 有真实的多实现需求（mock / 线上切换）才写这一层；简单 feature 可以由
/// `logic/` 直接调用 `SampleService`（见 frontend/directory-structure.md）。
///
/// 列表与单条两条路径都留着（演示两种形态）；自己的 feature 用不到哪条删哪条。
abstract class SampleRepository {
  Future<Result<List<SampleItem>, Failure>> getItems();

  Future<Result<SampleItem, Failure>> getItem(int id);
}
