// lib/features/general_tasks/data/models/general_task_model.dart

class GeneralTaskModel {
  final int taskId;
  final String taskName;
  final String taskDescription;
  final String? taskDeadline;
  final String status;
  final String displayStatus;
  final String createdByName;
  final String? createdDate;
  final List<dynamic> assignedTo;
  final List<String> assignedUsers;
  final String assignedUsersNames;
  final String? assignedDate;
  final String? filePath;
  final String? uploadedDate;
  final bool isOverdue;
  final bool canEdit;
  final bool canAssign;
  final bool canDelete;
  final bool canUpload;
  final bool canViewDoc;

  const GeneralTaskModel({
    required this.taskId,
    required this.taskName,
    required this.taskDescription,
    required this.taskDeadline,
    required this.status,
    required this.displayStatus,
    required this.createdByName,
    required this.createdDate,
    required this.assignedTo,
    required this.assignedUsers,
    required this.assignedUsersNames,
    required this.assignedDate,
    required this.filePath,
    required this.uploadedDate,
    required this.isOverdue,
    required this.canEdit,
    required this.canAssign,
    required this.canDelete,
    required this.canUpload,
    required this.canViewDoc,
  });

  factory GeneralTaskModel.fromJson(Map<String, dynamic> json) {
    // ── task_id ──────────────────────────────────────────────────────────────
    final taskId = int.tryParse(json['task_id']?.toString() ?? '0') ?? 0;

    // ── assigned_to ───────────────────────────────────────────────────────────
    // Backend may return:
    //   null                → not assigned yet
    //   []                  → empty array
    //   [5, 12]             → int IDs (MySQL JSON stores integers)
    //   ["5", "12"]         → string IDs (edge case, legacy data)
    //   5                   → single raw value (shouldn't happen, but guard it)
    final rawAssignedTo = json['assigned_to'];
    final List<dynamic> assignedTo;
    if (rawAssignedTo == null) {
      assignedTo = const [];
    } else if (rawAssignedTo is List) {
      assignedTo = rawAssignedTo;
    } else {
      assignedTo = [rawAssignedTo];
    }

    // ── assigned_users_names ─────────────────────────────────────────────────
    final assignedUsersNames =
        json['assigned_users_names']?.toString().trim() ?? '';

    // ── assigned_users ───────────────────────────────────────────────────────
    final List<String> assignedUsers =
        ((json['assigned_users'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList();

    // ── status + file_path ───────────────────────────────────────────────────
    final filePath  = json['file_path']?.toString();
    final rawStatus = json['status']?.toString() ?? 'pending';
    final effectiveStatus =
        (filePath != null && filePath.isNotEmpty) ? 'completed' : rawStatus;

    String displayStatus = json['display_status']?.toString() ?? '';
    if (displayStatus.isEmpty) {
      displayStatus = effectiveStatus
          .split('_')
          .map((w) =>
              w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
    }

    // ── is_overdue ───────────────────────────────────────────────────────────
    bool isOverdue = json['is_overdue'] == true;
    if (!isOverdue && json['is_overdue'] == null) {
      final deadlineStr = json['task_deadline']?.toString();
      if (deadlineStr != null &&
          deadlineStr.isNotEmpty &&
          effectiveStatus != 'completed') {
        try {
          final deadline = DateTime.parse(deadlineStr);
          isOverdue = deadline.isBefore(DateTime.now());
        } catch (_) {}
      }
    }

    // ── can_view_doc ─────────────────────────────────────────────────────────
    final hasFile = filePath != null && filePath.isNotEmpty;
    final canViewDoc = json['can_view_doc'] == true ||
        (json['can_view_doc'] == null &&
            hasFile &&
            (json['can_edit'] == true ||
                json['can_assign'] == true ||
                json['can_upload'] == true));

    return GeneralTaskModel(
      taskId: taskId,
      taskName: json['task_name']?.toString() ?? '',
      taskDescription: json['task_description']?.toString() ?? '',
      taskDeadline: json['task_deadline']?.toString(),
      status: effectiveStatus,
      displayStatus: displayStatus,
      createdByName: json['created_by_name']?.toString() ??
          json['created_by']?.toString() ??
          'Unknown',
      createdDate: json['created_date']?.toString() ??
          json['created_at']?.toString(),
      assignedTo: assignedTo,
      assignedUsers: assignedUsers,
      assignedUsersNames: assignedUsersNames.isEmpty
          ? (assignedTo.isEmpty ? 'Not Assigned' : assignedTo.join(', '))
          : assignedUsersNames,
      assignedDate: json['assigned_date']?.toString(),
      filePath: filePath,
      uploadedDate: json['uploaded_date']?.toString(),
      isOverdue: isOverdue,
      canEdit:    json['can_edit']    == true,
      canAssign:  json['can_assign']  == true,
      canDelete:  json['can_delete']  == true,
      canUpload:  json['can_upload']  == true,
      canViewDoc: canViewDoc,
    );
  }

  /// Completed if status='completed' OR file_path is set.
  bool get isCompleted =>
      status == 'completed' || (filePath?.isNotEmpty ?? false);

  bool get isAssigned => assignedTo.isNotEmpty;
}