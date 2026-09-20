enum QuestionStatus {
  incomplete,
  revisionNeeded,
  completed,
}

class Question {
  String id;
  String title;
  String courseId;
  String unitId;
  QuestionStatus status;
  int difficulty;
  String? notes;
  String? userNotes;
  List<String>? images;
  DateTime? lastViewedAt;
  DateTime? createdAt;
  List<String>? plannerEventIds;

  Question({
    required this.id,
    required this.title,
    required this.courseId,
    required this.unitId,
    this.status = QuestionStatus.incomplete,
    this.difficulty = 3,
    this.notes,
    this.userNotes,
    this.images,
    this.lastViewedAt,
    this.createdAt,
    this.plannerEventIds,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'courseId': courseId,
      'unitId': unitId,
      'status': status.name,
      'difficulty': difficulty,
      'notes': notes,
      'userNotes': userNotes,
      'images': images,
      'lastViewedAt': lastViewedAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'plannerEventIds': plannerEventIds,
    };
  }

  factory Question.fromMap(Map<String, dynamic> map, String docId) {
    return Question(
      id: docId,
      title: map['title'] ?? '',
      courseId: map['courseId'] ?? '',
      unitId: map['unitId'] ?? '',
      status: QuestionStatus.values.firstWhere((e) => e.name == map['status'], orElse: () => QuestionStatus.incomplete),
      difficulty: map['difficulty'] ?? 3,
      notes: map['notes'],
      userNotes: map['userNotes'],
      images: map['images'] != null ? List<String>.from(map['images']) : null,
      lastViewedAt: map['lastViewedAt'] != null ? DateTime.parse(map['lastViewedAt']) : null,
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,
      plannerEventIds: map['plannerEventIds'] != null ? List<String>.from(map['plannerEventIds']) : null,
    );
  }
}
