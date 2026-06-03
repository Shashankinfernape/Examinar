import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:exam_command_center/core/database/isar_provider.dart';
import '../../domain/models/question.dart';
import '../../domain/models/unit.dart';

part 'question_repository.g.dart';

class QuestionRepository {
  final Isar isar;

  QuestionRepository(this.isar);

  int _parseDifficulty(String title) {
    int stars = RegExp(r'[★☆⭐🌟\*]').allMatches(title).length;
    if (stars == 0) return 3;
    return stars > 5 ? 5 : stars;
  }

  String _cleanTitle(String title) {
    return title.replaceAll(RegExp(r'[★☆⭐🌟\*]'), '').split('\n').first.trim();
  }

  Future<void> addQuestion(String title, int unitId, {int? courseId}) async {
    await isar.writeTxn(() async {
      final unit = await isar.units.get(unitId);
      if (unit == null) return;

      final question = Question()
        ..title = _cleanTitle(title)
        ..difficulty = _parseDifficulty(title)
        ..unitId = unitId
        ..courseId = courseId ?? 0
        ..createdAt = DateTime.now();
      
      await isar.questions.put(question);
      
      question.unitLink.value = unit;
      await question.unitLink.save();
    });
  }

  // Helper for internal use (like Paste & Build)
  Question createQuestionObject(String title, int unitId) {
    return Question()
      ..title = _cleanTitle(title)
      ..difficulty = _parseDifficulty(title)
      ..unitId = unitId
      ..createdAt = DateTime.now();
  }

  Future<void> updateStatus(int questionId, QuestionStatus newStatus) async {
    await isar.writeTxn(() async {
      final question = await isar.questions.get(questionId);
      if (question == null) return;

      question.status = newStatus;
      question.lastViewedAt = DateTime.now();
      await isar.questions.put(question);
    });
  }

  Future<void> updateDifficulty(int questionId, int stars) async {
    await isar.writeTxn(() async {
      final question = await isar.questions.get(questionId);
      if (question == null) return;

      question.difficulty = stars;
      await isar.questions.put(question);
    });
  }

  Future<void> deleteQuestion(int questionId) async {
    await isar.writeTxn(() async {
      await isar.questions.delete(questionId);
    });
  }

  Future<List<Question>> getQuestionsForUnit(int unitId) async {
    return isar.questions.where().filter().unitIdEqualTo(unitId).findAll();
  }

  Future<List<Question>> getQuestionsForCourse(int courseId) async {
    return isar.questions.where().filter().courseIdEqualTo(courseId).findAll();
  }

  Future<List<Question>> getRevisionQueue() async {
    return isar.questions.where()
        .filter()
        .statusEqualTo(QuestionStatus.revisionNeeded)
        .sortByLastViewedAt()
        .findAll();
  }
}

@riverpod
Future<QuestionRepository> questionRepository(QuestionRepositoryRef ref) async {
  final isar = await ref.watch(isarProvider.future);
  return QuestionRepository(isar);
}
