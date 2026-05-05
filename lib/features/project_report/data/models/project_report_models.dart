// lib/features/project_report/data/models/project_report_models.dart

// ── Project (dropdown item) ────────────────────────────────────────────────

class ReportProject {
  final int id;
  final String societyName;

  const ReportProject({required this.id, required this.societyName});

  factory ReportProject.fromJson(Map<String, dynamic> json) => ReportProject(
        id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
        societyName: json['society_name']?.toString() ?? '',
      );
}

// ── Team row ───────────────────────────────────────────────────────────────

class ProjectReportTeamRow {
  final int teamId;
  final String teamName;
  final String teamColor;
  final String teamLeader;
  final int completedTasks;
  final int pendingTasks;
  final int notAssignedTasks;
  final int totalTasks;
  final int overdueTasks;
  final int upcomingDeadlineTasks;

  const ProjectReportTeamRow({
    required this.teamId,
    required this.teamName,
    required this.teamColor,
    required this.teamLeader,
    required this.completedTasks,
    required this.pendingTasks,
    required this.notAssignedTasks,
    required this.totalTasks,
    required this.overdueTasks,
    required this.upcomingDeadlineTasks,
  });

  factory ProjectReportTeamRow.fromJson(Map<String, dynamic> json) =>
      ProjectReportTeamRow(
        teamId: int.tryParse(json['team_id']?.toString() ?? '0') ?? 0,
        teamName: json['team_name']?.toString() ?? '',
        teamColor: json['team_color']?.toString() ?? '#77DD77',
        teamLeader: json['team_leader']?.toString() ?? 'N/A',
        completedTasks:
            int.tryParse(json['completed_tasks']?.toString() ?? '0') ?? 0,
        pendingTasks:
            int.tryParse(json['pending_tasks']?.toString() ?? '0') ?? 0,
        notAssignedTasks:
            int.tryParse(json['not_assigned_tasks']?.toString() ?? '0') ?? 0,
        totalTasks:
            int.tryParse(json['total_tasks']?.toString() ?? '0') ?? 0,
        overdueTasks:
            int.tryParse(json['overdue_tasks']?.toString() ?? '0') ?? 0,
        upcomingDeadlineTasks:
            int.tryParse(json['upcoming_deadline_tasks']?.toString() ?? '0') ??
                0,
      );
}

// ── Summary ────────────────────────────────────────────────────────────────

class ProjectReportSummary {
  final int totalTeams;
  final int totalCompleted;
  final int totalPending;
  final int totalNotAssigned;
  final int totalTasks;
  final int totalOverdue;
  final int totalUpcoming;

  const ProjectReportSummary({
    required this.totalTeams,
    required this.totalCompleted,
    required this.totalPending,
    required this.totalNotAssigned,
    required this.totalTasks,
    required this.totalOverdue,
    required this.totalUpcoming,
  });

  factory ProjectReportSummary.fromJson(Map<String, dynamic> json) =>
      ProjectReportSummary(
        totalTeams:
            int.tryParse(json['total_teams']?.toString() ?? '0') ?? 0,
        totalCompleted:
            int.tryParse(json['total_completed']?.toString() ?? '0') ?? 0,
        totalPending:
            int.tryParse(json['total_pending']?.toString() ?? '0') ?? 0,
        totalNotAssigned:
            int.tryParse(json['total_not_assigned']?.toString() ?? '0') ?? 0,
        totalTasks:
            int.tryParse(json['total_tasks']?.toString() ?? '0') ?? 0,
        totalOverdue:
            int.tryParse(json['total_overdue']?.toString() ?? '0') ?? 0,
        totalUpcoming:
            int.tryParse(json['total_upcoming']?.toString() ?? '0') ?? 0,
      );
}

// ── Full response ──────────────────────────────────────────────────────────

class ProjectReportData {
  final List<ProjectReportTeamRow> teams;
  final ProjectReportSummary summary;

  const ProjectReportData({required this.teams, required this.summary});

  factory ProjectReportData.fromJson(Map<String, dynamic> json) {
    final rawTeams = json['data'] as List<dynamic>? ?? [];
    final rawSummary =
        json['summary'] as Map<String, dynamic>? ?? {};
    return ProjectReportData(
      teams: rawTeams
          .whereType<Map<String, dynamic>>()
          .map(ProjectReportTeamRow.fromJson)
          .toList(),
      summary: ProjectReportSummary.fromJson(rawSummary),
    );
  }
}