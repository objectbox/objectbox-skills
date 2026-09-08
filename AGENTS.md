# Working on this repository

This repo is an [Agent Skills](https://agentskills.io) repository, shipped as a
Claude Code plugin. It contains one skill, `objectbox`, that teaches AI coding
agents to use the ObjectBox database correctly. The product here is curated
**failure-mode knowledge** — the things official docs don't say and training
data gets wrong. It is not a mirror of API documentation.

## Layout

- `skills/objectbox/SKILL.md` — the skill entry point: YAML frontmatter, the
  binding-agnostic contract, and routing tables that send agents to reference
  files along two axes: language binding and task.
- `skills/objectbox/references/<binding>.md` — per-binding guidance
  (`dart-flutter.md`, `java-kotlin.md`; `swift.md`, `go.md`, `python.md`,
  `c-cpp.md` are marked stubs).
- `skills/objectbox/references/<topic>.md` — cross-cutting task guides
  (`sync-server-setup.md`, `vector-search.md`).
- `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` — the repo
  root is the plugin; skills under `skills/` are auto-discovered.
- `validation/<binding>/` — executable checks for the claims in the skill
  files (see `validation/README.md`). Not skill content; agents never load it.

## Rules for editing content

- **Shared rules live exactly once, in SKILL.md's contract.** Never copy a
  binding-agnostic rule into a language or topic file — link to where it lives.
  Duplication drifting apart is the exact failure mode this repo exists to
  prevent; do not recreate it internally.
- **Bindings are asymmetric — never extrapolate.** Do not fill in an API name,
  annotation, or path for one binding based on another binding's file or on
  memory. Verify against the official docs (append `.md` to any docs page URL;
  each site has an `/llms.txt` index — the URLs are listed in SKILL.md).
- **Do not vendor documentation.** The skill links to the live docs sites;
  never copy doc pages into this repo where they would go stale. The same
  goes for example code: link the official example repos (raw file URLs),
  never keep templates here.
- **Docs prove existence, not behavior.** Checking a docs page settles only
  whether an API exists. A claim that something *happens* — fails silently,
  is ignored, drifts, leaks — needs a test under `validation/<binding>/` or
  an explicit `unverified` row in that binding's `COVERAGE.md`. Hedged
  wording ("either fails or is silently ignored") means nobody ran it: run
  it.
- **Topics graduate, structure stays.** When a section of a binding file grows
  into real workflow material, move it to its own `references/<topic>.md` and
  add a row to SKILL.md's task-guide table. A new *skill* is justified only for
  a trigger intent that occurs outside ObjectBox application code.
- **All cross-references are relative links** within `skills/objectbox/`
  (`references/x.md` from SKILL.md, `x.md` or `../SKILL.md` from a reference).
  No absolute GitHub URLs between files of this repo.
- **Stub conventions:** keep the `> **Status: stub.**` banner with its
  fallback instructions (contract + official-docs URL). Completing a stub
  means a pass by someone who works in that binding; afterwards remove the
  banner, update the routing-table "stub" marker in SKILL.md, and update the
  status table in README.md.
- **Style:** concrete code snippets over prose; prefer traps that fail
  *silently*; end binding files with the "Quick reference — common mistakes"
  table (Mistake / Why it breaks / Fix); wrap Markdown near 80 columns.
- **Frontmatter:** keep `name: objectbox` stable. The `description` is the
  trigger — third person, states when to use the skill, names the bindings.

## Validate before committing

- Both files in `.claude-plugin/` parse: `python3 -m json.tool <file>`.
- Every relative `.md` link resolves to an existing file.
- SKILL.md stays well under 500 lines; deep material goes to `references/`.
- Any new or changed API claim was checked against the official docs, not
  recalled.
- `validation/dart/run.sh` passes after touching `dart-flutter.md`, and every
  row of its "Quick reference" table has a row in
  `validation/dart/COVERAGE.md`.
