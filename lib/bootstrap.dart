import 'package:app_core/logging/logging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:leak_tracker/leak_tracker.dart';
import 'package:my_app/app/app.dart';
import 'package:my_app/core/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Required environment variables for the app.
const _requiredEnvKeys = ['BASE_URL'];

/// 当前环境名：`--dart-define=env=xxx` 优先，否则按构建模式取
/// development / production。
///
/// **不能**用 `defaultValue` 兜底，见 backend/quality-guidelines.md「环境配置」。
String get _activeEnv {
  const defined = String.fromEnvironment('env');
  if (defined.isNotEmpty) return defined;
  return kReleaseMode ? 'production' : 'development';
}

/// 对应的 .env 文件名
String get _envFileName => '.env.$_activeEnv';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 框架错误：保持 Flutter 默认行为（红屏 + 完整堆栈）。框架错误本来就会经过这里，
  // 再记一条日志只是把同一件事打两遍。
  FlutterError.onError = FlutterError.presentError;

  // 未捕获的异步错误（根 zone）。默认只会打到控制台，这里接进结构化日志。
  // 不用 `runZonedGuarded`：它与本 handler 覆盖同一批错误（见 frontend/quality-guidelines.md）。
  PlatformDispatcher.instance.onError = (exception, stackTrace) {
    Logging.error(
      'Unhandled async error',
      exception: exception,
      stackTrace: stackTrace,
    );
    return true; // 已处理，不继续传播
  };

  await dotenv.load(fileName: _envFileName);
  Logging.info('Environment: $_activeEnv ($_envFileName)');
  _validateEnv();

  _initLeakTracker();

  // 启动期把异步依赖解析完，之后所有消费者**同步**拿它
  // （理由与「为什么不用 FutureProvider」见 core/providers.dart 的 prefsProvider）。
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs)],
      child: const MyApp(),
    ),
  );
}

void _validateEnv() {
  for (final key in _requiredEnvKeys) {
    if (dotenv.env[key] == null || dotenv.env[key]!.isEmpty) {
      throw Exception('Missing required env key: $key');
    }
  }
}

void _initLeakTracker() {
  assert(() {
    FlutterMemoryAllocations.instance.addListener(
      (event) => LeakTracking.dispatchObjectEvent(event.toMap()),
    );
    LeakTracking.start();
    Logging.info('leak_tracker started — memory leaks will be reported');
    return true;
  }(), 'leak_tracker 只能在 debug 模式启动（release 下 assert 不执行）');
}
