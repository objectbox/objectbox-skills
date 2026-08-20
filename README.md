# ObjectBox Agent Skills

[Agent Skills](https://agentskills.io) that help AI coding agents use
[ObjectBox](https://objectbox.io) correctly.

ObjectBox has six language bindings that are **not symmetric**, mandatory code
generation, and a sync-critical generated model file. Agents working from
training data get these wrong in ways that fail silently — a `@Sync()`
annotation on the wrong level, a `DateTime` stored as nanoseconds, a
hand-rolled polling loop instead of a query subscription, a deprecated
`Sync.client(...)` call.

This repository encodes the failure modes as a skill.

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

Rather than mirroring API documentation, the skill points agents at the
official docs, which serve agent-readable Markdown: append `.md` to any page
URL, or fetch the `/llms.txt` index of each docs site.

## Status

| Binding | State |
|---|---|
| Dart / Flutter | Written, derived from production use |
| Java / Kotlin | Written, derived from production use |
| Swift | Stub — needs a maintainer pass |
| Go | Stub — needs a maintainer pass |
| Python | Stub — needs a maintainer pass |
| C / C++ | Stub — needs a maintainer pass |

Stub bindings still get the full binding-agnostic contract; their reference
files carry the known asymmetries and point to the official docs for the rest.

## Feedback

If this guidance was wrong, open an issue with the prompt, the agent and model,
the binding and version, and what actually happened. That is what improves it.

## License

Apache 2.0
