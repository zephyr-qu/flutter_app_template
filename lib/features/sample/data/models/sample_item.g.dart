// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sample_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SampleItem _$SampleItemFromJson(Map<String, dynamic> json) => _SampleItem(
  id: (json['id'] as num).toInt(),
  title: json['title'] as String,
  body: json['body'] as String,
);

Map<String, dynamic> _$SampleItemToJson(_SampleItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'body': instance.body,
    };
