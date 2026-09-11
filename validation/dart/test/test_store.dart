import 'dart:io';

import 'package:objectbox/objectbox.dart';
import 'package:objectbox_skill_validation/objectbox.g.dart';

/// One throw-away store per test, deleted on dispose (skill: Testing).
///
/// With the sync-enabled native library loaded, a started SyncClient against
/// an unreachable loopback port activates writes to @Sync() types (case B).
class TestStore {
  final Store store;
  final Directory dir;
  final SyncClient? syncClient;
  TestStore._(this.store, this.dir, this.syncClient);

  static Future<TestStore> open({bool activateSync = true}) async {
    final dir = Directory.systemTemp.createTempSync('obx_skill_');
    final store = await openStore(directory: dir.path);
    SyncClient? syncClient;
    if (activateSync && Sync.isAvailable()) {
      syncClient = SyncClient(
          store, ['ws://127.0.0.1:1'], [SyncCredentials.none()])
        ..start();
    }
    return TestStore._(store, dir, syncClient);
  }

  void dispose() {
    syncClient?.close();
    store.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}

/// `skip:` value for tests that write @Sync() entities.
final String? needsSyncLib = Sync.isAvailable()
    ? null
    : 'writes @Sync() entities: needs the sync-enabled native library';
