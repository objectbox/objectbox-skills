#!/usr/bin/env python3
"""Verifies every relative Markdown link under skills/: the file exists and,
if the link has a #fragment, a heading with that GitHub-style anchor exists.
Section references are links, not numbers, so a stale one fails here."""
import re, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent / "skills"

def slug(heading):
    h = re.sub(r"[`*_]", "", heading).strip().lower()
    h = re.sub(r"[^\w\- ]", "", h)
    return h.replace(" ", "-")

def anchors(md):
    seen, out = {}, set()
    for m in re.finditer(r"^#+ (.+)$", md.read_text(), re.M):
        s = slug(m.group(1))
        n = seen.get(s, 0); seen[s] = n + 1
        out.add(s if n == 0 else f"{s}-{n}")
    return out

bad = 0
for md in sorted(ROOT.rglob("*.md")):
    for m in re.finditer(r"\[[^\]]*\]\(([^)\s]+)\)", md.read_text()):
        target = m.group(1)
        if re.match(r"^[a-z]+:", target):
            continue
        file_part, _, frag = target.partition("#")
        dest = md if not file_part else (md.parent / file_part).resolve()
        if not dest.exists():
            bad += 1; print(f"missing file: {md.relative_to(ROOT.parent)} -> {target}")
            continue
        if frag and frag not in anchors(dest):
            bad += 1; print(f"missing anchor: {md.relative_to(ROOT.parent)} -> {target}")
print("broken links:", bad)
sys.exit(1 if bad else 0)
