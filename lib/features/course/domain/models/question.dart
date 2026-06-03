import 'package:isar/isar.dart';
import 'unit.dart';

part 'question.g.dart';

enum QuestionStatus {
  incomplete,
  revisionNeeded,
  completed,
}

@collection
class Question {
  Id id = Isar.autoIncrement;

  late String title;

  int courseId = 0;
  int unitId = 0;
  int? topicId; // Kept for schema backwards compatibility, but unused now.

  @enumerated
  QuestionStatus status = QuestionStatus.incomplete;

  int difficulty = 3; // 1 to 5 stars

  String? notes;
  String? userNotes;

  List<String>? images; // Paths to local images

  DateTime? lastViewedAt;
  
  DateTime? createdAt;

  List<String>? plannerEventIds;

  final unitLink = IsarLink<Unit>();
}
