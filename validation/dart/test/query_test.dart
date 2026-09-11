import 'package:objectbox/objectbox.dart';
import 'package:objectbox_skill_validation/entities.dart';
import 'package:objectbox_skill_validation/objectbox.g.dart';
import 'package:test/test.dart';

import 'test_store.dart';

void main() {
  late TestStore ts;
  setUp(() async => ts = await TestStore.open());
  tearDown(() => ts.dispose());

  group('Query lifecycle query lifecycle', skip: needsSyncLib, () {
    test('build, find with order, close', () {
      final box = ts.store.box<Conversation>();
      box.putMany([
        Conversation(userId: 'u', title: 'old')..updatedAt = DateTime(2020),
        Conversation(userId: 'u', title: 'new')..updatedAt = DateTime(2025),
        Conversation(userId: 'other', title: 'x'),
      ]);
      final query = box
          .query(Conversation_.userId.equals('u'))
          .order(Conversation_.updatedAt, flags: Order.descending)
          .build();
      try {
        expect(query.find().map((c) => c.title), ['new', 'old']);
      } finally {
        query.close();
      }
    });
  });

  group('Query lifecycle long-lived queries', skip: needsSyncLib, () {
    test('param().value re-runs a built query with new values', () {
      final box = ts.store.box<Conversation>();
      box.putMany([
        Conversation(userId: 'a'),
        Conversation(userId: 'a'),
        Conversation(userId: 'b'),
      ]);
      final byUser = box.query(Conversation_.userId.equals('')).build();
      expect((byUser..param(Conversation_.userId).value = 'a').find().length, 2);
      expect((byUser..param(Conversation_.userId).value = 'b').find().length, 1);
      byUser.close();
    });

    test('using a closed query throws StateError', () {
      final query = ts.store.box<Conversation>().query().build();
      query.close();
      expect(query.find, throwsStateError);
    });
  });

  group('Vector search (HNSW) vector search', () {
    test('default HNSW distance is squared Euclidean, scores ascend', () {
      final box = ts.store.box<ChunkDefault>();
      box.putMany([
        ChunkDefault(embedding: [3, 0, 0]),
        ChunkDefault(embedding: [0, 0, 0]),
        ChunkDefault(embedding: [1, 0, 0]),
      ]);
      final query = box
          .query(ChunkDefault_.embedding.nearestNeighborsF32([0, 0, 0], 3))
          .build();
      final scores = query.findWithScores().map((r) => r.score).toList();
      query.close();
      expect(scores, [0.0, 1.0, 9.0]);
    });

    test('cosine: score is a distance (1 - similarity), lower is better', () {
      final box = ts.store.box<Chunk>();
      box.putMany([
        Chunk(text: 'orthogonal', embedding: [0, 1, 0]),
        Chunk(text: 'same', embedding: [1, 0, 0]),
        Chunk(text: 'scaled', embedding: [2, 0, 0]),
      ]);
      final query = box
          .query(Chunk_.embedding.nearestNeighborsF32([1, 0, 0], 3))
          .build();
      final results = query.findWithScores();
      query.close();
      expect(results.map((r) => r.object.text).toList(),
          containsAllInOrder(['orthogonal']));
      expect(results[0].score, closeTo(0, 1e-6));
      expect(results[1].score, closeTo(0, 1e-6));
      expect(results[2].object.text, 'orthogonal');
      expect(results[2].score, closeTo(1, 1e-6));
    });
  });

  group('Reactive streams entityChanges', skip: needsSyncLib, () {
    test('watch(triggerImmediately: true): emits now, per change of the queried '
        'type only, and cancel() leaves the query open', () async {
      final box = ts.store.box<Conversation>();
      final id = box.put(Conversation(title: 'v1'));
      final seen = <String?>[];
      Query<Conversation>? last;
      final sub = box
          .query(Conversation_.id.equals(id))
          .watch(triggerImmediately: true)
          .listen((q) {
        last = q;
        seen.add(q.findFirst()?.title);
      });
      await Future<void>.delayed(const Duration(milliseconds: 100));
      box.put(box.get(id)!..title = 'v2');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      ts.store.box<Chunk>().put(Chunk(embedding: [0, 0, 0])); // other type
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await sub.cancel();
      expect(seen, ['v1', 'v2']);
      expect(last!.findFirst()!.title, 'v2',
          reason: 'the emitted query is still open after cancel()');
      last!.close();
    });

    test('emits only the entity types that changed', () async {
      final events = <List<Type>>[];
      final sub = ts.store.entityChanges.listen(events.add);
      ts.store.box<Conversation>().put(Conversation());
      await Future<void>.delayed(const Duration(milliseconds: 100));
      ts.store.box<Chunk>().put(Chunk(embedding: [0, 0, 0]));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await sub.cancel();
      expect(events, [
        [Conversation],
        [Chunk],
      ]);
    });
  });
}
