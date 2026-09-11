import 'package:objectbox/objectbox.dart';

// Mirrors the entity shapes used in dart-flutter.md so the snippet check and
// the behavior tests share one generated model.

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

/// Vector search: default distance type.
@Entity()
class ChunkDefault {
  @Id()
  int id = 0;

  @HnswIndex(dimensions: 3)
  @Property(type: PropertyType.floatVector)
  List<double>? embedding;

  ChunkDefault({this.id = 0, this.embedding});
}

enum Role { unknown, author, admin }

/// Transient fields and enums: transient field and the docs' enum mapping pattern.
@Entity()
class User {
  @Id()
  int id = 0;
  String name = '';

  @Transient()
  String? draft;

  @Transient()
  Role role = Role.unknown;

  int get dbRole => role.index;
  set dbRole(int value) => role = value >= 0 && value < Role.values.length
      ? Role.values[value]
      : Role.unknown;

  User({this.id = 0, this.name = ''});
}

/// Entity declaration: every DateTime storage type side by side.
@Entity()
class DateEntity {
  @Id()
  int id = 0;

  /// No annotation: the generator picks PropertyType.date (and warns).
  DateTime? plain;

  @Property(type: PropertyType.date)
  DateTime? date;

  @Property(type: PropertyType.dateUtc)
  DateTime? dateUtc;

  @Property(type: PropertyType.dateNano)
  DateTime? dateNano;

  @Property(type: PropertyType.dateNanoUtc)
  DateTime? dateNanoUtc;
}
