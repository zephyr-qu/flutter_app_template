import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/models/user.dart';

void main() {
  group('User model', () {
    test('fromJson parses correctly', () {
      final json = {'id': 7, 'name': '开发者'};
      final user = User.fromJson(json);

      expect(user.id, equals(7));
      expect(user.name, equals('开发者'));
    });

    test('toJson serializes correctly', () {
      const user = User(id: 7, name: '开发者');
      final json = user.toJson();

      expect(json['id'], equals(7));
      expect(json['name'], equals('开发者'));
    });

    test('toJson roundtrip produces an equal object', () {
      const original = User(id: 42, name: '测试用户');
      final restored = User.fromJson(original.toJson());

      expect(restored, equals(original));
    });

    test('freezed copyWith works', () {
      const user = User(id: 1, name: '原名');
      final updated = user.copyWith(name: '新名');

      expect(updated.id, equals(1));
      expect(updated.name, equals('新名'));
    });
  });
}
