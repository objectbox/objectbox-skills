#!/usr/bin/env bash
# Runs every check for skills/objectbox/references/dart-flutter.md.
#
#   ./run.sh             sync-enabled native library (default: all tests run)
#   ./run.sh --non-sync  plain library (tests that write @Sync() types skip)
#
# The native library version follows the objectbox version pinned in
# pubspec.yaml. Delete lib/libobjectbox.* to switch variants.
set -euo pipefail
cd "$(dirname "$0")"

variant="--sync"
[ "${1:-}" = "--non-sync" ] && variant=""
version=$(grep -E '^\s+objectbox:' pubspec.yaml | awk '{print $2}')
if ! ls lib/libobjectbox.* >/dev/null 2>&1; then
  echo "Installing ObjectBox C library $version ${variant:-(non-sync)} into ./lib"
  bash <(curl -fsSL "https://raw.githubusercontent.com/objectbox/objectbox-dart/v$version/install.sh") --quiet $variant
fi

dart pub get
dart run build_runner build --delete-conflicting-outputs
dart run tool/check_snippets.dart
dart run tool/check_coverage.dart
python3 ../check_links.py
dart test
