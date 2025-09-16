class Machine {
  final String id;
  final String unit;
  final String machineCode;
  final String machineType;
  final String description;
  final String type;
  final int capacity;
  final String? remarks;
  final String status;
  final bool isActive;
  final String createdAt;
  final String updatedAt;
  final List<dynamic> jobs;

  Machine({
    required this.id,
    required this.unit,
    required this.machineCode,
    required this.machineType,
    required this.description,
    required this.type,
    required this.capacity,
    this.remarks,
    required this.status,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.jobs,
  });

  factory Machine.fromJson(Map<String, dynamic> json) {
    return Machine(
      id: json['id'] as String,
      unit: json['unit'] as String,
      machineCode: json['machineCode'] as String,
      machineType: json['machineType'] as String,
      description: json['description'] as String,
      type: json['type'] as String,
      capacity: json['capacity'] as int,
      remarks: json['remarks'] as String?, // nullable
      status: json['status'] as String,
      isActive: json['isActive'] as bool,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
      jobs: json['jobs'] as List<dynamic>,
    );
  }
}