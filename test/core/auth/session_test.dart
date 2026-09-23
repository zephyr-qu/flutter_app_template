import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/auth/session.dart';
import 'package:my_app/core/models/user.dart';

import '../../support/app_test_harness.dart';

/// `Session` 是 `AuthStorage` 的**可订阅镜像**：真源永远是存储本身
/// （路由守卫同步读它），本 provider 只把 `userChanges` 流折射成给 UI 用的状态。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestAppContext app;

  setUp(() async {
    app = await setUpTestApp();
    // keepAlive 的 provider 也要有订阅者：否则测到的只是「读了一次」，
    // 而页面关心的是「状态会不会自己变」
    app.container.listen(sessionProvider, (_, _) {});
  });

  test('首个状态就是存储里的当前用户（首帧不留空窗）', () async {
    await app.storage.saveUser(const User(id: 1, name: '张三'));

    expect(app.container.read(sessionProvider)?.name, '张三');
    expect(app.container.read(sessionProvider.notifier).isLoggedIn, isTrue);
  });

  test('存储变化经 userChanges 回流成 provider 状态', () async {
    expect(app.container.read(sessionProvider), isNull);

    await app.storage.saveUser(const User(id: 1, name: '张三'));
    await pumpEventQueue();
    expect(app.container.read(sessionProvider)?.name, '张三');

    // 401 之后拦截器清掉的就是这份存储，UI 必须跟着变
    await app.storage.clearAuth();
    await pumpEventQueue();
    expect(app.container.read(sessionProvider), isNull);
    expect(app.container.read(sessionProvider.notifier).isLoggedIn, isFalse);
  });

  test('signOut 清本地凭证，真源仍在 AuthStorage', () async {
    await app.storage.saveUser(const User(id: 1, name: '张三'));
    await pumpEventQueue();

    await app.container.read(sessionProvider.notifier).signOut();
    await pumpEventQueue();

    expect(app.storage.currentUser, isNull);
    expect(app.container.read(sessionProvider), isNull);
  });

  test('saveUser 委托给 AuthStorage（本类不另存一份）', () async {
    await app.container
        .read(sessionProvider.notifier)
        .saveUser(const User(id: 9, name: '李四'));

    expect(app.storage.currentUser?.id, 9);
    expect(app.prefs.getString('auth.user'), isNotNull);
    await pumpEventQueue();
    expect(app.container.read(sessionProvider)?.id, 9);
  });
}
