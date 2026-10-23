import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/sample/api.dart';

/// `features/sample/api.dart` 出口的最小守卫。
///
/// 出口里 `show` 的名字写错、或模型漏了导出，这里会先炸，而不是等别的 feature
/// 引用时才发现。只验证「拿得到」，不读 provider 值（那需要真实仓库）。
void main() {
  test('出口能拿到只读 provider 与模型', () {
    expect(sampleListProvider, isNotNull);

    const item = SampleItem(id: 1, title: '示例', body: '正文');
    expect(item.title, '示例');
  });
}
