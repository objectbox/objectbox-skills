# ObjectBox — Dart / Flutter

Binding-specific guidance for ObjectBox in Dart/Flutter. It assumes the
binding-agnostic contract in [SKILL.md](../SKILL.md). For Sync Server setup see
[sync-server-setup.md](sync-server-setup.md).

## Start from a template, not from prose

Smaller models reliably copy-and-adapt concrete code but reconstruct annotations
badly from rules. When a template exists, start from it and change only field
names and types — keep every annotation exactly where it is. The structural
mistakes (annotations on the property instead of the class, nullable `ToOne?`,
missing cross-imports) are all prevented by sticking to a working example.

Until dedicated templates ship, use the entity in section 1 and the query in
section 11 as your starting shapes.

<!-- TODO(templates): once these exist in this repo, uncomment and link them.
     They were the single most effective measure against structural annotation
     errors in small models.

- **`example/templates/objectbox-entity-template.dart`** — a complete
  `@Entity()` + `@Sync()` class with `@Id`, `@Index`,
  `@Property(type: PropertyType.dateUtc)`, `ToOne`, `ToMany` + `@Backlink`,
  and a constructor.
- **`example/templates/objectbox-repository-template.dart`** — a complete
  repository with CRUD and QueryBuilder patterns (equals / order / range /
  relation), including `query.close()` handling.
-->

## Before you write code

1. **Check the installed version:** `flutter pub deps | grep objectbox`.
   Current release: https://pub.dev/packages/objectbox
2. **Run code generation after every entity change:**
   `dart run build_runner build`. Stale or missing `objectbox.g.dart` makes
   `flutter analyze` and `flutter test` fail in ways that look like ObjectBox bugs.
3. **Look up the API, don't recall it.** Any docs page can be fetched as Markdown
   by appending `.md` — e.g. `https://docs.objectbox.io/queries.md`.
   Generated API reference: https://pub.dev/documentation/objectbox/latest/

## 1. Entity declaration

```dart
@Entity()
@Sync()
class Conversation {
  @Id() int id = 0;
  @Index() String userId = '';
  String title = '';
  @Property(type: PropertyType.dateUtc) DateTime updatedAt = DateTime.now();

  Conversation({this.id = 0, this.userId = '', this.title = ''});
}
```

Two traps in that snippet, both silent:

- **`@Sync()` is class-level, never property-level.** On a `String`/`bool`/`int`
  field it either fails codegen or is silently ignored — the entity is then
  simply not synced and nothing tells you.
- **`DateTime` needs `@Property(type: PropertyType.dateUtc)` (5.1+).**
  `DateTime` is stored as milliseconds, but the older `date` / `dateNano`
  annotations do not handle UTC properly — values drift with the device
  timezone. Use `dateUtc` (or `dateNanoUtc` when you need nanoseconds) and
  avoid the old `date` and `dateNano` forms.

## 2. Relations

Dart declares relations as **`final` fields with no constructor arguments** —
unlike the JVM binding, there is no `this`/`Entity_` reference to pass:

```dart
@Entity()
class Message {
  @Id() int id = 0;
  String body = '';

  final conversation = ToOne<Conversation>();          // to-one
}

@Entity()
class Conversation {
  @Id() int id = 0;

  @Backlink('conversation')
  final messages = ToMany<Message>();                  // to-many backlink
}
```

Rules:
- Declare relation fields as **`final`** and **non-nullable**. `ToOne<X>? x;`
  is wrong — the relation object always exists; it is its *target* that may be null.
- `@Backlink('fieldName')` names the `ToOne` field on the other side. For
  many-to-many, `@Backlink()` without an argument.
- To-many relations resolve lazily on first access, then cache. The cache is
  not invalidated by changes made elsewhere — call `reset()` on the `ToMany`
  or re-read the source entity to see them.

Reading and writing:

```dart
final conv = message.conversation.target;             // read to-one
message.conversation.target = conversation;           // write to-one
box.put(message);

conversation.messages.add(Message());                 // write to-many
box.put(conversation);

conversation.messages.removeAt(0);                    // dissolves the relation
box.put(conversation);                                // does NOT delete the Message
```

## 3. `attach()`

`ToOne` reads its target lazily from the database. An entity you built yourself
has no store, so `.target` cannot resolve.

```dart
message.conversation.attach(store);
```

- Entities returned from a `Box` are already attached — no call needed.
- If you construct an entity manually and hand it to callers who may read
  `.target`, attach first.
- `hasValue` tells you whether a target is set without triggering a read.

## 4. Do not mirror a relation as a plain `int`

Sync remaps relation IDs. It does **not** remap a hand-maintained mirror field.

```dart
class Message {
  @Index() int conversationId = 0;      // manual mirror — risky under Sync
  final conversation = ToOne<Conversation>();
}
```

Safe options:
- **A:** use only the `ToOne`, and query it via the generated property
  (`Message_.conversation`).
- **B:** keep the plain `int` only if the parent uses
  `@Sync(sharedGlobalIds: true)` and you can guarantee uniqueness.

Querying the relation's own generated backing property is fine — that is not a
mirror. What is forbidden is a second, manually maintained field.

## 5. Cascade deletes are manual — and must be complete

ObjectBox does not cascade. Removing a to-many entry dissolves the relationship;
it does not delete the target. Orphans are silent.

```dart
bool deleteConversation(int conversationId) {
  return store.runInTransaction(TxMode.write, () {
    final conv = conversationBox.get(conversationId);
    if (conv == null) return false;

    messageBox.query(Message_.conversation.equals(conversationId)).build()
      ..remove()
      ..close();

    conversationBox.remove(conversationId);
    return true;
  });
}
```

- Wrap the cascade in `store.runInTransaction(TxMode.write, ...)`.
- Remove via the query — do not load-to-delete.
- Include **every** referencing entity type.
- `TxMode` has exactly two values: `TxMode.read` and `TxMode.write`.

## 6. Assignable IDs with Sync

```dart
@Entity()
@Sync(sharedGlobalIds: true)
class ManualDocument {
  @Id(assignable: true) int id = 0;
}
```

- `@Id(assignable: true)` alone is **not** enough — without
  `sharedGlobalIds: true` IDs may be remapped.
- `sharedGlobalIds` is immutable after first deployment.
- Only use it when global uniqueness across devices is guaranteed.
- Assignable IDs break new-vs-persisted detection: relation targets are no
  longer put automatically — put them explicitly, and attach the box before
  modifying relations.

## 7. Local-only entities in a sync store

Entities without `@Sync()` are local-only.

- Do not create relations across the sync/local boundary.
- A plain ID reference from a local entity to a synced one is only safe if the
  synced entity uses `sharedGlobalIds: true`.
- **You cannot flip an existing entity to `@Sync()` in place.** Options: while
  still in development, add the annotation and wipe the databases; or assign
  the entity a new UID (keeping the name), which drops that type's existing
  data; or create a second, synced entity and migrate data in code. All are
  destructive for that type — back up first.

## 8. Persisted state

- Do not overload fields (e.g. bumping a `version` field just to "touch" sync).
- If state must survive re-creation, give it a dedicated field.
- Do not define duplicate enums for the same concept — one canonical enum in the
  data layer, bridged to the UI, not a second copy inside a widget.

## 9. Reactive streams — never poll

Dart exposes store-level change notifications through
`store.entityChanges` (`Stream<List<Type>>`). Bridge it to a `Stream` rather
than polling:

```dart
Stream<Conversation?> watchConversation(int id) {
  late final StreamSubscription<List<Type>> subscription;
  late final StreamController<Conversation?> controller;

  void emit() {
    if (!controller.isClosed) {
      controller.add(conversationBox.get(id));
    }
  }

  controller = StreamController<Conversation?>(
    onListen: () {
      emit();                                   // current value immediately
      subscription = store.entityChanges.listen((changedTypes) {
        if (changedTypes.contains(Conversation)) emit();
      });
    },
    onCancel: () async => subscription.cancel(),
  );

  return controller.stream;
}
```

Rules:
- Check `!controller.isClosed` before adding — otherwise you throw after disposal.
- Cancel the subscription in `onCancel`.
- Filter `changedTypes` — `entityChanges` fires for every entity type.
- Emit immediately on listen, so the first frame has data.

For a filtered, ordered list rather than a single object, use the query's own
watch form instead of `entityChanges` — `.watch(triggerImmediately: true)`
emits the current value on listen, so you don't hand-roll that part.

### With Riverpod

```dart
final objectBoxProvider = Provider<ObjectBox>((ref) {
  throw UnimplementedError('Override in ProviderScope');
});

final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  return ConversationRepository(ref.watch(objectBoxProvider).store);
});

final conversationProvider = StreamProvider.family<Conversation?, int>((ref, id) {
  return ref.watch(conversationRepositoryProvider).watchConversation(id);
});
```

Invalidate after a mutation if the widget must re-read eagerly:
`ref.invalidate(conversationProvider(id));`

## 10. Vector search (HNSW)

```dart
@Entity()
class Chunk {
  @Id() int id = 0;
  String text = '';

  @HnswIndex(dimensions: 384, distanceType: VectorDistanceType.cosine)
  @Property(type: PropertyType.floatVector)
  List<double>? embedding;
}
```

Query with the **Dart-specific** method name — it is *not* `nearestNeighbors`:

```dart
final query = chunkBox
    .query(Chunk_.embedding.nearestNeighborsF32(queryVector, maxCount))
    .build();
final results = query.findWithScores();
query.close();
// score is a DISTANCE — lower is better
```

- Default distance is (squared) Euclidean; set cosine explicitly for sentence
  embeddings.

Index design, filter over-fetching, stale detection, and how vectors interact
with Sync: [vector-search.md](vector-search.md).

## 11. Query lifecycle

```dart
final query = conversationBox
    .query(Conversation_.userId.equals(userId))
    .order(Conversation_.updatedAt, flags: Order.descending)
    .build();
try {
  return query.find();
} finally {
  query.close();
}
```

- Always close queries. Unclosed queries leak in long-running processes.
- Cache and reuse long-lived queries only inside repository/data-access code.

## 12. Native library — sync vs. non-sync

The **sync-enabled** native library is a different artifact, not a flag. Writing
to a `@Sync()` entity with the non-sync library fails with
`"sync has not been activated"`.

- **Flutter app:** use `objectbox_sync_flutter_libs`, which bundles the
  sync-enabled library inside the built app.
- **CLI tools, servers, tests:** install the library explicitly and make sure it
  is on the load path for the process that needs it.
- **Never commit `libobjectbox.dylib` / `.so` / `.dll` to git.** Add
  `lib/libobjectbox*` to `.gitignore`. It is a dev-time install.

### The `@Sync()` write constraint

When the sync-enabled native library is loaded, **any `@Sync()` entity requires
an active SyncClient before `box.put()` will work.**

- The store must create a SyncClient *before* writing to `@Sync()` entities.
- Read-only CLI tools should wrap bootstrap writes in try/catch.
- Tests must open the store with a dummy sync config (see Testing).

## 13. Sync client API (5.2.0+)

```dart
// Deprecated:
final client = Sync.client(store, 'ws://host:port', SyncCredentials.none());

// Current:
final client = SyncClient(store, ['ws://host:port'], [SyncCredentials.none()]);
client.start();
```

Training data is full of the deprecated form. Check before you write it.

Rules:
- `Sync.isAvailable()` tells you whether the loaded native library is
  sync-enabled — check it first when debugging "sync has not been activated".
- **Do not create a SyncClient when sync is disabled.** Check the enabled flag
  *before* constructing the client. A bogus URL like `ws://127.0.0.1:65535` plus
  `start()` is wrong — it still attempts a TCP connection.
- Sync sends and receives automatically once started. Do not add a fetch loop.
- Use sync event listeners for UI status, not polling.
- `SyncCredentials.none()` pairs with a server started
  `--unsecured-no-authentication`, which is **loopback development only**. For
  anything else use the shared-secret credentials form and never commit the
  secret. See [sync-server-setup.md](sync-server-setup.md).

## 14. Testing

**Never open a real SyncClient in tests.** It is nondeterministic — connection
races, port collisions — and hostile to CI.

### Case A — the test does not touch `@Sync()` entities

Open a plain store in a temp directory and delete it in teardown:

```dart
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
  return TestStoreHandle._(await openStore(directory: dir.path), dir);
}
```

```dart
late TestStoreHandle handle;
setUp(()    async => handle = await openTestStore());
tearDown(() async => handle.dispose());
```

### Case B — the test writes to `@Sync()` entities

Case A is not enough: with the sync-enabled native library loaded, a `@Sync()`
entity needs an active sync write path. Use a reserved port so the write bit
activates without any connection:

```dart
SyncConfig(
  enabled: true,
  serverUri: 'ws://127.0.0.1:0',   // port 0 — kernel never assigns a listener
  tls: false,
)
```

The store activates its `@Sync()` write path but never replicates and holds no
native connection to tear down.

### Both cases

- **Prefer one shared in-process store for the whole suite** — open once in a
  shared helper, reuse it, close it in teardown. No store should outlive its
  test, and no two live stores should overlap.
- Never share a store between test *groups* that assume a clean database.
- A green run of each test file *in isolation* does not prove the suite is safe.
  Run the full `flutter test` and confirm a clean, zero-exit teardown.

## 15. macOS: the `ulimit` crash

libwebsockets, used internally by ObjectBox Sync, fails when `ulimit -n` is
`unlimited`, with `"problem getting process max files"`. Set a finite limit
before running anything that opens a sync store:

```bash
ulimit -n 4096   # before dart test, dart run, flutter test
```

## 16. Model file

`lib/objectbox-model.json` carries stable UIDs that Sync depends on.

- Commit it. Never delete or regenerate it to fix an error.
- After any schema change: run `dart run build_runner build`, then follow
  [sync-server-setup.md](sync-server-setup.md)
  to update the server. A stale server model rejects clients with
  `UNSUPPORTED_DATA_MODEL` (error 57) or fails with schema errors like
  `"Relations not allowed"`.

## Quick reference — common mistakes

| Mistake | Why it breaks | Fix |
|---|---|---|
| `@Sync()` on a property | class-level annotation; silently not synced | move it to the class |
| `DateTime` with old `date`/`dateNano` annotations | broken UTC handling, timezone drift | `@Property(type: PropertyType.dateUtc)` (5.1+) |
| `ToOne<X>? x;` — nullable or non-final | the relation object always exists; the *target* is what may be null | `final x = ToOne<X>();` |
| Reading `.target` on a manually built entity | no store attached, cannot resolve | `x.attach(store)` first |
| Mirror `int` FK on a synced relation | Sync remaps relations, not mirrors | use `ToOne` or `sharedGlobalIds: true` |
| Expecting `removeAt()` to delete the target | it only dissolves the relationship | delete the target explicitly |
| Cascade delete without a transaction | partial deletes leave orphans | `store.runInTransaction(TxMode.write, ...)` |
| `@Id(assignable: true)` without `sharedGlobalIds: true` | IDs get remapped under Sync | set both |
| Adding `@Sync()` to an entity with data | unsupported migration | wipe server + clients, or model anew |
| `Sync.client(...)` | deprecated in 5.2.0+ | `SyncClient(store, [url], [credentials])` |
| SyncClient created while sync disabled | still attempts a TCP connection | check the flag first |
| Real SyncClient in tests | nondeterministic, CI-hostile | `ws://127.0.0.1:0` dummy config |
| `--unsecured-no-authentication` beyond loopback | anyone on the network can read/write | shared secret, never committed |
| Non-sync native lib + `@Sync()` entities | writes fail: "sync has not been activated" | install the sync-enabled library |
| `ulimit -n unlimited` on macOS | libwebsockets crashes | `ulimit -n 4096` |
| Committing `libobjectbox.dylib` | dev-time artifact in git | `.gitignore` it |
| Skipping `build_runner` after entity change | stale `objectbox.g.dart`; analyze/test fail | `dart run build_runner build` |
| `nearestNeighbors(...)` | that is the Java/Kotlin name | `nearestNeighborsF32(...)` |
| Treating score as similarity | score is a distance | invert before ranking |
| Unclosed query | leaks in long-running processes | `query.close()` in a `finally` |
| Polling instead of `store.entityChanges` | duplicates ObjectBox reactivity | bridge `entityChanges` to a Stream |
| Adding to a closed StreamController | throws after widget disposal | check `!controller.isClosed` |
| Not filtering `changedTypes` | fires on every entity type | `changedTypes.contains(MyEntity)` |
| Duplicate enums for sync status | UI and data layer drift apart | one canonical enum, bridge it |
| Unused `objectbox` dependency in a package | native setup breaks fresh clones for zero benefit | remove it from `pubspec.yaml` |
| Sharing a test store across groups | cross-test pollution | one store per suite, or reset per group |
| Stale server model | clients rejected (`UNSUPPORTED_DATA_MODEL`) | give the server the new model file |
