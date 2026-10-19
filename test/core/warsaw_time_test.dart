import 'package:cool_lodz/core/warsaw_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('warsawUtcOffset', () {
    test('2026: CEST from 29 March 01:00 UTC to 25 October 01:00 UTC', () {
      Duration at(DateTime utc) => warsawUtcOffset(utc);
      expect(at(DateTime.utc(2026, 3, 29, 0, 59, 59)).inHours, 1);
      expect(at(DateTime.utc(2026, 3, 29, 1)).inHours, 2);
      expect(at(DateTime.utc(2026, 7, 15, 12)).inHours, 2);
      expect(at(DateTime.utc(2026, 10, 25, 0, 59, 59)).inHours, 2);
      expect(at(DateTime.utc(2026, 10, 25, 1)).inHours, 1);
      expect(at(DateTime.utc(2026, 1, 10)).inHours, 1);
      expect(at(DateTime.utc(2026, 12, 31, 23)).inHours, 1);
    });

    test('other years: last Sundays of March and October', () {
      // 2027: 28 March, 31 October.
      expect(warsawUtcOffset(DateTime.utc(2027, 3, 28, 0, 59)).inHours, 1);
      expect(warsawUtcOffset(DateTime.utc(2027, 3, 28, 1)).inHours, 2);
      expect(warsawUtcOffset(DateTime.utc(2027, 10, 31, 0, 59)).inHours, 2);
      expect(warsawUtcOffset(DateTime.utc(2027, 10, 31, 1)).inHours, 1);
    });
  });

  group('parseWarsawTime', () {
    test('summer and winter wall-clock time', () {
      expect(
        parseWarsawTime('2026-07-15 10:00:00'),
        DateTime.utc(2026, 7, 15, 8),
      );
      expect(parseWarsawTime('2026-07-15T10:00'), DateTime.utc(2026, 7, 15, 8));
      expect(
        parseWarsawTime('2026-01-10 12:20:13'),
        DateTime.utc(2026, 1, 10, 11, 20, 13),
      );
      expect(parseWarsawTime('2026-01-10'), DateTime.utc(2026, 1, 9, 23));
      expect(
        parseWarsawTime('2026-07-15 10:00:00.000'),
        DateTime.utc(2026, 7, 15, 8),
      );
    });

    test('spring forward on 2026-03-29', () {
      expect(
        parseWarsawTime('2026-03-29 01:59:00'),
        DateTime.utc(2026, 3, 29, 0, 59),
      );
      expect(
        parseWarsawTime('2026-03-29 03:00:00'),
        DateTime.utc(2026, 3, 29, 1),
      );
      // 02:30 does not exist: read as CET.
      expect(
        parseWarsawTime('2026-03-29 02:30'),
        DateTime.utc(2026, 3, 29, 1, 30),
      );
    });

    test('fall back on 2026-10-25', () {
      expect(
        parseWarsawTime('2026-10-25 01:30'),
        DateTime.utc(2026, 10, 24, 23, 30),
      );
      // 02:30 happens twice: the CEST one first.
      expect(
        parseWarsawTime('2026-10-25 02:30'),
        DateTime.utc(2026, 10, 25, 0, 30),
      );
      expect(
        parseWarsawTime('2026-10-25 03:00'),
        DateTime.utc(2026, 10, 25, 2),
      );
    });

    test('explicit offsets are kept', () {
      expect(
        parseWarsawTime('2026-07-15T10:00:00+02:00'),
        DateTime.utc(2026, 7, 15, 8),
      );
      expect(
        parseWarsawTime('2026-07-15 10:00:00Z'),
        DateTime.utc(2026, 7, 15, 10),
      );
    });

    test('not a timestamp → null', () {
      expect(parseWarsawTime(null), isNull);
      expect(parseWarsawTime(''), isNull);
      expect(parseWarsawTime('jutro'), isNull);
      expect(parseWarsawTime(1752566400), isNull);
    });

    test('results are UTC', () {
      expect(parseWarsawTime('2026-07-15 10:00')!.isUtc, isTrue);
    });
  });
}
