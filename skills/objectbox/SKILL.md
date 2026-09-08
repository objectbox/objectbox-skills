---
name: objectbox
description: Use ObjectBox (on-device database with vector search and data sync) correctly in any of its bindings — Dart/Flutter, Java/Kotlin, Swift, Go, Python, C/C++. Use when writing, reviewing, or debugging code that stores, queries, observes, syncs, or vector-searches data with ObjectBox, including entities, relations, HNSW vector search, Sync clients, Sync Server setup, and the generated model file.
license: Apache-2.0
---

# ObjectBox

ObjectBox has six language bindings that are **not symmetric**, mandatory code
generation, and a sync-critical generated model file. Reconstructing its APIs
from training data or another binding's documentation produces code that fails
silently — a `@Sync()` annotation on the wrong level, a `DateTime` stored as
nanoseconds, a hand-rolled polling loop instead of a query subscription, a
deprecated `Sync.client(...)` call. This skill encodes the failure modes.

## How to use this skill

1. Apply the binding-agnostic contract below — it holds in every binding.
2. Identify the project's binding and read its reference file.
3. If the task matches a topic guide, read that too.

### Find your binding

| Project has | Binding | Read |
|---|---|---|
| `pubspec.yaml` with `objectbox` | Dart / Flutter | [references/dart-flutter.md](references/dart-flutter.md) |
| `build.gradle(.kts)` with `io.objectbox` | Java / Kotlin | [references/java-kotlin.md](references/java-kotlin.md) |
| `Package.swift` / `Podfile` with ObjectBox | Swift | [references/swift.md](references/swift.md) — stub, see banner |
| `go.mod` with `objectbox/objectbox-go` | Go | [references/go.md](references/go.md) — stub, see banner |
| `pyproject.toml` / requirements with `objectbox` | Python | [references/python.md](references/python.md) — stub, see banner |
| `CMakeLists.txt` / headers with `objectbox` | C / C++ | [references/c-cpp.md](references/c-cpp.md) — stub, see banner |

A workspace with several bindings (e.g. Flutter app + Go backend) needs the
reference file for each binding you touch. Stub files are incomplete: for those
bindings, follow this contract, use the stub's known asymmetries, and look up
everything else in the official docs (see below) — do not extrapolate from
another binding.

### Task-specific guides

| Task | Read |
|---|---|
| Set up or run a Sync Server; schema changes with Sync | [references/sync-server-setup.md](references/sync-server-setup.md) |
| Vector search, semantic retrieval, RAG, HNSW indexes | [references/vector-search.md](references/vector-search.md) |

### Look up the API, don't recall it

The official docs serve clean Markdown: append `.md` to any page URL
(e.g. `https://docs.objectbox.io/queries.md`), and each site publishes a full
page index at `/llms.txt`.

| Site | Covers |
|---|---|
| https://docs.objectbox.io/llms.txt | Java/Kotlin, Dart/Flutter, Python |
| https://swift.objectbox.io/llms.txt | Swift |
| https://golang.objectbox.io/llms.txt | Go |
| https://cpp.objectbox.io | C/C++ (no llms.txt index) |
| https://sync.objectbox.io/llms.txt | Sync and Sync Server |

### Start from an official example

Smaller models copy-and-adapt concrete code reliably but reconstruct
annotations badly from rules. Fetch an official example, copy its structure,
then apply this skill's rules on top. Where the two disagree, this skill
wins: an example targets one release, this skill tracks the current one.
Fetch the raw file (`https://raw.githubusercontent.com/<org>/<repo>/main/<path>`),
not the GitHub HTML page. Binding files name the specific files to fetch where
they exist, and the in-file snippets to fall back on when you cannot fetch URLs.

| Repository | Covers |
|---|---|
| https://github.com/objectbox/objectbox-sync-examples | Sync clients for every binding (`tasks/client-*`) and Sync Server setups (`tasks/server-*`) |
| https://github.com/objectbox/objectbox-examples | Java, Kotlin, Android: relations, vector search, multi-module, multi-process |
| https://github.com/objectbox/objectbox-dart/tree/main/objectbox/example | Dart/Flutter: basics, relations, vector search |
| https://github.com/objectbox/objectbox-swift/tree/main/Example | Swift: Notes app for iOS and macOS |
| https://github.com/objectbox/objectbox-go/tree/main/examples | Go |
| https://github.com/objectbox/objectbox-python/tree/main/example | Python: tasks, vector search, ollama |
| https://github.com/objectbox/objectbox-c/tree/main/examples | C and C++ |

---

# The contract

Binding-agnostic hard constraints. When a project uses ObjectBox as its data
layer, do not re-implement ObjectBox features in application code. Treat the
rules below as constraints, not preferences. Where a rule cannot be met,
propose the smallest fallback and say explicitly why.

Exact API names differ per binding — see the binding's reference file.

## 1) Store lifecycle

**Use**
- one store per process, opened once and reused
- a centralized store bootstrap
- the generated model file, committed to version control

**Do not**
- open multiple stores for the same dataset in one process
- treat the database as a JSON bucket
- regenerate or delete the model file to "fix" schema issues

## 2) Modeling

**Use**
- typed entity classes
- real relations and typed link entities
- queryable scalar fields for anything you filter, count or sort on
- normalized child entities when the relationship carries metadata
- a persisted property for any state that must survive a re-read
- one enum per concept, defined in the data layer, persisted through a
  scalar mapping you own

**Do not**
- default to JSON-string bags for semantically important data
- hide structure in opaque blobs when it should be queryable
- keep state in transient fields or plain memory and expect it back after a
  re-read
- persist an enum through a mapping that changes when the enum is edited

Objects are rebuilt on every read: `get`, queries and relation access return
fresh instances, so nothing held in a transient field or only in memory
survives a re-read. Enums go through a converter or an int getter/setter
(see the binding file); keep that mapping stable across releases and give
the enum an explicit unknown value for ids it does not recognize.

## 3) Identity and invariants

Important invariants must be enforced by schema and write paths, not by comments.

**Use**
- synthetic unique identity keys when composite uniqueness is needed
- transaction-safe query-or-create / upsert helpers
- deterministic duplicate repair with explicit logging

**Do not**
- rely on "there should only be (exactly) one row" comments
- use silent replace semantics on root identity entities
- do not use replace-on-conflict when syncing:
  prefer update-in-place inside a transaction

## 4) Queries

**Use**
- direct queries for counts, slices and ordering
- relation-aware filtering where the binding supports it
- narrow hydration after targeted queries
- explicit query close (or the binding's scoped form)

**Do not**
- bulk-load whole boxes and compute statistics in memory when a query can do it
- use "get all" as the default read pattern
- leave queries unclosed in long-running processes

## 5) Reactive updates

**Use**
- data observers / query subscriptions as the primary change signal
- explicit subscription cancellation — no leaked subscriptions

**Do not**
- implement polling or tick loops as the primary DB change detector
- use repeated queries as invalidation
- rely on timers except for low-frequency safety and recovery cases

For headless queue workers: subscription-driven wakeups are primary.
A low-frequency timer is acceptable only for lease-deadline recovery or
inter-process wake safety — never as primary change detection.

## 6) Vector search

**Use**
- ObjectBox vector search with an HNSW index
- one canonical ANN index per semantic retrieval use case
- explicit stale detection via text hash, embedding model identity, or source identity

**Do not**
- brute-force similarity scans (other than tests/debugging)
- load all vectors into memory to compute similarity
- keep two active vector-search systems for the same retrieval flow
- query several ANN boxes and merge results without a documented reason

Two properties of the API that are easy to get wrong:
- the returned score is a **distance** — lower is better, not higher
- HNSW dimensions must match your embedding output exactly, and are fixed once set

Index design, filter interaction, sync behavior, and the per-binding API names
are in [references/vector-search.md](references/vector-search.md) — read it
before designing or reviewing a retrieval flow.

## 7) Sync

**Use**
- Sync as *the* replication mechanism
- explicit synced vs. local-only modeling
- local-only entities for caches, traces and recomputable indexes
- stable references across the sync/local boundary
- sync event listeners for UX status only
- an explicit shutdown order: stop and close the sync client **before**
  closing the store — the reverse is undefined behavior

**Do not**
- build custom "pull updates" or "request changes" background jobs
- poll the server for new changes when Sync is enabled
- write manual conflict/merge loops outside ObjectBox unless explicitly required
- blur sync boundaries with accidental relations
- create references from synced entities to device-local rows
- leave sync/local decisions documented only in comments

## 8) Schema and the model file

The generated model file carries stable UIDs that Sync depends on.
Treat it as sync-critical source code.

| Binding | Path |
|---|---|
| Java/Kotlin | `objectbox-models/default.json` (under `app/` in a default Android setup) |
| Swift | `model-<target-name>.json` |
| Dart | `lib/objectbox-model.json` |
| Go | `objectbox-model.json` — per package, next to `objectbox-model.go` |
| C/C++ | `objectbox-model.json` (the generated `objectbox-model.h` is a separate file) |

- Commit it.
- Never delete or regenerate it to resolve an error. The only sanctioned reset
  is the deliberate "nuke option" during initial development: delete the model
  file **and** every database created with it (including any Sync Server
  dataset) together.
- If a Sync Server is involved, copy it to the server after every schema change,
  and start the server with an explicit `--model <path>` pointing at that copy.

## 9) Failure handling

**Use**
- explicit logging and repair when invariants break
- typed failures/results where an operation can be rejected
- deterministic cleanup for duplicates and stale index rows

**Do not**
- fail silently
- silently degrade from one retrieval path to another
- ignore rejected state transitions or broken references

## 10) Binding differences — do not extrapolate

API names are not symmetric across bindings. Reconstructing a call from another
binding's documentation is the most common source of broken ObjectBox code.

Known asymmetries:
- nearest-neighbor query methods are named differently per binding, and vector
  search is not available in Go at all
- the Python binding does not support relations — do not generate relation code for it
- relation loading defaults differ: Go loads relations eagerly by default,
  Swift and Dart lazily
- code generation is invoked differently per binding, but is required in all of them

Always read the reference file for the binding you are working in, and verify
anything a stub does not cover against the official docs listed above.
