# ObjectBox capabilities contract

Binding-agnostic hard constraints. Applies to every ObjectBox binding
(Dart/Flutter, Java/Kotlin, Swift, Go, Python, C/C++).

When a project uses ObjectBox as its data layer, do not re-implement ObjectBox
features in application code. Treat the rules below as constraints, not
preferences. Where a rule cannot be met, propose the smallest fallback and say
explicitly why.

Exact API names differ per binding — see the binding's own `AGENTS.md`.

---

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

**Do not**
- default to JSON-string bags for semantically important data
- hide structure in opaque blobs when it should be queryable

Data that usually should *not* live primarily in a JSON string: tags, failure
modes, file lists, command lists, verification outcomes, retrieval inputs.

## 3) Identity and invariants

Important invariants must be enforced by schema and write paths, not by comments.

**Use**
- synthetic unique identity keys when composite uniqueness is needed
- transaction-safe query-or-create / upsert helpers
- deterministic duplicate repair with explicit logging

**Do not**
- rely on "there should only be one row" comments
- assume a query returns exactly one row without checking
- use silent replace semantics on root identity entities

Specifically: do not use replace-on-conflict for project/plan/root identity rows
unless the reason is explicit and documented. Prefer update-in-place inside a
transaction.

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

For headless queue workers: subscription-driven wakeups are primary. A
low-frequency timer is acceptable only for lease-deadline recovery or
inter-process wake safety — never as primary change detection.

## 6) Vector search

**Use**
- ObjectBox vector search with an HNSW index
- one canonical ANN index per semantic retrieval use case
- explicit stale detection via text hash, embedding model identity, or source identity

**Do not**
- ship brute-force similarity scans in production
- load all vectors into memory to compute similarity
- keep two active vector-search systems for the same retrieval flow
- query several ANN boxes and merge results without a documented reason

Preferred shape: rich domain entities stay source of truth; one canonical
retrieval-index entity owns vectors and ANN queries; retrieval hydrates source
entities after the nearest-neighbor search.

Two properties of the API that are easy to get wrong:
- the returned score is a **distance** — lower is better, not higher
- HNSW dimensions must match your embedding output exactly, and are fixed once set

## 7) Sync

**Use**
- Sync as *the* replication mechanism
- explicit synced vs. local-only modeling
- local-only entities for caches, traces and recomputable indexes
- stable references across the sync/local boundary
- sync event listeners for UX status only

**Do not**
- build custom "pull updates" or "request changes" background jobs
- poll the server for new changes when Sync is enabled
- write manual conflict/merge loops outside ObjectBox unless explicitly required
- blur sync boundaries with accidental relations
- create references from synced entities to device-local rows
- leave sync/local decisions documented only in comments

## 8) Schema and the model file

The generated model file carries stable UIDs that Sync depends on. Treat it as
sync-critical source code.

| Binding | Path |
|---|---|
| Java/Kotlin | `objectbox-models/default.json` |
| Swift | `model-<project-name>.json` |
| Dart, Go, C/C++ | `objectbox-model.json` |

- Commit it.
- Never delete or regenerate it to resolve an error.
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
- nearest-neighbor query methods are named differently per binding
- the Python binding does not support relations — do not generate relation code for it
- code generation is invoked differently per binding, but is required in all of them

Always read the `AGENTS.md` in the binding's own repository.
