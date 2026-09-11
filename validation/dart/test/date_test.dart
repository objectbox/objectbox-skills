import 'package:objectbox/objectbox.dart';
import 'package:objectbox_skill_validation/entities.dart';
import 'package:test/test.dart';

import 'test_store.dart';

void main() {
  late TestStore ts;
  late Box<DateEntity> box;
  setUp(() async {
    ts = await TestStore.open();
    box = ts.store.box<DateEntity>();
  });
  tearDown(() => ts.dispose());

  DateEntity roundTrip(DateEntity e) => box.get(box.put(e))!;

  // Millisecond-exact and local: only the zone flag can differ on read-back.
  final local = DateTime(2026, 9, 8, 12, 30, 15, 250);

  group('Entity declaration DateTime', () {
    test('default type (no annotation) reads back local, same instant', () {
      final r = roundTrip(DateEntity()
        ..plain = local
        ..date = local);
      expect(r.plain!.isUtc, isFalse);
      expect(r.date!.isUtc, isFalse);
      expect(r.plain!.isAtSameMomentAs(local), isTrue);
      // Same zone flag and millisecond precision: == holds.
      expect(r.plain, equals(local));
      expect(r.date, equals(local));
    });

    test('dateUtc reads back UTC, same instant', () {
      final r = roundTrip(DateEntity()..dateUtc = local);
      expect(r.dateUtc!.isUtc, isTrue);
      expect(r.dateUtc!.isAtSameMomentAs(local), isTrue);
    });

    test('local value into dateUtc: == fails on the zone flag alone', () {
      final r = roundTrip(DateEntity()..dateUtc = local);
      expect(r.dateUtc == local, isFalse);
      expect(r.dateUtc!.isAtSameMomentAs(local), isTrue);
    });

    test('UTC value into the default type: reads back local, == fails', () {
      final utc = local.toUtc();
      final r = roundTrip(DateEntity()..date = utc);
      expect(r.date!.isUtc, isFalse);
      expect(r.date == utc, isFalse);
      expect(r.date!.isAtSameMomentAs(utc), isTrue);
    });

    test('no drift: the stored instant is the same for local and UTC input',
        () {
      final r = roundTrip(DateEntity()
        ..date = local
        ..dateUtc = local.toUtc());
      expect(r.date!.millisecondsSinceEpoch, local.millisecondsSinceEpoch);
      expect(r.dateUtc!.millisecondsSinceEpoch, local.millisecondsSinceEpoch);
    });

    test('date truncates to milliseconds, dateNano keeps microseconds', () {
      final micro = DateTime(2026, 9, 8, 12, 30, 15, 250, 500);
      final r = roundTrip(DateEntity()
        ..date = micro
        ..dateNano = micro
        ..dateNanoUtc = micro);
      expect(r.date!.microsecond, 0);
      expect(r.date == micro, isFalse);
      expect(r.dateNano!.microsecond, 500);
      expect(r.dateNano, equals(micro));
      expect(r.dateNanoUtc!.isUtc, isTrue);
      expect(r.dateNanoUtc!.isAtSameMomentAs(micro), isTrue);
    });
  });
}
