# Validation

Executable checks for the claims in `skills/objectbox/references/`. The skill
files are prose; this directory is where that prose gets falsified.

Each claim in a binding file is one of these, and each type has a different
oracle. Reading the docs settles only the first.

| Claim type | Example | Oracle | Check |
|---|---|---|---|
| API shape | `nearestNeighborsF32`, `ToMany.reset()` | the analyzer, pinned version | `tool/check_snippets.dart` extracts every ` ```dart ` block from the skill file and analyzes it |
| Runtime behavior | `date` reads back local | running code | an objectbox-dart test cited by name in `COVERAGE.md` and resolved by `check_upstream.py`, or a local `dart test` for what upstream does not assert |
| Version, deprecation | `Sync.client` deprecated in 5.2.0 | CHANGELOG | recorded in `COVERAGE.md` with the version |
| Environment, ops | ulimit on macOS, error 57 | issue tracker, docs, a CI job on that OS | evidence link in `COVERAGE.md` |
| Idiom | `watch(triggerImmediately: true)` | official examples | the raw-file links in the skill file |
| Architecture opinion | never poll | a human | marked `opinion` in `COVERAGE.md` |

`check_links.py` verifies every relative link and heading anchor under
`skills/`; `dart/run.sh` runs it too. `check_upstream.py` resolves the
upstream test locators in `dart/COVERAGE.md` against objectbox-dart at the
pinned tag (`--run` executes them, `--diff OLD NEW` shows cited tests that
changed between two tags).

Per binding: `validation/<binding>/` with a `run.sh`, a `COVERAGE.md` that has
one row per row of the skill file's "Quick reference" table, and the tests.
Only `dart/` exists so far.

## Dart

```bash
validation/dart/run.sh             # sync-enabled native library, all tests
validation/dart/run.sh --non-sync  # plain library; @Sync() write tests skip
```

`run.sh` installs the ObjectBox C library matching the `objectbox` version
pinned in `pubspec.yaml` into `lib/`, runs code generation, analyzes the skill
snippets, then runs the tests. Bump the pin deliberately; `COVERAGE.md`
records the version each claim was verified against.

Layout:

- `lib/entities.dart` — the entity shapes the skill's snippets assume.
- `lib/snippet_context.dart` — free variables the snippets use without
  declaring (`store`, `conversationBox`, ...). Analyzed, never run.
- `tool/check_snippets.dart` — the snippet extractor and analyzer run.
- `test/*_test.dart` — behavior tests; `test/test_store.dart` is the
  per-test store with the disconnected `SyncClient` from the Testing section.
