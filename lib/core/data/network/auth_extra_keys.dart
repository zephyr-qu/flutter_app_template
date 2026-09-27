/// Dio `RequestOptions.extra` 中使用的键。
///
/// 用 `extra` 而不是按 URL 判断：语义跟着请求走，重放时会被原样复用。
library;

/// 标记「这个请求本身就是刷新令牌的请求」（缺了它，刷新接口 401 会无限递归）
const String kSkipAuthRefresh = 'skipAuthRefresh';

/// 标记「这个请求已经用新令牌重放过一次」（重放仍 401 说明新令牌也不被接受）
const String kAuthRetried = 'authRetried';
