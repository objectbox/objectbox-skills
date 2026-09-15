#!/usr/bin/env python3
"""Extracts every ```kotlin block from the Java/Kotlin skill file into
src/main/kotlin/io/objectbox/skill/snippets/, one file per block, so that
`./gradlew compileKotlin` compiles them against the pinned ObjectBox version.

Wrapping rules mirror validation/dart/tool/check_snippets.dart: a block with a
top-level declaration (annotation, class, function, property modifier at
column 0) is emitted as-is; anything else is wrapped in a function. Every file
star-imports the ObjectBox packages and the snippet context
(src/main/kotlin/io/objectbox/skill/context/); `Sync` exists both as an
annotation and as the client factory, so the one the block uses is imported
explicitly. Blocks matching a skip rule are reported and left out.
"""
import pathlib, re, sys

HERE = pathlib.Path(__file__).resolve().parent
SKILL = HERE.parents[2] / "skills" / "objectbox" / "references" / "java-kotlin.md"
OUT = HERE.parent / "src" / "main" / "kotlin" / "io" / "objectbox" / "skill" / "snippets"

SKIP_RULES = {
    re.compile(r"^plugins\s*\{", re.M): "Gradle build script, not Kotlin source",
}
DECL_LINE = re.compile(
    r"^(@\w+|(?:private |internal |public )?(?:fun |class |data class |object |lateinit |abstract |open )|import |package )",
    re.M)
HEADER = """// GENERATED from java-kotlin.md line {line} by tool/extract_snippets.py. Do not edit.
@file:Suppress("unused", "UNUSED_VARIABLE", "UNUSED_PARAMETER", "DEPRECATION", "PropertyName",
    "ObjectPropertyName", "ClassName", "FunctionName", "RedundantSuppression")

package io.objectbox.skill.snippets

import io.objectbox.*
import io.objectbox.annotation.*
import io.objectbox.kotlin.*
import io.objectbox.query.*
import io.objectbox.reactive.*
import io.objectbox.relation.*
import io.objectbox.sync.*
import io.objectbox.skill.context.*
import java.io.File
import java.nio.file.Files
import org.junit.After
import org.junit.Before
{sync_import}
"""


def main():
    text = SKILL.read_text()
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("*.kt"):
        old.unlink()
    total = skipped = 0
    for m in re.finditer(r"^```kotlin\n(.*?)^```", text, re.M | re.S):
        total += 1
        code = m.group(1)
        line = text.count("\n", 0, m.start()) + 1
        reason = next((r for rule, r in SKIP_RULES.items() if rule.search(code)), None)
        if reason:
            skipped += 1
            print(f"skip  block at line {line}: {reason}")
            continue
        if "@Sync" in code:
            sync_import = "import io.objectbox.annotation.Sync\n"
        elif re.search(r"\bSync\.", code):
            sync_import = "import io.objectbox.sync.Sync\n"
        else:
            sync_import = ""
        body = code if DECL_LINE.search(code) else f"fun snippet{total}() {{\n{code}}}\n"
        name = f"Snippet{total:02d}Line{line}.kt"
        (OUT / name).write_text(HEADER.format(line=line, sync_import=sync_import) + body)
    print(f"extracted {total - skipped} of {total} kotlin blocks to {OUT.relative_to(HERE.parent)}")
    if total == 0:
        sys.exit("no kotlin blocks found")


if __name__ == "__main__":
    main()
