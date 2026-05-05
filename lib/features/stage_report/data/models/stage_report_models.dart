// lib/features/stage_report/data/models/stage_report_models.dart

class StageReportProject {
  final int id;
  final String societyName;

  const StageReportProject({required this.id, required this.societyName});

  factory StageReportProject.fromJson(Map<String, dynamic> json) {
    return StageReportProject(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      societyName: json['society_name']?.toString() ?? '',
    );
  }
}

class StageTaskStats {
  final int completed;
  final int pending;
  final int assigned;
  final int total;

  const StageTaskStats({
    required this.completed,
    required this.pending,
    required this.assigned,
    required this.total,
  });

  factory StageTaskStats.fromJson(Map<String, dynamic> json) {
    return StageTaskStats(
      completed: _parseInt(json['completed']),
      pending: _parseInt(json['pending']),
      assigned: _parseInt(json['assigned']),
      total: _parseInt(json['total']),
    );
  }

  static int _parseInt(dynamic v) =>
      v is int ? v : int.tryParse(v?.toString() ?? '0') ?? 0;
}

class StageReportRow {
  final int srNo;
  final int projectId;
  final String projectName;
  final StageTaskStats stage1;
  final StageTaskStats stage2;

  const StageReportRow({
    required this.srNo,
    required this.projectId,
    required this.projectName,
    required this.stage1,
    required this.stage2,
  });

  factory StageReportRow.fromJson(Map<String, dynamic> json, {int srNo = 0}) {
    return StageReportRow(
      srNo: srNo,
      projectId: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      projectName: json['project_name']?.toString() ??
          json['society_name']?.toString() ??
          '',
      stage1: StageTaskStats(
        completed: _parseInt(json['stage1_completed']),
        pending: _parseInt(json['stage1_pending']),
        assigned: _parseInt(json['stage1_assigned']),
        total: _parseInt(json['stage1_total']),
      ),
      stage2: StageTaskStats(
        completed: _parseInt(json['stage2_completed']),
        pending: _parseInt(json['stage2_pending']),
        assigned: _parseInt(json['stage2_assigned']),
        total: _parseInt(json['stage2_total']),
      ),
    );
  }

  static int _parseInt(dynamic v) =>
      v is int ? v : int.tryParse(v?.toString() ?? '0') ?? 0;
}

class StageReportResponse {
  final List<StageReportRow> rows;
  final int total;
  final int currentPage;
  final int lastPage;

  const StageReportResponse({
    required this.rows,
    required this.total,
    required this.currentPage,
    required this.lastPage,
  });

  factory StageReportResponse.empty() => const StageReportResponse(
        rows: [],
        total: 0,
        currentPage: 1,
        lastPage: 1,
      );
}