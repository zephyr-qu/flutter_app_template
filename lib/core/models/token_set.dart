/// 一对令牌 + 访问令牌的过期时刻。
///
/// 同一个形状在三个地方流转（登录响应、刷新响应、本地存储），所以收成一个值对象，
/// 各层只搬运它，不再各自重复 `accessToken` / `refreshToken` / `expiresIn` 三个参数。
///
/// 两种来源用两个构造器区分，因为时间的表达方式不同：
/// - 服务端给的是**相对秒数** `expiresIn` → [TokenSet.withExpiresIn] 当场换算成绝对时刻；
/// - 落盘再读回来时相对秒数早已失效 → [TokenSet.fromJson] / [toJson] 用的是绝对时刻。
class TokenSet {
  const new({required this.accessToken, this.refreshToken, this.expiresAt});

  /// 从接口响应的 JSON 构造（线上形状：`expiresIn` 是秒）
  factory fromApi(Map<String, dynamic> json) => TokenSet.withExpiresIn(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String?,
    expiresIn: json['expiresIn'] as int?,
  );

  /// 从已解析的字段构造；`expiresIn`（秒）在这里换算成绝对时刻
  factory withExpiresIn({
    required String accessToken,
    String? refreshToken,
    int? expiresIn,
  }) => TokenSet(
    accessToken: accessToken,
    refreshToken: refreshToken,
    expiresAt: expiresIn == null
        ? null
        : DateTime.now().add(Duration(seconds: expiresIn)),
  );

  /// 从落盘 JSON 构造（落盘形状：`expiresAt` 是毫秒时间戳）
  factory fromJson(Map<String, dynamic> json) => TokenSet(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String?,
    expiresAt: switch (json['expiresAt']) {
      final int millis => DateTime.fromMillisecondsSinceEpoch(millis),
      _ => null,
    },
  );

  final String accessToken;

  /// 服务端只在轮换时才返回新的；为空表示「沿用当前刷新令牌」，不是「没有」
  final String? refreshToken;

  /// null = 服务端未给 `expiresIn`，无法主动刷新，只能等 401 兜底
  final DateTime? expiresAt;

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    if (refreshToken != null) 'refreshToken': refreshToken,
    if (expiresAt != null) 'expiresAt': expiresAt!.millisecondsSinceEpoch,
  };
}
