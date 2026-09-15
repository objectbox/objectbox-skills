// Free variables that the snippets in java-kotlin.md use without declaring them, and the one
// entity no snippet declares. Compiled, never run. The snippets star-import this package, so a
// name a snippet declares itself (e.g. the Testing section's `store`) shadows the one here.
@file:Suppress("unused")

package io.objectbox.skill.context

import io.objectbox.Box
import io.objectbox.BoxStore
import io.objectbox.annotation.Entity
import io.objectbox.annotation.HnswIndex
import io.objectbox.annotation.Id
import io.objectbox.annotation.VectorDistanceType
import io.objectbox.skill.snippets.Conversation
import io.objectbox.skill.snippets.Message

lateinit var store: BoxStore
lateinit var conversationBox: Box<Conversation>
lateinit var messageBox: Box<Message>
lateinit var chunkBox: Box<Chunk>
lateinit var queryVector: FloatArray
lateinit var userId: String
var maxCount: Int = 10

/** The vector search section points at the docs and the City example for the entity shape. */
@Entity
class Chunk(@Id var id: Long = 0, var text: String = "") {
    @HnswIndex(dimensions = 384, distanceType = VectorDistanceType.COSINE)
    var embeddingVector: FloatArray? = null
}
