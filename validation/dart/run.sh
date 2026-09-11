#!/usr/bin/env bash
# Runs every check for skills/objectbox/references/dart-flutter.md:
# snippet analysis against the pinned objectbox version, the coverage and
# link checkers, and the cited objectbox-dart tests at the pinned tag
# (cloned into validation/.cache/ on first use).
#
#   ./run.sh             everything
#   ./run.sh --static    skip the upstream test run
set -euo pipefail
cd "$(dirname "$0")"

dart pub get
dart run build_runner build --delete-conflicting-outputs
dart run tool/check_snippets.dart
dart run tool/check_coverage.dart
python3 ../check_links.py
if [ "${1:-}" = "--static" ]; then
  python3 ../check_upstream.py
else
  python3 ../check_upstream.py --prepare --run
fi
