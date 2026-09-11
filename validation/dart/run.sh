#!/usr/bin/env bash
# Runs every check for skills/objectbox/references/dart-flutter.md:
# snippet analysis against the pinned objectbox version, the coverage and
# link checkers, and resolution of the cited objectbox-dart tests at the
# pinned tag (a blob-less clone in validation/.cache/, made on first use).
set -euo pipefail
cd "$(dirname "$0")"

dart pub get
dart run build_runner build
dart run tool/check_snippets.dart
dart run tool/check_coverage.dart
python3 ../check_links.py
python3 ../check_upstream.py
