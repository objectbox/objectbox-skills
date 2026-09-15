# ObjectBox Agent Skills

[Agent Skills](https://agentskills.io) that help AI coding agents use
[ObjectBox](https://objectbox.io) correctly.

ObjectBox has six language bindings that are not always symmetric, mandatory code
generation, and a sync-critical generated model file.
The official docs cover the API.
They do not cover the pitfalls an agent runs into in practice, for example:

- a vector search score read as similarity, when it is a distance and lower is
  better, so results rank backwards;
- a store closed before its sync client, which is undefined behavior;
- a generated model file regenerated to "fix" a schema error, which throws away
  the UIDs that Sync depends on;
- an API name or relation-loading default carried over from another binding,
  where the bindings differ.

Most of these fail silently or with a misleading error.
This repository encodes the pitfalls and their fixes as a skill,
so an agent avoids them instead of debugging them.

## What this adds over the docs

An agent that can fetch the official docs can look up any API. The skill sends
it there (append `.md` to any docs page URL, or fetch the site's `/llms.txt`
index) and adds the three things the docs cannot give it:

- **Behavior the docs do not state.** Traps that fail silently or with a
  misleading error. Each is backed by an objectbox-dart test cited in
  `validation/dart/COVERAGE.md`, or marked unverified there.
  No model can look up what is not written down.
- **Asymmetries between bindings.** Method names, relation-loading defaults and
  feature availability differ per binding. Fluency makes this worse, not better:
  an agent that has seen more Java ObjectBox than Dart reconstructs Dart calls
  from Java. The skill forbids extrapolation and lists the known differences.
- **Operational policy.** How to treat the generated model file, how to hand a
  Sync Server the model after a schema change, the shutdown order of sync client
  and store, how to test against a Sync Server without flakes.
  This is team practice, not API.

Stronger models need the contract's architecture rules less and the trap tables
just as much.

## When you do not need it

One binding, no Sync, no vector search, and an agent that can fetch the docs:
the skill is then mostly a review checklist, and the binding's quick-reference
table is the part still worth reading. Sync, or several bindings in one
workspace, is where the skill pays for itself.

## Install

**Any agent, via [`npx skills`](https://github.com/vercel-labs/skills)** —
installs into Claude Code, Codex, Cursor, OpenCode, and many other agents:

```
npx skills add objectbox/objectbox-skills
```

**Claude Code, via the plugin marketplace:**

```
/plugin marketplace add objectbox/objectbox-skills
/plugin install objectbox@objectbox-skills
```

**Claude Code, manually:** copy `skills/objectbox/` into `.claude/skills/` in
your project, or into `~/.claude/skills/` for all projects.

**Other agents:** any tool that supports the
[Agent Skills format](https://agentskills.io) can load
`skills/objectbox/SKILL.md` directly.

## Layout

One skill, `objectbox`. Its `SKILL.md` holds the binding-agnostic contract and
routes the agent to on-demand reference files along two axes — the project's
language binding, and the task at hand:

```
skills/objectbox/
  SKILL.md                   ← contract + routing; loaded when the skill triggers
  references/
    dart-flutter.md          ← per-binding guidance, loaded for the binding in play
    java-kotlin.md
    swift.md                 ← stub — needs a maintainer pass
    go.md                    ← stub
    python.md                ← stub
    c-cpp.md                 ← stub
    sync-server-setup.md     ← task guide: run a Sync Server, schema changes
    vector-search.md         ← task guide: HNSW design + per-binding API names
```

Shared rules live exactly once, in `SKILL.md`. Deep or cross-cutting topics are
reference files. An agent loads the contract plus only the references its task
needs — adding a binding or a topic is one file and one routing row.

The skill does not mirror API documentation; it points agents at the official
docs instead, so nothing here goes stale against a release.

## Validation

The skill files are prose, so `validation/` holds what falsifies them. Each
binding has a `COVERAGE.md` that maps every row of the skill's quick-reference
table to the upstream test behind it (objectbox-dart, objectbox-java or the
internal objectbox-integration-test), or marks it unverified; `run.sh` checks
the table against the skill file and resolves every cited test at the pinned
upstream tag. For Dart, `validation/dart/run.sh` additionally compiles every
code snippet in `dart-flutter.md` against a pinned ObjectBox version. No tests
live here: what upstream did not assert is added upstream.

## Status

| Binding        | State                                |
|----------------|--------------------------------------|
| Dart / Flutter | Written, derived from production use |
| Java / Kotlin  | Written, derived from production use |
| Swift          | Stub — needs a maintainer pass       |
| Go             | Stub — needs a maintainer pass       |
| Python         | Stub — needs a maintainer pass       |
| C / C++        | Stub — needs a maintainer pass       |

Stub bindings still get the full binding-agnostic contract; their reference
files carry the known asymmetries and point to the official docs for the rest.

## Feedback

If this guidance was wrong, open an issue with the prompt, the agent and model,
the binding and version, and what actually happened. That is what improves it.

## License

Apache 2.0
