#!/usr/bin/env bash
# Runs every check for skills/objectbox/references/java-kotlin.md: the coverage
# and link checkers, compilation of every ```kotlin block against the pinned
# ObjectBox version (Gradle, code generation included, nothing is executed),
# then resolution of the cited objectbox-java tests at the pinned tag (a
# blob-less clone in validation/.cache/, made on first use). The cited
# objectbox-integration-test tests are only resolved when that internal
# repository is configured (OBJECTBOX_INTEGRATION_TEST_REPO or --repo).
# Behavior is asserted by the upstream suites, see COVERAGE.md.
set -euo pipefail
cd "$(dirname "$0")"

python3 ../check_coverage.py ../../skills/objectbox/references/java-kotlin.md COVERAGE.md
python3 ../check_links.py
python3 tool/extract_snippets.py
./gradlew --quiet --console=plain compileKotlin
python3 ../check_upstream.py --binding java "$@"
