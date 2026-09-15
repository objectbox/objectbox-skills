#!/usr/bin/env bash
# Runs every check for skills/objectbox/references/java-kotlin.md: the coverage
# and link checkers, then resolution of the cited objectbox-java and
# objectbox-integration-test tests at the pinned tags (blob-less clones in
# validation/.cache/, made on first use). There is no Gradle project here:
# behavior is asserted by the upstream suites, see COVERAGE.md.
set -euo pipefail
cd "$(dirname "$0")"

python3 ../check_coverage.py ../../skills/objectbox/references/java-kotlin.md COVERAGE.md
python3 ../check_links.py
python3 ../check_upstream.py --binding java "$@"
