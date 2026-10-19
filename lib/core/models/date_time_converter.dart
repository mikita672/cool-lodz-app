import 'package:json_annotation/json_annotation.dart';

/// ISO 8601 with the UTC offset, as the API expects:
/// `2026-07-15T14:30:00+02:00`.
///
/// Parsed values are converted to device local time (the app assumes the
/// device runs in Europe/Warsaw), so wall-clock reads like `.hour` give Łódź
/// time.
class OffsetDateTimeConverter implements JsonConverter<DateTime, String> {
  const OffsetDateTimeConverter();

  @override
  DateTime fromJson(String json) => DateTime.parse(json).toLocal();

  @override
  String toJson(DateTime value) => formatOffsetDateTime(value);
}

String formatOffsetDateTime(DateTime value) {
  final whole = DateTime(
    value.year,
    value.month,
    value.day,
    value.hour,
    value.minute,
    value.second,
  );
  final base = whole.toIso8601String().substring(0, 19);
  if (value.isUtc) return '${base}Z';
  final offset = value.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final minutes = offset.inMinutes.abs();
  return '$base$sign${_two(minutes ~/ 60)}:${_two(minutes % 60)}';
}

String _two(int n) => n.toString().padLeft(2, '0');

/// `"HH:mm"` → minutes since midnight. `"24:00"` → 1440.
int parseHhMm(String value) {
  final parts = value.split(':');
  if (parts.length != 2) throw FormatException('Bad time "$value"');
  final h = int.parse(parts[0]);
  final m = int.parse(parts[1]);
  if (h < 0 || h > 24 || m < 0 || m > 59 || (h == 24 && m != 0)) {
    throw FormatException('Bad time "$value"');
  }
  return h * 60 + m;
}

/// Minutes since midnight → `"HH:mm"` (1440 → `"24:00"`).
String formatHhMm(int minutes) =>
    '${_two(minutes ~/ 60)}:${_two(minutes % 60)}';

/// Minutes since local midnight of [value].
int minuteOfDay(DateTime value) => value.hour * 60 + value.minute;
