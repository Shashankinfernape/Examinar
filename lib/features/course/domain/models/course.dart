class Course {
  String id;
  String name;
  DateTime? examDate;
  String? colorTag;
  String? examStrategy;

  Course({
    required this.id,
    required this.name,
    this.examDate,
    this.colorTag,
    this.examStrategy,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'examDate': examDate?.toIso8601String(),
      'colorTag': colorTag,
      'examStrategy': examStrategy,
    };
  }

  factory Course.fromMap(Map<String, dynamic> map, String docId) {
    return Course(
      id: docId,
      name: map['name'] ?? '',
      examDate: map['examDate'] != null ? DateTime.parse(map['examDate']) : null,
      colorTag: map['colorTag'],
      examStrategy: map['examStrategy'],
    );
  }
}
