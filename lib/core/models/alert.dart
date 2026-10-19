import 'package:json_annotation/json_annotation.dart';

import 'date_time_converter.dart';

part 'alert.g.dart';

@JsonSerializable()
class AlertsResponse {
  const AlertsResponse({required this.alerts});

  factory AlertsResponse.fromJson(Map<String, dynamic> json) =>
      _$AlertsResponseFromJson(json);

  /// Empty = no alert.
  final List<Alert> alerts;

  Map<String, dynamic> toJson() => _$AlertsResponseToJson(this);
}

/// IMGW heat warning.
@JsonSerializable()
class Alert {
  const Alert({
    required this.id,
    required this.level,
    required this.title,
    required this.area,
    required this.validFrom,
    required this.validTo,
    required this.source,
    this.recommendations = const [],
    this.officialUrl,
  });

  factory Alert.fromJson(Map<String, dynamic> json) => _$AlertFromJson(json);

  final String id;

  /// 1..3
  final int level;

  final String title;
  final String area;

  @OffsetDateTimeConverter()
  final DateTime validFrom;

  @OffsetDateTimeConverter()
  final DateTime validTo;

  final String source;

  /// Three short tips in Polish.
  final List<String> recommendations;

  final String? officialUrl;

  bool isActiveAt(DateTime time) =>
      !time.isBefore(validFrom) && time.isBefore(validTo);

  Map<String, dynamic> toJson() => _$AlertToJson(this);
}
