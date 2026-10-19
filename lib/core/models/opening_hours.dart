import 'date_time_converter.dart';

/// Contract day keys; index + 1 == [DateTime.weekday].
const weekdayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

/// One opening interval in minutes since midnight. [end] > [start]; an
/// interval past midnight (`["22:00", "02:00"]`) has [end] > 1440.
class TimeInterval {
  const TimeInterval(this.start, this.end) : assert(end > start);

  factory TimeInterval.fromJson(List<dynamic> json) {
    if (json.length != 2) throw FormatException('Bad interval $json');
    final start = parseHhMm(json[0] as String);
    var end = parseHhMm(json[1] as String);
    if (end <= start) end += 1440;
    return TimeInterval(start, end);
  }

  final int start;
  final int end;

  List<String> toJson() => [
    formatHhMm(start),
    formatHhMm(end > 1440 ? end - 1440 : end),
  ];

  @override
  bool operator ==(Object other) =>
      other is TimeInterval && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => '${toJson()}';
}

/// Summer opening hours by weekday. A day with no intervals (or missing from
/// the JSON) is closed. A place whose `hours` is null is always open — that
/// is handled by `Place`, not here.
///
/// All methods take device local time (Europe/Warsaw).
class OpeningHours {
  OpeningHours(Map<int, List<TimeInterval>> byWeekday)
    : _byWeekday = {
        for (var d = DateTime.monday; d <= DateTime.sunday; d++)
          d: List.unmodifiable(
            [...?byWeekday[d]]..sort((a, b) => a.start.compareTo(b.start)),
          ),
      };

  factory OpeningHours.fromJson(Map<String, dynamic> json) => OpeningHours({
    for (var i = 0; i < weekdayKeys.length; i++)
      i + 1: [
        for (final interval in (json[weekdayKeys[i]] as List<dynamic>?) ?? [])
          TimeInterval.fromJson(interval as List<dynamic>),
      ],
  });

  final Map<int, List<TimeInterval>> _byWeekday;

  /// Intervals for [weekday] (`DateTime.monday`..`DateTime.sunday`).
  List<TimeInterval> on(int weekday) => _byWeekday[weekday]!;

  bool isOpenAt(DateTime local) => closingTime(local) != null;

  /// When the current opening interval ends; null if closed at [local].
  DateTime? closingTime(DateTime local) {
    final minute = minuteOfDay(local);
    final today = _midnight(local);
    for (final i in on(local.weekday)) {
      if (minute >= i.start && minute < i.end) return _at(today, i.end);
    }
    // Intervals from yesterday that run past midnight.
    final yesterday = local.weekday == DateTime.monday
        ? DateTime.sunday
        : local.weekday - 1;
    for (final i in on(yesterday)) {
      if (i.end > 1440 && minute < i.end - 1440) {
        return _at(today, i.end - 1440);
      }
    }
    return null;
  }

  /// Next moment the place opens after [local]; null if it is open at
  /// [local] or never opens.
  DateTime? nextOpening(DateTime local) {
    if (isOpenAt(local)) return null;
    final today = _midnight(local);
    for (var offset = 0; offset <= 7; offset++) {
      final day = DateTime(today.year, today.month, today.day + offset);
      for (final i in on(day.weekday)) {
        final start = _at(day, i.start);
        if (start.isAfter(local)) return start;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    for (var i = 0; i < weekdayKeys.length; i++)
      weekdayKeys[i]: [for (final interval in on(i + 1)) interval.toJson()],
  };

  static DateTime _midnight(DateTime t) => DateTime(t.year, t.month, t.day);

  static DateTime _at(DateTime midnight, int minutes) =>
      DateTime(midnight.year, midnight.month, midnight.day, 0, minutes);
}
