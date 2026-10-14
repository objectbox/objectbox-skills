#!/usr/bin/env python3
"""Runs every ```python block of skills/objectbox/references/python.md, in order, in one namespace,
against the installed objectbox package (stores are in memory; files go to a temporary directory).
A snippet that raises fails the check: unlike Dart or Kotlin, Python has no compiler to prove the
API shape, so the snippets are executed.

  check_snippets.py [skill file]
"""
import os, pathlib, re, sys, tempfile, textwrap, traceback

HERE = pathlib.Path(__file__).resolve().parent
SKILL = HERE.parents[2] / "skills" / "objectbox" / "references" / "python.md"
BLOCK = re.compile(r"^([ \t]*)```python\n(.*?)^\1```", re.M | re.S)


def main():
    path = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else SKILL
    text = path.read_text()
    blocks = [(text.count("\n", 0, m.start()) + 2, textwrap.dedent(m.group(2))) for m in BLOCK.finditer(text)]
    if not blocks:
        sys.exit(f"no ```python blocks in {path}")
    import objectbox
    print(f"objectbox {objectbox.version} (C library {objectbox.version_core})")
    failed = 0
    with tempfile.TemporaryDirectory() as tmp:
        os.chdir(tmp)
        namespace = {"__name__": "snippets", "__file__": os.path.join(tmp, "snippets.py")}
        for line, code in blocks:
            try:
                exec(compile(code, f"{path.name}:{line}", "exec"), namespace)
                print(f"ok      {path.name}:{line}")
            except Exception:
                failed += 1
                print(f"FAILED  {path.name}:{line}")
                traceback.print_exc()
        for value in list(namespace.values()):
            if isinstance(value, objectbox.Store):
                value.close()
    print(f"{len(blocks)} snippets run, {failed} failed")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
