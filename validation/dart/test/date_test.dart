import 'package:objectbox/objectbox.dart';
import 'package:objectbox_skill_validation/entities.dart';
import 'package:test/test.dart';

import 'test_store.dart';

// The read-back zone flags themselves are asserted upstream
// (objectbox_test/test/box_test.dart::DateTime field). This keeps only the
// consequence the skill warns about.
void main() {
  late TestStore ts;
  setUp(() async => ts = await TestStore.open());
  tearDown(() => ts.dispose());

  test('Entity declaration: local value into dateUtc, == fails on the zone flag alone', () {
    final box = ts.store.box<DateEntity>();
    final local = DateTime(2026, 9, 8, 12, 30, 15, 250); // millisecond-exact
    final read = box.get(box.put(DateEntity()..dateUtc = local))!;
    expect(read.dateUtc!.isUtc, isTrue);
    expect(read.dateUtc == local, isFalse);
    expect(read.dateUtc!.isAtSameMomentAs(local), isTrue);
  });
}
