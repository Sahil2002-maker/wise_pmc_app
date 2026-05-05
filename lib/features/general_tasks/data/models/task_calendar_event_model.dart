// lib/features/general_tasks/data/models/task_calendar_event_model.dart
//
// FIXES:
// 1. Handles both flat and nested (extendedProps) JSON from Laravel backend
// 2. Robust date parsing — never throws, falls back gracefully
// 3. Handles null start/end dates by using task_deadline or created_at
// 4. Parses type from both top-level and extendedProps
// 5. Handles ISO strings, date-only strings, and timestamps

class TaskCalendarEventModel {
  final String  id;
  final String  title;
  final DateTime start;
  final DateTime? end;
  final String? backgroundColor;
  final String? borderColor;
  final String  type;           // 'general_task' | 'process_task'
  final String  status;         // 'pending' | 'completed' | 'not_assigned'
  final String  description;
  final int?    teamId;
  final String? teamName;
  final String  assignedUsersNames;
  final int?    originalId;
  final String? projectName;
  final String? processName;
  final bool    isOverdue;

  const TaskCalendarEventModel({
    required this.id,
    required this.title,
    required this.start,
    this.end,
    this.backgroundColor,
    this.borderColor,
    required this.type,
    required this.status,
    required this.description,
    this.teamId,
    this.teamName,
    required this.assignedUsersNames,
    this.originalId,
    this.projectName,
    this.processName,
    this.isOverdue = false,
  });

  bool get isGeneralTask  => type == 'general_task';
  bool get isProcessTask  => type == 'process_task';
  bool get isCompleted    => status == 'completed';

  // ── Safe date parser ────────────────────────────────────────────────────────
  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    try {
      final dt = DateTime.parse(s);
      return dt.toLocal();
    } catch (_) {
      return null;
    }
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  // ── Factory ─────────────────────────────────────────────────────────────────
  factory TaskCalendarEventModel.fromJson(Map<String, dynamic> json) {
    final ext = json['extendedProps'] is Map<String, dynamic>
        ? json['extendedProps'] as Map<String, dynamic>
        : <String, dynamic>{};

    final id    = json['id']?.toString()    ?? '';
    final title = json['title']?.toString() ?? 'Untitled';

    DateTime? startDt = _parseDate(json['start'])
        ?? _parseDate(ext['startDate'])
        ?? _parseDate(ext['assignDate'])
        ?? _parseDate(ext['deadline'])
        ?? DateTime.now();

    DateTime? endDt = _parseDate(json['end'])
        ?? _parseDate(ext['deadline'])
        ?? _parseDate(ext['uploadedDate']);

    final type   = (ext['type']   ?? json['type']   ?? 'general_task').toString();
    final status = (ext['status'] ?? json['status'] ?? 'pending').toString();

    final bgColor     = json['backgroundColor']?.toString() ?? ext['backgroundColor']?.toString();
    final borderColor = json['borderColor']?.toString()     ?? ext['borderColor']?.toString();

    int? originalId = _parseInt(ext['original_id']);
    if (originalId == null || originalId <= 0) {
      final stripped = id.replaceAll(RegExp(r'^(general_|process_)'), '');
      originalId = int.tryParse(stripped);
    }

    final teamId   = _parseInt(ext['teamId']   ?? json['teamId']);
    final teamName = (ext['teamName'] ?? json['teamName'])?.toString();

    final assignedNames =
        (ext['assignedUsersNames'] ?? json['assignedUsersNames'] ?? '').toString();

    final projectName = (ext['projectName'] ?? json['projectName'])?.toString();
    final processName = (ext['processName'] ?? json['processName'])?.toString();

    final description = (ext['description'] ?? json['description'] ?? '').toString();

    final isOverdue = ext['isOverdue'] == true || json['isOverdue'] == true;

    return TaskCalendarEventModel(
      id:                 id,
      title:              title,
      start:              startDt ?? DateTime.now(),
      end:                endDt,
      backgroundColor:    bgColor,
      borderColor:        borderColor,
      type:               type,
      status:             status,
      description:        description,
      teamId:             teamId,
      teamName:           teamName,
      assignedUsersNames: assignedNames,
      originalId:         originalId,
      projectName:        projectName,
      processName:        processName,
      isOverdue:          isOverdue,
    );
  }
}