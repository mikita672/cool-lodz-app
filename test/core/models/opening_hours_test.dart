import 'package:cool_lodz/core/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 2026-07-13 is a Monday.
  DateTime at(int day, int hour, [int minute = 0]) =>
      DateTime(2026, 7, day, hour, minute);

  final ec1 = OpeningHours.fromJson({
    'mon': [],
    'tue': [
      ['10:00', '18:00'],
    ],
    'wed': [
      ['10:00', '14:00'],
      ['15:00', '18:00'],
    ],
    'thu': [
      ['10:00', '18:00'],
    ],
    'fri': [
      ['10:00', '20:00'],
    ],
    'sat': [
      ['10:00', '20:00'],
    ],
    // sun missing → closed
  });

  test('open inside an interval, end is exclusive', () {
    expect(ec1.isOpenAt(at(14, 10)), isTrue);
    expect(ec1.isOpenAt(at(14, 17, 59)), isTrue);
    expect(ec1.isOpenAt(at(14, 18)), isFalse);
    expect(ec1.closingTime(at(14, 12)), at(14, 18));
  });

  test('before opening: next opening is the same day', () {
    expect(ec1.isOpenAt(at(14, 9, 30)), isFalse);
    expect(ec1.nextOpening(at(14, 9, 30)), at(14, 10));
    expect(ec1.closingTime(at(14, 9, 30)), isNull);
  });

  test('after closing: next opening is the next open day', () {
    expect(ec1.isOpenAt(at(14, 19)), isFalse);
    expect(ec1.nextOpening(at(14, 19)), at(15, 10));
  });

  test('break between two intervals', () {
    expect(ec1.isOpenAt(at(15, 14, 30)), isFalse);
    expect(ec1.nextOpening(at(15, 14, 30)), at(15, 15));
  });

  test('closed day ([] or missing) skips to the next open day', () {
    expect(ec1.isOpenAt(at(13, 12)), isFalse); // Monday []
    expect(ec1.nextOpening(at(13, 12)), at(14, 10));
    expect(ec1.isOpenAt(at(19, 12)), isFalse); // Sunday missing
    expect(ec1.nextOpening(at(19, 12)), at(21, 10)); // Mon closed → Tue
    expect(ec1.nextOpening(at(18, 21)), at(21, 10)); // Sat evening
  });

  test('open now → nextOpening is null', () {
    expect(ec1.nextOpening(at(14, 11)), isNull);
  });

  test('never opens → null', () {
    final closed = OpeningHours.fromJson({});
    expect(closed.isOpenAt(at(14, 12)), isFalse);
    expect(closed.nextOpening(at(14, 12)), isNull);
  });

  test('interval past midnight and 24:00', () {
    final late = OpeningHours.fromJson({
      'fri': [
        ['20:00', '02:00'],
      ],
      'sat': [
        ['00:00', '24:00'],
      ],
    });
    expect(late.isOpenAt(at(17, 23)), isTrue); // Fri
    expect(late.closingTime(at(17, 23)), at(18, 2));
    expect(late.isOpenAt(at(18, 23, 59)), isTrue); // Sat all day
    expect(late.isOpenAt(at(19, 0, 30)), isFalse); // Sun
    expect(late.toJson()['fri'], [
      ['20:00', '02:00'],
    ]);
    expect(late.toJson()['sat'], [
      ['00:00', '24:00'],
    ]);
  });

  test('null hours on Place = always open', () {
    const place = Place(id: 'p', type: PlaceType.cool, lat: 0, lon: 0);
    expect(place.isOpenAt(at(13, 3)), isTrue);
    expect(place.nextOpening(at(13, 3)), isNull);
  });

  test('bad time is rejected', () {
    expect(
      () => OpeningHours.fromJson({
        'mon': [
          ['25:00', '26:00'],
        ],
      }),
      throwsFormatException,
    );
  });
}
