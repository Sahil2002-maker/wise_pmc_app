// lib/features/employee_report/data/models/employee_report_models.dart

// ── Init response models ──────────────────────────────────────────────────────

class ReportUser {
  final int id;
  final String name;

  const ReportUser({required this.id, required this.name});

  factory ReportUser.fromJson(Map<String, dynamic> json) => ReportUser(
        id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
        name: json['name']?.toString() ?? '',
      );
}

class ReportTeam {
  final int id;
  final String teamName;
  final String teamColor;

  const ReportTeam({
    required this.id,
    required this.teamName,
    required this.teamColor,
  });

  factory ReportTeam.fromJson(Map<String, dynamic> json) => ReportTeam(
        id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
        teamName: json['team_name']?.toString() ?? '',
        teamColor: json['team_color']?.toString() ?? '#77DD77',
      );
}

// ── Report member (row in the matrix) ────────────────────────────────────────

class ReportMember {
  final int id;
  final String name;
  final bool isLeader;
  final Map<String, int> taskCounts; // date -> count
  final int totalTasks;
  final int maxTasks;
  final double avgTasks;
  final int zeroDays;

  const ReportMember({
    required this.id,
    required this.name,
    required this.isLeader,
    required this.taskCounts,
    required this.totalTasks,
    required this.maxTasks,
    required this.avgTasks,
    required this.zeroDays,
  });

  factory ReportMember.fromJson(Map<String, dynamic> json) {
    final raw = json['task_counts'] as Map<String, dynamic>? ?? {};
    final counts = raw.map((k, v) =>
        MapEntry(k, int.tryParse(v?.toString() ?? '0') ?? 0));

    return ReportMember(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      isLeader: json['is_leader'] == true,
      taskCounts: counts,
      totalTasks: int.tryParse(json['total_tasks']?.toString() ?? '0') ?? 0,
      maxTasks: int.tryParse(json['max_tasks']?.toString() ?? '0') ?? 0,
      avgTasks:
          double.tryParse(json['avg_tasks']?.toString() ?? '0') ?? 0.0,
      zeroDays: int.tryParse(json['zero_days']?.toString() ?? '0') ?? 0,
    );
  }
}

// ── Team group ────────────────────────────────────────────────────────────────

class ReportTeamGroup {
  final int teamId;
  final String teamName;
  final String teamColor;
  final String teamLeaderName;
  final List<ReportMember> members;

  const ReportTeamGroup({
    required this.teamId,
    required this.teamName,
    required this.teamColor,
    required this.teamLeaderName,
    required this.members,
  });

  factory ReportTeamGroup.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['members'] as List<dynamic>? ?? [];
    return ReportTeamGroup(
      teamId: int.tryParse(json['team_id']?.toString() ?? '0') ?? 0,
      teamName: json['team_name']?.toString() ?? '',
      teamColor: json['team_color']?.toString() ?? '#77DD77',
      teamLeaderName: json['team_leader_name']?.toString() ?? '',
      members: rawMembers
          .whereType<Map<String, dynamic>>()
          .map(ReportMember.fromJson)
          .toList(),
    );
  }
}

// ── Generate response ─────────────────────────────────────────────────────────

class EmployeeReportData {
  final List<ReportTeamGroup> teams;
  final List<String> dates;

  const EmployeeReportData({required this.teams, required this.dates});

  factory EmployeeReportData.fromJson(Map<String, dynamic> json) {
    final rawTeams = json['data'] as List<dynamic>? ?? [];
    final rawDates = json['dates'] as List<dynamic>? ?? [];
    return EmployeeReportData(
      teams: rawTeams
          .whereType<Map<String, dynamic>>()
          .map(ReportTeamGroup.fromJson)
          .toList(),
      dates: rawDates.map((d) => d.toString()).toList(),
    );
  }
}

// ── Task detail models ────────────────────────────────────────────────────────

class ReportProcessTask {
  final int id;
  final int projectId;
  final String projectName;
  final int processId;
  final String processName;
  final String status; // 'completed' | 'overdue' | 'pending'
  final String? deadline;

  const ReportProcessTask({
    required this.id,
    required this.projectId,
    required this.projectName,
    required this.processId,
    required this.processName,
    required this.status,
    this.deadline,
  });

  factory ReportProcessTask.fromJson(Map<String, dynamic> json) =>
      ReportProcessTask(
        id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
        projectId: int.tryParse(json['project_id']?.toString() ?? '0') ?? 0,
        projectName: json['project_name']?.toString() ?? '',
        processId: int.tryParse(json['process_id']?.toString() ?? '0') ?? 0,
        processName: json['process_name']?.toString() ?? '',
        status: json['status']?.toString() ?? 'pending',
        deadline: json['deadline']?.toString(),
      );
}

class ReportGeneralTask {
  final int taskId;
  final String taskName;
  final String? taskDescription;
  final String? taskDeadline;
  final String status;

  const ReportGeneralTask({
    required this.taskId,
    required this.taskName,
    this.taskDescription,
    this.taskDeadline,
    required this.status,
  });

  factory ReportGeneralTask.fromJson(Map<String, dynamic> json) =>
      ReportGeneralTask(
        taskId: int.tryParse(json['task_id']?.toString() ?? '0') ?? 0,
        taskName: json['task_name']?.toString() ?? '',
        taskDescription: json['task_description']?.toString(),
        taskDeadline: json['task_deadline']?.toString(),
        status: json['status']?.toString() ?? 'pending',
      );
}

class TaskDetailResult {
  final List<ReportProcessTask> processTasks;
  final List<ReportGeneralTask> generalTasks;

  const TaskDetailResult({
    required this.processTasks,
    required this.generalTasks,
  });

  factory TaskDetailResult.fromJson(Map<String, dynamic> json) {
    final rawProcess = json['process_tasks'] as List<dynamic>? ?? [];
    final rawGeneral = json['general_tasks'] as List<dynamic>? ?? [];
    return TaskDetailResult(
      processTasks: rawProcess
          .whereType<Map<String, dynamic>>()
          .map(ReportProcessTask.fromJson)
          .toList(),
      generalTasks: rawGeneral
          .whereType<Map<String, dynamic>>()
          .map(ReportGeneralTask.fromJson)
          .toList(),
    );
  }
}