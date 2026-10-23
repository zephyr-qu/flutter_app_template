// `features/sample` 的对外出口 —— 跨 feature 依赖的唯一样板。
//
// 只有 feature 根上的 `api.dart` 允许被别的 feature 引用（规则
// `cross_feature_only_data` 放行它，feature 根上的其他文件照旧违规）。约定：
//   - 只 re-export 对外的**只读 provider 与模型**；
//   - 不导出 Notifier 类本身 —— 拿到类就等于拿到写权限，边界白设；
//   - 不导出 `page/`（规则 `api_facade_no_page` 会拦）。
//
// 别的 feature 要读你的状态时，先在这里开一条出口，而不是把业务计算挪进
// `data/` —— 后者只是为了让调用方绕开规则，代价是业务逻辑降级到数据层。

export 'data/models/sample_item.dart';
export 'logic/sample_list_notifier.dart' show sampleListProvider;
