# Vector search (HNSW) — design and use

Cross-binding guide for ObjectBox on-device vector search. The hard constraints
are in the SKILL.md contract (section 6); this file holds the design guidance,
the sync interaction, and the per-binding API names. Entity and query snippets
for your binding are in its own reference file.

Official docs: https://docs.objectbox.io/on-device-vector-search.md

## Semantics that hold in every binding

- The returned score is a **distance** — lower is better, not higher. Invert
  before ranking if callers expect similarity.
- HNSW dimensions are required, must match your embedding output exactly, and
  are **fixed once set**.
- The default distance is (squared) Euclidean. For sentence embeddings set
  cosine explicitly.
- HNSW is a **local** index — it updates as objects arrive. Do not try to sync
  or rebuild it manually.

## Index design

- One canonical ANN index per semantic retrieval use case. Two active
  vector-search systems for the same retrieval flow means one of them is stale.
- Preferred shape: rich domain entities stay source of truth; one canonical
  retrieval-index entity owns vectors and ANN queries; retrieval hydrates
  source entities after the nearest-neighbor search.
- Explicit stale detection: store a text hash, the embedding model identity, or
  the source identity next to the vector, and re-embed when it no longer
  matches. Never guess freshness.

## Querying efficiently

- Query the HNSW index directly. Never write a manual cosine scan over all rows
  in production, and never load all vectors into memory to compute similarity —
  both defeat the index and grow linearly with the dataset.
- When combining nearest-neighbor search with a selective filter, **over-fetch**:
  the filter is applied to the ANN candidates, so a small `maxCount` returns too
  few matches. A working heuristic: `maxCount = max(limit * 8, 40)`, then trim.
- Close queries like any other query (see the contract, section 4).

## Vectors and Sync

Embeddings sync as normal entity data — the "sync the text, recompute vectors
locally" workaround is not needed. Put the embedding on the same synced entity
as its metadata. Keep dimensions stable; to change embedding models, add a new
property and migrate deliberately. The HNSW index itself stays local and
updates as synced objects arrive. Watch payload size: large vectors increase
sync traffic.

## Per-binding API — do not extrapolate

The nearest-neighbor query method is named differently per binding. Getting it
from another binding's docs is the most common failure mode.

| Binding | Nearest-neighbor query | Index declaration |
|---|---|---|
| Java/Kotlin | `nearestNeighbors(queryVector, maxCount)` | `@HnswIndex(dimensions = ...)` on a `FloatArray?` |
| Dart | `nearestNeighborsF32(queryVector, maxCount)` | `@HnswIndex(dimensions: ...)` + `@Property(type: PropertyType.floatVector)` on `List<double>?` |
| Swift, Go, Python, C/C++ | look it up in the official docs — see SKILL.md | look it up |

Both documented bindings return scored results via `findWithScores()`; the
score is a distance.
