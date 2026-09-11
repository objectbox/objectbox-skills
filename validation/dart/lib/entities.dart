import 'package:objectbox/objectbox.dart';

// The entity shapes the snippets in dart-flutter.md refer to. Only analyzed
// against, never run: behavior is verified by objectbox-dart's own tests, see
// COVERAGE.md.

/// Entity declaration, Relations, Cascade deletes, Reactive streams: sync-enabled entity with a to-many backlink.
@Entity()
@Sync()
class Conversation {
  @Id()
  int id = 0;
  @Index()
  String userId = '';
  String title = '';
  @Property(type: PropertyType.date)
  DateTime updatedAt = DateTime.now();

  @Backlink('conversation')
  final messages = ToMany<Message>();

  Conversation({this.id = 0, this.userId = '', this.title = ''});
}

/// Relations, attach(), mirror-int, Cascade deletes: to-one side of the relation.
@Entity()
@Sync()
class Message {
  @Id()
  int id = 0;
  String body = '';

  final conversation = ToOne<Conversation>();

  Message({this.id = 0, this.body = ''});
}

/// Vector search: explicit cosine distance.
@Entity()
class Chunk {
  @Id()
  int id = 0;
  String text = '';

  @HnswIndex(dimensions: 3, distanceType: VectorDistanceType.cosine)
  @Property(type: PropertyType.floatVector)
  List<double>? embedding;

  Chunk({this.id = 0, this.text = '', this.embedding});
}
