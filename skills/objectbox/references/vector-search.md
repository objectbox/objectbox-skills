# Vector search (HNSW) — design and use

Cross-binding guide for ObjectBox on-device vector search. The hard constraints
are in the SKILL.md contract ([rule 6](../SKILL.md#6-vector-search)); this file
holds the design guidance, the sync interaction, and the per-binding API names.
Entity and query snippets for your binding are in its own reference file.

Official docs: https://docs.objectbox.io/on-device-vector-search.md

Available in Python, C, C++, Dart/Flutter, Java/Kotlin and Swift.
**Not available in the Go binding** — do not generate HNSW code for Go.

## Semantics that hold in every binding

- The returned score is a **distance** — lower is better, not higher. Invert
  before ranking if callers expect similarity.
- Only the scored find variants (`findWithScores()` / `findIdsWithScores()`;
  Python `find_with_scores()` / `find_ids_with_scores()`) return results
  **ordered by distance**. The plain `find()` methods are not distance-ordered
  — taking the first N of a plain find silently returns wrong "top" results.
- HNSW dimensions are required and fixed per index. Vectors with **more**
  dimensions than the index are accepted (extra dimensions unused); vectors
  with **fewer** dimensions are **silently skipped by the index** — the object
  is stored but can never be found by nearest-neighbor search. Match your
  embedding output; keep it stable.
- The default distance is (squared) Euclidean. Available types: euclidean,
  cosine, dotProduct, dotProductNonNormalized, geo. For sentence embeddings
  set cosine explicitly.
- HNSW is a **local** index, updated automatically as objects are written. Do
  not try to sync or rebuild it manually.

## Index design

- One canonical ANN index per semantic retrieval use case. Two active
  vector-search systems for the same retrieval flow means one of them is stale.
- Preferred shape: rich domain entities stay source of truth; one canonical
  retrieval-index entity owns vectors and ANN queries; retrieval hydrates
  source entities after the nearest-neighbor search.
- Explicit stale detection: store a text hash, the embedding model identity, or
  the source identity next to the vector, and re-embed when it no longer
  matches. Never guess freshness.
- Tuning knobs: `neighborsPerNode` (default 30) and `indexingSearchCount`
  (docs recommend at least 200) trade index quality against indexing cost.

## Querying efficiently

- Query the HNSW index directly. Never write a manual cosine scan over all rows
  in production, and never load all vectors into memory to compute similarity —
  both defeat the index and grow linearly with the dataset.
- When combining nearest-neighbor search with a selective filter, **over-fetch**:
  other conditions are applied to the ANN candidates, so a small `maxCount`
  returns too few matches. A working heuristic from production use (the docs do
  not specify one): `maxCount = max(limit * 8, 40)`, then trim.
- Close queries like any other query (see the contract,
  [rule 4](../SKILL.md#4-queries)).

## Vectors and Sync

Embeddings sync as normal entity data — the "sync the text, recompute vectors
locally" workaround is not needed. Put the embedding on the same synced entity
as its metadata. Keep dimensions stable; to change embedding models, add a new
property and migrate deliberately. The HNSW index itself stays local and
updates as synced objects arrive. Watch payload size: large vectors increase
sync traffic.

## Per-binding API — do not extrapolate

The nearest-neighbor query API differs per binding — in method name, casing,
and even declaration mechanism. Getting it from another binding's docs is the
most common failure mode.

| Binding | Nearest-neighbor query | Index declaration |
|---|---|---|
| Java/Kotlin | `nearestNeighbors(queryVector, maxCount)` | `@HnswIndex(dimensions = ...)` on `float[]` / `FloatArray?` |
| Dart | `nearestNeighborsF32(queryVector, maxCount)` | `@HnswIndex(dimensions: ...)` + `@Property(type: PropertyType.floatVector)` on `List<double>?` |
| Python | `nearest_neighbor(query_vector, count)` | `Float32Vector(index=HnswIndex(dimensions=..., distance_type=VectorDistanceType....))` |
| Swift | `nearestNeighbors(queryVector: v, maxCount: n)` — labeled arguments | comment annotation `// objectbox:hnswIndex: dimensions=...` on `[Float]?` |
| C/C++ | `Entity_::prop.nearestNeighbors(v, n)` | in the `.fbs` schema: `/// objectbox: index=hnsw, hnsw-dimensions=...` (distance via `/// objectbox: hnsw-distance-type=...`) |
| Go | not supported | not supported |

Scored finds: `findWithScores()` / `findIdsWithScores()` in Java/Kotlin, Dart
and Swift; `find_with_scores()` / `find_ids_with_scores()` in Python; C++
`findWithScores()` returns entity/distance pairs.

Python note: the docs mark the Python vector-search APIs as non-final and
subject to change — re-check on version updates.
