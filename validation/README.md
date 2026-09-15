# Validation

Executable checks for the claims in `skills/objectbox/references/`. The skill
files are prose; this directory is where that prose gets falsified.

Each claim in a binding file is one of these, and each type has a different
oracle. Reading the docs settles only the first.

| Claim type | Example | Oracle | Check |
|---|---|---|---|
| API shape | `nearestNeighborsF32`, `ToMany.reset()` | the analyzer, pinned version | `tool/check_snippets.dart` extracts every ` ```dart ` block from the skill file and analyzes it |
| Runtime behavior | `date` reads back local | objectbox-dart's own tests | a test cited by name in `COVERAGE.md`; `check_upstream.py` checks it exists at the pinned tag and diffs its body on pin bumps; missing ones are added upstream |
| Version, deprecation | `Sync.client` deprecated in 5.2.0 | CHANGELOG | recorded in `COVERAGE.md` with the version |
| Environment, ops | ulimit on macOS, error 57 | issue tracker, docs, a CI job on that OS | evidence link in `COVERAGE.md` |
| Idiom | `watch(triggerImmediately: true)` | official examples | the raw-file links in the skill file |
| Architecture opinion | never poll | a human | marked `opinion` in `COVERAGE.md` |

`.gitlab-ci.yml` runs all of this in `validate`, plus a scheduled, advisory
`upstream-drift` job that diffs the cited test bodies against objectbox-dart
`main`.

`check_links.py` verifies every relative link and heading anchor under
`skills/`; every `run.sh` runs it too. `check_upstream.py --binding <b>`
resolves the upstream test locators in `<b>/COVERAGE.md` against the upstream
repositories at the pinned tags; `--diff [OLD] NEW` shows cited tests that
changed between two refs. It never runs them: the upstream CI already did, at
that tag. `check_coverage.py` fails when the skill file's "Quick reference"
table and `COVERAGE.md` disagree on their first column.

Per binding: `validation/<binding>/` with a `run.sh` and a `COVERAGE.md` that
has one row per row of the skill file's "Quick reference" table. `dart/` also
has a package that compiles the skill's snippets; `java/` has no build at all,
see below.

## Dart

```bash
validation/dart/run.sh
```

`run.sh` runs code generation for the snippet fixtures, analyzes every code
snippet of the skill file against the pinned `objectbox` version, checks the
coverage table and the links, then resolves every upstream locator against
objectbox-dart at the pinned tag (a blob-less clone in `validation/.cache/`).
Bump the pin deliberately; `COVERAGE.md` records the version each claim was
verified against, and `check_upstream.py --diff <new-tag>` shows which cited
tests changed since the old pin.

Layout:

- `lib/entities.dart` — the entity shapes the skill's snippets assume.
- `lib/snippet_context.dart` — free variables the snippets use without
  declaring (`store`, `conversationBox`, ...). Analyzed, never run.
- `tool/check_snippets.dart` — the snippet extractor and analyzer run.
- `tool/check_coverage.dart` — quick-reference rows vs. `COVERAGE.md`.

There are no tests in this repository: behavior is asserted by
objectbox-dart's own suite, and what it did not assert was added there.

## Java / Kotlin

```bash
validation/java/run.sh
```

`run.sh` checks the coverage table and the links, extracts every ` ```kotlin `
block of the skill file into a small Gradle project and compiles it against
the pinned ObjectBox version (annotation processor included, nothing is run),
then resolves every upstream locator at tag `V<version>`. The version is the
single `objectbox` entry in `java/gradle/libs.versions.toml`.

The Gradle project is compile-only, on purpose: the upstream suites already
have the store, entity and Sync Server setup, so every behavior claim is cited
from [objectbox-java](https://github.com/objectbox/objectbox-java)
(`tests/objectbox-java-test`) or from the internal objectbox-integration-test
repository (`test-java`, `test-kotlin`, `test-java-sync-server`), and what
they did not assert was added there. Locators have the form
`<repo>:<path>::<method>`, where `<repo>` is `objectbox-java` or
`objectbox-integration-test`. objectbox-java is cloned from GitHub;
objectbox-integration-test is internal, so its locators are skipped unless
`OBJECTBOX_INTEGRATION_TEST_REPO` or `--repo objectbox-integration-test=<path>`
names it, e.g. locally:

```bash
validation/java/run.sh --repo objectbox-integration-test=../objectbox-integration-test
```

Layout:

- `gradle/libs.versions.toml` — the pinned ObjectBox, Kotlin and JUnit versions.
- `src/main/kotlin/io/objectbox/skill/context/SnippetContext.kt` — free
  variables the snippets use without declaring (`store`, `conversationBox`, ...)
  and the one entity no snippet declares. Compiled, never run.
- `tool/extract_snippets.py` — the snippet extractor; writes the generated
  files to `src/main/kotlin/io/objectbox/skill/snippets/` (git-ignored, like
  the processor's `objectbox-models/`).
