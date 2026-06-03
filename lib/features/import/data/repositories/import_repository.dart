import 'dart:convert';
import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:exam_command_center/core/database/isar_provider.dart';
import 'package:exam_command_center/features/course/domain/models/course.dart';
import 'package:exam_command_center/features/course/domain/models/unit.dart';
import 'package:exam_command_center/features/course/domain/models/topic.dart';
import 'package:exam_command_center/features/course/domain/models/question.dart';

part 'import_repository.g.dart';

class ImportRepository {
  final Isar isar;

  ImportRepository(this.isar);

  Future<void> importFromJson(String jsonString) async {
    final data = jsonDecode(jsonString);
    
    await isar.writeTxn(() async {
      final courseData = data['course'];
      final course = Course()
        ..name = courseData['name']
        ..examDate = courseData['examDate'] != null ? DateTime.parse(courseData['examDate']) : null
        ..colorTag = courseData['colorTag'];
      
      await isar.courses.put(course);

      if (courseData['units'] != null) {
        for (var unitData in courseData['units']) {
          final unit = Unit()
            ..name = unitData['name']
            ..index = unitData['index'];
          
          await isar.units.put(unit);
          course.units.add(unit);

          if (unitData['topics'] != null) {
            for (var topicData in unitData['topics']) {
              final topic = Topic()..name = topicData['name'];
              await isar.topics.put(topic);
              unit.topics.add(topic);

              if (topicData['questions'] != null) {
                for (var qData in topicData['questions']) {
                  final question = Question()
                    ..title = qData['title']
                    ..notes = qData['notes']
                    ..difficulty = qData['confidenceScore'] ?? 3
                    ..createdAt = DateTime.now();
                  
                  await isar.questions.put(question);
                  topic.questions.add(question);
                  question.unitLink.value = unit;
                  await question.unitLink.save();
                }
              }
              await unit.topics.save();
            }
          }
        }
      }
      await course.units.save();
    });
  }
}

@riverpod
Future<ImportRepository> importRepository(ImportRepositoryRef ref) async {
  final isar = await ref.watch(isarProvider.future);
  return ImportRepository(isar);
}
