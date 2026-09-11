import 'package:objectbox/objectbox.dart';
import 'package:objectbox_skill_validation/entities.dart';
import 'package:objectbox_skill_validation/objectbox.g.dart';
import 'package:test/test.dart';

import 'test_store.dart';

void main() {
  late TestStore ts;
  late Store store;
  late Box<Conversation> convBox;
  late Box<Message> msgBox;
  setUp(() async {
    ts = await TestStore.open();
    store = ts.store;
    convBox = store.box<Conversation>();
    msgBox = store.box<Message>();
  });
  tearDown(() => ts.dispose());

  group('Relations relations', skip: needsSyncLib, () {
    test('to-one write and read through .target', () {
      final conv = Conversation(title: 'c');
      final msg = Message(body: 'm')..conversation.target = conv;
      msgBox.put(msg); // puts the new target too
      expect(conv.id, isNonZero);
      expect(msgBox.get(msg.id)!.conversation.target!.title, 'c');
    });

    test('adding to a backlink ToMany and putting the owner puts the target',
        () {
      final conv = Conversation()..messages.add(Message(body: 'm'));
      convBox.put(conv);
      expect(msgBox.count(), 1);
      expect(msgBox.getAll().single.conversation.targetId, conv.id);
    });

    test('removeAt dissolves the relation but does not delete the target', () {
      final conv = Conversation()..messages.add(Message(body: 'm'));
      convBox.put(conv);
      final loaded = convBox.get(conv.id)!;
      loaded.messages.removeAt(0);
      convBox.put(loaded);
      expect(msgBox.count(), 1, reason: 'target still exists');
      expect(msgBox.getAll().single.conversation.targetId, 0,
          reason: 'relation dissolved');
      expect(convBox.get(conv.id)!.messages, isEmpty);
    });

    test('a loaded ToMany does not see relations added elsewhere until re-read',
        () {
      final conv = Conversation();
      convBox.put(conv);
      final loaded = convBox.get(conv.id)!;
      expect(loaded.messages, isEmpty); // triggers the lazy load

      msgBox.put(Message(body: 'later')..conversation.target = loaded);

      expect(loaded.messages, isEmpty, reason: 'cached list is stale');
      expect(convBox.get(conv.id)!.messages.length, 1,
          reason: 're-reading the owner sees the new relation');
    });
  });

  group('`attach()` attach', skip: needsSyncLib, () {
    test('.target on a manually built entity needs attach(store)', () {
      final conv = Conversation(title: 'c');
      convBox.put(conv);

      final msg = Message()..conversation.targetId = conv.id;
      Object? error;
      try {
        msg.conversation.target;
      } catch (e) {
        error = e;
      }
      expect(error, isNotNull,
          reason: 'reading .target without a store should fail');
      // ignore: avoid_print
      print('`attach()` detached .target error: $error');

      msg.conversation.attach(store);
      expect(msg.conversation.target!.title, 'c');
      expect(msg.conversation.hasValue, isTrue);
    });

    test('entities returned from a Box are attached', () {
      final conv = Conversation(title: 'c');
      msgBox.put(Message()..conversation.target = conv);
      expect(msgBox.getAll().single.conversation.target!.title, 'c');
    });
  });

  group('Cascade deletes cascade delete', skip: needsSyncLib, () {
    bool deleteConversation(int conversationId) {
      return store.runInTransaction(TxMode.write, () {
        final conv = convBox.get(conversationId);
        if (conv == null) return false;
        msgBox.query(Message_.conversation.equals(conversationId)).build()
          ..remove()
          ..close();
        convBox.remove(conversationId);
        return true;
      });
    }

    test('query-based remove inside a transaction deletes only that tree', () {
      final a = Conversation()
        ..messages.addAll([Message(body: 'a1'), Message(body: 'a2')]);
      final b = Conversation()..messages.add(Message(body: 'b1'));
      convBox.putMany([a, b]);
      expect(msgBox.count(), 3);

      expect(deleteConversation(a.id), isTrue);
      expect(convBox.get(a.id), isNull);
      expect(msgBox.count(), 1);
      expect(msgBox.getAll().single.body, 'b1');
      expect(deleteConversation(a.id), isFalse);
    });
  });
}
