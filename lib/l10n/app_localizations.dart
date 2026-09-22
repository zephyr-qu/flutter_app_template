import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @loading.
  ///
  /// In zh, this message translates to:
  /// **'加载中...'**
  String get loading;

  /// No description provided for @errorTitle.
  ///
  /// In zh, this message translates to:
  /// **'出错了'**
  String get errorTitle;

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @backToHome.
  ///
  /// In zh, this message translates to:
  /// **'返回首页'**
  String get backToHome;

  /// No description provided for @notFoundMessage.
  ///
  /// In zh, this message translates to:
  /// **'页面未找到'**
  String get notFoundMessage;

  /// No description provided for @errorTimeout.
  ///
  /// In zh, this message translates to:
  /// **'请求超时'**
  String get errorTimeout;

  /// No description provided for @errorConnection.
  ///
  /// In zh, this message translates to:
  /// **'网络连接失败'**
  String get errorConnection;

  /// No description provided for @errorBadCertificate.
  ///
  /// In zh, this message translates to:
  /// **'安全连接校验失败'**
  String get errorBadCertificate;

  /// No description provided for @errorUnauthorized.
  ///
  /// In zh, this message translates to:
  /// **'未授权，请登录'**
  String get errorUnauthorized;

  /// No description provided for @errorForbidden.
  ///
  /// In zh, this message translates to:
  /// **'禁止访问'**
  String get errorForbidden;

  /// No description provided for @errorNotFound.
  ///
  /// In zh, this message translates to:
  /// **'资源不存在'**
  String get errorNotFound;

  /// No description provided for @errorInvalidRequest.
  ///
  /// In zh, this message translates to:
  /// **'请求参数有误'**
  String get errorInvalidRequest;

  /// No description provided for @errorConflict.
  ///
  /// In zh, this message translates to:
  /// **'数据冲突，请刷新后重试'**
  String get errorConflict;

  /// No description provided for @errorInvalidPayload.
  ///
  /// In zh, this message translates to:
  /// **'提交的内容不合法'**
  String get errorInvalidPayload;

  /// No description provided for @errorTooManyRequests.
  ///
  /// In zh, this message translates to:
  /// **'请求过于频繁，请稍后重试'**
  String get errorTooManyRequests;

  /// No description provided for @errorServer.
  ///
  /// In zh, this message translates to:
  /// **'服务器错误'**
  String get errorServer;

  /// No description provided for @errorRequestFailed.
  ///
  /// In zh, this message translates to:
  /// **'请求失败（{status}）'**
  String errorRequestFailed(String status);

  /// No description provided for @errorCancelled.
  ///
  /// In zh, this message translates to:
  /// **'请求已取消'**
  String get errorCancelled;

  /// No description provided for @errorUnexpected.
  ///
  /// In zh, this message translates to:
  /// **'网络异常，请稍后重试'**
  String get errorUnexpected;

  /// No description provided for @errorUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知错误'**
  String get errorUnknown;

  /// No description provided for @navHome.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get navHome;

  /// No description provided for @navArticles.
  ///
  /// In zh, this message translates to:
  /// **'文章'**
  String get navArticles;

  /// No description provided for @navProfile.
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get navProfile;

  /// No description provided for @userFallback.
  ///
  /// In zh, this message translates to:
  /// **'用户'**
  String get userFallback;

  /// No description provided for @homeGreeting.
  ///
  /// In zh, this message translates to:
  /// **'你好, {name}'**
  String homeGreeting(String name);

  /// No description provided for @homeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'今天也是美好的一天'**
  String get homeSubtitle;

  /// No description provided for @homeQuickActions.
  ///
  /// In zh, this message translates to:
  /// **'快捷功能'**
  String get homeQuickActions;

  /// No description provided for @homeRecentActivity.
  ///
  /// In zh, this message translates to:
  /// **'最近动态'**
  String get homeRecentActivity;

  /// No description provided for @homeNoRecentActivity.
  ///
  /// In zh, this message translates to:
  /// **'暂无最近动态'**
  String get homeNoRecentActivity;

  /// No description provided for @profileTitle.
  ///
  /// In zh, this message translates to:
  /// **'个人'**
  String get profileTitle;

  /// No description provided for @notLoggedIn.
  ///
  /// In zh, this message translates to:
  /// **'未登录'**
  String get notLoggedIn;

  /// No description provided for @welcomeUse.
  ///
  /// In zh, this message translates to:
  /// **'欢迎使用'**
  String get welcomeUse;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @settingsNotifications.
  ///
  /// In zh, this message translates to:
  /// **'通知'**
  String get settingsNotifications;

  /// No description provided for @settingsPrivacy.
  ///
  /// In zh, this message translates to:
  /// **'隐私'**
  String get settingsPrivacy;

  /// No description provided for @settingsAppearance.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get settingsAppearance;

  /// No description provided for @settingsLanguage.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get settingsLanguage;

  /// No description provided for @settingsHelp.
  ///
  /// In zh, this message translates to:
  /// **'帮助与支持'**
  String get settingsHelp;

  /// No description provided for @logout.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get logout;

  /// No description provided for @languageTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择语言'**
  String get languageTitle;

  /// No description provided for @languageSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get languageSystem;

  /// No description provided for @themeTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择主题'**
  String get themeTitle;

  /// No description provided for @themeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeDark;

  /// No description provided for @articlesEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无文章'**
  String get articlesEmpty;

  /// No description provided for @articleReadMore.
  ///
  /// In zh, this message translates to:
  /// **'点击阅读更多...'**
  String get articleReadMore;

  /// No description provided for @articleRead.
  ///
  /// In zh, this message translates to:
  /// **'阅读'**
  String get articleRead;

  /// No description provided for @articleTag.
  ///
  /// In zh, this message translates to:
  /// **'技术'**
  String get articleTag;

  /// No description provided for @articleReadingTime.
  ///
  /// In zh, this message translates to:
  /// **'{minutes} 分钟阅读'**
  String articleReadingTime(int minutes);

  /// No description provided for @loginWelcome.
  ///
  /// In zh, this message translates to:
  /// **'欢迎回来'**
  String get loginWelcome;

  /// No description provided for @loginSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'登录以继续使用'**
  String get loginSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In zh, this message translates to:
  /// **'邮箱'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get passwordLabel;

  /// No description provided for @passwordHint.
  ///
  /// In zh, this message translates to:
  /// **'至少 6 位'**
  String get passwordHint;

  /// No description provided for @loginButton.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get loginButton;

  /// No description provided for @splashTagline.
  ///
  /// In zh, this message translates to:
  /// **'简洁 · 优雅 · 实用'**
  String get splashTagline;

  /// No description provided for @storageDemoTitle.
  ///
  /// In zh, this message translates to:
  /// **'本地存储示例'**
  String get storageDemoTitle;

  /// No description provided for @storageDemoFileSection.
  ///
  /// In zh, this message translates to:
  /// **'文件缓存'**
  String get storageDemoFileSection;

  /// No description provided for @storageDemoFileDescription.
  ///
  /// In zh, this message translates to:
  /// **'写入应用目录与临时目录，并统计占用空间'**
  String get storageDemoFileDescription;

  /// No description provided for @storageDemoInputHint.
  ///
  /// In zh, this message translates to:
  /// **'要保存的内容'**
  String get storageDemoInputHint;

  /// No description provided for @storageDemoSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get storageDemoSave;

  /// No description provided for @storageDemoDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get storageDemoDelete;

  /// No description provided for @storageDemoClearTemp.
  ///
  /// In zh, this message translates to:
  /// **'清空临时目录'**
  String get storageDemoClearTemp;

  /// No description provided for @storageDemoContentLabel.
  ///
  /// In zh, this message translates to:
  /// **'应用目录中的内容'**
  String get storageDemoContentLabel;

  /// No description provided for @storageDemoEmptyValue.
  ///
  /// In zh, this message translates to:
  /// **'（无）'**
  String get storageDemoEmptyValue;

  /// No description provided for @storageDemoUsage.
  ///
  /// In zh, this message translates to:
  /// **'占用：{kb} KB'**
  String storageDemoUsage(int kb);

  /// No description provided for @storageDemoDbSection.
  ///
  /// In zh, this message translates to:
  /// **'数据库缓存'**
  String get storageDemoDbSection;

  /// No description provided for @storageDemoDbDescription.
  ///
  /// In zh, this message translates to:
  /// **'填充示例数据后，文章列表在离线时会回退到这份缓存'**
  String get storageDemoDbDescription;

  /// No description provided for @storageDemoCachedCount.
  ///
  /// In zh, this message translates to:
  /// **'已缓存 {count} 篇文章'**
  String storageDemoCachedCount(int count);

  /// No description provided for @storageDemoSeed.
  ///
  /// In zh, this message translates to:
  /// **'填充示例数据'**
  String get storageDemoSeed;

  /// No description provided for @storageDemoClearCache.
  ///
  /// In zh, this message translates to:
  /// **'清空缓存'**
  String get storageDemoClearCache;

  /// No description provided for @storageDemoFailed.
  ///
  /// In zh, this message translates to:
  /// **'操作失败'**
  String get storageDemoFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
