// lib/features/development_process/data/models/development_process_model.dart
//
// FIX (View button shows "Completed" with no actual file):
//   Previously `isCompleted` was: `status == 'completed' || hasFile`.
//   That meant a stray/legacy `status` value of 'completed' coming back
//   from the API — with no document_path attached — would make the card
//   render "Completed" + a "View" button, and tapping View would then
//   immediately fail with "No file is attached to this process."
//
//   `isCompleted` is now derived ONLY from whether a file actually exists
//   (`hasFile`). The `status` field is no longer trusted as a source of
//   truth for completion — it's informational only.
//
//   Also added robust `filePath` / `fileName` extraction: the backend may
//   (now or in the future) store the document path under a different
//   column name, or as a JSON-encoded array/object (the same class of bug
//   already found in the MWM module's JSON column). `_unwrapPathValue`
//   defensively unwraps any of those shapes into a plain string.

import 'dart:convert';

class DevelopmentProcessAssignment {
  final int? id;
  final int? projectId;
  final int? processId;
  final int? orderNo;
  final String? stage;
  final int? assignedTo;
  final String? assignedUserName;
  final String? assignedUserRole;
  final String? deadline;
  final String? status;
  final String? filePath;
  final String? fileName;
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
    this.assignedUserRole,
    this.deadline,
    this.status,
    this.filePath,
    this.fileName,
    this.notApplicable = false,
    this.assignedDate,
    this.uploadedDate,
  });

  /// Field names match MobileDevelopmentProcessController::getProjectProcesses
  /// exactly: assignment_id, assigned_user (plain string), assigned_user_role,
  /// document_path, document_name, not_applicable.
  factory DevelopmentProcessAssignment.fromJson(Map<String, dynamic> json) {
    return DevelopmentProcessAssignment(
      id: _parseInt(json['assignment_id'] ?? json['id']),
      projectId: _parseInt(json['project_id']),
      processId: _parseInt(json['process_id']),
      orderNo: _parseInt(json['order_no']),
      stage: json['stage']?.toString(),
      assignedTo: _parseInt(json['assigned_to']),
      assignedUserName: json['assigned_user']?.toString() ??
          json['assigned_user_name']?.toString(),
      assignedUserRole: json['assigned_user_role']?.toString(),
      deadline: json['deadline']?.toString(),
      status: json['status']?.toString(),
      filePath: _extractDocumentPath(json),
      fileName: _extractDocumentName(json),
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

  // ── Robust document path / name extraction ──────────────────────────────
  //
  // Tries every field name the backend might plausibly use, and unwraps
  // JSON-encoded arrays/objects so a malformed value never silently turns
  // into an empty path (which is what was causing the "Completed" card with
  // no actual file behind it).

  static String? _extractDocumentPath(Map<String, dynamic> json) {
    final candidates = [
      json['document_path'],
      json['file_path'],
      json['path'],
      json['document'],
      json['completed_document_path'],
    ];
    for (final c in candidates) {
      final v = _unwrapPathValue(c);
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  static String? _extractDocumentName(Map<String, dynamic> json) {
    final candidates = [
      json['document_name'],
      json['file_name'],
      json['name'],
    ];
    for (final c in candidates) {
      final v = _unwrapPathValue(c);
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  /// Unwraps a value that should represent a single path/name string, but
  /// might instead be:
  ///   • a plain string                         -> use directly
  ///   • a JSON-encoded string of an array/map   -> decode then unwrap
  ///   • a real List (already decoded by http)   -> use first entry
  ///   • a real Map (already decoded by http)    -> look for path/name/url
  static String? _unwrapPathValue(dynamic v) {
    if (v == null) return null;

    if (v is String) {
      final trimmed = v.trim();
      if (trimmed.isEmpty) return null;
      if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
        try {
          final decoded = jsonDecode(trimmed);
          return _unwrapPathValue(decoded);
        } catch (_) {
          // Not actually JSON despite the leading bracket — use as-is.
          return trimmed;
        }
      }
      return trimmed;
    }

    if (v is List) {
      if (v.isEmpty) return null;
      return _unwrapPathValue(v.first);
    }

    if (v is Map) {
      return _unwrapPathValue(
        v['path'] ?? v['document_path'] ?? v['file_path'] ?? v['url'] ?? v['name'],
      );
    }

    return null;
  }

  // ── Semantic getters ──────────────────────────────────────────────────────

  /// Convenience alias — the numeric user-id this process is assigned to.
  int? get assignedToUserId => assignedTo;

  bool get isAssigned => assignedTo != null && !notApplicable;

  bool get hasFile => filePath != null && filePath!.isNotEmpty;

  /// FIX: completion is determined ONLY by whether a file actually exists.
  /// A stray `status == 'completed'` value with no document attached used
  /// to make the card show "Completed" + a "View" button that failed with
  /// "No file is attached to this process." That can no longer happen.
  bool get isCompleted => hasFile;

  bool get isNA => notApplicable || status == 'not_applicable';

  bool get isPending => !isAssigned && !isCompleted && !isNA;

  bool get isAssignedToTeamLeader =>
      (assignedUserRole ?? '').toLowerCase().contains('leader');
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
      teamName: json['team_name']?.toString(),
      teamColor: json['team_color']?.toString(),
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

/// `role` comes straight from the backend's getTeamMembers() response:
/// 'Team Leader' or 'Team Member'. No client-side guessing needed.
class TeamMemberItem {
  final int id;
  final String name;
  final String? email;
  final String? role;

  const TeamMemberItem({
    required this.id,
    required this.name,
    this.email,
    this.role,
  });

  bool get isTeamLeader => (role ?? '').toLowerCase().contains('leader');

  factory TeamMemberItem.fromJson(Map<String, dynamic> json) {
    return TeamMemberItem(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString(),
      role: json['role']?.toString(),
    );
  }
}