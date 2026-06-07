import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../../../core/database/isar_provider.dart';
import '../../auth/data/auth_service.dart';
import '../../course/domain/models/course.dart';
import '../../course/domain/models/unit.dart';
import '../../course/domain/models/topic.dart';
import '../../course/domain/models/question.dart';
import '../../planner/domain/models/planner_event.dart';

final cloudSyncServiceProvider = FutureProvider<CloudSyncService>((ref) async {
  final isar = await ref.watch(isarProvider.future);
  final authService = ref.watch(authServiceProvider);
  return CloudSyncService(isar, FirebaseFirestore.instance, authService);
});

class CloudSyncService {
  final Isar _isar;
  final FirebaseFirestore _firestore;
  final AuthService _authService;

  CloudSyncService(this._isar, this._firestore, this._authService);

  Future<void> backupToCloud() async {
    final user = _authService.currentUser;
    if (user == null) throw Exception('User not logged in');

    // 1. Read all local data
    final courses = await _isar.courses.where().findAll();
    final units = await _isar.units.where().findAll();
    final topics = await _isar.topics.where().findAll();
    final questions = await _isar.questions.where().findAll();
    final events = await _isar.plannerEvents.where().findAll();

    // 2. Serialize to Maps
    final coursesMap = courses.map((c) => {
      'id': c.id,
      'name': c.name,
      'examDate': c.examDate?.millisecondsSinceEpoch,
      'colorTag': c.colorTag,
      'examStrategy': c.examStrategy,
    }).toList();

    final unitsMap = units.map((u) => {
      'id': u.id,
      'name': u.name,
      'index': u.index,
      'course_id': u.course.value?.id,
    }).toList();

    final topicsMap = topics.map((t) => {
      'id': t.id,
      'name': t.name,
      'unit_id': t.unit.value?.id,
    }).toList();

    final questionsMap = <Map<String, dynamic>>[];
    for (final q in questions) {
      final qMap = {
        'id': q.id,
        'title': q.title,
        'courseId': q.courseId,
        'unitId': q.unitId,
        'topicId': q.topicId,
        'status': q.status.index,
        'difficulty': q.difficulty,
        'notes': q.notes,
        'userNotes': q.userNotes,
        'lastViewedAt': q.lastViewedAt?.millisecondsSinceEpoch,
        'createdAt': q.createdAt?.millisecondsSinceEpoch,
        'plannerEventIds': q.plannerEventIds,
        'unitLink_id': q.unitLink.value?.id,
      };

      if (q.images != null && q.images!.isNotEmpty) {
        final cloudImages = <String>[];
        for (int i = 0; i < q.images!.length; i++) {
          final path = q.images![i];
          if (path.startsWith('firestore:')) {
            cloudImages.add(path); // Already backed up
          } else {
            final file = File(path);
            if (!await file.exists()) {
              throw Exception('Attached image file missing from device: $path. Please delete and re-attach it before backing up.');
            }
            
            final imageBytes = await file.readAsBytes();
            final decodedImage = img.decodeImage(imageBytes);
            if (decodedImage != null) {
              // Compress and resize to stay well under 1MB Firestore limit
              final resized = decodedImage.width > 1080 ? img.copyResize(decodedImage, width: 1080) : decodedImage;
              final compressed = img.encodeJpg(resized, quality: 60);
              final base64String = base64Encode(compressed);
              
              final imageId = 'q_${q.id}_img_$i';
              await _firestore.collection('users').doc(user.uid).collection('images').doc(imageId).set({
                'data': base64String,
                'createdAt': FieldValue.serverTimestamp(),
              });
              cloudImages.add('firestore:$imageId');
            } else {
              throw Exception('Failed to decode and compress image: $path. Format might be unsupported.');
            }
          }
        }
        qMap['images'] = cloudImages;
      }
      questionsMap.add(qMap);
    }

    final eventsMap = events.map((e) => {
      'id': e.id,
      'title': e.title,
      'startTime': e.startTime.millisecondsSinceEpoch,
      'endTime': e.endTime.millisecondsSinceEpoch,
      'questionIds': e.questionIds,
      'sessionType': e.sessionType.index,
      'colorHex': e.colorHex,
      'isCompleted': e.isCompleted,
    }).toList();

    // 3. Upload to Firestore
    final dataPayload = {
      'last_synced_at': FieldValue.serverTimestamp(),
      'courses': coursesMap,
      'units': unitsMap,
      'topics': topicsMap,
      'questions': questionsMap,
      'plannerEvents': eventsMap,
    };

    await _firestore.collection('users').doc(user.uid).set(dataPayload);
  }

  Future<void> restoreFromCloud() async {
    final user = _authService.currentUser;
    if (user == null) throw Exception('User not logged in');

    final docSnapshot = await _firestore.collection('users').doc(user.uid).get();
    if (!docSnapshot.exists || docSnapshot.data() == null) {
      throw Exception('No backup found in cloud');
    }

    final data = docSnapshot.data()!;

    final coursesList = List<Map<String, dynamic>>.from(data['courses'] ?? []);
    final unitsList = List<Map<String, dynamic>>.from(data['units'] ?? []);
    final topicsList = List<Map<String, dynamic>>.from(data['topics'] ?? []);
    final questionsList = List<Map<String, dynamic>>.from(data['questions'] ?? []);
    final eventsList = List<Map<String, dynamic>>.from(data['plannerEvents'] ?? []);

    // Setup local directory for downloaded images
    final docsDir = Platform.isWindows ? await getApplicationSupportDirectory() : await getApplicationDocumentsDirectory();
    final examinarImagesDir = Directory('${docsDir.path}/ExaminarImages');
    if (!await examinarImagesDir.exists()) {
      await examinarImagesDir.create(recursive: true);
    }

    // Wipe local Isar DB to overwrite
    await _isar.writeTxn(() async {
      await _isar.clear();

      // 1. Restore Courses
      for (var cMap in coursesList) {
        final c = Course()
          ..id = cMap['id']
          ..name = cMap['name']
          ..examDate = cMap['examDate'] != null ? DateTime.fromMillisecondsSinceEpoch(cMap['examDate']) : null
          ..colorTag = cMap['colorTag']
          ..examStrategy = cMap['examStrategy'];
        await _isar.courses.put(c);
      }

      // 2. Restore Units & Link to Course
      for (var uMap in unitsList) {
        final u = Unit()
          ..id = uMap['id']
          ..name = uMap['name']
          ..index = uMap['index'];
        await _isar.units.put(u);
        
        if (uMap['course_id'] != null) {
          final course = await _isar.courses.get(uMap['course_id']);
          if (course != null) {
            u.course.value = course;
            await u.course.save();
          }
        }
      }

      // 3. Restore Topics & Link to Unit
      for (var tMap in topicsList) {
        final t = Topic()
          ..id = tMap['id']
          ..name = tMap['name'];
        await _isar.topics.put(t);
        
        if (tMap['unit_id'] != null) {
          final unit = await _isar.units.get(tMap['unit_id']);
          if (unit != null) {
            t.unit.value = unit;
            await t.unit.save();
          }
        }
      }

      // 4. Restore Questions & Link to Unit
      for (var qMap in questionsList) {
        
        final images = <String>[];
        if (qMap['images'] != null) {
          for (var imgPath in qMap['images']) {
            if (imgPath.toString().startsWith('firestore:')) {
              final imageId = imgPath.toString().split(':')[1];
              try {
                final doc = await _firestore.collection('users').doc(user.uid).collection('images').doc(imageId).get();
                if (doc.exists && doc.data() != null && doc.data()!['data'] != null) {
                  final base64Data = doc.data()!['data'] as String;
                  final bytes = base64Decode(base64Data);
                  final localFile = File('${examinarImagesDir.path}/$imageId.jpg');
                  await localFile.writeAsBytes(bytes);
                  images.add(localFile.path); // Add the NEW absolute path to Isar
                }
              } catch (e) {
                // Ignore missing images and skip
              }
            } else {
              images.add(imgPath.toString());
            }
          }
        }

        final q = Question()
          ..id = qMap['id']
          ..title = qMap['title']
          ..courseId = qMap['courseId'] ?? 0
          ..unitId = qMap['unitId'] ?? 0
          ..topicId = qMap['topicId']
          ..status = QuestionStatus.values[qMap['status'] ?? 0]
          ..difficulty = qMap['difficulty'] ?? 3
          ..notes = qMap['notes']
          ..userNotes = qMap['userNotes']
          ..images = images.isNotEmpty ? images : null
          ..lastViewedAt = qMap['lastViewedAt'] != null ? DateTime.fromMillisecondsSinceEpoch(qMap['lastViewedAt']) : null
          ..createdAt = qMap['createdAt'] != null ? DateTime.fromMillisecondsSinceEpoch(qMap['createdAt']) : null
          ..plannerEventIds = qMap['plannerEventIds'] != null ? List<String>.from(qMap['plannerEventIds']) : null;
        await _isar.questions.put(q);

        if (qMap['unitLink_id'] != null) {
           final unit = await _isar.units.get(qMap['unitLink_id']);
           if (unit != null) {
             q.unitLink.value = unit;
             await q.unitLink.save();
           }
        }
      }

      // 5. Restore PlannerEvents
      for (var eMap in eventsList) {
        final e = PlannerEvent()
          ..id = eMap['id']
          ..title = eMap['title']
          ..startTime = DateTime.fromMillisecondsSinceEpoch(eMap['startTime'])
          ..endTime = DateTime.fromMillisecondsSinceEpoch(eMap['endTime'])
          ..questionIds = eMap['questionIds'] != null ? List<int>.from(eMap['questionIds']) : null
          ..sessionType = SessionType.values[eMap['sessionType'] ?? 0]
          ..colorHex = eMap['colorHex']
          ..isCompleted = eMap['isCompleted'] ?? false;
        await _isar.plannerEvents.put(e);
      }
    });
  }
}
