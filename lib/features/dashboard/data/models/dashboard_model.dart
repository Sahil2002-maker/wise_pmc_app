// lib/features/dashboard/data/models/dashboard_model.dart

// ── Helpers ────────────────────────────────────────────────────────────────

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is bool) return v ? 1 : 0;
  return int.tryParse(v.toString()) ?? 0;
}

double _toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

bool _toBool(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is int) return v == 1;
  final s = v.toString().toLowerCase();
  return s == 'true' || s == '1';
}

String _toStr(dynamic v, [String fallback = '']) =>
    v?.toString() ?? fallback;

/// Safe list cast — never throws, always returns List<Map>.
List<Map<String, dynamic>> _toMapList(dynamic raw) {
  if (raw == null) return [];
  if (raw is List) {
    return raw.whereType<Map>().map((e) {
      final Map<String, dynamic> m = {};
      e.forEach((k, v) => m[k.toString()] = v);
      return m;
    }).toList();
  }
  return [];
}

// ── Task Summary ───────────────────────────────────────────────────────────

class DashboardTaskSummary {
  final int total;
  final int completed;
  final int inProgress;
  final int pending;
  final int progressPercentage;

  const DashboardTaskSummary({
    required this.total,
    required this.completed,
    required this.inProgress,
    required this.pending,
    required this.progressPercentage,
  });

  factory DashboardTaskSummary.fromJson(Map<String, dynamic> json) {
    return DashboardTaskSummary(
      total:              _toInt(json['total']),
      completed:          _toInt(json['completed']),
      inProgress:         _toInt(json['in_progress']),
      pending:            _toInt(json['pending']),
      progressPercentage: _toInt(json['progress_percentage']),
    );
  }

  factory DashboardTaskSummary.empty() => const DashboardTaskSummary(
    total: 0, completed: 0, inProgress: 0, pending: 0, progressPercentage: 0,
  );
}

// ── Attendance Summary ─────────────────────────────────────────────────────

class DashboardAttendanceSummary {
  final int workingDays;
  final int presentDays;
  final int halfDays;
  final int absentDays;
  final double attendancePercentage;

  const DashboardAttendanceSummary({
    required this.workingDays,
    required this.presentDays,
    required this.halfDays,
    required this.absentDays,
    required this.attendancePercentage,
  });

  factory DashboardAttendanceSummary.fromJson(Map<String, dynamic> json) {
    return DashboardAttendanceSummary(
      workingDays:          _toInt(json['working_days']),
      presentDays:          _toInt(json['present_days']),
      halfDays:             _toInt(json['half_days']),
      absentDays:           _toInt(json['absent_days']),
      attendancePercentage: _toDouble(json['attendance_percentage']),
    );
  }

  factory DashboardAttendanceSummary.empty() =>
      const DashboardAttendanceSummary(
        workingDays: 0, presentDays: 0, halfDays: 0,
        absentDays: 0, attendancePercentage: 0,
      );
}

// ── Project Summary ────────────────────────────────────────────────────────

class DashboardProjectSummary {
  final int projectId;
  final String projectName;
  final int total;
  final int completed;
  final int assigned;
  final int pending;
  final int progressPercentage;

  const DashboardProjectSummary({
    required this.projectId,
    required this.projectName,
    required this.total,
    required this.completed,
    required this.assigned,
    required this.pending,
    required this.progressPercentage,
  });

  factory DashboardProjectSummary.fromJson(Map<String, dynamic> json) {
    return DashboardProjectSummary(
      projectId:          _toInt(json['project_id']),
      projectName:        _toStr(json['project_name']),
      total:              _toInt(json['total']),
      completed:          _toInt(json['completed']),
      assigned:           _toInt(json['assigned']),
      pending:            _toInt(json['pending']),
      progressPercentage: _toInt(json['progress_percentage']),
    );
  }
}

// ── Team Member ────────────────────────────────────────────────────────────

class DashboardTeamMember {
  final int id;
  final String name;
  final String email;

  const DashboardTeamMember({
    required this.id,
    required this.name,
    required this.email,
  });

  factory DashboardTeamMember.fromJson(Map<String, dynamic> json) {
    return DashboardTeamMember(
      id:    _toInt(json['id']),
      name:  _toStr(json['name']),
      email: _toStr(json['email']),
    );
  }
}

// ── Member Task Summary ────────────────────────────────────────────────────

class MemberTaskSummary {
  final int memberId;
  final String memberName;
  final bool isLeader;
  final DashboardTaskSummary summary;

  const MemberTaskSummary({
    required this.memberId,
    required this.memberName,
    required this.isLeader,
    required this.summary,
  });

  factory MemberTaskSummary.fromJson(Map<String, dynamic> json) {
    final rawSummary = json['summary'];
    return MemberTaskSummary(
      memberId:   _toInt(json['member_id']),
      memberName: _toStr(json['member_name']),
      isLeader:   _toBool(json['is_leader']),
      summary: (rawSummary is Map)
          ? DashboardTaskSummary.fromJson(
              Map<String, dynamic>.from(rawSummary))
          : DashboardTaskSummary.empty(),
    );
  }
}

// ── Member Attendance Summary ──────────────────────────────────────────────
// Backend returns a flat object:
//   { member_id, member_name, working_days, present_days, half_days,
//     absent_days, attendance_percentage }

class MemberAttendanceSummary {
  final int memberId;
  final String memberName;
  final DashboardAttendanceSummary attendance;

  const MemberAttendanceSummary({
    required this.memberId,
    required this.memberName,
    required this.attendance,
  });

  factory MemberAttendanceSummary.fromJson(Map<String, dynamic> json) {
    return MemberAttendanceSummary(
      memberId:   _toInt(json['member_id']),
      memberName: _toStr(json['member_name']),
      // The attendance fields are flat in the same JSON object
      attendance: DashboardAttendanceSummary.fromJson(json),
    );
  }
}

// ── Upcoming Deadline Task ─────────────────────────────────────────────────

class UpcomingDeadlineTask {
  final int id;
  final String title;
  final String projectName;
  final String deadlineFormatted;
  final int daysRemaining;
  final String status;
  final String taskType;
  final bool isOverdue;
  final bool isToday;
  final bool isUrgent;
  final String assignedToName;

  const UpcomingDeadlineTask({
    required this.id,
    required this.title,
    required this.projectName,
    required this.deadlineFormatted,
    required this.daysRemaining,
    required this.status,
    required this.taskType,
    required this.isOverdue,
    required this.isToday,
    required this.isUrgent,
    required this.assignedToName,
  });

  factory UpcomingDeadlineTask.fromJson(Map<String, dynamic> json) {
    return UpcomingDeadlineTask(
      id: _toInt(json['id']),
      // Backend sends 'name' key (not 'title')
      title: _toStr(json['name'] ?? json['title']),
      projectName:       _toStr(json['project_name']),
      deadlineFormatted: _toStr(
        json['deadline_formatted'] ?? json['deadline'],
      ),
      daysRemaining:  _toInt(json['days_remaining']),
      status:         _toStr(json['status'], 'pending'),
      taskType:       _toStr(json['task_type'], 'general'),
      isOverdue:      _toBool(json['is_overdue']),
      isToday:        _toBool(json['is_today']),
      isUrgent:       _toBool(json['is_urgent']),
      assignedToName: _toStr(json['assigned_to_name']),
    );
  }
}

// ── Top-level Dashboard Model ──────────────────────────────────────────────

class DashboardModel {
  final String role;
  final String userName;
  final int userId;
  final String? profilePhotoUrl;
  final String startDate;
  final String endDate;

  // Employee
  final DashboardTaskSummary taskSummary;
  final List<DashboardProjectSummary> projectSummary;
  final DashboardAttendanceSummary attendanceSummary;
  final List<UpcomingDeadlineTask> upcomingTasks;

  // Team Leader
  final String? teamName;
  final List<DashboardTeamMember> teamMembers;
  final DashboardTaskSummary leaderTaskSummary;
  final DashboardAttendanceSummary leaderAttendanceSummary;
  final DashboardTaskSummary combinedTaskSummary;
  final DashboardTaskSummary teamTaskSummary;
  final List<MemberTaskSummary> memberTaskSummaries;
  final List<MemberAttendanceSummary> memberAttendance;
  final List<UpcomingDeadlineTask> teamUpcomingTasks;

  const DashboardModel({
    required this.role,
    required this.userName,
    required this.userId,
    this.profilePhotoUrl,
    required this.startDate,
    required this.endDate,
    required this.taskSummary,
    required this.projectSummary,
    required this.attendanceSummary,
    this.upcomingTasks = const [],
    this.teamName,
    this.teamMembers = const [],
    required this.leaderTaskSummary,
    required this.leaderAttendanceSummary,
    required this.combinedTaskSummary,
    required this.teamTaskSummary,
    this.memberTaskSummaries = const [],
    this.memberAttendance = const [],
    this.teamUpcomingTasks = const [],
  });

  bool get isTeamLeader => role == 'team_leader';

  // ── FIX: moved _parseUpcoming OUT of factory to avoid Dart illegal
  //         nested-function-in-factory compile error.
  // ──────────────────────────────────────────────────────────────────
  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    final userDetails = (json['user_details'] is Map)
        ? Map<String, dynamic>.from(json['user_details'] as Map)
        : <String, dynamic>{};

    final dateRange = (json['date_range'] is Map)
        ? Map<String, dynamic>.from(json['date_range'] as Map)
        : <String, dynamic>{};

    final role = _toStr(json['role'], 'employee');

    // ── Task summaries ─────────────────────────────────────────────────────
    final taskSummary = (json['task_summary'] is Map)
        ? DashboardTaskSummary.fromJson(
            Map<String, dynamic>.from(json['task_summary'] as Map))
        : DashboardTaskSummary.empty();

    final projectSummary = _toMapList(json['project_summary'])
        .map(DashboardProjectSummary.fromJson)
        .toList();

    final attendanceSummary = (json['attendance_summary'] is Map)
        ? DashboardAttendanceSummary.fromJson(
            Map<String, dynamic>.from(json['attendance_summary'] as Map))
        : DashboardAttendanceSummary.empty();

    // ── Team-leader-only fields ────────────────────────────────────────────
    final teamInfo = (json['team_info'] is Map)
        ? Map<String, dynamic>.from(json['team_info'] as Map)
        : null;

    final teamMembers = _toMapList(json['team_members'])
        .map(DashboardTeamMember.fromJson)
        .toList();

    final leaderTask = (json['leader_task_summary'] is Map)
        ? DashboardTaskSummary.fromJson(
            Map<String, dynamic>.from(json['leader_task_summary'] as Map))
        : DashboardTaskSummary.empty();

    final leaderAtt = (json['leader_attendance_summary'] is Map)
        ? DashboardAttendanceSummary.fromJson(
            Map<String, dynamic>.from(json['leader_attendance_summary'] as Map))
        : DashboardAttendanceSummary.empty();

    final combined = (json['combined_task_summary'] is Map)
        ? DashboardTaskSummary.fromJson(
            Map<String, dynamic>.from(json['combined_task_summary'] as Map))
        : DashboardTaskSummary.empty();

    final teamOnly = (json['team_task_summary'] is Map)
        ? DashboardTaskSummary.fromJson(
            Map<String, dynamic>.from(json['team_task_summary'] as Map))
        : DashboardTaskSummary.empty();

    final memberTaskSummaries = _toMapList(json['member_task_summaries'])
        .map(MemberTaskSummary.fromJson)
        .toList();

    final memberAttendance = _toMapList(json['member_attendance'])
        .map(MemberAttendanceSummary.fromJson)
        .toList();

    // ── Upcoming tasks ─────────────────────────────────────────────────────
    // FIX: was a nested function inside factory → illegal in Dart.
    // Extracted to top-level helper _parseUpcomingTasks().
    final upcomingTasks =
        _parseUpcomingTasks(json['upcoming_tasks']);
    final teamUpcomingTasks =
        _parseUpcomingTasks(
          json['team_upcoming_tasks'] ?? json['upcoming_tasks'],
        );

    return DashboardModel(
      role:                    role,
      userName:                _toStr(userDetails['name']),
      userId:                  _toInt(userDetails['id']),
      profilePhotoUrl:         userDetails['profile_photo_url']?.toString(),
      startDate:               _toStr(dateRange['start_date']),
      endDate:                 _toStr(dateRange['end_date']),
      taskSummary:             taskSummary,
      projectSummary:          projectSummary,
      attendanceSummary:       attendanceSummary,
      upcomingTasks:           upcomingTasks,
      teamName:                teamInfo?['name']?.toString(),
      teamMembers:             teamMembers,
      leaderTaskSummary:       leaderTask,
      leaderAttendanceSummary: leaderAtt,
      combinedTaskSummary:     combined,
      teamTaskSummary:         teamOnly,
      memberTaskSummaries:     memberTaskSummaries,
      memberAttendance:        memberAttendance,
      teamUpcomingTasks:       teamUpcomingTasks,
    );
  }
}

// ── FIX: top-level helper (was illegal nested function in factory) ──────────
List<UpcomingDeadlineTask> _parseUpcomingTasks(dynamic raw) {
  return _toMapList(raw).map(UpcomingDeadlineTask.fromJson).toList();
}