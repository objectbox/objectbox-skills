#!/usr/bin/env bash
# Runs every check for skills/objectbox/references/python.md: the coverage and link checkers, every
# ```python block executed in order against the pinned objectbox version (requirements.txt), then
# resolution of the cited objectbox-python tests at the pinned tag (a blob-less clone in
# validation/.cache/, made on first use). Behavior is asserted by objectbox-python's test suite,
# see COVERAGE.md.
# PYTHON: an interpreter that already has the objectbox package to check against (e.g. a locally
# built wheel); without it, validation/python/.venv is created from requirements.txt.
# Arguments are passed to check_upstream.py, e.g. --repo objectbox-python=<checkout> --ref <commit>.
set -euo pipefail
cd "$(dirname "$0")"

python3 ../check_coverage.py ../../skills/objectbox/references/python.md COVERAGE.md
python3 ../check_links.py
if [ -z "${PYTHON:-}" ]; then
  [ -x .venv/bin/python ] || python3 -m venv .venv
  .venv/bin/python -m pip install --quiet --requirement requirements.txt
  PYTHON=.venv/bin/python
fi
"$PYTHON" tool/check_snippets.py
python3 ../check_upstream.py --binding python "$@"
