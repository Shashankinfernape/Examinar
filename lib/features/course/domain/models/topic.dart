import 'package:isar/isar.dart';
import 'unit.dart';
import 'question.dart';

part 'topic.g.dart';

@collection
class Topic {
  Id id = Isar.autoIncrement;

  late String name;

  @Backlink(to: 'topics')
  final unit = IsarLink<Unit>();

  final questions = IsarLinks<Question>();
}
// Note: This model is being phased out but kept for schema compatibility during migration.
