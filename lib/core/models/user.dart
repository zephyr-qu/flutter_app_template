import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

/// 用户模型。跨 auth / home / profile 共享，所以放 `core/models/`。
@freezed
sealed class User with _$User {
  const factory({required int id, required String name}) = _User;

  factory fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
