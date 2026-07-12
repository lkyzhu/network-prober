class Module {
  final int id;
  final String name;
  final int parentId;
  final int order;
  final DateTime createdAt;

  Module({
    required this.id,
    required this.name,
    this.parentId = 0,
    this.order = 0,
    required this.createdAt,
  });

  factory Module.fromJson(Map<String, dynamic> json) {
    return Module(
      id: json['id'] as int,
      name: json['name'] as String,
      parentId: (json['parent_id'] as num).toInt(),
      order: (json['order'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'parent_id': parentId,
    'order': order,
    'created_at': createdAt.toIso8601String(),
  };
}
