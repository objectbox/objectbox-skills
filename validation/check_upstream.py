#!/usr/bin/env python3
"""Resolves the upstream test locators in validation/dart/COVERAGE.md against
objectbox-dart, without running anything.

A locator has the form  objectbox_test/test/<file>::<exact test name>  and
claims that this test, at the pinned objectbox version, asserts the row's
behavior. Running those tests is pointless (objectbox-dart's CI already did,
at that tag); what can silently go wrong is the test being renamed, removed,
or rewritten along with a behavior change. Hence two modes:

  check_upstream.py [--repo PATH] [--ref REF]     every locator exists at REF
  check_upstream.py --diff [OLD] NEW              cited test bodies changed?

REF defaults to the tag v<objectbox version from validation/dart/pubspec.yaml>;
so does OLD. Without --repo, objectbox-dart is cloned blob-less into
validation/.cache/ from $OBJECTBOX_DART_REPO (default: GitHub). Exit status is
non-zero when a locator is missing or, with --diff, when a cited test changed:
read that test before trusting the row again (see AGENTS.md).
"""
import argparse, difflib, os, re, subprocess, sys, pathlib

HERE = pathlib.Path(__file__).resolve().parent
COVERAGE = HERE / "dart" / "COVERAGE.md"
PUBSPEC = HERE / "dart" / "pubspec.yaml"
CACHE = HERE / ".cache" / "objectbox-dart"
REMOTE = os.environ.get("OBJECTBOX_DART_REPO", "https://github.com/objectbox/objectbox-dart.git")
LOCATOR = re.compile(r"(objectbox_test/test/[\w/]+\.dart)::([^|`\n]+?)(?=\s*[|`]|\s*;|\s*$)")

def sh(*cmd, cwd=None, check=True):
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, check=check)

def pinned_tag():
    return "v" + re.search(r"^\s+objectbox:\s*(\S+)", PUBSPEC.read_text(), re.M).group(1)

def ensure_repo(repo, refs):
    if repo is None:
        repo = CACHE
        if not repo.exists():
            repo.parent.mkdir(parents=True, exist_ok=True)
            sh("git", "clone", "--quiet", "--filter=blob:none", "--no-checkout", REMOTE, str(repo))
        sh("git", "fetch", "--quiet", "--tags", "origin", cwd=repo)
    for ref in refs:
        if sh("git", "rev-parse", "--verify", "--quiet", f"{ref}^{{commit}}", cwd=repo, check=False).returncode:
            sys.exit(f"ref {ref!r} not found in {repo}")
    return pathlib.Path(repo)

def locators():
    found = set()
    for line in COVERAGE.read_text().splitlines():
        for m in LOCATOR.finditer(line):
            found.add((m.group(1), m.group(2).strip()))
    return sorted(found)

def file_at(repo, ref, path):
    r = sh("git", "show", f"{ref}:{path}", cwd=repo, check=False)
    return r.stdout if r.returncode == 0 else None

def test_body(src, name):
    m = re.search(r"\btest\(\s*(['\"])" + re.escape(name) + r"\1", src or "")
    if not m:
        return None
    col = m.start() - src.rfind("\n", 0, m.start()) - 1
    nxt = re.compile(r"\n {%d}(test\(|group\(|\}\);?$)" % col, re.M).search(src, m.end())
    return src[m.start(): nxt.start() if nxt else len(src)]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", type=pathlib.Path)
    ap.add_argument("--ref")
    ap.add_argument("--diff", nargs="+", metavar="REF", help="[OLD] NEW; OLD defaults to the pinned tag")
    a = ap.parse_args()
    bad = 0
    if a.diff:
        old, new = (a.diff if len(a.diff) == 2 else [pinned_tag(), a.diff[0]])
        repo = ensure_repo(a.repo, [old, new])
        for path, name in locators():
            bo, bn = (test_body(file_at(repo, r, path), name) for r in (old, new))
            if bo is None or bn is None:
                bad += 1; print(f"MISSING  {path}::{name}  (in {old}: {bo is not None}, in {new}: {bn is not None})")
            elif bo != bn:
                bad += 1; print(f"CHANGED  {path}::{name}")
                print("\n".join(difflib.unified_diff(bo.splitlines(), bn.splitlines(), old, new, lineterm="", n=1)))
            else:
                print(f"same     {path}::{name}")
        print(f"{len(locators())} cited tests compared, {old} -> {new}: {bad} to review")
        sys.exit(1 if bad else 0)
    ref = a.ref or pinned_tag()
    repo = ensure_repo(a.repo, [ref])
    for path, name in locators():
        if test_body(file_at(repo, ref, path), name) is None:
            bad += 1; print(f"MISSING  {path}::{name}  at {ref}")
        else:
            print(f"ok  {path}::{name}")
    print(f"{len(locators())} locators checked at {ref}, {bad} missing")
    sys.exit(1 if bad else 0)

if __name__ == "__main__":
    main()
