// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quest_place.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QuestData _$QuestDataFromJson(Map<String, dynamic> json) => QuestData(
  questId: json['questId'] as String?,
  title: json['title'] as String?,
  places: (json['places'] as List<dynamic>)
      .map((e) => QuestPlace.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$QuestDataToJson(QuestData instance) => <String, dynamic>{
  'questId': ?instance.questId,
  'title': ?instance.title,
  'places': instance.places.map((e) => e.toJson()).toList(),
};

QuestPlace _$QuestPlaceFromJson(Map<String, dynamic> json) => QuestPlace(
  placeId: json['placeId'] as String,
  letter: json['letter'] as String,
  order: (json['order'] as num).toInt(),
  name: json['name'] as String?,
  lat: (json['lat'] as num?)?.toDouble(),
  lon: (json['lon'] as num?)?.toDouble(),
);

Map<String, dynamic> _$QuestPlaceToJson(QuestPlace instance) =>
    <String, dynamic>{
      'placeId': instance.placeId,
      'letter': instance.letter,
      'order': instance.order,
      'name': ?instance.name,
      'lat': ?instance.lat,
      'lon': ?instance.lon,
    };
