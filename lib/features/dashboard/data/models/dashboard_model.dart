// lib/features/dashboard/data/models/dashboard_model.dart

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
      total:               _toInt(json['total']),
      completed:           _toInt(json['completed']),
      inProgress:          _toInt(json['in_progress']),
      pending:             _toInt(json['pending']),
      progressPercentage:  _toInt(json['progress_percentage']),
    );
  }

  factory DashboardTaskSummary.empty() => const DashboardTaskSummary(
        total: 0, completed: 0, inProgress: 0, pending: 0, progressPercentage: 0,
      );

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v?.toString() ?? '0') ?? 0;
  }
}

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
      workingDays:           _toInt(json['working_days']),
      presentDays:           _toInt(json['present_days']),
      halfDays:              _toInt(json['half_days']),
      absentDays:            _toInt(json['absent_days']),
      attendancePercentage:  _toDouble(json['attendance_percentage']),
    );
  }

  factory DashboardAttendanceSummary.empty() =>
      const DashboardAttendanceSummary(
        workingDays: 0, presentDays: 0, halfDays: 0,
        absentDays: 0, attendancePercentage: 0,
      );

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v?.toString() ?? '0') ?? 0;
  }

  static double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v?.toString() ?? '0') ?? 0;
  }
}

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
      projectId:            _toInt(json['project_id']),
      projectName:          json['project_name']?.toString() ?? '',
      total:                _toInt(json['total']),
      completed:            _toInt(json['completed']),
      assigned:             _toInt(json['assigned']),
      pending:              _toInt(json['pending']),
      progressPercentage:   _toInt(json['progress_percentage']),
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v?.toString() ?? '0') ?? 0;
  }
}

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
      name:  json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '0') ?? 0;
  }
}

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
    return MemberTaskSummary(
      memberId:   _toInt(json['member_id']),
      memberName: json['member_name']?.toString() ?? '',
      isLeader:   json['is_leader'] == true,
      summary: json['summary'] is Map<String, dynamic>
          ? DashboardTaskSummary.fromJson(json['summary'] as Map<String, dynamic>)
          : DashboardTaskSummary.empty(),
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '0') ?? 0;
  }
}

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
      memberName: json['member_name']?.toString() ?? '',
      attendance: DashboardAttendanceSummary.fromJson(json),
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '0') ?? 0;
  }
}

// ── Top-level model ──────────────────────────────────────────────────────────

class DashboardModel {
  final String role; // 'employee' | 'team_leader'
  final String userName;
  final int userId;
  final String? profilePhotoUrl;
  final String startDate;
  final String endDate;

  // Employee fields
  final DashboardTaskSummary taskSummary;
  final List<DashboardProjectSummary> projectSummary;
  final DashboardAttendanceSummary attendanceSummary;

  // Team leader extra fields
  final String? teamName;
  final List<DashboardTeamMember> teamMembers;
  final DashboardTaskSummary leaderTaskSummary;
  final DashboardAttendanceSummary leaderAttendanceSummary;
  final DashboardTaskSummary combinedTaskSummary;
  final DashboardTaskSummary teamTaskSummary;
  final List<MemberTaskSummary> memberTaskSummaries;
  final List<MemberAttendanceSummary> memberAttendance;

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
    this.teamName,
    this.teamMembers = const [],
    required this.leaderTaskSummary,
    required this.leaderAttendanceSummary,
    required this.combinedTaskSummary,
    required this.teamTaskSummary,
    this.memberTaskSummaries = const [],
    this.memberAttendance = const [],
  });

  bool get isTeamLeader => role == 'team_leader';

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    final userDetails = json['user_details'] as Map<String, dynamic>? ?? {};
    final dateRange   = json['date_range']   as Map<String, dynamic>? ?? {};
    final role        = json['role']?.toString() ?? 'employee';

    // Shared
    final taskSummary = json['task_summary'] is Map<String, dynamic>
        ? DashboardTaskSummary.fromJson(json['task_summary'] as Map<String, dynamic>)
        : DashboardTaskSummary.empty();

    final rawProjects = json['project_summary'] as List<dynamic>? ?? [];
    final projectSummary = rawProjects
        .whereType<Map<String, dynamic>>()
        .map(DashboardProjectSummary.fromJson)
        .toList();

    final attendanceSummary =
        json['attendance_summary'] is Map<String, dynamic>
            ? DashboardAttendanceSummary.fromJson(
                json['attendance_summary'] as Map<String, dynamic>)
            : DashboardAttendanceSummary.empty();

    // Team leader specific
    final teamInfo = json['team_info'] as Map<String, dynamic>?;

    final rawMembers = json['team_members'] as List<dynamic>? ?? [];
    final teamMembers = rawMembers
        .whereType<Map<String, dynamic>>()
        .map(DashboardTeamMember.fromJson)
        .toList();

    final leaderTask = json['leader_task_summary'] is Map<String, dynamic>
        ? DashboardTaskSummary.fromJson(json['leader_task_summary'] as Map<String, dynamic>)
        : DashboardTaskSummary.empty();

    final leaderAtt = json['leader_attendance_summary'] is Map<String, dynamic>
        ? DashboardAttendanceSummary.fromJson(
            json['leader_attendance_summary'] as Map<String, dynamic>)
        : DashboardAttendanceSummary.empty();

    final combined = json['combined_task_summary'] is Map<String, dynamic>
        ? DashboardTaskSummary.fromJson(json['combined_task_summary'] as Map<String, dynamic>)
        : DashboardTaskSummary.empty();

    final teamOnly = json['team_task_summary'] is Map<String, dynamic>
        ? DashboardTaskSummary.fromJson(json['team_task_summary'] as Map<String, dynamic>)
        : DashboardTaskSummary.empty();

    final rawMemberSummaries = json['member_task_summaries'] as List<dynamic>? ?? [];
    final memberTaskSummaries = rawMemberSummaries
        .whereType<Map<String, dynamic>>()
        .map(MemberTaskSummary.fromJson)
        .toList();

    final rawMemberAtt = json['member_attendance'] as List<dynamic>? ?? [];
    final memberAttendance = rawMemberAtt
        .whereType<Map<String, dynamic>>()
        .map(MemberAttendanceSummary.fromJson)
        .toList();

    return DashboardModel(
      role:                    role,
      userName:                userDetails['name']?.toString() ?? '',
      userId:                  _toInt(userDetails['id']),
      profilePhotoUrl:         userDetails['profile_photo_url']?.toString(),
      startDate:               dateRange['start_date']?.toString() ?? '',
      endDate:                 dateRange['end_date']?.toString() ?? '',
      taskSummary:             taskSummary,
      projectSummary:          projectSummary,
      attendanceSummary:       attendanceSummary,
      teamName:                teamInfo?['name']?.toString(),
      teamMembers:             teamMembers,
      leaderTaskSummary:       leaderTask,
      leaderAttendanceSummary: leaderAtt,
      combinedTaskSummary:     combined,
      teamTaskSummary:         teamOnly,
      memberTaskSummaries:     memberTaskSummaries,
      memberAttendance:        memberAttendance,
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '0') ?? 0;
  }
}