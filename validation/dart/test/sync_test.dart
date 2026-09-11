import 'package:objectbox/objectbox.dart';
import 'package:objectbox_skill_validation/entities.dart';
import 'package:test/test.dart';

import 'test_store.dart';

// Runs under whichever native library ./run.sh installed.
void main() {
  late TestStore ts;
  setUp(() async => ts = await TestStore.open(activateSync: false));
  tearDown(() => ts.dispose());

  final syncLib = Sync.isAvailable();
  final notActivated = throwsA(predicate((e) =>
      e.toString().contains('sync has not been activated for this store')));

  group('Native library write constraint (${syncLib ? 'sync' : 'non-sync'} library)', () {
    test('report which library is loaded', () {
      // ignore: avoid_print
      print('Native library Sync.isAvailable() == $syncLib');
    });

    test('writing a @Sync() entity with no client fails', () {
      expect(() => ts.store.box<Conversation>().put(Conversation()),
          notActivated);
    });

    test('entities without @Sync() are unaffected', () {
      final id = ts.store.box<Chunk>().put(Chunk(embedding: [0, 0, 0]));
      expect(ts.store.box<Chunk>().get(id), isNotNull);
    });

    test('a constructed but not started client does not activate writes',
        skip: syncLib ? null : 'needs the sync-enabled library', () {
      final client = SyncClient(
          ts.store, ['ws://127.0.0.1:1'], [SyncCredentials.none()]);
      expect(() => ts.store.box<Conversation>().put(Conversation()),
          notActivated);
      client.close();
    });

    test('start() against an unreachable port activates writes; close() ends it',
        skip: syncLib ? null : 'needs the sync-enabled library', () async {
      final client = SyncClient(
          ts.store, ['ws://127.0.0.1:1'], [SyncCredentials.none()])
        ..start();
      final id = ts.store.box<Conversation>().put(Conversation(title: 'c'));
      expect(ts.store.box<Conversation>().get(id)!.title, 'c');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(client.state(), SyncState.disconnected);
      client.close();
      expect(() => ts.store.box<Conversation>().put(Conversation()),
          notActivated);
    });
  });
}
