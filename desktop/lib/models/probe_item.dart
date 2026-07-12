class ProbeItem {
  final int id;
  final String address;
  final String protocol;
  final String probeType;
  final int moduleId;
  final String? certData;
  final int order;
  final DateTime createdAt;

  ProbeItem({
    required this.id,
    required this.address,
    required this.protocol,
    required this.probeType,
    required this.moduleId,
    this.certData,
    this.order = 0,
    required this.createdAt,
  });

  factory ProbeItem.fromJson(Map<String, dynamic> json) {
    return ProbeItem(
      id: json['id'] as int,
      address: json['address'] as String,
      protocol: json['protocol'] as String,
      probeType: json['probe_type'] as String,
      moduleId: json['module_id'] as int,
      certData: json['cert_data'] as String?,
      order: (json['order'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'address': address,
    'protocol': protocol,
    'probe_type': probeType,
    'module_id': moduleId,
    'cert_data': certData,
    'order': order,
    'created_at': createdAt.toIso8601String(),
  };
}
