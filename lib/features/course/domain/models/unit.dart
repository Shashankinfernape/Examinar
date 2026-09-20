class Unit {
  String id;
  String name;
  int? index;
  String courseId;

  Unit({
    required this.id,
    required this.name,
    this.index,
    required this.courseId,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'index': index,
      'courseId': courseId,
    };
  }

  factory Unit.fromMap(Map<String, dynamic> map, String docId) {
    return Unit(
      id: docId,
      name: map['name'] ?? '',
      index: map['index'],
      courseId: map['courseId'] ?? '',
    );
  }
}
