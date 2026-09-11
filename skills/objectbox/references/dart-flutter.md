# ObjectBox — Dart / Flutter

Binding-specific guidance for ObjectBox in Dart/Flutter. It assumes the
binding-agnostic contract in [SKILL.md](../SKILL.md). For Sync Server setup see
[sync-server-setup.md](sync-server-setup.md).

## Start from a working example, not from prose

Follow "Start from an official example" in [SKILL.md](../SKILL.md): fetch an
official example, copy its structure, then apply this file's rules on top.
The files to fetch for Dart/Flutter:

- **Sync-enabled entity, store bootstrap, `SyncClient`, reactive query** —
  `tasks/client-flutter/lib/` in the sync examples:
  https://raw.githubusercontent.com/objectbox/objectbox-sync-examples/main/tasks/client-flutter/lib/model.dart
  https://raw.githubusercontent.com/objectbox/objectbox-sync-examples/main/tasks/client-flutter/lib/objectbox.dart
- **Relations: `ToOne`, `ToMany`, `@Backlink`** (no Sync) — the
  event-management tutorial in objectbox-dart:
  https://raw.githubusercontent.com/objectbox/objectbox-dart/main/objectbox/example/flutter/event_management_tutorial/many_to_many/lib/model.dart
- **Vector search, `@HnswIndex`** — the Dart-native cities example:
  https://raw.githubusercontent.com/objectbox/objectbox-dart/main/objectbox/example/dart-native/vectorsearch_cities/lib/model.dart

If you cannot fetch URLs, use the entity in
[Entity declaration](#entity-declaration), the relations in
[Relations](#relations) and the query in [Query lifecycle](#query-lifecycle) as
your starting shapes.

## Before you write code

1. **Check the installed version:** `flutter pub deps | grep objectbox`.
   Current release: https://pub.dev/packages/objectbox
2. **Run code generation after every entity change:**
   `dart run build_runner build`. Stale or missing `objectbox.g.dart` makes
   `flutter analyze` and `flutter test` fail in ways that look like ObjectBox bugs.
3. **Look up the API, don't recall it.** Any docs page can be fetched as Markdown
   by appending `.md` — e.g. `https://docs.objectbox.io/queries.md`.
   Generated API reference: https://pub.dev/documentation/objectbox/latest/

## Entity declaration

```dart
@Entity()
@Sync()
class Conversation {
  @Id() int id = 0;
  @Index() String userId = '';
  String title = '';
  @Property(type: PropertyType.date)     // explicit: the generator warns otherwise
  DateTime updatedAt = DateTime.now();   // stored as UTC millis, read back local

  Conversation({this.id = 0, this.userId = '', this.title = ''});
}
```

Two traps in that snippet, both silent:

- **`@Sync()` is class-level, never property-level.** On a `String`/`bool`/`int`
  field it either fails codegen or is silently ignored — the entity is then
  simply not synced and nothing tells you.
- **`DateTime` comes back with the zone flag of its type, not of the value you
  stored.** `PropertyType.date` returns local time, `PropertyType.dateUtc`
  returns UTC; the stored instant is the same either way. Match the type to how
  the app handles time, and compare with `isAtSameMomentAs`, never `==` — Dart's
  `==` also compares the zone flag. Details:
  https://docs.objectbox.io/property-types.md

## Relations

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
- To-many relations load lazily on first access, then cache. The cached list
  does not see relations added or removed elsewhere — re-read the owner from
  its box to refresh it. Dart's `ToMany` has no `reset()`; that is the Java
  API.

Reading, writing and adding follow the docs
(https://docs.objectbox.io/relations.md). The silent one:

```dart
conversation.messages.removeAt(0);                    // dissolves the relation
box.put(conversation);                                // does NOT delete the Message
```

## `attach()`

`ToOne` reads its target lazily from the database. An entity you built yourself
has no store, so `.target` cannot resolve.

```dart
message.conversation.attach(store);
```

- Entities returned from a `Box` are already attached — no call needed.
- If you construct an entity manually and hand it to callers who may read
  `.target`, attach first.
- `hasValue` tells you whether a target is set without triggering a read.

## Do not mirror a relation as a plain `int`

Sync remaps IDs, including relation IDs.
It does **not** remap a hand-maintained int field like e.g. `@Index() int conversationId = 0;`. 

Safe option: use only the `ToOne`, and query it via the generated property
(e.g. `Message_.conversation`).


## Cascade deletes are manual

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

## Avoid assignable IDs with Sync

Shared global IDs should be avoided in general;
they collide if 2 clients increment from the same base ID.
A valid use case would be IDs provided from an external system.

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

## Local-only entities in a sync store

Entities without `@Sync()` are local-only.

- Do not create relations across the sync/local boundary.
- **You cannot flip an existing entity to `@Sync()` in place.** Options: while
  still in development, add the annotation and wipe the databases; or assign
  the entity a new UID (keeping the name), which drops that type's existing
  data; or create a second, synced entity and migrate data in code. All are
  destructive for that type — back up first.

## Transient fields and enums

Objects are rebuilt on every read (contract [rule 2](../SKILL.md#2-modeling)).

- `@Transient()` marks a field that is not stored: after `box.get()` it is
  back at its initializer, whatever you set before `put()`.
- Enums persist through the docs pattern — an `int` getter/setter over a
  `@Transient()` enum field: https://docs.objectbox.io/advanced/custom-types.md
  The stored `int` is the enum index, so never reorder or remove values once
  shipped; append, and map out-of-range ids to `unknown`. Query on the
  generated property of the getter (`User_.dbRole`), not on the enum field.
- One enum per concept, in the data layer. A second copy in a widget is a
  second index mapping.

## Reactive streams — never poll

A query's `watch()` is the change signal. It subscribes to
`store.entityChanges` for the queried types and re-emits one `Query` instance
on every change; `triggerImmediately: true` emits it on listen too, so the
first frame has data. That is the whole bridge — do not hand-roll a
`StreamController` over `entityChanges` for it.

```dart
Stream<Conversation?> watchConversation(int id) => conversationBox
    .query(Conversation_.id.equals(id))
    .watch(triggerImmediately: true)
    .map((query) => query.findFirst());

Stream<List<Conversation>> watchConversations(String userId) =>
    conversationBox
        .query(Conversation_.userId.equals(userId))
        .order(Conversation_.updatedAt, flags: Order.descending)
        .watch(triggerImmediately: true)
        .map((query) => query.find());
```

Rules:
- Cancel the subscription when the widget or provider goes away.
- `cancel()` stops the events but does not close the emitted `Query`; it is
  held until garbage collection, which rarely matters.
- Expose the stream through your state layer's stream primitive (a
  `StreamProvider` in Riverpod). No invalidation after a mutation — the
  `put()` already triggers the next event.
- `store.entityChanges` (`Stream<List<Type>>`) fires for every entity type.
  Reach for it only when you need a signal without a query, and filter on
  `changedTypes.contains(...)`.

## Vector search (HNSW)

The entity shape is in the docs
(https://docs.objectbox.io/on-device-vector-search.md) and in the cities
example linked at the top of this file: `@HnswIndex(dimensions: ...,
distanceType: ...)` on a `@Property(type: PropertyType.floatVector)
List<double>?` field. The default distance is squared Euclidean — set
`VectorDistanceType.cosine` explicitly for sentence embeddings.

Query with the **Dart-specific** method name — it is *not* `nearestNeighbors`:

```dart
final query = chunkBox
    .query(Chunk_.embedding.nearestNeighborsF32(queryVector, maxCount))
    .build();
final results = query.findWithScores();
query.close();
// score is a DISTANCE — lower is better
```

Index design, filter over-fetching, stale detection, and how vectors interact
with Sync: [vector-search.md](vector-search.md).

## Query lifecycle

Closing, reuse and parameters are in the docs — "Close the query" and
"Reuse Queries and Parameters" in https://docs.objectbox.io/queries.md
The short-lived shape:

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

For a hot path build once and change parameters with `param(...).value`
instead of rebuilding. A query emitted by `watch()` is long-lived by
construction ([Reactive streams](#reactive-streams--never-poll)).

## Native library — sync vs. non-sync

The **sync-enabled** native library is a different artifact, not a flag.

- **Flutter app:** use `objectbox_sync_flutter_libs`, which bundles the
  sync-enabled library inside the built app.
- **CLI tools, servers, tests:** install the library into the process's
  working directory — `install.sh --sync` from the objectbox-dart repo puts it
  in `lib/`, which the binding checks before the system library paths.
- **Never commit `libobjectbox.dylib` / `.so` / `.dll` to git.** Add
  `lib/libobjectbox*` to `.gitignore`. It is a dev-time install.

### The `@Sync()` write constraint

**Both** library variants refuse writes to `@Sync()` types until sync has been
activated for the store:

```
Can not modify object of sync-enabled type "Conversation" because sync has
not been activated for this store. (OBX_ERROR code 10001)
```

- With the non-sync library nothing can activate it: `@Sync()` entities are
  read-only there. Any process that writes them needs the sync-enabled library.
- With the sync-enabled library, `SyncClient.start()` activates writes —
  constructing the client is not enough — and `close()` deactivates them
  again. The server does not have to be reachable.
- Read-only CLI tools should wrap bootstrap writes in try/catch.
- Tests start a client against an unreachable loopback port (see Testing).

## Sync client API (5.2.0+)

```dart
// Deprecated since 5.2.0 — recognise it, do not write it:
//   Sync.client(store, 'ws://host:port', SyncCredentials.none());

// Current:
final client = SyncClient(store, ['ws://host:port'], [SyncCredentials.none()]);
client.start();
```

Training data is full of the deprecated form. Check before you write it.

Rules:
- `Sync.isAvailable()` tells you whether the loaded native library is
  sync-enabled — check it first when debugging "sync has not been activated".
- **Do not start a SyncClient in app code when sync is disabled.** Check the
  enabled flag *before* constructing the client, and remember that `@Sync()`
  types are then read-only
  ([Native library](#native-library--sync-vs-non-sync)). A bogus URL plus
  `start()` is not a disabled mode — it is a live client that tries to connect.
  That trick is for tests only ([Testing](#testing)).
- Sync sends and receives automatically once started. Do not add a fetch loop.
- Use sync event listeners for UI status, not polling.
- `SyncCredentials.none()` pairs with a server started
  `--unsecured-no-authentication`, which is **loopback development only**. For
  anything else use the shared-secret credentials form and never commit the
  secret. See [sync-server-setup.md](sync-server-setup.md).

## Testing

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

### Case B — the test writes to `@Sync()` entities, no server needed

A real `SyncClient` in tests is fine.

Case A is not enough: writes to `@Sync()` types fail until a SyncClient has been
*started* ([Native library](#native-library--sync-vs-non-sync)). Install the
sync-enabled library for the test process and start a client against a loopback
port nothing listens on. It activates the write path, stays
`SyncState.disconnected`, and never replicates:

```dart
SyncClient? syncClient;
if (Sync.isAvailable()) {
  syncClient = SyncClient(
      store, ['ws://127.0.0.1:1'], [SyncCredentials.none()])
    ..start();
}
// ... run the tests ...
syncClient?.close();   // in tearDown, before store.close()
```

Constructing the client without `start()` does not activate writes, and
`close()` deactivates them again. Under the non-sync library these tests
cannot pass — skip them on `!Sync.isAvailable()`. There is no `SyncConfig`
class in the package; do not invent one.

### Case C — the test syncs against a real server

Each pitfall with the fix ObjectBox's own tests use:

- **Fixed ports collide** when suites run in parallel. Bind a free loopback
  port first (`ServerSocket.bind(InternetAddress.loopbackIPv4, 0)`, read the
  port, close the socket) and start the server with
  `--bind=ws://127.0.0.1:$port`.
- **Server data survives between runs.** Give the server its own
  `--db-directory` per test and delete it before start and after stop.
- **The server must know the current model.** Start it with
  `--model=<test project>/objectbox-model.json`; a stale model rejects the
  client ([Model file](#model-file)).
- **Sync is asynchronous.** Do not sleep and assert. Wait for
  `client.state() == SyncState.loggedIn`, or for `client.loginEvents.first`
  with a timeout, before the first assertion, and for `completionEvents`
  before asserting that data arrived. The event streams do not buffer:
  subscribe before `start()`.
- **Teardown order:** close the client, stop the server, then close and
  delete the store. A closed client cannot be restarted — make a new one.

Server setup and authentication: [sync-server-setup.md](sync-server-setup.md).

### All cases

- **Prefer one shared in-process store for the whole suite** — open once in a
  shared helper, reuse it, close it in teardown. No store should outlive its
  test, and no two live stores should overlap.
- Never share a store between test *groups* that assume a clean database.
- A green run of each test file *in isolation* does not prove the suite is safe.
  Run the full `flutter test` and confirm a clean, zero-exit teardown.

## macOS: the `ulimit` crash

libwebsockets, used internally by ObjectBox Sync, fails when `ulimit -n` is
`unlimited`, with `"problem getting process max files"`. Set a finite limit
before running anything that opens a sync store:

```bash
ulimit -n 4096   # before dart test, dart run, flutter test
```

## Model file

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
| `dateUtc` on a field written with local `DateTime.now()` (or vice versa) | the instant is stored fine, but the zone flag flips on read-back; `==` then fails | default `date` for local time, `dateUtc` for UTC; compare with `isAtSameMomentAs` |
| `ToOne<X>? x;` — nullable or non-final | the relation object always exists; the *target* is what may be null | `final x = ToOne<X>();` |
| `toMany.reset()` | Java API; Dart's `ToMany` has no `reset()` | re-read the owner from its box |
| Reading `.target` on a manually built entity | no store attached, cannot resolve | `x.attach(store)` first |
| Mirror `int` FK on a synced relation | Sync remaps relations, not mirrors | use `ToOne` |
| Expecting `removeAt()` to delete the target | it only dissolves the relationship | delete the target explicitly |
| Cascade delete without a transaction | partial deletes leave orphans | `store.runInTransaction(TxMode.write, ...)` |
| Adding `@Sync()` to an entity with data | unsupported migration | wipe server + clients, or model anew |
| `Sync.client(...)` | deprecated in 5.2.0+ | `SyncClient(store, [url], [credentials])` |
| SyncClient created while sync disabled | still attempts a TCP connection | check the flag first |
| Sync test on a fixed port, shared server data, or a sleep before asserting | port collisions, leftovers between runs, timing flakes | free loopback port, per-test `--db-directory`, wait on `state()` or `loginEvents` ([Testing](#testing)) |
| `--unsecured-no-authentication` beyond loopback | anyone on the network can read/write | shared secret, never committed |
| Writing `@Sync()` entities without a *started* SyncClient | "sync has not been activated for this store", under both library variants | sync-enabled library plus `SyncClient.start()` |
| `ulimit -n unlimited` on macOS | libwebsockets crashes | `ulimit -n 4096` |
| Committing `libobjectbox.dylib` | dev-time artifact in git | `.gitignore` it |
| Skipping `build_runner` after entity change | stale `objectbox.g.dart`; analyze/test fail | `dart run build_runner build` |
| `nearestNeighbors(...)` | that is the Java/Kotlin name | `nearestNeighborsF32(...)` |
| Treating score as similarity | score is a distance | invert before ranking |
| Rebuilding the same query on every call in a hot path | build cost on every call | build once, `param(...).value` before each run |
| Polling, or a hand-rolled `StreamController` over `entityChanges` | `watch()` already is that bridge | `box.query(...).watch(triggerImmediately: true)` |
| Not filtering `changedTypes` | fires on every entity type | `changedTypes.contains(MyEntity)` |
| State in a `@Transient()` field or a second enum copy | objects are rebuilt on every read; a second enum is a second index mapping | persisted property; one enum with a stable `int` mapping ([Transient fields and enums](#transient-fields-and-enums)) |
| Unused `objectbox` dependency in a package | native setup breaks fresh clones for zero benefit | remove it from `pubspec.yaml` |
| Sharing a test store across groups | cross-test pollution | one store per suite, or reset per group |
| Stale server model | clients rejected (`UNSUPPORTED_DATA_MODEL`) | give the server the new model file |
