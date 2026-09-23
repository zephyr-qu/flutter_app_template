import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:msw_dio_interceptor/msw_dio_interceptor.dart';
import 'package:my_app/core/data/network/dio_client.dart';
import 'package:my_app/core/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/app_test_harness.dart' show noRetry;
import '../../../support/scripted_http_adapter.dart';

/// 应用侧的 Dio 装配。`dio_client.dart` 只做三件本应用专属的事：从 dotenv 取
/// 配置、按偏好决定调试日志、注册内置 Mock 规则；拦截器栈本身（顺序、重试、
/// 刷新）由 `interceptor_stack_test.dart` 覆盖，这里只管「装配对不对」。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    // 关掉调试日志：`dioProvider` 会按用户偏好挂 PrettyDioLogger，
    // 否则每个响应都会被打到测试输出里
    SharedPreferences.setMockInitialValues({'app.debug.logging': false});
    FlutterSecureStorage.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      retry: noRetry,
      overrides: [prefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('NetworkConfig 的唯一来源是 dotenv', () {
    dotenv.loadFromString(
      envString: 'BASE_URL=https://api.test\nUSE_MOCK=false',
    );

    final config = createContainer().read(networkConfigProvider);

    expect(config.baseUrl, 'https://api.test');
    expect(config.isMock, isFalse);
  });

  test('isMock=false 时不挂 Mock 拦截器', () {
    dotenv.loadFromString(
      envString: 'BASE_URL=https://api.test\nUSE_MOCK=false',
    );

    final dio = createContainer().read(dioProvider);

    expect(dio.options.baseUrl, 'https://api.test');
    expect(dio.interceptors.whereType<MockInterceptor>(), isEmpty);
  });

  test('isMock=true 时挂 Mock 拦截器，且内置规则真的生效', () async {
    dotenv.loadFromString(
      envString: 'BASE_URL=http://test.local\nUSE_MOCK=true',
    );
    final dio = createContainer().read(dioProvider);

    expect(dio.interceptors.whereType<MockInterceptor>(), hasLength(1));

    // 规则没命中就会走真实网络：换一个假适配器，把「没命中」变成可读的
    // 空响应，而不是 DNS 超时
    dio.httpClientAdapter = ScriptedHttpAdapter();

    final response = await dio.get<List<dynamic>>('/sample-items');

    // 规则必须用 MockRule.regex 且锚定结尾（见 network-guidelines.md），
    // 否则这里只会拿到假适配器的空响应
    expect(response.data, hasLength(2));
    expect((response.data!.first as Map)['title'], '示例条目一');
  });
}
