// lib/features/development_process/data/models/dev_process_model.dart
//
// FIX: All numeric fields now use _parseInt() / _parseDouble() helpers
// instead of hard casts (e.g. `json['order_no'] as num`).
// The Laravel API returns numeric IDs as JSON strings in some responses,
// which caused: "type 'String' is not a subtype of type 'num' in type cast"
//
// FIX 2: Added `stageLabel` getter used by DevProcessCard.
// FIX 3: `teamColor` falls back to empty string (not null) to match
//         DevProcessCard which calls _hexColor(process.teamColor) — non-nullable.
// FIX 4: Added DevProcessAssignmentModel with document fields for S3 uploads.

// ─── Helpers ──────────────────────────────────────────────────────────────────

int? _parseInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is num) return v.toInt();
  return int.tryParse(v.toString().trim());
}

int _parseIntOrZero(dynamic v) => _parseInt(v) ?? 0;

String _str(dynamic v) => v?.toString() ?? '';

// ─── DevProcessModel ──────────────────────────────────────────────────────────

class DevProcessModel {
  final int processId;
  final int orderNo;
  final String processName;
  final int stageNum;
  final int? teamId;
  final String? teamName;
  final String teamColor;
  final int? day;

  const DevProcessModel({
    required this.processId,
    required this.orderNo,
    required this.processName,
    required this.stageNum,
    this.teamId,
    this.teamName,
    this.teamColor = '',
    this.day,
  });

  String get stageLabel => 'Stage $stageNum';

  factory DevProcessModel.fromJson(Map<String, dynamic> json) {
    final rawStage = _str(json['stage'] ?? json['stage_label'] ?? '');
    final stageNum = _parseStageNum(rawStage, json);

    final processId = _parseIntOrZero(
      json['process_id'] ?? json['id'] ?? json['order_no'],
    );
    final orderNo = _parseIntOrZero(
      json['order_no'] ?? json['process_id'] ?? json['id'],
    );

    final teamMap = json['team'] is Map ? json['team'] as Map : null;
    final teamId = _parseInt(json['team_id'] ?? teamMap?['id']);
    final teamName = _str(
      json['team_name'] ?? teamMap?['team_name'] ?? teamMap?['name'],
    ).nullIfEmpty;
    final teamColor = _str(
      json['team_color'] ?? teamMap?['team_color'] ?? teamMap?['color'],
    );

    return DevProcessModel(
      processId:   processId,
      orderNo:     orderNo,
      processName: _str(json['process_name'] ?? json['name']),
      stageNum:    stageNum,
      teamId:      teamId,
      teamName:    teamName,
      teamColor:   teamColor,
      day:         _parseInt(json['day']),
    );
  }

  static int _parseStageNum(String rawStage, Map<String, dynamic> json) {
    final directInt = _parseInt(json['stage']);
    if (directInt != null && directInt >= 0 && directInt <= 3) {
      return directInt;
    }
    final digits = rawStage.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  Map<String, dynamic> toJson() => {
        'process_id':   processId,
        'order_no':     orderNo,
        'process_name': processName,
        'stage':        stageNum,
        'team_id':      teamId,
        'team_name':    teamName,
        'team_color':   teamColor,
        'day':          day,
      };

  DevProcessModel copyWith({
    int?    processId,
    int?    orderNo,
    String? processName,
    int?    stageNum,
    int?    teamId,
    String? teamName,
    String? teamColor,
    int?    day,
  }) {
    return DevProcessModel(
      processId:   processId   ?? this.processId,
      orderNo:     orderNo     ?? this.orderNo,
      processName: processName ?? this.processName,
      stageNum:    stageNum    ?? this.stageNum,
      teamId:      teamId      ?? this.teamId,
      teamName:    teamName    ?? this.teamName,
      teamColor:   teamColor   ?? this.teamColor,
      day:         day         ?? this.day,
    );
  }
}

// ─── DevProcessAssignmentModel ────────────────────────────────────────────────
// Mirrors the DevelopmentProcessAssignment Eloquent model fields returned
// by the API alongside each process in getProjectProcesses().

class DevProcessAssignmentModel {
  final int? assignmentId;
  final int? processId;
  final int? assignedTo;
  final String? assignedUser;
  final int? orderNo;
  final String? deadline;
  final String? status;
  // S3 document fields (populated after upload)
  final String? documentPath; // S3 key, e.g. documents/development_process/{projectId}/{processId}/uuid.pdf
  final String? documentName; // original file name shown in the UI

  const DevProcessAssignmentModel({
    this.assignmentId,
    this.processId,
    this.assignedTo,
    this.assignedUser,
    this.orderNo,
    this.deadline,
    this.status,
    this.documentPath,
    this.documentName,
  });

  bool get hasDocument =>
      documentPath != null && documentPath!.isNotEmpty;

  factory DevProcessAssignmentModel.fromJson(Map<String, dynamic> json) {
    return DevProcessAssignmentModel(
      assignmentId: _parseInt(json['assignment_id'] ?? json['id']),
      processId:    _parseInt(json['process_id']),
      assignedTo:   _parseInt(json['assigned_to']),
      assignedUser: _str(json['assigned_user']).nullIfEmpty,
      orderNo:      _parseInt(json['order_no']),
      deadline:     _str(json['deadline']).nullIfEmpty,
      status:       _str(json['status']).nullIfEmpty,
      documentPath: _str(json['document_path']).nullIfEmpty,
      documentName: _str(json['document_name']).nullIfEmpty,
    );
  }

  Map<String, dynamic> toJson() => {
        'assignment_id': assignmentId,
        'process_id':    processId,
        'assigned_to':   assignedTo,
        'assigned_user': assignedUser,
        'order_no':      orderNo,
        'deadline':      deadline,
        'status':        status,
        'document_path': documentPath,
        'document_name': documentName,
      };

  DevProcessAssignmentModel copyWith({
    int?    assignmentId,
    int?    processId,
    int?    assignedTo,
    String? assignedUser,
    int?    orderNo,
    String? deadline,
    String? status,
    String? documentPath,
    String? documentName,
  }) {
    return DevProcessAssignmentModel(
      assignmentId: assignmentId ?? this.assignmentId,
      processId:    processId    ?? this.processId,
      assignedTo:   assignedTo   ?? this.assignedTo,
      assignedUser: assignedUser ?? this.assignedUser,
      orderNo:      orderNo      ?? this.orderNo,
      deadline:     deadline     ?? this.deadline,
      status:       status       ?? this.status,
      documentPath: documentPath ?? this.documentPath,
      documentName: documentName ?? this.documentName,
    );
  }
}

// ─── DevProcessStageModel ─────────────────────────────────────────────────────

class DevProcessStageModel {
  final int stage;
  final String stageLabel;
  final int count;
  final List<DevProcessModel> processes;

  const DevProcessStageModel({
    required this.stage,
    required this.stageLabel,
    required this.count,
    required this.processes,
  });

  factory DevProcessStageModel.fromJson(Map<String, dynamic> json) {
    final rawProcesses = json['processes'] as List? ?? [];
    final processes = rawProcesses
        .whereType<Map<String, dynamic>>()
        .map(DevProcessModel.fromJson)
        .toList();

    return DevProcessStageModel(
      stage:      _parseIntOrZero(json['stage']),
      stageLabel: _str(json['stage_label'] ?? 'Stage ${json['stage']}'),
      count:      _parseIntOrZero(json['count'] ?? processes.length),
      processes:  processes,
    );
  }
}

// ─── DevProcessTeamModel ──────────────────────────────────────────────────────

class DevProcessTeamModel {
  final int id;
  final String teamName;
  final String teamColor;
  final List<int> memberIds;

  const DevProcessTeamModel({
    required this.id,
    required this.teamName,
    required this.teamColor,
    this.memberIds = const [],
  });

  factory DevProcessTeamModel.fromJson(Map<String, dynamic> json) {
    List<int> memberIds = [];
    final rawIds = json['member_ids'];
    if (rawIds is List) {
      memberIds = rawIds.map((e) => _parseIntOrZero(e)).toList();
    }

    return DevProcessTeamModel(
      id:        _parseIntOrZero(json['id']),
      teamName:  _str(json['team_name'] ?? json['name']),
      teamColor: _str(json['team_color'] ?? json['color'] ?? '#6C757D'),
      memberIds: memberIds,
    );
  }
}

// ─── String extension helper ──────────────────────────────────────────────────

extension _StringNullable on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}