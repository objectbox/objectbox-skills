// Compiles the ```kotlin blocks of java-kotlin.md (extracted by tool/extract_snippets.py into
// src/main/kotlin/io/objectbox/skill/snippets/) against the pinned ObjectBox version, with the
// annotation processor generating the *_ classes and MyObjectBox like a user project would.
// Nothing here is ever run: there are no tests and no native library is loaded.
plugins {
    alias(libs.plugins.kotlin.jvm)
    alias(libs.plugins.kotlin.kapt)
    alias(libs.plugins.objectbox)
}

dependencies {
    implementation(libs.objectbox.java)
    implementation(libs.objectbox.kotlin)
    // The Testing section's snippet uses JUnit's @Before and @After.
    implementation(libs.junit)
}

kapt {
    arguments {
        // Entities live in two packages (context and snippets); put MyObjectBox where the snippets are.
        arg("objectbox.myObjectBoxPackage", "io.objectbox.skill.snippets")
    }
}
