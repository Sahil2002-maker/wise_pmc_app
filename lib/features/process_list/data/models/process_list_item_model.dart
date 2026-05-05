// lib/features/process_list/data/models/process_list_item_model.dart

import 'dart:convert';

class ProcessListItemModel {
  final dynamic processId;
  final String processName;
  final String stage;
  final String? rawStage;
  final int? orderNo;
  final int? day;
  final String? groupName;
  final int? workingTeamId;
  final String? teamName;
  final String? teamColor;

  // Task fields
  final dynamic assignUser;
  final String? assignUserName;
  final String? assignDate;
  final String? deadline;
  final int? deadlineDays;
  final String status;
  final String? filePath;
  final String? fileName;
  final String? uploadedDate;
  final String? description;
  final dynamic completedBy;

  // Sub-stage (CC / Layout / OC)
  final String? subStage;

  const ProcessListItemModel({
    required this.processId,
    required this.processName,
    required this.stage,
    this.rawStage,
    this.orderNo,
    this.day,
    this.groupName,
    this.workingTeamId,
    this.teamName,
    this.teamColor,
    this.assignUser,
    this.assignUserName,
    this.assignDate,
    this.deadline,
    this.deadlineDays,
    this.status = 'pending',
    this.filePath,
    this.fileName,
    this.uploadedDate,
    this.description,
    this.completedBy,
    this.subStage,
  });

  // ── Computed getters ──────────────────────────────────────────────────────

  /// FIX: Only requires assignUser to be non-null.
  /// Previously required BOTH assignUser AND assignDate — if the backend
  /// omits assign_date the task appeared unassigned even though it had a user.
  bool get isAssigned => assignUser != null && _resolveFirstUserId(assignUser) != null;

  bool get isNotApplicable => status == 'not_applicable';
  bool get isCompleted => status == 'completed';
  bool get hasFile => filePath != null && filePath!.isNotEmpty;

  String get statusLabel {
    switch (status) {
      case 'completed':      return 'Completed';
      case 'assigned':       return 'Assigned';
      case 'not_applicable': return 'N/A';
      case 'not_started':    return 'Not Started';
      default:               return 'Pending';
    }
  }

  /// Returns true if [userId] is the currently assigned user for this task.
  bool isAssignedToCurrentUser(int userId) {
    if (assignUser == null) return false;
    return _resolveUserIds(assignUser).contains(userId);
  }

  /// Extract the first user id from whatever format assignUser comes in.
  static int? _resolveFirstUserId(dynamic raw) {
    final ids = _resolveUserIds(raw);
    return ids.isEmpty ? null : ids.first;
  }

  /// Resolve ALL user ids from assignUser (int, List, or JSON-encoded string).
  static List<int> _resolveUserIds(dynamic raw) {
    if (raw == null) return [];
    if (raw is int) return raw > 0 ? [raw] : [];
    if (raw is List) {
      return raw
          .map((e) => int.tryParse(e.toString()))
          .whereType<int>()
          .where((id) => id > 0)
          .toList();
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.startsWith('[')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is List) {
            return decoded
                .map((e) => int.tryParse(e.toString()))
                .whereType<int>()
                .where((id) => id > 0)
                .toList();
          }
        } catch (_) {}
      }
      final single = int.tryParse(trimmed);
      if (single != null && single > 0) return [single];
    }
    return [];
  }

  // ── Factory ───────────────────────────────────────────────────────────────

  factory ProcessListItemModel.fromJson(Map<String, dynamic> json) {
    final task = json['task_details'] as Map<String, dynamic>?;

    String status       = 'pending';
    dynamic assignUser;
    String? assignUserName;
    String? assignDate;
    String? deadline;
    int?    deadlineDays;
    String? filePath;
    String? fileName;
    String? uploadedDate;
    String? description;
    dynamic completedBy;

    if (task != null) {
      status         = task['status']?.toString() ?? 'pending';
      assignUser     = task['assign_user'];
      assignUserName = task['assign_user_name']?.toString();
      assignDate     = task['assign_date']?.toString();
      deadline       = task['deadline']?.toString();
      deadlineDays   = _parseInt(task['deadline_days']);
      filePath       = task['file_path']?.toString();
      fileName       = task['file_name']?.toString();
      uploadedDate   = task['uploaded_date']?.toString();
      description    = task['description']?.toString();
      completedBy    = task['completed_by'];
    }

    return ProcessListItemModel(
      processId:      json['process_id'],
      processName:    json['process_name']?.toString() ?? '',
      stage:          json['stage']?.toString() ?? '',
      rawStage:       json['raw_stage']?.toString(),
      orderNo:        _parseInt(json['order_no']),
      day:            _parseInt(json['day']),
      groupName:      json['group_name']?.toString(),
      workingTeamId:  _parseInt(json['working_team_id']),
      teamName:       json['team_name']?.toString(),
      teamColor:      json['team_color']?.toString() ??
                      (json['team'] as Map<String, dynamic>?)?['color']?.toString(),
      assignUser:     assignUser,
      assignUserName: assignUserName,
      assignDate:     assignDate,
      deadline:       deadline,
      deadlineDays:   deadlineDays,
      status:         status,
      filePath:       filePath,
      fileName:       fileName,
      uploadedDate:   uploadedDate,
      description:    description,
      completedBy:    completedBy,
      subStage:       json['sub_stage']?.toString(),
    );
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }
}