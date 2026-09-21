# Coverage — dart-flutter.md

One row per row of the "Quick reference — common mistakes" table in
`skills/objectbox/references/dart-flutter.md`, verbatim in the first column
(`tool/check_coverage.dart` fails when the two drift). Verified against
`objectbox` **5.3.2** on Linux x64, 2026-09-08; rows added 2026-09-17 after the skill
evaluation (objectbox-skills-eval, recipes app, twelve runs) were verified the same day.

The Upstream column cites objectbox-dart tests as `objectbox_test/test/<file>::<exact test name>`;
`../check_upstream.py` resolves every such locator at the pinned tag and diffs them on pin bumps.
A locator is only written after reading the test body; a grep hit is a candidate, not evidence.

Status values: `verified <version>` (a local test, an upstream test or the analyzer proves it),
`partial` (the recipe is proven, the failure mode is not), `unverified`
(nobody has run it — treat the skill text as a hypothesis), `pending upstream`
(asserted by a test on an objectbox-dart branch that is not in a tagged release
yet; becomes a locator once the pin contains it), `manual` (evidence is a docs
page or issue, linked in the check column), `opinion` (an architecture rule,
not falsifiable), `n/a` (not an ObjectBox claim).

| Mistake | Type | Other evidence | Upstream (objectbox-dart) | Status |
|---|---|---|---|---|
| `@Sync()` on a property | behavior | unverified — needs a negative codegen fixture: put `@Sync()` on a property, run build_runner, record whether it errors or is ignored | — | unverified |
| `dateUtc` on a field written with local `DateTime.now()` (or vice versa) | behavior | Dart `==` on `DateTime` compares the zone flag (dart:core `DateTime.==` docs) | `objectbox_test/test/box_test.dart::DateTime field` — asserts `isUtc` per type and identical millis for local and UTC input | verified 5.3.2 |
| `ToOne<X>? x;` — nullable or non-final | API | snippet check compiles the correct form; the wrong form is not exercised | — | partial |
| `toMany.reset()` | API | pub.dev API reference, `ToMany` 5.3.2 has no `reset()`; the snippet check would flag it | — | verified 5.3.2 |
| Reading `.target` on a manually built entity | behavior | — | `objectbox_test/test/relations_test.dart::put` — asserts "ToOne relation field not initialized. Make sure attach(store) is called before using this." | verified 5.3.2 |
| Mirror `int` FK on a synced relation | behavior (Sync) | unverified — needs a Sync Server and two clients | — | unverified |
| Expecting `removeAt()` to delete the target | behavior | relations.md: "Optional: also remove the order entity" | `objectbox_test/test/relations_test.dart::removal` asserts list bookkeeping only; pending: `removing from a ToMany does not remove the target` on branch `added-tests` | pending upstream |
| Cascade delete without a transaction | behavior | the recipe is app code over `runInTransaction`, `query.remove()` and `box.remove()` | `objectbox_test/test/query_test.dart::.remove deletes the right items` | partial |
| Adding `@Sync()` to an entity with data | behavior (Sync) | unverified — docs claim, sync.objectbox.io | — | unverified |
| `Sync.client(...)` | version | CHANGELOG 5.2.0: "SyncClient: add a constructor, deprecate `Sync.client` and related helper methods"; the analyzer reports DEPRECATED_MEMBER_USE | — | verified 5.3.2 |
| SyncClient created while sync disabled | behavior | — | `objectbox_test/test/sync_test.dart::SyncClient states (no server available)` | partial |
| Sync test on a fixed port, shared server data, or a sleep before asserting | ops | mirrors objectbox-dart `objectbox_test/test/sync_test.dart` (free port via `ServerSocket.bind(..., 0)`, per-port `--db-directory`, `loginEvents.first.timeout`); not run here, needs a `sync-server` binary | — | manual |
| `--unsecured-no-authentication` beyond loopback | ops | sync-server-setup.md, sync.objectbox.io | — | manual |
| Writing `@Sync()` entities without a *started* SyncClient | behavior | error text observed under both library variants | pending: `sync-enabled entity writes require a started client` and `put of sync-enabled entity fails without sync` on branch `added-tests` | pending upstream |
| `ulimit -n unlimited` on macOS | environment | unverified — needs a macOS runner | — | unverified |
| Committing `libobjectbox.dylib` | opinion | — | — | opinion |
| `flutter test` without `lib/libobjectbox.*`, or with an old system copy | environment | objectbox-dart 5.3.2 `bindings.dart`: `lib/<libName>` under `Directory.current` is opened first, then (macOS) `/usr/local/lib`, then `DynamicLibrary.open(libName)`; the "not compatible: is ... expected ... or newer" and "Failed to load ObjectBox library" texts are in the same file; both observed in the eval runs with a 5.0.0 copy in `/usr/lib` | — | manual |
| `install.sh` from `main` | version | objectbox-dart `install.sh`: `cLibVersion=6.0.0-beta` on `main` vs `cLibVersion=5.3.2` at tag `v5.3.2` (checked 2026-09-17); the script's header comment warns that a version mismatch is not reported; docs' getting-started page fetches `main` | — | manual |
| Committing the `download/` directory | opinion | objectbox-c `download.sh` extracts into `download/`; one eval run committed it | — | opinion |
| Dropping `objectbox_flutter_libs` because tests use `lib/` | environment | `bindings.dart` load failure text: "For Flutter apps, check if objectbox_flutter_libs is added to dependencies. For unit tests and Dart apps, check if the ObjectBox library was downloaded"; one eval run dropped the package | — | manual |
| Skipping `build_runner` after entity change | process | — | — | opinion |
| `nearestNeighbors(...)` | API | snippet check | `objectbox_test/test/hnsw_test.dart::query` — uses `nearestNeighborsF32` | verified 5.3.2 |
| Treating score as similarity | behavior | — | `objectbox_test/test/hnsw_test.dart::query` — scores 0.25, 1.25, 3.25 ascending for squared distances 0.25, 1.25, 3.25 | verified 5.3.2 |
| Rebuilding the same query on every call in a hot path | API + behavior | — | `objectbox_test/test/query_test.dart::set param single` | verified 5.3.2 |
| Rebuilding the nearest-neighbor query per lookup because "vectors take no parameter" | API | `params.dart` 5.3.2: `nearestNeighborsF32(List<double> queryVector, int maxResultCount)` on `QueryParam`; snippet check compiles the call | `objectbox_test/test/hnsw_test.dart::query` — `query.param(HnswObject_.floatVector).nearestNeighborsF32(searchVector, 3)` then asserts the new result set | verified 5.3.2 |
| `param()` on a `List<String>` condition | API | `params.dart` 5.3.2 has `QueryParam` extensions for `String`, `List<int>`, `int`, `double`, `bool` only; "The setter 'value' isn't defined for the type 'QueryParam<List<String>>'" observed in an eval run | — | verified 5.3.2 |
| `store.query(...)`, `store.put(...)`, `store.runInTx(...)`, `box.find(...)` | API | analyzer errors observed in five eval runs ("The method 'query' isn't defined for the type 'Store'", "'runInTx'", "'put'", "The method 'find' isn't defined for the type 'Box'"); snippet check compiles the correct forms | — | verified 5.3.2 |
| `box.query(c).find()` | API | "The method 'find' isn't defined for the type 'QueryBuilder'" observed in two eval runs; snippet check compiles `build()` first | — | verified 5.3.2 |
| `box.query().linkMany(...).build()` | API | "The method 'build' isn't defined for the type '_QueryBuilder'" observed in an eval run; `builder.dart` 5.3.2: `linkMany` returns `_QueryBuilder<TargetEntityT>`, `build()` is on `QueryBuilder<T>` | `objectbox_test/test/relations_test.dart::query link` — keeps the source builder, calls `linkMany` on it, then `build()` | verified 5.3.2 |
| Join entity with two `int` id fields instead of a `ToMany` | opinion + API | link queries need a relation (`QueryRelationToMany` argument); three eval runs built join entities and loaded whole boxes for every set query | `objectbox_test/test/relations_test.dart::query link` | opinion |
| Relying on `ToMany` insertion order | behavior | ad-hoc run against 5.3.2 on 2026-09-17 (not kept in this repo): targets added as c, a, b (ids 3, 1, 2) read back a, b, c on the owning side, and the backlink side is id-ordered too; upstream `relations_test.dart` asserts to-many contents with `unorderedEquals` only; three eval runs hit it | — | verified 5.3.2 (ad hoc); upstream test pending |
| Re-putting a fresh instance to replace its `ToMany` targets | behavior | relations.md "Updating ToMany": the list tracks changes to objects; a fresh instance has tracked additions only | `objectbox_test/test/relations_test.dart::don't load old data when just adding` — adds on an unloaded relation (`itemsLoaded` false), puts, and the read-back holds the old items plus the new ones | verified 5.3.2 |
| A hash of the natural key as `@Id(assignable: true)` | API + opinion | entity-annotations.md "If you need to use another type for IDs (such as a string UID given by a server), model them as regular properties and use queries to look up objects by your application-specific ID", with `@Unique` and `findUnique()`; contract rule 3 (no silent replace on root identity); one eval run hashed every natural key into an assignable id | — | manual |
| Query-or-create that opens a write transaction on every call | behavior | transactions.md: "Read(-only) transactions never get blocked or block a write transaction", "There can only be a single write transaction at any time; they run strictly one after the other", "read transactions are cheap ... there is no commit and thus no expensive sync to the file system" | — | manual |
| Filter or lookup property without `@Index()` | opinion | entity-annotations.md: `@Index()` "or alternatively use @Unique()" for lookups; the unindexed `ingredientCount` filter was the M2 fail or soft spot in four eval runs | — | opinion |
| One transaction per object, or one for a whole import | opinion + behavior | transactions.md: "Committing a transaction involves syncing data to physical storage, which is a relatively expensive operation"; the batch size is the spec's and the docs' bulk-put advice, not a measured optimum; one eval run parsed the whole file into memory to run a single transaction | — | manual |
| Ranking a filtered subset in Dart while the index serves the unfiltered case | API + opinion | snippet check compiles the `&` form; one eval run did the filtered case with a cosine loop | `objectbox_test/test/hnsw_test.dart::filtered search name` — `nearestNeighborsF32(...).and(HnswObject_.name.startsWith("Apple"))` and the other string conditions | verified 5.3.2 (recipe) |
| Empty list for a lookup from an item without a vector | opinion | contract rule 9; three eval runs returned `const []` for both "no vector" and "unknown id" | — | opinion |
| `getAll()` or a whole-box `find()` to diff ids on import | API + opinion | queries.md "Retrieve IDs / Count": `findIds()` and `count()` "avoid creating objects and are therefore faster than find()"; `Box.getMany` returns `List<T?>` (`box.dart` 5.3.2) | — | manual |
| Polling, or a hand-rolled `StreamController` over `entityChanges` | API + behavior | snippet check | `objectbox_test/test/stream_test.dart::trigger immediately`; `objectbox_test/test/stream_test.dart::can use query after subscription is canceled` | verified 5.3.2 |
| Not filtering `changedTypes` | behavior | — | `objectbox_test/test/observer_test.dart::Observe multiple entities` — asserts one entry per changed type | verified 5.3.2 |
| State in a `@Transient()` field or a second enum copy | behavior | — | `objectbox_test/test/query_test.dart::ignore transient field`; pending: `get returns a new instance each time`, `enum via int getter and setter` on branch `added-tests` | verified 5.3.2 (transient); rest pending upstream |
| Unused `objectbox` dependency in a package | opinion | — | — | opinion |
| Sharing a test store across groups | opinion | — | — | opinion |
| Stale server model | behavior (Sync) | unverified — needs a Sync Server; error name from sync.objectbox.io | — | unverified |

## Verified claims outside the table

| Claim | Evidence |
|---|---|
| Entity declaration: `date` truncates to milliseconds, `dateNano` keeps microseconds; the stored instant is identical for local and UTC input | `objectbox_test/test/box_test.dart::DateTime field` |
| Relations: a loaded `ToMany` does not see relations added elsewhere until the owner is re-read | pending upstream: `loaded backlink is cached until the owner is read again` on branch `added-tests` |
| contract rule 2: objects are rebuilt on every read (`identical` is false; in-memory edits vanish) | pending upstream: `get returns a new instance each time` on branch `added-tests` |
| Query lifecycle: a closed query throws `StateError`; an unclosed one is closed by a `NativeFinalizer` on GC | `objectbox_test/test/query_test.dart::use after close throws`; objectbox-dart `query.dart` |
| Reactive streams: the `Query` emitted by `watch()` stays open after `cancel()`; events only for the queried types | `objectbox_test/test/stream_test.dart::can use query after subscription is canceled`; `objectbox_test/test/stream_test.dart::Only observers of a single entity are notified, no cross-entity observer notification` |
| Vector search: the default HNSW distance is squared Euclidean | `objectbox_test/test/hnsw_test.dart::query` (fixture `@HnswIndex(dimensions: 2)` without a distance type) |
| Native library: the binding loads `lib/libobjectbox.*` from the working directory before system paths | objectbox-dart `bindings.dart`; observed: `./lib` variant wins over `/usr/lib` |
| Before you write code: the generated `openStore()` returns `Future<Store>` in a Flutter project and `Store` in a pure Dart package | objectbox_generator 5.3.2 `code_chunks.dart`: `obxFlutter ? 'Future<Store>' : 'Store'` |
| Link queries: several `link()`/`linkMany()` calls on one builder AND together | ad-hoc run against 5.3.2 on 2026-09-17 (not kept): `linkMany(name == 'a')` plus `linkMany(name == 'zzz')` matches nothing, `'a'` plus `'b'` matches both objects that carry both; upstream `query_test.dart::set param on links` builds a query with two links but asserts only `describeParameters()`; upstream test pending |
| Link queries: a source object appears once even when several of its targets match | ad-hoc run against 5.3.2 on 2026-09-17 (not kept): `linkMany(name.oneOf(['a', 'b', 'c']))` over objects carrying all three returns each once (`find`, `findIds`, `count` agree); upstream test pending |
| Link queries: link conditions accept `param()` | `objectbox_test/test/query_test.dart::set param on links` |
| Vector search: the query vector and count are parameters of a built query | `objectbox_test/test/hnsw_test.dart::query` |
| Native library: `SyncClient.start()` activates `@Sync()` writes, construction does not, `close()` deactivates | pending upstream: `sync-enabled entity writes require a started client` on branch `added-tests` |
| Testing: `await openStore(...)` | in a Flutter package `openStore` returns a `Future`; in this Dart-native package it is synchronous, so the snippet check reports `await_only_futures` as an info |

## Known gaps

- Three claims added on 2026-09-17 rest on ad-hoc runs that are not kept here: `ToMany`
  read-back order, AND semantics of several links on one builder, and one result per
  source object in link queries. Each needs a test in objectbox-dart (`relations_test.dart`).
- Rows added on 2026-09-21 from the second evaluation round (six with-skill runs on the revised
  skill): the natural-key, index and batching rows are docs-backed opinion; the `ToMany`
  replace-targets row cites an upstream test that shows the accumulation but does not assert
  a removal attempt on an unloaded relation, so a test for the failure mode is still wanted.

- Five rows are `pending upstream`: their tests live on objectbox-dart branch
  `added-tests`. When a tagged release contains them, bump the pin, run
  `check_upstream.py --diff`, replace the pending notes with locators.
- Every `unverified` Sync row needs a Sync Server in the loop. The
  `server-docker` setup in objectbox-sync-examples is the candidate.
- The property-level `@Sync()` codegen claim needs a negative fixture package.
- macOS-only claims need a macOS runner.
