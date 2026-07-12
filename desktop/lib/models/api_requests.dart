class CreateModuleRequest {
  final String name;
  final int parentId;

  CreateModuleRequest({required this.name, this.parentId = 0});

  Map<String, dynamic> toJson() => {
    'name': name,
    'parent_id': parentId,
  };
}

class UpdateModuleRequest {
  final String name;

  UpdateModuleRequest({required this.name});

  Map<String, dynamic> toJson() => {
    'name': name,
  };
}

class MoveModuleRequest {
  final int id;
  final int newParentId;
  final int sortOrder;

  MoveModuleRequest({
    required this.id,
    this.newParentId = 0,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'new_parent_id': newParentId,
    'sort_order': sortOrder,
  };
}

class CreateItemRequest {
  final String address;
  final String protocol;
  final String probeType;
  final int moduleId;
  final String? certData;

  CreateItemRequest({
    required this.address,
    required this.protocol,
    required this.probeType,
    required this.moduleId,
    this.certData,
  });

  Map<String, dynamic> toJson() => {
    'address': address,
    'protocol': protocol,
    'probe_type': probeType,
    'module_id': moduleId,
    'cert_data': certData,
  };
}

class UpdateItemRequest {
  final String? address;
  final String? protocol;
  final String? probeType;
  final String? certData;
  final bool clearCert;

  UpdateItemRequest({
    this.address,
    this.protocol,
    this.probeType,
    this.certData,
    this.clearCert = false,
  });

  Map<String, dynamic> toJson() => {
    if (address != null) 'address': address,
    if (protocol != null) 'protocol': protocol,
    if (probeType != null) 'probe_type': probeType,
    if (certData != null) 'cert_data': certData,
    'clear_cert': clearCert,
  };
}

class MoveItemRequest {
  final int id;
  final int newModuleId;
  final int sortOrder;

  MoveItemRequest({
    required this.id,
    this.newModuleId = 0,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'new_module_id': newModuleId,
    'sort_order': sortOrder,
  };
}

class ImportItem {
  final String address;
  final String protocol;
  final String probeType;
  final String? certData;

  ImportItem({
    required this.address,
    required this.protocol,
    required this.probeType,
    this.certData,
  });

  Map<String, dynamic> toJson() => {
    'address': address,
    'protocol': protocol,
    'probe_type': probeType,
    'cert_data': certData,
  };
}

class ImportRequest {
  final int moduleId;
  final String protocol;
  final String probeType;
  final List<ImportItem> items;

  ImportRequest({
    required this.moduleId,
    this.protocol = 'http',
    this.probeType = 'full',
    required this.items,
  });

  Map<String, dynamic> toJson() => {
    'module_id': moduleId,
    'protocol': protocol,
    'probe_type': probeType,
    'items': items.map((e) => e.toJson()).toList(),
  };
}

class DetectRequest {
  final List<int> itemIds;

  DetectRequest({required this.itemIds});

  Map<String, dynamic> toJson() => {
    'item_ids': itemIds,
  };
}
