import 'package:freezed_annotation/freezed_annotation.dart';

part 'sample_item.freezed.dart';
part 'sample_item.g.dart';

/// 示例条目模型（`features/sample` 私有）。
///
/// 新增模型照抄本文件：`@freezed` + `fromJson`，结构约定见
/// frontend/type-safety.md。只有被 2+ feature 共用、或 core 自己要用的模型
/// 才提到 `lib/core/models/`（当前仓库还没有这个目录，需要时再建）。
@freezed
sealed class SampleItem with _$SampleItem {
  const factory({
    required int id,
    required String title,
    required String body,
  }) = _SampleItem;

  factory fromJson(Map<String, dynamic> json) => _$SampleItemFromJson(json);
}
