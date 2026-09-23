// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sample_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SampleItem {

 int get id; String get title; String get body;
/// Create a copy of SampleItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SampleItemCopyWith<SampleItem> get copyWith => _$SampleItemCopyWithImpl<SampleItem>(this as SampleItem, _$identity);

  /// Serializes this SampleItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SampleItem;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SampleItem&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.body, _this.body) || other.body == _this.body));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SampleItem;
  return Object.hash(runtimeType,_this.id,_this.title,_this.body);
}

@override
String toString() {
  final _this = this as SampleItem;
  return 'SampleItem(id: ${_this.id}, title: ${_this.title}, body: ${_this.body})';
}


}

/// @nodoc
abstract mixin class $SampleItemCopyWith<$Res>  {
  factory $SampleItemCopyWith(SampleItem value, $Res Function(SampleItem) _then) = _$SampleItemCopyWithImpl;
@useResult
$Res call({
 int id, String title, String body
});




}
/// @nodoc
class _$SampleItemCopyWithImpl<$Res>
    implements $SampleItemCopyWith<$Res> {
  _$SampleItemCopyWithImpl(this._self, this._then);

  final SampleItem _self;
  final $Res Function(SampleItem) _then;

/// Create a copy of SampleItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? body = null,}) {
  return _then(SampleItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [SampleItem].
extension SampleItemPatterns on SampleItem {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SampleItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SampleItem() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SampleItem value)  $default,){
final _that = this;
switch (_that) {
case _SampleItem():
return $default(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SampleItem value)?  $default,){
final _that = this;
switch (_that) {
case _SampleItem() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String title,  String body)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SampleItem() when $default != null:
return $default(_that.id,_that.title,_that.body);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String title,  String body)  $default,) {final _that = this;
switch (_that) {
case _SampleItem():
return $default(_that.id,_that.title,_that.body);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String title,  String body)?  $default,) {final _that = this;
switch (_that) {
case _SampleItem() when $default != null:
return $default(_that.id,_that.title,_that.body);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SampleItem implements SampleItem {
  const _SampleItem({required this.id, required this.title, required this.body});
  factory _SampleItem.fromJson(Map<String, dynamic> json) => _$SampleItemFromJson(json);

@override final  int id;
@override final  String title;
@override final  String body;

/// Create a copy of SampleItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SampleItemCopyWith<_SampleItem> get copyWith => __$SampleItemCopyWithImpl<_SampleItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SampleItemToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SampleItem&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,title,body);
}

@override
String toString() {
    return 'SampleItem(id: $id, title: $title, body: $body)';
}


}

/// @nodoc
abstract mixin class _$SampleItemCopyWith<$Res> implements $SampleItemCopyWith<$Res> {
  factory _$SampleItemCopyWith(_SampleItem value, $Res Function(_SampleItem) _then) = __$SampleItemCopyWithImpl;
@override @useResult
$Res call({
 int id, String title, String body
});




}
/// @nodoc
class __$SampleItemCopyWithImpl<$Res>
    implements _$SampleItemCopyWith<$Res> {
  __$SampleItemCopyWithImpl(this._self, this._then);

  final _SampleItem _self;
  final $Res Function(_SampleItem) _then;

/// Create a copy of SampleItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? body = null,}) {
  return _then(_SampleItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
