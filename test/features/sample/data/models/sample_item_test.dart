import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/sample/data/models/sample_item.dart';

/// 模型层要守的只有两件事：`fromJson` 认得后端字段、值相等性可用
/// （后者是列表 diff 与测试断言的前提）。
void main() {
  const item = SampleItem(id: 1, title: '示例条目一', body: '正文');

  test('fromJson 解析后端字段', () {
    final parsed = SampleItem.fromJson(const {
      'id': 7,
      'title': '标题',
      'body': '正文',
    });

    expect(parsed.id, 7);
    expect(parsed.title, '标题');
    expect(parsed.body, '正文');
  });

  test('同值实例相等（freezed 生成的 == / hashCode）', () {
    expect(const SampleItem(id: 1, title: '示例条目一', body: '正文'), item);
    expect(
      const SampleItem(id: 1, title: '示例条目一', body: '正文').hashCode,
      item.hashCode,
    );
  });

  test('copyWith 只覆盖指定字段', () {
    final renamed = item.copyWith(title: '新标题');

    expect(renamed.title, '新标题');
    expect(renamed.id, 1);
    expect(renamed.body, '正文');
  });
}
