import 'package:json_annotation/json_annotation.dart';

part 'quest_place.g.dart';

/// `assets/demo/quest.json`, the seed for Firestore `questPlaces`.
@JsonSerializable()
class QuestData {
  const QuestData({
    this.questId,
    this.title,
    this.password,
    required this.places,
  });

  /// Accepts `{"places": [...]}` or a bare list of places.
  factory QuestData.fromJson(Object json) => json is List
      ? QuestData(
          places: [
            for (final p in json)
              QuestPlace.fromJson(p as Map<String, dynamic>),
          ],
        )
      : _$QuestDataFromJson(json as Map<String, dynamic>);

  final String? questId;
  final String? title;

  /// The quest password (e.g. `CHŁODNO`), if the file carries it.
  final String? password;
  final List<QuestPlace> places;

  /// Places in quest order.
  List<QuestPlace> get ordered =>
      [...places]..sort((a, b) => a.order.compareTo(b.order));

  Map<String, dynamic> toJson() => _$QuestDataToJson(this);
}

/// A quest place: which cool place (`placeId` → `Place.id`) gives which letter.
@JsonSerializable()
class QuestPlace {
  const QuestPlace({
    required this.placeId,
    required this.letter,
    required this.order,
    this.name,
    this.lat,
    this.lon,
  });

  factory QuestPlace.fromJson(Map<String, dynamic> json) =>
      _$QuestPlaceFromJson(json);

  final String placeId;
  final String letter;

  /// 1-based position of the letter in the password.
  final int order;

  final String? name;
  final double? lat;
  final double? lon;

  Map<String, dynamic> toJson() => _$QuestPlaceToJson(this);
}
