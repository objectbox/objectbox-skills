import 'package:objectbox_skill_validation/entities.dart';
import 'package:objectbox_skill_validation/objectbox.g.dart';
import 'package:test/test.dart';

import 'test_store.dart';

void main() {
  late TestStore ts;
  setUp(() async => ts = await TestStore.open());
  tearDown(() => ts.dispose());

  group('Transient fields and enums transient fields and enums (contract rule 2)', () {
    test('every read returns a fresh instance', () {
      final box = ts.store.box<User>();
      final id = box.put(User(name: 'a'));
      final first = box.get(id)!;
      final second = box.get(id)!;
      expect(identical(first, second), isFalse);
      first.name = 'changed in memory only';
      expect(box.get(id)!.name, 'a');
    });

    test('a @Transient() field does not survive a re-read', () {
      final box = ts.store.box<User>();
      final id = box.put(User(name: 'a')..draft = 'unsaved');
      expect(box.get(id)!.draft, isNull);
    });

    test('enum round-trips through the int mapping, unknown ids map to unknown',
        () {
      final box = ts.store.box<User>();
      final id = box.put(User(name: 'a')..role = Role.admin);
      expect(box.get(id)!.role, Role.admin);

      final query = box.query(User_.dbRole.equals(Role.admin.index)).build();
      expect(query.count(), 1);
      query.close();

      expect((User()..dbRole = 99).role, Role.unknown);
    });
  });
}
