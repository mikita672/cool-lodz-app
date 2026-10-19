/// Europe/Warsaw time without a timezone database.
///
/// EU rule: CEST (+02:00) from the last Sunday of March 01:00 UTC to the last
/// Sunday of October 01:00 UTC, CET (+01:00) otherwise.
library;

const _cet = Duration(hours: 1);
const _cest = Duration(hours: 2);

/// UTC offset of Europe/Warsaw at the instant [instant].
Duration warsawUtcOffset(DateTime instant) {
  final utc = instant.toUtc();
  final start = _lastSundayUtc(utc.year, DateTime.march);
  final end = _lastSundayUtc(utc.year, DateTime.october);
  return !utc.isBefore(start) && utc.isBefore(end) ? _cest : _cet;
}

/// 01:00 UTC on the last Sunday of [month].
DateTime _lastSundayUtc(int year, int month) {
  final last = DateTime.utc(year, month + 1, 0); // day 0 = last of [month]
  final back = last.weekday % DateTime.sunday; // Sunday → 0
  return DateTime.utc(year, month, last.day - back, 1);
}

/// The instant (in UTC) of Warsaw wall-clock time [y]-[m]-[d] [h]:[min]:[s].
///
/// In the autumn overlap the earlier (CEST) instant wins; a time inside the
/// spring gap is read as CET.
DateTime warsawWallClockToUtc(
  int y,
  int m,
  int d, [
  int h = 0,
  int min = 0,
  int s = 0,
]) {
  final wall = DateTime.utc(y, m, d, h, min, s);
  for (final offset in const [_cest, _cet]) {
    final utc = wall.subtract(offset);
    if (warsawUtcOffset(utc) == offset) return utc;
  }
  return wall.subtract(_cet);
}

final _naive = RegExp(
  r'^(\d{4})-(\d{1,2})-(\d{1,2})(?:[T ](\d{1,2}):(\d{2})(?::(\d{2})(?:[.,]\d+)?)?)?$',
);

/// Warsaw wall-clock time of [instant], as a UTC-flagged [DateTime] whose
/// fields (year … minute) read like a clock in Łódź.
DateTime warsawWallClock(DateTime instant) =>
    instant.toUtc().add(warsawUtcOffset(instant));

/// Minutes since midnight in Łódź (route `"HH:mm"` slots are Warsaw time).
int warsawMinuteOfDay(DateTime instant) {
  final wall = warsawWallClock(instant);
  return wall.hour * 60 + wall.minute;
}

/// Parses `2026-07-15 10:00:00`, `2026-07-15T10:00`, `2026-07-15` as Warsaw
/// wall-clock time; strings with `Z` or an offset keep their own zone.
/// Returns a UTC [DateTime], or null when [value] is not a timestamp.
DateTime? parseWarsawTime(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  if (text.isEmpty) return null;
  final match = _naive.firstMatch(text);
  if (match != null) {
    int part(int i) => int.parse(match.group(i) ?? '0');
    return warsawWallClockToUtc(
      part(1),
      part(2),
      part(3),
      part(4),
      part(5),
      part(6),
    );
  }
  return DateTime.tryParse(text.replaceFirst(' ', 'T'))?.toUtc();
}
