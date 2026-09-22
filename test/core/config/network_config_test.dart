import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/config/network_config.dart';

void main() {
  group('NetworkConfig.fromEnv', () {
    test('读取 BASE_URL 与 USE_MOCK', () {
      final config = NetworkConfig.fromEnv(const {
        'BASE_URL': 'https://api.example.com/v1',
        'USE_MOCK': 'true',
      });

      expect(config.baseUrl, 'https://api.example.com/v1');
      expect(config.isMock, isTrue);
    });

    test('USE_MOCK 大写同样识别，缺省为 false', () {
      expect(NetworkConfig.fromEnv(const {'USE_MOCK': 'TRUE'}).isMock, isTrue);
      expect(NetworkConfig.fromEnv(const {}).isMock, isFalse);
    });
  });

  group('NetworkConfig 默认值', () {
    test('超时与重试有默认值', () {
      const config = NetworkConfig(baseUrl: 'https://api.test');

      expect(config.connectTimeout, 10000);
      expect(config.receiveTimeout, 10000);
      expect(config.retries, 3);
      expect(config.defaultHeaders['Accept'], 'application/json');
    });

    test('每个值都可被覆盖（测试隔离的前提）', () {
      const config = NetworkConfig(
        baseUrl: 'http://localhost:1',
        isMock: true,
        connectTimeout: 1,
        receiveTimeout: 2,
        retries: 0,
      );

      expect(config.baseUrl, 'http://localhost:1');
      expect(config.isMock, isTrue);
      expect(config.connectTimeout, 1);
      expect(config.receiveTimeout, 2);
      expect(config.retries, 0);
    });
  });
}
