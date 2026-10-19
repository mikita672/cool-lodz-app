// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comfort_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ComfortProfile _$ComfortProfileFromJson(Map<String, dynamic> json) =>
    ComfortProfile(
      id: $enumDecode(_$ProfileIdEnumMap, json['id']),
      weights: ProfileWeights.fromJson(json['weights'] as Map<String, dynamic>),
      seniorMode: json['seniorMode'] as bool,
    );

Map<String, dynamic> _$ComfortProfileToJson(ComfortProfile instance) =>
    <String, dynamic>{
      'id': _$ProfileIdEnumMap[instance.id]!,
      'weights': instance.weights.toJson(),
      'seniorMode': instance.seniorMode,
    };

const _$ProfileIdEnumMap = {
  ProfileId.senior: 'senior',
  ProfileId.tourist: 'tourist',
  ProfileId.standard: 'default',
};
