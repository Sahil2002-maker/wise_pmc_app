// lib/features/development_process/data/models/development_process_model.dart

class DevelopmentProcessAssignment {
  final int? id;
  final int? projectId;
  final int? processId;
  final int? orderNo;
  final String? stage;
  final int? assignedTo;
  final String? assignedUserName;
  final String? deadline;
  final String? status;
  final String? filePath;
  final bool notApplicable;
  final String? assignedDate;
  final String? uploadedDate;

  const DevelopmentProcessAssignment({
    this.id,
    this.projectId,
    this.processId,
    this.orderNo,
    this.stage,
    this.assignedTo,
    this.assignedUserName,
    this.deadline,
    this.status,
    this.filePath,
    this.notApplicable = false,
    this.assignedDate,
    this.uploadedDate,
  });

  factory DevelopmentProcessAssignment.fromJson(Map<String, dynamic> json) {
    return DevelopmentProcessAssignment(
      id: _parseInt(json['id']),
      projectId: _parseInt(json['project_id']),
      processId: _parseInt(json['process_id']),
      orderNo: _parseInt(json['order_no']),
      stage: json['stage']?.toString(),
      assignedTo: _parseInt(json['assigned_to']),
      assignedUserName: json['assigned_user_name']?.toString() ??
          (json['assigned_user'] is Map
              ? json['assigned_user']['name']?.toString()
              : null),
      deadline: json['deadline']?.toString(),
      status: json['status']?.toString(),
      filePath: json['file_path']?.toString(),
      notApplicable: _parseBool(json['not_applicable']),
      assignedDate: json['assigned_date']?.toString(),
      uploadedDate: json['uploaded_date']?.toString(),
    );
  }

  static int? _parseInt(dynamic v) =>
      v == null ? null : int.tryParse(v.toString());

  static bool _parseBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    return v.toString() == '1' || v.toString().toLowerCase() == 'true';
  }

  bool get isAssigned => status == 'assigned' || (assignedTo != null && !notApplicable);
  bool get isCompleted => status == 'completed';
  bool get isNA => notApplicable || status == 'not_applicable';
  bool get isPending => !isAssigned && !isCompleted && !isNA;
  bool get hasFile => filePath != null && filePath!.isNotEmpty;
}

class DevelopmentProcessItem {
  final int? processId;
  final String processName;
  final int? orderNo;
  final String? stage;
  final int? teamId;
  final String? teamName;
  final String? teamColor;
  final DevelopmentProcessAssignment? assignment;

  const DevelopmentProcessItem({
    this.processId,
    required this.processName,
    this.orderNo,
    this.stage,
    this.teamId,
    this.teamName,
    this.teamColor,
    this.assignment,
  });

  factory DevelopmentProcessItem.fromJson(Map<String, dynamic> json) {
    DevelopmentProcessAssignment? assignment;
    final rawAssign = json['assignment'];
    if (rawAssign is Map<String, dynamic>) {
      assignment = DevelopmentProcessAssignment.fromJson(rawAssign);
    }

    return DevelopmentProcessItem(
      processId: _parseInt(json['process_id']),
      processName: json['process_name']?.toString() ?? '',
      orderNo: _parseInt(json['order_no']),
      stage: json['stage']?.toString(),
      teamId: _parseInt(json['team_id']),
      teamName: json['team_name']?.toString() ??
          (json['team'] is Map ? json['team']['team_name']?.toString() : null),
      teamColor: json['team_color']?.toString() ??
          (json['team'] is Map ? json['team']['color']?.toString() : null),
      assignment: assignment,
    );
  }

  static int? _parseInt(dynamic v) =>
      v == null ? null : int.tryParse(v.toString());
}

class DevelopmentStageData {
  final int stageNumber;
  final String stageLabel;
  final List<DevelopmentProcessItem> processes;

  const DevelopmentStageData({
    required this.stageNumber,
    required this.stageLabel,
    required this.processes,
  });
}

class TeamMemberItem {
  final int id;
  final String name;
  final String? email;

  const TeamMemberItem({
    required this.id,
    required this.name,
    this.email,
  });

  factory TeamMemberItem.fromJson(Map<String, dynamic> json) {
    return TeamMemberItem(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString(),
    );
  }
}