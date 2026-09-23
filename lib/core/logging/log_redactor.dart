/// 调试日志脱敏：把 `PrettyDioLogger` 打出来的敏感值换成 `***`。
///
/// [redact] **带状态**——折行的长值只替换第一行会把令牌漏出去，所以同一个实例
/// 要按顺序喂入同一批日志行。判断刻意偏保守：宁可多屏蔽一行，也不能漏一个令牌。
///
/// 为什么只能在日志行上做、折行的坑、新增敏感字段的清单，见
/// backend/logging-guidelines.md「HTTP 日志」。
class LogRedactor {
  /// 一条日志流的脱敏器。**同一个实例要按顺序喂入同一批日志行**，
  /// 否则它无法判断「这一行是上一行的续行，还是普通的新行」。
  new();

  /// 替换敏感值用的占位符
  static const masked = '***';

  /// 命中即屏蔽的字段名（大小写不敏感）。长的排在短的前面，
  /// 这样正则的命中范围一眼可读（`accessToken` 不会被 `token` 抢先解释）。
  static const sensitiveKeys = <String>[
    'authorization',
    'accessToken',
    'access_token',
    'refreshToken',
    'refresh_token',
    'oldPassword',
    'newPassword',
    'clientSecret',
    'client_secret',
    'password',
    'passwd',
    'secret',
    'token',
    'apiKey',
    'api_key',
    'set-cookie',
    'cookie',
    'credential',
  ];

  /// 字段名 + 分隔符。只认「独立出现的 key」：`"refreshToken": `、
  /// `authorization: `、`password=` —— 正文里恰好出现 "token" 这类词不会命中。
  static final RegExp _field = RegExp(
    '(?:"|\'|\\b)(?:${sensitiveKeys.join('|')})(?:"|\'|\\b)\\s*[:=]\\s*',
    caseSensitive: false,
  );

  /// 值的收尾 / 结构标记：引号（值的收尾或新字段的开头）、分隔线、括号。
  /// 值分片（令牌、base64、UUID）里不会出现它们。
  static final RegExp _structure = RegExp('["\'─{}()\\[\\]]');

  /// 上一行命中的敏感值还没结束，本行仍是它的分片
  bool _insideValue = false;

  /// 脱敏一行日志，返回可直接打印的内容。
  String redact(String line) {
    if (_insideValue) {
      if (_structure.hasMatch(line)) _insideValue = false;
      return masked;
    }

    final match = _field.firstMatch(line);
    if (match == null) return line;

    if (!_valueEndsOnThisLine(line, match.end)) _insideValue = true;
    return '${line.substring(0, match.end)}$masked';
  }

  /// 值是否在本行结束 —— 决定要不要进入「续行屏蔽」状态。
  static bool _valueEndsOnThisLine(String line, int valueStart) {
    final rest = line.substring(valueStart).trimRight();
    // `authorization: ` 后面直接换行 → 值在后续行
    if (rest.isEmpty) return false;
    final quote = rest[0];
    // 非引号值（header / query 的写法）由 PrettyDioLogger 在行内截断，不产生续行
    if (quote != '"' && quote != "'") return true;
    // 引号值：必须等到闭合引号
    return _structure.hasMatch(rest.substring(1));
  }
}
