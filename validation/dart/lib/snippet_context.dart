/// Free variables that the prose snippets in dart-flutter.md use without
/// declaring them. This library is only analyzed, never executed.
library;

import 'dart:io';

import 'entities.dart';
import 'objectbox.g.dart';

late Store store;
late Box box; // Box<dynamic>: the snippets put different entity types into it
late Box<Conversation> conversationBox;
late Box<Message> messageBox;
late Box<Chunk> chunkBox;
late Conversation conversation;
late Message message;
late String userId;
late int conversationId;
late int id;
late List<double> queryVector;
late int maxCount;

// The Testing section declares these in its first block and uses them in the second.
// Each block becomes its own file, so the second block resolves them here.
class TestStoreHandle {
  final Store store;
  final Directory _dir;
  TestStoreHandle._(this.store, this._dir);

  Future<void> dispose() async {
    store.close();
    if (_dir.existsSync()) _dir.deleteSync(recursive: true);
  }
}

Future<TestStoreHandle> openTestStore() async {
  final dir = Directory.systemTemp.createTempSync('obx_test_');
  // The skill's snippet targets Flutter, where openStore() returns a Future.
  // ignore: await_only_futures
  return TestStoreHandle._(await openStore(directory: dir.path), dir);
}
