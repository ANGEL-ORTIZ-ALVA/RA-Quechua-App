class ModuleModel {
  final int? id;
  final String name;
  final String nameQuechua;
  final String description;
  final String icon;
  final int orderIndex;

  ModuleModel({
    this.id,
    required this.name,
    required this.nameQuechua,
    required this.description,
    required this.icon,
    required this.orderIndex,
  });

  factory ModuleModel.fromMap(Map<String, dynamic> map) {
    return ModuleModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      nameQuechua: map['name_quechua'] as String,
      description: map['description'] as String,
      icon: map['icon'] as String,
      orderIndex: map['order_index'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'name_quechua': nameQuechua,
      'description': description,
      'icon': icon,
      'order_index': orderIndex,
    };
  }

  @override
  String toString() {
    return 'ModuleModel{id: $id, name: $name, nameQuechua: $nameQuechua}';
  }
}