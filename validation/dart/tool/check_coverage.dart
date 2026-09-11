// Fails when the "Quick reference" table in the skill file and COVERAGE.md
// disagree on their first column (verbatim).
import 'dart:io';

const skillPath = '../../skills/objectbox/references/dart-flutter.md';
const coveragePath = 'COVERAGE.md';

Set<String> firstCells(String text, String header) {
  final out = <String>{};
  var inTable = false;
  for (final l in text.split('\n')) {
    if (l.startsWith(header)) {
      inTable = true;
      continue;
    }
    if (!inTable) continue;
    if (!l.startsWith('|')) break;
    if (l.startsWith('|---')) continue;
    out.add(l.split('|')[1].trim());
  }
  return out;
}

void main() {
  final skill = firstCells(
    File(skillPath).readAsStringSync(),
    '| Mistake | Why',
  );
  final cov = firstCells(
    File(coveragePath).readAsStringSync(),
    '| Mistake | Type',
  );
  final missing = skill.difference(cov), stale = cov.difference(skill);
  for (final m in missing) {
    stderr.writeln('no coverage row for: $m');
  }
  for (final s in stale) {
    stderr.writeln('coverage row without a skill row: $s');
  }
  if (missing.isNotEmpty || stale.isNotEmpty) exit(1);
  stdout.writeln('coverage check passed (${skill.length} rows)');
}
