#!/usr/bin/env python3
"""Resolves the upstream test locators in validation/dart/COVERAGE.md against
an objectbox-dart checkout.

A locator has the form  objectbox_test/test/<file>::<exact test name>  and
claims that this test, at the pinned objectbox version, asserts the row's
behavior. This script checks that the named test exists at that ref
(renames and deletions fail), can run just those tests, and can diff the
cited test bodies between two refs when the pin is bumped.

  check_upstream.py [--repo PATH] [--ref REF] [--prepare] [--run] [--diff OLD NEW]

Without --repo, objectbox-dart is cloned into validation/.cache/ (from
$OBJECTBOX_DART_REPO if set, else GitHub). Without
--ref, the tag v<objectbox version from validation/dart/pubspec.yaml> is used.
--run needs the objectbox_test package set up in the checkout (pub get,
build_runner, native library). --prepare does that: with the cache clone it
also checks out the ref; with --repo it leaves the working tree as it is.
"""
import argparse, os, re, subprocess, sys, pathlib

HERE = pathlib.Path(__file__).resolve().parent
COVERAGE = HERE / "dart" / "COVERAGE.md"
PUBSPEC = HERE / "dart" / "pubspec.yaml"
CACHE = HERE / ".cache" / "objectbox-dart"
REMOTE = os.environ.get("OBJECTBOX_DART_REPO", "https://github.com/objectbox/objectbox-dart.git")
LOCATOR = re.compile(r"(objectbox_test/test/[\w/]+\.dart)::([^|`\n]+?)(?=\s*[|`]|\s*;|\s*$)")

def sh(*cmd, cwd=None, check=True):
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, check=check)

def pinned_version():
    m = re.search(r"^\s+objectbox:\s*(\S+)", PUBSPEC.read_text(), re.M)
    return m.group(1)

def ensure_repo(repo, ref):
    if repo is None:
        repo = CACHE
        if not repo.exists():
            repo.parent.mkdir(parents=True, exist_ok=True)
            sh("git", "clone", "--quiet", "--filter=blob:none", "--no-checkout", REMOTE, str(repo))
        sh("git", "fetch", "--quiet", "--tags", "origin", cwd=repo)
    if sh("git", "rev-parse", "--verify", "--quiet", f"{ref}^{{commit}}", cwd=repo, check=False).returncode:
        sys.exit(f"ref {ref!r} not found in {repo}")
    return pathlib.Path(repo)

def locators():
    out = []
    for line in COVERAGE.read_text().splitlines():
        for m in LOCATOR.finditer(line):
            out.append((m.group(1), m.group(2).strip()))
    return sorted(set(out))

def file_at(repo, ref, path):
    r = sh("git", "show", f"{ref}:{path}", cwd=repo, check=False)
    return r.stdout if r.returncode == 0 else None

def test_pattern(name):
    return re.compile(r"\btest\(\s*(['\"])" + re.escape(name) + r"\1")

def test_body(src, name):
    m = test_pattern(name).search(src)
    if not m:
        return None
    # body runs until the next top-level test/group at the same indentation
    indent = src.rfind("\n", 0, m.start())
    col = m.start() - indent - 1
    nxt = re.compile(r"\n {%d}(test\(|group\(|\}\);?$)" % col, re.M).search(src, m.end())
    return src[m.start(): nxt.start() if nxt else len(src)]

def prepare(repo, ref, checkout):
    if checkout:
        sh("git", "checkout", "--quiet", "--detach", ref, cwd=repo)
    t = repo / "objectbox_test"
    print(f"preparing {t} at {ref}")
    sh("dart", "pub", "get", cwd=t)
    sh("dart", "run", "build_runner", "build", "--delete-conflicting-outputs", cwd=t)
    if not list((t / "lib").glob("libobjectbox.*")):
        # the tag's own installer fetches the matching C library; --sync so the
        # sync test group runs too
        sh("bash", "../install.sh", "--quiet", "--sync", cwd=t)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", type=pathlib.Path)
    ap.add_argument("--ref")
    ap.add_argument("--prepare", action="store_true")
    ap.add_argument("--run", action="store_true")
    ap.add_argument("--diff", nargs=2, metavar=("OLD", "NEW"))
    a = ap.parse_args()
    ref = a.ref or f"v{pinned_version()}"
    repo = ensure_repo(a.repo, a.ref or ref if not a.diff else a.diff[1])
    if a.prepare:
        prepare(repo, ref, checkout=a.repo is None)
    locs = locators()
    bad = 0
    if a.diff:
        old, new = a.diff
        for path, name in locs:
            bo, bn = (test_body(file_at(repo, r, path) or "", name) for r in (old, new))
            if bo is None or bn is None:
                bad += 1; print(f"MISSING  {path}::{name}  (old: {bo is not None}, new: {bn is not None})")
            elif bo != bn:
                print(f"CHANGED  {path}::{name}"); import difflib
                print("\n".join(difflib.unified_diff(bo.splitlines(), bn.splitlines(), old, new, lineterm="", n=1)))
            else:
                print(f"same     {path}::{name}")
        sys.exit(1 if bad else 0)
    for path, name in locs:
        src = file_at(repo, ref, path)
        if src is None:
            bad += 1; print(f"MISSING FILE  {path}  at {ref}"); continue
        if not test_pattern(name).search(src):
            bad += 1; print(f"MISSING TEST  {path}::{name}  at {ref}"); continue
        print(f"ok  {path}::{name}")
        if a.run:
            # --name is a regex over the full "group test" name: escape the
            # locator and anchor it, so "put" does not also run "put and get".
            r = sh("dart", "test", path.replace("objectbox_test/", ""),
                   "--name", r"(^|\s)" + re.escape(name) + "$",
                   cwd=repo / "objectbox_test", check=False)
            tail = (r.stdout.strip().splitlines() or [""])[-1]
            print(f"    {tail}")
            if r.returncode:
                bad += 1
    print(f"{len(locs)} locators checked at {ref}, {bad} problem(s)")
    sys.exit(1 if bad else 0)

if __name__ == "__main__":
    main()
