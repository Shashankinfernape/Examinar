class Topic {
  String id;
  String name;
  String unitId;

  Topic({
    required this.id,
    required this.name,
    required this.unitId,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'unitId': unitId,
    };
  }

  factory Topic.fromMap(Map<String, dynamic> map, String docId) {
    return Topic(
      id: docId,
      name: map['name'] ?? '',
      unitId: map['unitId'] ?? '',
    );
  }
}
// Note: This model is being phased out but kept for schema compatibility during migration.
