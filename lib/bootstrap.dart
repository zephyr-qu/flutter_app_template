import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:leak_tracker/leak_tracker.dart';
import 'package:my_app/app/app.dart';
import 'package:my_app/core/logging/logging.dart';
import 'package:my_app/di/service_locator.dart';

/// 环境值与它的来源：`--dart-define` / `--dart-define-from-file` 注入的**编译期常量**。
///
/// 不走 `.env` 文件 + `dotenv` 的那套：文件要作为 asset 打进产物、要按环境名选文件、
/// 还要在启动期 `await` 一次 IO，而编译期常量这三件事都不需要。
const _baseUrl = String.fromEnvironment('BASE_URL');
const _useMock = String.fromEnvironment('USE_MOCK', defaultValue: 'false');

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

  // 缺 BASE_URL 直接抛，不静默启动 —— 否则会带着空地址跑到第一次网络请求才炸。
  if (_baseUrl.isEmpty) {
    throw Exception(
      '缺少 BASE_URL：用 --dart-define-from-file=.env.example 注入（见 .env.example）',
    );
  }
  Logging.info('Network: BASE_URL=$_baseUrl, USE_MOCK=$_useMock');

  _initLeakTracker();

  await configureDependencies();
  runApp(const MyApp());
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
