// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get loading => 'Loading...';

  @override
  String get errorTitle => 'Something went wrong';

  @override
  String get retry => 'Retry';

  @override
  String get backToHome => 'Back to home';

  @override
  String get notFoundMessage => 'Page not found';

  @override
  String get errorTimeout => 'Request timed out';

  @override
  String get errorConnection => 'Connection failed';

  @override
  String get errorBadCertificate => 'Secure connection failed';

  @override
  String get errorUnauthorized => 'Not authorized, please sign in';

  @override
  String get errorForbidden => 'Access denied';

  @override
  String get errorNotFound => 'Not found';

  @override
  String get errorInvalidRequest => 'Invalid request';

  @override
  String get errorConflict => 'Data conflict, please refresh and retry';

  @override
  String get errorInvalidPayload => 'Invalid input';

  @override
  String get errorTooManyRequests =>
      'Too many requests, please try again later';

  @override
  String get errorServer => 'Server error';

  @override
  String errorRequestFailed(String status) {
    return 'Request failed ($status)';
  }

  @override
  String get errorCancelled => 'Request cancelled';

  @override
  String get errorUnexpected => 'Network error, please try again';

  @override
  String get errorUnknown => 'Unknown error';

  @override
  String get navHome => 'Home';

  @override
  String get navArticles => 'Articles';

  @override
  String get navProfile => 'Profile';

  @override
  String get userFallback => 'there';

  @override
  String homeGreeting(String name) {
    return 'Hello, $name';
  }

  @override
  String get homeSubtitle => 'Have a nice day';

  @override
  String get homeQuickActions => 'Quick actions';

  @override
  String get homeRecentActivity => 'Recent activity';

  @override
  String get homeNoRecentActivity => 'No recent activity';

  @override
  String get profileTitle => 'Profile';

  @override
  String get notLoggedIn => 'Not signed in';

  @override
  String get welcomeUse => 'Welcome';

  @override
  String get settings => 'Settings';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsHelp => 'Help & support';

  @override
  String get logout => 'Sign out';

  @override
  String get languageTitle => 'Choose language';

  @override
  String get languageSystem => 'Follow system';

  @override
  String get themeTitle => 'Choose theme';

  @override
  String get themeSystem => 'Follow system';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get articlesEmpty => 'No articles yet';

  @override
  String get articleReadMore => 'Tap to read more...';

  @override
  String get articleRead => 'Read';

  @override
  String get articleTag => 'Tech';

  @override
  String articleReadingTime(int minutes) {
    return '$minutes min read';
  }

  @override
  String get loginWelcome => 'Welcome back';

  @override
  String get loginSubtitle => 'Sign in to continue';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordHint => 'At least 6 characters';

  @override
  String get loginButton => 'Sign in';

  @override
  String get splashTagline => 'Simple · Elegant · Practical';

  @override
  String get storageDemoTitle => 'Local storage demo';

  @override
  String get storageDemoFileSection => 'File cache';

  @override
  String get storageDemoFileDescription =>
      'Write to the app and temp directories, and measure usage';

  @override
  String get storageDemoInputHint => 'Text to save';

  @override
  String get storageDemoSave => 'Save';

  @override
  String get storageDemoDelete => 'Delete';

  @override
  String get storageDemoClearTemp => 'Clear temp';

  @override
  String get storageDemoContentLabel => 'Content in the app directory';

  @override
  String get storageDemoEmptyValue => '(empty)';

  @override
  String storageDemoUsage(int kb) {
    return 'Usage: $kb KB';
  }

  @override
  String get storageDemoDbSection => 'Database cache';

  @override
  String get storageDemoDbDescription =>
      'After seeding, the article list falls back to this cache when offline';

  @override
  String storageDemoCachedCount(int count) {
    return '$count cached articles';
  }

  @override
  String get storageDemoSeed => 'Seed sample data';

  @override
  String get storageDemoClearCache => 'Clear cache';

  @override
  String get storageDemoFailed => 'Operation failed';
}
