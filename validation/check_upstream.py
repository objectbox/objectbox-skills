#!/usr/bin/env python3
"""Resolves the upstream test locators in validation/<binding>/COVERAGE.md
against the upstream repositories, without running anything.

A locator claims that a test at the pinned upstream version asserts the row's
behavior. Running those tests is pointless (the upstream CI already did, at
that tag); what can silently go wrong is the test being renamed, removed, or
rewritten along with a behavior change. Hence two modes:

  check_upstream.py [--binding B] [--repo NAME=PATH]... [--ref REF]   every locator exists at REF
  check_upstream.py [--binding B] --diff [OLD] NEW                    cited test bodies changed?

Locator forms:
  dart   objectbox_test/test/<file>.dart::<exact test name>            (objectbox-dart)
  java   <repo>:<path>.java::<method>  or  <repo>:<path>.kt::<method>  (objectbox-java,
         objectbox-integration-test)

REF defaults to the pinned tag: v<objectbox version from validation/dart/pubspec.yaml>
for Dart, V<objectbox version from validation/java/gradle/libs.versions.toml>
for both Java repositories; so does OLD. Without --repo, a repository is cloned
blob-less into validation/.cache/ from its remote (env OBJECTBOX_DART_REPO,
OBJECTBOX_JAVA_REPO, OBJECTBOX_INTEGRATION_TEST_REPO). objectbox-integration-test
is internal and has no default remote: its locators are skipped unless the env
var or --repo names a checkout. Exit status is non-zero when a locator is
missing or, with --diff, when a cited test changed: read that test before
trusting the row again (see AGENTS.md).
"""
import argparse, difflib, os, re, subprocess, sys, pathlib

HERE = pathlib.Path(__file__).resolve().parent
CACHE = HERE / ".cache"


def sh(*cmd, cwd=None, check=True):
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, check=check)


def dart_pin():
    text = (HERE / "dart" / "pubspec.yaml").read_text()
    return "v" + re.search(r"^\s+objectbox:\s*(\S+)", text, re.M).group(1)


def java_pin():
    text = (HERE / "java" / "gradle" / "libs.versions.toml").read_text()
    return "V" + re.search(r'^objectbox\s*=\s*"([^"]+)"', text, re.M).group(1)


def dart_test_body(src, name):
    m = re.search(r"\btest\(\s*(['\"])" + re.escape(name) + r"\1", src or "")
    if not m:
        return None
    col = m.start() - src.rfind("\n", 0, m.start()) - 1
    nxt = re.compile(r"\n {%d}(test\(|group\(|\}\);?$)" % col, re.M).search(src, m.end())
    return src[m.start(): nxt.start() if nxt else len(src)]


def junit_test_body(src, name):
    """A JUnit method (Java or Kotlin): from its @Test annotation to the closing brace at the
    method's indentation."""
    m = re.search(r"^([ \t]*)@Test\b[^\n]*\n(?:\1@[^\n]*\n)*\1(?:[\w<>\[\], ]+\s)?(?:void|fun)\s+"
                  + re.escape(name) + r"\s*\(", src or "", re.M)
    if not m:
        return None
    indent = m.group(1)
    end = re.compile(r"^" + indent + r"\}[ \t]*$", re.M).search(src, m.end())
    return src[m.start(): end.end() if end else len(src)]


BINDINGS = {
    "dart": dict(
        coverage=HERE / "dart" / "COVERAGE.md",
        locator=re.compile(r"()(objectbox_test/test/[\w/]+\.dart)::([^|`\n]+?)(?=\s*[|`]|\s*;|\s*$)"),
        default_repo="objectbox-dart",
        body=dart_test_body,
        repos={"objectbox-dart": dict(
            remote=os.environ.get("OBJECTBOX_DART_REPO", "https://github.com/objectbox/objectbox-dart.git"),
            pin=dart_pin)},
    ),
    "java": dict(
        coverage=HERE / "java" / "COVERAGE.md",
        locator=re.compile(r"(objectbox-java|objectbox-integration-test):([\w/.-]+\.(?:java|kt))::(\w+)"),
        default_repo=None,
        body=junit_test_body,
        repos={
            "objectbox-java": dict(
                remote=os.environ.get("OBJECTBOX_JAVA_REPO", "https://github.com/objectbox/objectbox-java.git"),
                pin=java_pin),
            "objectbox-integration-test": dict(
                remote=os.environ.get("OBJECTBOX_INTEGRATION_TEST_REPO"),  # internal, none by default
                pin=java_pin),
        },
    ),
}


def ensure_repo(name, spec, override, refs):
    repo = override
    if repo is None:
        if spec["remote"] is None:
            return None
        repo = CACHE / name
        if not repo.exists():
            repo.parent.mkdir(parents=True, exist_ok=True)
            sh("git", "clone", "--quiet", "--filter=blob:none", "--no-checkout", spec["remote"], str(repo))
        sh("git", "fetch", "--quiet", "--tags", "origin", cwd=repo)
    for ref in refs:
        if sh("git", "rev-parse", "--verify", "--quiet", f"{ref}^{{commit}}", cwd=repo, check=False).returncode:
            sys.exit(f"ref {ref!r} not found in {repo} ({name})")
    return pathlib.Path(repo)


def locators(binding):
    found = set()
    for line in binding["coverage"].read_text().splitlines():
        for m in binding["locator"].finditer(line):
            found.add((m.group(1) or binding["default_repo"], m.group(2), m.group(3).strip()))
    return sorted(found)


def file_at(repo, ref, path):
    r = sh("git", "show", f"{ref}:{path}", cwd=repo, check=False)
    return r.stdout if r.returncode == 0 else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--binding", choices=sorted(BINDINGS), default="dart")
    ap.add_argument("--repo", action="append", default=[], metavar="[NAME=]PATH",
                    help="local checkout to use instead of cloning; NAME may be omitted for a single-repo binding")
    ap.add_argument("--ref", help="check at this ref instead of the pinned tag (all repos of the binding)")
    ap.add_argument("--diff", nargs="+", metavar="REF", help="[OLD] NEW; OLD defaults to the pinned tag")
    a = ap.parse_args()
    binding = BINDINGS[a.binding]
    overrides = {}
    for item in a.repo:
        name, _, path = item.rpartition("=")
        overrides[name or binding["default_repo"]] = pathlib.Path(path)
    body = binding["body"]
    bad = 0
    if a.diff:
        new = a.diff[-1]
        for name, spec in binding["repos"].items():
            old = a.diff[0] if len(a.diff) == 2 else spec["pin"]()
            repo = ensure_repo(name, spec, overrides.get(name), [old, new])
            if repo is None:
                print(f"skip     {name}: no repository configured (set OBJECTBOX_INTEGRATION_TEST_REPO or --repo)")
                continue
            for rname, path, test in locators(binding):
                if rname != name:
                    continue
                bo, bn = (body(file_at(repo, r, path), test) for r in (old, new))
                if bo is None or bn is None:
                    bad += 1; print(f"MISSING  {name}:{path}::{test}  (in {old}: {bo is not None}, in {new}: {bn is not None})")
                elif bo != bn:
                    bad += 1; print(f"CHANGED  {name}:{path}::{test}")
                    print("\n".join(difflib.unified_diff(bo.splitlines(), bn.splitlines(), old, new, lineterm="", n=1)))
                else:
                    print(f"same     {name}:{path}::{test}")
            print(f"{name}: {old} -> {new}")
        print(f"{len(locators(binding))} cited tests compared: {bad} to review")
        sys.exit(1 if bad else 0)
    for name, spec in binding["repos"].items():
        ref = a.ref or spec["pin"]()
        repo = ensure_repo(name, spec, overrides.get(name), [ref])
        if repo is None:
            n = sum(1 for r, _, _ in locators(binding) if r == name)
            print(f"skip  {name}: {n} locators not checked, no repository configured"
                  " (set OBJECTBOX_INTEGRATION_TEST_REPO or --repo)")
            continue
        for rname, path, test in locators(binding):
            if rname != name:
                continue
            if body(file_at(repo, ref, path), test) is None:
                bad += 1; print(f"MISSING  {name}:{path}::{test}  at {ref}")
            else:
                print(f"ok  {name}:{path}::{test}")
    print(f"{len(locators(binding))} locators checked, {bad} missing")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
