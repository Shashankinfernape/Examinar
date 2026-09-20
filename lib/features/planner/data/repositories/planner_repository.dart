import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:exam_command_center/core/database/firestore_provider.dart';
import '../../domain/models/planner_event.dart';

part 'planner_repository.g.dart';

class PlannerRepository {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  PlannerRepository(this.firestore, this.auth);

  String get uid {
    final currentUser = auth.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');
    return currentUser.uid;
  }

  CollectionReference<Map<String, dynamic>> get _eventsRef => firestore.collection('users').doc(uid).collection('plannerEvents');

  Future<void> addEvent(PlannerEvent event) async {
    final docRef = (event.id == null || event.id.isEmpty) ? _eventsRef.doc() : _eventsRef.doc(event.id);
    event.id = docRef.id;
    await docRef.set(event.toMap());
  }

  Future<void> updateEvent(PlannerEvent event) async {
    await _eventsRef.doc(event.id).update(event.toMap());
  }

  Future<void> deleteEvent(String id) async {
    await _eventsRef.doc(id).delete();
  }

  Future<List<PlannerEvent>> getAllEvents() async {
    final snapshot = await _eventsRef.get();
    return snapshot.docs.map((doc) => PlannerEvent.fromMap(doc.data(), doc.id)).toList();
  }

  Stream<List<PlannerEvent>> watchAllEvents() {
    return _eventsRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => PlannerEvent.fromMap(doc.data(), doc.id)).toList();
    });
  }
}

@riverpod
PlannerRepository plannerRepository(PlannerRepositoryRef ref) {
  final fs = ref.watch(firestoreProvider);
  final auth = ref.watch(firebaseAuthProvider);
  return PlannerRepository(fs, auth);
}
