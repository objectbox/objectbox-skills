# Coverage — dart-flutter.md

One row per row of the "Quick reference — common mistakes" table in
`skills/objectbox/references/dart-flutter.md`, verbatim in the first column
(`tool/check_coverage.dart` fails when the two drift). Verified against
`objectbox` **5.3.2** on Linux x64, 2026-09-08.

The Upstream column cites objectbox-dart tests as `objectbox_test/test/<file>::<exact test name>`;
`../check_upstream.py` resolves every such locator at the pinned tag and can run or diff them.
A locator is only written after reading the test body; a grep hit is a candidate, not evidence.

Status values: `verified <version>` (a local test, an upstream test or the analyzer proves it),
`partial` (the recipe is proven, the failure mode is not), `unverified`
(nobody has run it — treat the skill text as a hypothesis), `manual` (evidence
is a docs page or issue, linked in the check column), `opinion` (an
architecture rule, not falsifiable), `n/a` (not an ObjectBox claim).

| Mistake | Type | Check (local) | Upstream (objectbox-dart) | Status |
|---|---|---|---|---|
| `@Sync()` on a property | behavior | unverified — needs a negative codegen fixture: put `@Sync()` on a property, run build_runner, record whether it errors or is ignored | — | unverified |
| `dateUtc` on a field written with local `DateTime.now()` (or vice versa) | behavior | `test/date_test.dart`: `==` fails on the zone flag alone | `objectbox_test/test/box_test.dart::DateTime field` — asserts `isUtc` per type and identical millis for local and UTC input | verified 5.3.2 |
| `ToOne<X>? x;` — nullable or non-final | API | snippet check compiles the correct form; the wrong form is not exercised | — | partial |
| `toMany.reset()` | API | pub.dev API reference, `ToMany` 5.3.2 has no `reset()`; the snippet check would flag it | — | verified 5.3.2 |
| Reading `.target` on a manually built entity | behavior | — | `objectbox_test/test/relations_test.dart::put` — asserts "ToOne relation field not initialized. Make sure attach(store) is called before using this." | verified 5.3.2 |
| Mirror `int` FK on a synced relation | behavior (Sync) | unverified — needs a Sync Server and two clients | — | unverified |
| Expecting `removeAt()` to delete the target | behavior | `test/relations_test.dart`: target still in its box after put | `objectbox_test/test/relations_test.dart::removal` asserts list bookkeeping only (weaker), so the local test stays | verified 5.3.2 |
| Cascade delete without a transaction | behavior | `test/relations_test.dart`: the recipe deletes only that tree; the orphan claim without a transaction is not exercised | `objectbox_test/test/query_test.dart::.remove deletes the right items` — the remove part | partial |
| Adding `@Sync()` to an entity with data | behavior (Sync) | unverified — docs claim, sync.objectbox.io | — | unverified |
| `Sync.client(...)` | version | CHANGELOG 5.2.0: "SyncClient: add a constructor, deprecate `Sync.client` and related helper methods"; the analyzer reports DEPRECATED_MEMBER_USE | — | verified 5.3.2 |
| SyncClient created while sync disabled | behavior | `test/sync_test.dart`: a started client stays `SyncState.disconnected`; the TCP attempt itself is not observed | `objectbox_test/test/sync_test.dart::SyncClient states (no server available)` | partial |
| Sync test on a fixed port, shared server data, or a sleep before asserting | ops | mirrors objectbox-dart `objectbox_test/test/sync_test.dart` (free port via `ServerSocket.bind(..., 0)`, per-port `--db-directory`, `loginEvents.first.timeout`); not run here, needs a `sync-server` binary | — | manual |
| `--unsecured-no-authentication` beyond loopback | ops | sync-server-setup.md, sync.objectbox.io | — | manual |
| Writing `@Sync()` entities without a *started* SyncClient | behavior | `test/sync_test.dart` under both library variants | pending: added on branch `added-tests` as `sync-enabled entity writes require a started client`; cite once released | verified 5.3.2 |
| `ulimit -n unlimited` on macOS | environment | unverified — needs a macOS runner | — | unverified |
| Committing `libobjectbox.dylib` | opinion | — | — | opinion |
| Skipping `build_runner` after entity change | process | — | — | opinion |
| `nearestNeighbors(...)` | API | snippet check | `objectbox_test/test/hnsw_test.dart::query` — uses `nearestNeighborsF32` | verified 5.3.2 |
| Treating score as similarity | behavior | — | `objectbox_test/test/hnsw_test.dart::query` — scores 0.25, 1.25, 3.25 ascending for squared distances 0.25, 1.25, 3.25 | verified 5.3.2 |
| Rebuilding the same query on every call in a hot path | API + behavior | — | `objectbox_test/test/query_test.dart::set param single` | verified 5.3.2 |
| Polling, or a hand-rolled `StreamController` over `entityChanges` | API + behavior | snippet check | `objectbox_test/test/stream_test.dart::trigger immediately`; `objectbox_test/test/stream_test.dart::can use query after subscription is canceled` | verified 5.3.2 |
| Not filtering `changedTypes` | behavior | — | `objectbox_test/test/observer_test.dart::Observe multiple entities` — asserts one entry per changed type | verified 5.3.2 |
| State in a `@Transient()` field or a second enum copy | behavior | `test/persisted_state_test.dart`: fresh instance per read, enum int mapping and `User_.dbRole` query | `objectbox_test/test/query_test.dart::ignore transient field` — transient value is null after read | verified 5.3.2 |
| Unused `objectbox` dependency in a package | opinion | — | — | opinion |
| Sharing a test store across groups | opinion | — | — | opinion |
| Stale server model | behavior (Sync) | unverified — needs a Sync Server; error name from sync.objectbox.io | — | unverified |

## Verified claims outside the table

| Claim | Evidence |
|---|---|
| Entity declaration: `date` truncates to milliseconds, `dateNano` keeps microseconds; the stored instant is identical for local and UTC input | `objectbox_test/test/box_test.dart::DateTime field` |
| Relations: a loaded `ToMany` does not see relations added elsewhere until the owner is re-read | `test/relations_test.dart`; pending upstream on branch `added-tests` |
| contract rule 2: objects are rebuilt on every read (`identical` is false; in-memory edits vanish) | `test/persisted_state_test.dart` |
| Query lifecycle: a closed query throws `StateError`; an unclosed one is closed by a `NativeFinalizer` on GC | `objectbox_test/test/query_test.dart::use after close throws`; objectbox-dart `query.dart` |
| Reactive streams: the `Query` emitted by `watch()` stays open after `cancel()`; events only for the queried types | `objectbox_test/test/stream_test.dart::can use query after subscription is canceled`; `objectbox_test/test/stream_test.dart::Only observers of a single entity are notified, no cross-entity observer notification` |
| Vector search: the default HNSW distance is squared Euclidean | `objectbox_test/test/hnsw_test.dart::query` (fixture `@HnswIndex(dimensions: 2)` without a distance type) |
| Native library: the binding loads `lib/libobjectbox.*` from the working directory before system paths | objectbox-dart `bindings.dart`; observed: `./lib` variant wins over `/usr/lib` |
| Native library: `SyncClient.start()` activates `@Sync()` writes, construction does not, `close()` deactivates | `test/sync_test.dart`; pending upstream on branch `added-tests` |
| Testing: `await openStore(...)` | in a Flutter package `openStore` returns a `Future`; in this Dart-native package it is synchronous, so the snippet check reports `await_only_futures` as an info |

## Known gaps

- Every `unverified` Sync row needs a Sync Server in the loop. The
  `server-docker` setup in objectbox-sync-examples is the candidate.
- The property-level `@Sync()` codegen claim needs a negative fixture package.
- macOS-only claims need a macOS runner.
