// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get loading => '加载中...';

  @override
  String get errorTitle => '出错了';

  @override
  String get retry => '重试';

  @override
  String get backToHome => '返回首页';

  @override
  String get notFoundMessage => '页面未找到';

  @override
  String get errorTimeout => '请求超时';

  @override
  String get errorConnection => '网络连接失败';

  @override
  String get errorBadCertificate => '安全连接校验失败';

  @override
  String get errorUnauthorized => '未授权，请登录';

  @override
  String get errorForbidden => '禁止访问';

  @override
  String get errorNotFound => '资源不存在';

  @override
  String get errorInvalidRequest => '请求参数有误';

  @override
  String get errorConflict => '数据冲突，请刷新后重试';

  @override
  String get errorInvalidPayload => '提交的内容不合法';

  @override
  String get errorTooManyRequests => '请求过于频繁，请稍后重试';

  @override
  String get errorServer => '服务器错误';

  @override
  String errorRequestFailed(String status) {
    return '请求失败（$status）';
  }

  @override
  String get errorCancelled => '请求已取消';

  @override
  String get errorUnexpected => '网络异常，请稍后重试';

  @override
  String get errorUnknown => '未知错误';

  @override
  String get navHome => '首页';

  @override
  String get navArticles => '文章';

  @override
  String get navProfile => '我的';

  @override
  String get userFallback => '用户';

  @override
  String homeGreeting(String name) {
    return '你好, $name';
  }

  @override
  String get homeSubtitle => '今天也是美好的一天';

  @override
  String get homeQuickActions => '快捷功能';

  @override
  String get homeRecentActivity => '最近动态';

  @override
  String get homeNoRecentActivity => '暂无最近动态';

  @override
  String get profileTitle => '个人';

  @override
  String get notLoggedIn => '未登录';

  @override
  String get welcomeUse => '欢迎使用';

  @override
  String get settings => '设置';

  @override
  String get settingsNotifications => '通知';

  @override
  String get settingsPrivacy => '隐私';

  @override
  String get settingsAppearance => '外观';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsHelp => '帮助与支持';

  @override
  String get logout => '退出登录';

  @override
  String get languageTitle => '选择语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get themeTitle => '选择主题';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get articlesEmpty => '暂无文章';

  @override
  String get articleReadMore => '点击阅读更多...';

  @override
  String get articleRead => '阅读';

  @override
  String get articleTag => '技术';

  @override
  String articleReadingTime(int minutes) {
    return '$minutes 分钟阅读';
  }

  @override
  String get loginWelcome => '欢迎回来';

  @override
  String get loginSubtitle => '登录以继续使用';

  @override
  String get emailLabel => '邮箱';

  @override
  String get passwordLabel => '密码';

  @override
  String get passwordHint => '至少 6 位';

  @override
  String get loginButton => '登录';

  @override
  String get splashTagline => '简洁 · 优雅 · 实用';

  @override
  String get storageDemoTitle => '本地存储示例';

  @override
  String get storageDemoFileSection => '文件缓存';

  @override
  String get storageDemoFileDescription => '写入应用目录与临时目录，并统计占用空间';

  @override
  String get storageDemoInputHint => '要保存的内容';

  @override
  String get storageDemoSave => '保存';

  @override
  String get storageDemoDelete => '删除';

  @override
  String get storageDemoClearTemp => '清空临时目录';

  @override
  String get storageDemoContentLabel => '应用目录中的内容';

  @override
  String get storageDemoEmptyValue => '（无）';

  @override
  String storageDemoUsage(int kb) {
    return '占用：$kb KB';
  }

  @override
  String get storageDemoDbSection => '数据库缓存';

  @override
  String get storageDemoDbDescription => '填充示例数据后，文章列表在离线时会回退到这份缓存';

  @override
  String storageDemoCachedCount(int count) {
    return '已缓存 $count 篇文章';
  }

  @override
  String get storageDemoSeed => '填充示例数据';

  @override
  String get storageDemoClearCache => '清空缓存';

  @override
  String get storageDemoFailed => '操作失败';
}
