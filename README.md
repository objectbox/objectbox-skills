# ObjectBox Agent Skills

Instructions that help AI coding agents use ObjectBox correctly.

ObjectBox has six language bindings that are **not symmetric**, mandatory code
generation, and a sync-critical generated model file. Agents working from
training data get these wrong in ways that fail silently — a `@Sync()`
annotation on the wrong level, a `DateTime` stored as nanoseconds, a
hand-rolled polling loop instead of a query subscription, a deprecated
`Sync.client(...)` call.

These files encode the failure modes.

## Layout

Guidance is **per binding**, because the APIs are per binding.

```
shared/
  objectbox-capabilities.md   ← binding-agnostic contract. Referenced by all.

per-repo/
  objectbox-dart-AGENTS.md    → ships as AGENTS.md in objectbox/objectbox-dart
  objectbox-java-AGENTS.md    → ships as AGENTS.md in objectbox/objectbox-java
  objectbox-swift-AGENTS.md   → objectbox/objectbox-swift    (stub)
  objectbox-go-AGENTS.md      → objectbox/objectbox-go       (stub)
  objectbox-python-AGENTS.md  → objectbox/objectbox-python   (stub)
  objectbox-c-AGENTS.md       → objectbox/objectbox-c        (stub)
```

Each binding repository carries its own `AGENTS.md` at the repo root, so an
agent that clones or reads that repo picks it up without any extra setup. Each
one links back to `shared/objectbox-capabilities.md` for the rules that do not
change per language.

Nothing links *to* a stub, and nothing depends on one. Dart and Java/Kotlin
ship independently — the stubs can stay unfinished indefinitely without
blocking anything.

## Status

| Binding | State |
|---|---|
| Dart / Flutter | Written, derived from production use |
| Java / Kotlin | Written, derived from production use |
| Swift | Stub — needs a maintainer pass |
| Go | Stub — needs a maintainer pass |
| Python | Stub — needs a maintainer pass |
| C / C++ | Stub — needs a maintainer pass |

## Feedback

If this guidance was wrong, open an issue with the prompt, the agent and model,
the binding and version, and what actually happened. That is what improves it.

## License

Apache 2.0
