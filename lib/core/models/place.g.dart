// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'place.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PlacesResponse _$PlacesResponseFromJson(Map<String, dynamic> json) =>
    PlacesResponse(
      places: (json['places'] as List<dynamic>)
          .map((e) => Place.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$PlacesResponseToJson(PlacesResponse instance) =>
    <String, dynamic>{
      'places': instance.places.map((e) => e.toJson()).toList(),
    };

Place _$PlaceFromJson(Map<String, dynamic> json) => Place(
  id: json['id'] as String,
  type: $enumDecode(_$PlaceTypeEnumMap, json['type']),
  name: json['name'] as String?,
  category: $enumDecodeNullable(
    _$PlaceCategoryEnumMap,
    json['category'],
    unknownValue: PlaceCategory.other,
  ),
  address: json['address'] as String?,
  lat: (json['lat'] as num).toDouble(),
  lon: (json['lon'] as num).toDouble(),
  hours: json['hours'] == null
      ? null
      : OpeningHours.fromJson(json['hours'] as Map<String, dynamic>),
  amenities: json['amenities'] == null
      ? const []
      : _amenitiesFromJson(json['amenities'] as List?),
  accessible: json['accessible'] as bool?,
  questPlace: json['questPlace'] as bool? ?? false,
  source: json['source'] as String?,
);

Map<String, dynamic> _$PlaceToJson(Place instance) => <String, dynamic>{
  'id': instance.id,
  'type': _$PlaceTypeEnumMap[instance.type]!,
  'name': ?instance.name,
  'category': ?_$PlaceCategoryEnumMap[instance.category],
  'address': ?instance.address,
  'lat': instance.lat,
  'lon': instance.lon,
  'hours': ?instance.hours?.toJson(),
  'amenities': instance.amenities.map((e) => _$AmenityEnumMap[e]!).toList(),
  'accessible': ?instance.accessible,
  'questPlace': instance.questPlace,
  'source': ?instance.source,
};

const _$PlaceTypeEnumMap = {
  PlaceType.cool: 'cool',
  PlaceType.water: 'water',
  PlaceType.bench: 'bench',
};

const _$PlaceCategoryEnumMap = {
  PlaceCategory.library: 'library',
  PlaceCategory.museum: 'museum',
  PlaceCategory.culture: 'culture',
  PlaceCategory.mall: 'mall',
  PlaceCategory.park: 'park',
  PlaceCategory.station: 'station',
  PlaceCategory.church: 'church',
  PlaceCategory.other: 'other',
};

const _$AmenityEnumMap = {
  Amenity.airConditioning: 'airConditioning',
  Amenity.water: 'water',
  Amenity.toilet: 'toilet',
  Amenity.wheelchair: 'wheelchair',
};
