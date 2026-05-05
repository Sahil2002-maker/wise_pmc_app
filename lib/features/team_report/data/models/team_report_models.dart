// lib/features/team_report/data/models/team_report_models.dart


class TeamReportTeamItem {
  final int id;
  final String teamName;

  const TeamReportTeamItem({required this.id, required this.teamName});

  factory TeamReportTeamItem.fromJson(Map<String, dynamic> json) =>
      TeamReportTeamItem(
        id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
        teamName: json['team_name']?.toString() ?? '',
      );
}



class TeamReportMemberItem {
  final int id;
  final String name;
  final bool isLeader;
  final String label;

  const TeamReportMemberItem({
    required this.id,
    required this.name,
    required this.isLeader,
    required this.label,
  });

  factory TeamReportMemberItem.fromJson(Map<String, dynamic> json) =>
      TeamReportMemberItem(
        id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
        name: json['name']?.toString() ?? '',
        isLeader: json['is_leader'] == true,
        label: json['label']?.toString() ??
            json['name']?.toString() ??
            '',
      );
}

// ── Project Report Row ────────────────────────────────────────────────────────

class TeamReportRow {
  final int projectId;
  final String projectName;
  final int completedTasks;
  final int pendingTasks;
  final int notAssignedTasks;
  final int totalTasks;
  final int overdueTasks;
  final int upcomingDeadlineTasks;

  const TeamReportRow({
    required this.projectId,
    required this.projectName,
    required this.completedTasks,
    required this.pendingTasks,
    required this.notAssignedTasks,
    required this.totalTasks,
    required this.overdueTasks,
    required this.upcomingDeadlineTasks,
  });

  factory TeamReportRow.fromJson(Map<String, dynamic> json) => TeamReportRow(
        projectId:
            int.tryParse(json['project_id']?.toString() ?? '0') ?? 0,
        projectName: json['project_name']?.toString() ?? '',
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
        upcomingDeadlineTasks: int.tryParse(
                json['upcoming_deadline_tasks']?.toString() ?? '0') ??
            0,
      );

  /// Completion percentage (0.0 – 1.0) for progress bar.
  double get completionRatio =>
      totalTasks == 0 ? 0.0 : completedTasks / totalTasks;

  double get pendingRatio =>
      totalTasks == 0 ? 0.0 : pendingTasks / totalTasks;

  double get notAssignedRatio =>
      totalTasks == 0 ? 0.0 : notAssignedTasks / totalTasks;
}

// ── Report Summary ────────────────────────────────────────────────────────────

class TeamReportSummary {
  final int totalProjects;
  final int totalCompleted;
  final int totalPending;
  final int totalNotAssigned;
  final int totalOverdue;
  final int totalUpcomingDeadline;

  const TeamReportSummary({
    required this.totalProjects,
    required this.totalCompleted,
    required this.totalPending,
    required this.totalNotAssigned,
    required this.totalOverdue,
    required this.totalUpcomingDeadline,
  });

  factory TeamReportSummary.fromJson(Map<String, dynamic> json) =>
      TeamReportSummary(
        totalProjects:
            int.tryParse(json['total_projects']?.toString() ?? '0') ?? 0,
        totalCompleted:
            int.tryParse(json['total_completed']?.toString() ?? '0') ?? 0,
        totalPending:
            int.tryParse(json['total_pending']?.toString() ?? '0') ?? 0,
        totalNotAssigned:
            int.tryParse(json['total_not_assigned']?.toString() ?? '0') ?? 0,
        totalOverdue:
            int.tryParse(json['total_overdue']?.toString() ?? '0') ?? 0,
        totalUpcomingDeadline: int.tryParse(
                json['total_upcoming_deadline']?.toString() ?? '0') ??
            0,
      );

  static const TeamReportSummary empty = TeamReportSummary(
    totalProjects: 0,
    totalCompleted: 0,
    totalPending: 0,
    totalNotAssigned: 0,
    totalOverdue: 0,
    totalUpcomingDeadline: 0,
  );
}

// ── Full Report Result ────────────────────────────────────────────────────────

class TeamReportResult {
  final List<TeamReportRow> rows;
  final TeamReportSummary summary;
  final int total;
  final int currentPage;
  final int lastPage;
  final int perPage;

  const TeamReportResult({
    required this.rows,
    required this.summary,
    required this.total,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
  });

  factory TeamReportResult.fromJson(Map<String, dynamic> json) {
    final rawRows = json['data'] as List<dynamic>? ?? [];
    final rawSummary =
        json['summary'] as Map<String, dynamic>? ?? {};

    return TeamReportResult(
      rows: rawRows
          .whereType<Map<String, dynamic>>()
          .map(TeamReportRow.fromJson)
          .toList(),
      summary: TeamReportSummary.fromJson(rawSummary),
      total: int.tryParse(json['total']?.toString() ?? '0') ?? 0,
      currentPage:
          int.tryParse(json['current_page']?.toString() ?? '1') ?? 1,
      lastPage:
          int.tryParse(json['last_page']?.toString() ?? '1') ?? 1,
      perPage:
          int.tryParse(json['per_page']?.toString() ?? '20') ?? 20,
    );
  }
}