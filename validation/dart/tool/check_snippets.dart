// Extracts every ```dart block from the Dart/Flutter skill file, wraps each one
// so it resolves against this package, and runs the analyzer over the result.
// Any analyzer ERROR fails the check; warnings and infos are printed.
//
// Wrapping rules: a block with a top-level declaration (annotation, class, or a
// function signature at column 0) is emitted as-is; anything else is wrapped in
// an async function. Names the block declares are hidden from the entity and
// context imports so they don't clash. Free variables come from
// lib/snippet_context.dart.
import 'dart:io';

const skillPath = '../../skills/objectbox/references/dart-flutter.md';
const outDir = 'test/snippets';

const entityNames = {'Conversation', 'Message', 'Chunk', 'Tag'};
const contextNames = {
  'store',
  'box',
  'conversationBox',
  'messageBox',
  'chunkBox',
  'conversation',
  'message',
  'userId',
  'conversationId',
  'id',
  'queryVector',
  'maxCount',
  'tagBox',
  'tagNames',
  'dbDir',
  'idsInFile',
  'TestStoreHandle',
  'openTestStore',
};

/// Blocks matching any of these are skipped (with a reason).
final skipRules = {
  RegExp(r'Provider<'): 'Riverpod is not a dependency of this package',
};

final declLine = RegExp(
  r'^(@\w+|class\s|enum\s|mixin\s|typedef\s|(?:[A-Z]\w*(?:<[^;{]*>)?\??|bool|void|int|double|String)\s+\w+\s*\([^;]*\)\s*(?:async\s*)?\{)',
);
final declName = RegExp(
  r'^(?:class|enum|mixin)\s+(\w+)|^(?:[A-Z]\w*(?:<[^;{]*>)?\??|bool|void|int|double|String)\s+(\w+)\s*\(',
  multiLine: true,
);

void main() {
  final text = File(skillPath).readAsStringSync();
  final fence = RegExp(r'^```dart\n(.*?)^```', multiLine: true, dotAll: true);
  final dir = Directory(outDir)..createSync(recursive: true);
  for (final f in dir.listSync()) {
    f.deleteSync();
  }

  var total = 0, skipped = 0;
  for (final m in fence.allMatches(text)) {
    total++;
    final code = m.group(1)!;
    final line = text.substring(0, m.start).split('\n').length;
    final skip =
        skipRules.entries
            .where((e) => e.key.hasMatch(code))
            .map((e) => e.value)
            .firstOrNull;
    if (skip != null) {
      skipped++;
      stdout.writeln('skip  block at line $line: $skip');
      continue;
    }
    final isDecl = code.split('\n').any(declLine.hasMatch);
    final declared = {
      for (final d in declName.allMatches(code)) d.group(1) ?? d.group(2)!,
    };
    String hide(Set<String> names) {
      final h = names.intersection(declared);
      return h.isEmpty ? '' : ' hide ${h.join(', ')}';
    }

    final body = isDecl ? code : 'Future<dynamic> snippet() async {\n$code}\n';
    final out = '''
// GENERATED from dart-flutter.md line $line by tool/check_snippets.dart.
// ignore_for_file: unused_local_variable, unused_import, unused_element
// ignore_for_file: unused_field, unnecessary_import, undefined_hidden_name
import 'dart:async';
import 'dart:io';

import 'package:objectbox/objectbox.dart';
import 'package:test/test.dart';

import 'package:objectbox_skill_validation/entities.dart'${hide(entityNames)};
import 'package:objectbox_skill_validation/objectbox.g.dart';
import 'package:objectbox_skill_validation/snippet_context.dart'${hide(contextNames)};

$body''';
    final name = 'snippet_${total.toString().padLeft(2, '0')}_line$line.dart';
    File('$outDir/$name').writeAsStringSync(out);
  }
  stdout.writeln(
    'extracted ${total - skipped} of $total dart blocks to $outDir',
  );

  final result = Process.runSync('dart', [
    'analyze',
    '--format=machine',
    outDir,
  ]);
  final rows =
      (result.stdout as String)
          .split('\n')
          .where((l) => l.contains('|'))
          .map((l) => l.split('|'))
          .toList();
  var errors = 0;
  for (final r in rows) {
    final severity = r[0], code = r[2], file = r[3].split('/').last;
    final ln = r[4], msg = r.sublist(7).join('|');
    if (severity == 'ERROR') errors++;
    stdout.writeln('$severity $file:$ln $code: $msg');
  }
  if (result.stderr.toString().trim().isNotEmpty) stderr.writeln(result.stderr);
  if (errors > 0) {
    stderr.writeln('FAILED: $errors analyzer error(s) in skill snippets');
    exit(1);
  }
  stdout.writeln('snippet check passed (${rows.length} non-error diagnostics)');
}
