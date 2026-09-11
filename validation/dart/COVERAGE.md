# Coverage — dart-flutter.md

One row per row of the "Quick reference — common mistakes" table in
`skills/objectbox/references/dart-flutter.md`, verbatim in the first column
(`tool/check_coverage.dart` fails when the two drift). Verified against
`objectbox` **5.3.2** on Linux x64, 2026-09-08.

Status values: `verified <version>` (a test or the analyzer proves it),
`partial` (the recipe is proven, the failure mode is not), `unverified`
(nobody has run it — treat the skill text as a hypothesis), `manual` (evidence
is a docs page or issue, linked in the check column), `opinion` (an
architecture rule, not falsifiable), `n/a` (not an ObjectBox claim).

| Mistake | Type | Check | Status |
|---|---|---|---|
| `@Sync()` on a property | behavior | unverified — needs a negative codegen fixture: put `@Sync()` on a property, run build_runner, record whether it errors or is ignored | unverified |
| `dateUtc` on a field written with local `DateTime.now()` (or vice versa) | behavior | `test/date_test.dart` Entity declaration | verified 5.3.2 |
| `ToOne<X>? x;` — nullable or non-final | API | snippet check compiles the correct form; the wrong form is not exercised | partial |
| `toMany.reset()` | API | pub.dev API reference, `ToMany` 5.3.2 has no `reset()`; the snippet check would flag it | verified 5.3.2 |
| Reading `.target` on a manually built entity | behavior | `test/relations_test.dart` `attach()` — error: "ToOne relation field not initialized. Make sure attach(store) is called before using this." | verified 5.3.2 |
| Mirror `int` FK on a synced relation | behavior (Sync) | unverified — needs a Sync Server and two clients | unverified |
| Expecting `removeAt()` to delete the target | behavior | `test/relations_test.dart` Relations | verified 5.3.2 |
| Cascade delete without a transaction | behavior | `test/relations_test.dart` Cascade deletes runs the recipe; the orphan claim without a transaction is not exercised | partial |
| Adding `@Sync()` to an entity with data | behavior (Sync) | unverified — docs claim, sync.objectbox.io | unverified |
| `Sync.client(...)` | version | CHANGELOG 5.2.0: "SyncClient: add a constructor, deprecate `Sync.client` and related helper methods"; the analyzer reports DEPRECATED_MEMBER_USE | verified 5.3.2 |
| SyncClient created while sync disabled | behavior | `test/sync_test.dart` shows a started client stays `SyncState.disconnected`; the TCP attempt itself is not observed | partial |
| Sync test on a fixed port, shared server data, or a sleep before asserting | ops | mirrors objectbox-dart `objectbox_test/test/sync_test.dart` (free port via `ServerSocket.bind(..., 0)`, per-port `--db-directory`, `loginEvents.first.timeout`); not run here, needs a `sync-server` binary | manual |
| `--unsecured-no-authentication` beyond loopback | ops | sync-server-setup.md, sync.objectbox.io | manual |
| Writing `@Sync()` entities without a *started* SyncClient | behavior | `test/sync_test.dart` under both library variants | verified 5.3.2 |
| `ulimit -n unlimited` on macOS | environment | unverified — needs a macOS runner | unverified |
| Committing `libobjectbox.dylib` | opinion | — | opinion |
| Skipping `build_runner` after entity change | process | — | opinion |
| `nearestNeighbors(...)` | API | snippet check; `test/query_test.dart` Vector search (HNSW) | verified 5.3.2 |
| Treating score as similarity | behavior | `test/query_test.dart` Vector search (HNSW): scores ascend; default distance is squared Euclidean, cosine is 1 − similarity | verified 5.3.2 |
| Rebuilding the same query on every call in a hot path | API + behavior | `test/query_test.dart` Query lifecycle: `param(...).value` re-runs a built query with new values | verified 5.3.2 |
| Polling, or a hand-rolled `StreamController` over `entityChanges` | API + behavior | snippet check; `test/query_test.dart` Reactive streams: `watch(triggerImmediately: true)` emits on listen and per change, only for the queried types | verified 5.3.2 |
| Not filtering `changedTypes` | behavior | `test/query_test.dart` Reactive streams — one entity type per event | verified 5.3.2 |
| State in a `@Transient()` field or a second enum copy | behavior | `test/persisted_state_test.dart` Transient fields and enums: fresh instance per read, transient field reset, enum int mapping and `User_.dbRole` query | verified 5.3.2 |
| Unused `objectbox` dependency in a package | opinion | — | opinion |
| Sharing a test store across groups | opinion | — | opinion |
| Stale server model | behavior (Sync) | unverified — needs a Sync Server; error name from sync.objectbox.io | unverified |

## Verified claims outside the table

| Claim (section) | Check |
|---|---|
| Entity declaration `date` truncates to milliseconds; `dateNano` / `dateNanoUtc` keep microseconds | `test/date_test.dart` |
| Entity declaration the stored instant is identical for local and UTC input (no drift) | `test/date_test.dart` |
| Relations adding to a `@Backlink` `ToMany` and putting the owner puts the target | `test/relations_test.dart` |
| Relations a loaded `ToMany` does not see relations added elsewhere until re-read | `test/relations_test.dart` |
| `attach()` entities returned from a Box are attached | `test/relations_test.dart` |
| contract rule 2 objects are rebuilt on every read (`identical` is false; in-memory edits vanish) | `test/persisted_state_test.dart` |
| Query lifecycle a closed query throws `StateError`; an unclosed one is closed by a `NativeFinalizer` on GC | `test/query_test.dart`, objectbox-dart `query.dart` |
| Reactive streams the `Query` emitted by `watch()` stays open after `cancel()` | `test/query_test.dart`, objectbox-dart `builder.dart` |
| Vector search (HNSW) default HNSW distance is squared Euclidean (scores 0, 1, 9 for distances 0, 1, 3) | `test/query_test.dart` |
| Query lifecycle `query.find()` honours `order(..., flags: Order.descending)` | `test/query_test.dart` |
| Native library the binding loads `lib/libobjectbox.*` from the working directory before system paths | objectbox-dart `bindings.dart` source; observed: `./lib` variant wins over `/usr/lib` |
| Native library `SyncClient.start()` activates `@Sync()` writes, construction does not, `close()` deactivates | `test/sync_test.dart` |
| Testing `await openStore(...)` | in a Flutter package `openStore` returns a `Future`; in this Dart-native package it is synchronous, so the snippet check reports `await_only_futures` as an info |

## Known gaps

- Every `unverified` Sync row needs a Sync Server in the loop. The
  `server-docker` setup in objectbox-sync-examples is the candidate.
- The property-level `@Sync()` codegen claim needs a negative fixture package.
- macOS-only claims need a macOS runner.
