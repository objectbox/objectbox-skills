# ObjectBox — C / C++

> **Status: stub.** The binding-specific sections below are incomplete and need
> a pass from a maintainer who works in this binding; the content markers show
> what has to be filled in. Until it is complete: follow the contract in
> [SKILL.md](../SKILL.md), use what *is* filled in here, and look up everything
> else in the official docs at https://cpp.objectbox.io. Do not extrapolate
> from another binding's reference file.

Binding-specific guidance for ObjectBox in C / C++. It assumes the
binding-agnostic contract in [SKILL.md](../SKILL.md).

## Before you write code

1. **Check the installed version.** <!-- TODO: registry URL + how to check -->
2. **Run code generation.** <!-- TODO: exact command for this binding -->
3. **Look up the API, don't recall it.** Any docs page can be fetched as
   Markdown by appending `.md` — e.g. `https://docs.objectbox.io/queries.md`.

## Entity declaration

<!-- TODO: minimal working entity with id, index, date property, sync annotation -->

## Relations

<!-- TODO: ToOne / ToMany syntax, or state clearly that relations are unsupported -->

## Queries and lifecycle

<!-- TODO: query construction, and how queries are closed in this binding -->

## Reactive updates

<!-- TODO: the observer / subscription API name for this binding -->

## Vector search (HNSW)

<!-- TODO: THE nearest-neighbor method name for this binding.
     This is the single highest-value line in the file — the names differ
     (Java/Kotlin: nearestNeighbors, Dart: nearestNeighborsF32) and getting it
     from another binding's docs is the most common failure mode. -->

Score is a **distance** — lower is better.

## Sync

<!-- TODO: client construction, current vs. deprecated form, credentials -->

## Model file

<!-- TODO: generated model path for this binding; commit it, never regenerate to fix -->

## Quick reference — common mistakes

<!-- TODO: the traps that actually bite in this binding. Prefer ones that fail
     SILENTLY — those are what this file exists for. -->

| Mistake | Why it breaks | Fix |
|---|---|---|
| | | |
