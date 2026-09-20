enum SessionType {
  study,
  revision,
  mock,
}

class PlannerEvent {
  String id;
  String title;
  DateTime startTime;
  DateTime endTime;
  List<String>? questionIds;
  SessionType sessionType;
  String? colorHex;
  bool isCompleted;

  PlannerEvent({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.questionIds,
    this.sessionType = SessionType.study,
    this.colorHex,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'questionIds': questionIds,
      'sessionType': sessionType.name,
      'colorHex': colorHex,
      'isCompleted': isCompleted,
    };
  }

  factory PlannerEvent.fromMap(Map<String, dynamic> map, String docId) {
    return PlannerEvent(
      id: docId,
      title: map['title'] ?? '',
      startTime: map['startTime'] != null ? DateTime.parse(map['startTime']) : DateTime.now(),
      endTime: map['endTime'] != null ? DateTime.parse(map['endTime']) : DateTime.now(),
      questionIds: map['questionIds'] != null ? List<String>.from(map['questionIds']) : null,
      sessionType: SessionType.values.firstWhere((e) => e.name == map['sessionType'], orElse: () => SessionType.study),
      colorHex: map['colorHex'],
      isCompleted: map['isCompleted'] ?? false,
    );
  }
}
