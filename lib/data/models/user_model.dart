class UserModel {
  final int? id;
  final String name;
  final String level;
  final String? createdAt;

  UserModel({
    this.id,
    required this.name,
    required this.level,
    this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      level: map['level'] as String,
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'level': level,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'UserModel{id: $id, name: $name, level: $level}';
  }
}