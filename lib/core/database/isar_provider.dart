import 'dart:io';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/course/domain/models/course.dart';
import '../../features/course/domain/models/unit.dart';
import '../../features/course/domain/models/topic.dart';
import '../../features/course/domain/models/question.dart';
import '../../features/planner/domain/models/planner_event.dart';

part 'isar_provider.g.dart';

@Riverpod(keepAlive: true)
Future<Isar> isar(IsarRef ref) async {
  Directory dir;
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    dir = await getApplicationSupportDirectory();
  } else {
    dir = await getApplicationDocumentsDirectory();
  }
  
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  final isarInstance = await Isar.open(
    [
      CourseSchema,
      UnitSchema,
      TopicSchema,
      QuestionSchema,
      PlannerEventSchema,
    ],
    directory: dir.path,
  );

  // MIGRATION: Scrub stars from existing question titles and assign difficulty
  final questionsWithStars = await isarInstance.questions.filter().titleContains('★').or().titleContains('☆').or().titleContains('*').findAll();
  if (questionsWithStars.isNotEmpty) {
    await isarInstance.writeTxn(() async {
      for (final q in questionsWithStars) {
        int stars = RegExp(r'[★☆⭐🌟\*]').allMatches(q.title).length;
        if (stars > 0) q.difficulty = stars > 5 ? 5 : stars;
        q.title = q.title.replaceAll(RegExp(r'[★☆⭐🌟\*]'), '').split('\n').first.trim();
        await isarInstance.questions.put(q);
      }
    });
  }

  return isarInstance;
}
