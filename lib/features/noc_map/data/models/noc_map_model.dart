// lib/features/noc_map/data/models/noc_map_model.dart

class NocMapSummaryModel {
  final int totalNocProcesses;
  final int completedTasks;
  final int assignedTasks;
  final int pendingTasks;
  final double completionPercentage;
  final String orderRange;

  const NocMapSummaryModel({
    required this.totalNocProcesses,
    required this.completedTasks,
    required this.assignedTasks,
    required this.pendingTasks,
    required this.completionPercentage,
    required this.orderRange,
  });

  factory NocMapSummaryModel.fromJson(Map<String, dynamic> json) {
    return NocMapSummaryModel(
      totalNocProcesses:   (json['total_noc_processes'] as num?)?.toInt() ?? 0,
      completedTasks:      (json['completed_tasks'] as num?)?.toInt() ?? 0,
      assignedTasks:       (json['assigned_tasks'] as num?)?.toInt() ?? 0,
      pendingTasks:        (json['pending_tasks'] as num?)?.toInt() ?? 0,
      completionPercentage:(json['completion_percentage'] as num?)?.toDouble() ?? 0.0,
      orderRange:          json['order_range']?.toString() ?? '75-213',
    );
  }
}

class NocProcessModel {
  final int processId;
  final int orderNo;
  final String processName;
  final String? heading;
  final String status;       // 'Completed' | 'In Progress' | 'Not Started'
  final int statusCode;      // 0 | 1 | 2
  final NocAssignedUserModel? assignedUser;
  final String? assignDate;
  final String? uploadDate;
  final String? fileUrl;

  const NocProcessModel({
    required this.processId,
    required this.orderNo,
    required this.processName,
    this.heading,
    required this.status,
    required this.statusCode,
    this.assignedUser,
    this.assignDate,
    this.uploadDate,
    this.fileUrl,
  });

  factory NocProcessModel.fromJson(Map<String, dynamic> json) {
    return NocProcessModel(
      processId:   (json['process_id'] as num?)?.toInt() ?? 0,
      orderNo:     (json['order_no'] as num?)?.toInt() ?? 0,
      processName: json['process_name']?.toString() ?? '',
      heading:     json['heading']?.toString(),
      status:      json['status']?.toString() ?? 'Not Started',
      statusCode:  (json['status_code'] as num?)?.toInt() ?? 0,
      assignedUser: json['assigned_user'] != null
          ? NocAssignedUserModel.fromJson(
              Map<String, dynamic>.from(json['assigned_user'] as Map))
          : null,
      assignDate:  json['assign_date']?.toString(),
      uploadDate:  json['upload_date']?.toString(),
      fileUrl:     json['file_path']?.toString(),
    );
  }

  bool get isCompleted  => statusCode == 2;
  bool get isInProgress => statusCode == 1;
  bool get isNotStarted => statusCode == 0;
}

class NocAssignedUserModel {
  final int id;
  final String name;
  final String? email;

  const NocAssignedUserModel({
    required this.id,
    required this.name,
    this.email,
  });

  factory NocAssignedUserModel.fromJson(Map<String, dynamic> json) {
    return NocAssignedUserModel(
      id:    (json['id'] as num?)?.toInt() ?? 0,
      name:  json['name']?.toString() ?? '',
      email: json['email']?.toString(),
    );
  }
}

class NocMapDataModel {
  final NocProjectInfoModel project;
  final NocMapSummaryModel summary;
  final List<NocProcessModel> processes;

  const NocMapDataModel({
    required this.project,
    required this.summary,
    required this.processes,
  });

  factory NocMapDataModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return NocMapDataModel(
      project: NocProjectInfoModel.fromJson(
          Map<String, dynamic>.from(data['project'] as Map? ?? {})),
      summary: NocMapSummaryModel.fromJson(
          Map<String, dynamic>.from(data['summary'] as Map? ?? {})),
      processes: (data['processes'] as List? ?? [])
          .whereType<Map>()
          .map((e) => NocProcessModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class NocProjectInfoModel {
  final int id;
  final String societyName;
  final String? projectType;
  final String? status;
  final String? address;

  const NocProjectInfoModel({
    required this.id,
    required this.societyName,
    this.projectType,
    this.status,
    this.address,
  });

  factory NocProjectInfoModel.fromJson(Map<String, dynamic> json) {
    return NocProjectInfoModel(
      id:           (json['id'] as num?)?.toInt() ?? 0,
      societyName:  json['society_name']?.toString() ?? '',
      projectType:  json['project_type']?.toString(),
      status:       json['status']?.toString(),
      address:      json['address']?.toString(),
    );
  }
}