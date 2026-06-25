// lib/features/stage21/data/models/daily_project_report_model.dart

// ── Labor Report Row ──────────────────────────────────────────────────────────

class LaborReportRow {
  final String? agency;
  final double daySup;
  final double daySkilled;
  final double dayUnskilled;
  final double nightSup;
  final double nightSkilled;
  final double nightUnskilled;
  final double total;
  final String? remarks;

  const LaborReportRow({
    this.agency,
    this.daySup = 0,
    this.daySkilled = 0,
    this.dayUnskilled = 0,
    this.nightSup = 0,
    this.nightSkilled = 0,
    this.nightUnskilled = 0,
    this.total = 0,
    this.remarks,
  });

  factory LaborReportRow.fromJson(Map<String, dynamic> json) {
    double _d(String key) =>
        double.tryParse(json[key]?.toString() ?? '0') ?? 0;
    return LaborReportRow(
      agency:         json['agency']?.toString(),
      daySup:         _d('day_sup'),
      daySkilled:     _d('day_skilled'),
      dayUnskilled:   _d('day_unskilled'),
      nightSup:       _d('night_sup'),
      nightSkilled:   _d('night_skilled'),
      nightUnskilled: _d('night_unskilled'),
      total:          _d('total'),
      remarks:        json['remarks']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'agency':          agency ?? '',
        'day_sup':         daySup,
        'day_skilled':     daySkilled,
        'day_unskilled':   dayUnskilled,
        'night_sup':       nightSup,
        'night_skilled':   nightSkilled,
        'night_unskilled': nightUnskilled,
        'total':           total,
        'remarks':         remarks ?? '',
      };
}

// ── Progress Previous Row ─────────────────────────────────────────────────────

class ProgressPreviousRow {
  final String? activity;
  final double plannedPct;
  final double actualPct;
  final double plannedCumulative;
  final double actualCumulative;
  final String? remarks;

  const ProgressPreviousRow({
    this.activity,
    this.plannedPct = 0,
    this.actualPct = 0,
    this.plannedCumulative = 0,
    this.actualCumulative = 0,
    this.remarks,
  });

  factory ProgressPreviousRow.fromJson(Map<String, dynamic> json) {
    double _d(String key) =>
        double.tryParse(json[key]?.toString() ?? '0') ?? 0;
    return ProgressPreviousRow(
      activity:           json['activity']?.toString(),
      plannedPct:         _d('planned_pct'),
      actualPct:          _d('actual_pct'),
      plannedCumulative:  _d('planned_cumulative'),
      actualCumulative:   _d('actual_cumulative'),
      remarks:            json['remarks']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'activity':           activity ?? '',
        'planned_pct':        plannedPct,
        'actual_pct':         actualPct,
        'planned_cumulative': plannedCumulative,
        'actual_cumulative':  actualCumulative,
        'remarks':            remarks ?? '',
      };
}

// ── Works Planned Row ─────────────────────────────────────────────────────────

class WorksPlannedRow {
  final String? activity;
  final String? plannedQty;
  final String? remarks;

  const WorksPlannedRow({this.activity, this.plannedQty, this.remarks});

  factory WorksPlannedRow.fromJson(Map<String, dynamic> json) =>
      WorksPlannedRow(
        activity:   json['activity']?.toString(),
        plannedQty: json['planned_qty']?.toString(),
        remarks:    json['remarks']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'activity':    activity ?? '',
        'planned_qty': plannedQty ?? '',
        'remarks':     remarks ?? '',
      };
}

// ── Photo URL ─────────────────────────────────────────────────────────────────

class DprPhotoUrl {
  final String path;
  final String name;
  final String url;

  const DprPhotoUrl({required this.path, required this.name, required this.url});

  factory DprPhotoUrl.fromJson(Map<String, dynamic> json) => DprPhotoUrl(
        path: json['path']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        url:  json['url']?.toString() ?? '',
      );
}

// ── Creator ───────────────────────────────────────────────────────────────────

class DprCreator {
  final int id;
  final String name;

  const DprCreator({required this.id, required this.name});

  factory DprCreator.fromJson(Map<String, dynamic> json) => DprCreator(
        id:   int.tryParse(json['id']?.toString() ?? '0') ?? 0,
        name: json['name']?.toString() ?? '',
      );
}

// ── Daily Project Report Summary (used in list view) ─────────────────────────

class DailyProjectReportSummary {
  final int id;
  final String reportNo;
  final String? reportDate;
  final String? reportDateRaw;
  final String? weather;
  final int totalPhotos;
  final DprCreator? creator;
  final String? createdAt;
  final int laborCount;
  final bool hasDecisions;
  final bool hasBottleNecks;
  final bool hasMaterialDelivered;
  final bool hasEhs;

  const DailyProjectReportSummary({
    required this.id,
    required this.reportNo,
    this.reportDate,
    this.reportDateRaw,
    this.weather,
    this.totalPhotos = 0,
    this.creator,
    this.createdAt,
    this.laborCount = 0,
    this.hasDecisions = false,
    this.hasBottleNecks = false,
    this.hasMaterialDelivered = false,
    this.hasEhs = false,
  });

  factory DailyProjectReportSummary.fromJson(Map<String, dynamic> json) {
    DprCreator? creator;
    if (json['creator'] is Map<String, dynamic>) {
      creator = DprCreator.fromJson(json['creator'] as Map<String, dynamic>);
    }
    return DailyProjectReportSummary(
      id:                   int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      reportNo:             json['report_no']?.toString() ?? '',
      reportDate:           json['report_date']?.toString(),
      reportDateRaw:        json['report_date_raw']?.toString(),
      weather:              json['weather']?.toString(),
      totalPhotos:          int.tryParse(json['total_photos']?.toString() ?? '0') ?? 0,
      creator:              creator,
      createdAt:            json['created_at']?.toString(),
      laborCount:           int.tryParse(json['labor_count']?.toString() ?? '0') ?? 0,
      hasDecisions:         _parseBool(json['has_decisions']),
      hasBottleNecks:       _parseBool(json['has_bottle_necks']),
      hasMaterialDelivered: _parseBool(json['has_material_delivered']),
      hasEhs:               _parseBool(json['has_ehs']),
    );
  }

  static bool _parseBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    return v == 1 || v.toString().toLowerCase() == 'true';
  }
}

// ── Daily Project Report Detail (used in show/edit) ──────────────────────────

class DailyProjectReportDetail {
  final int id;
  final int projectId;
  final String reportNo;
  final String? reportDate;
  final String? reportDateRaw;
  final String? weather;
  final List<LaborReportRow> laborReport;
  final List<ProgressPreviousRow> progressPrevious;
  final List<WorksPlannedRow> worksPlanned;
  final String? decisionsApprovals;
  final String? bottleNecks;
  final String? changeAuthorizations;
  final String? materialDelivered;
  final String? ehsIncidentReports;
  final List<DprPhotoUrl> photoUrls;
  final DprCreator? creator;
  final String? createdAt;

  const DailyProjectReportDetail({
    required this.id,
    required this.projectId,
    required this.reportNo,
    this.reportDate,
    this.reportDateRaw,
    this.weather,
    this.laborReport = const [],
    this.progressPrevious = const [],
    this.worksPlanned = const [],
    this.decisionsApprovals,
    this.bottleNecks,
    this.changeAuthorizations,
    this.materialDelivered,
    this.ehsIncidentReports,
    this.photoUrls = const [],
    this.creator,
    this.createdAt,
  });

  factory DailyProjectReportDetail.fromJson(Map<String, dynamic> json) {
    List<T> _parseList<T>(
      dynamic raw,
      T Function(Map<String, dynamic>) fromJson,
    ) {
      if (raw is! List) return [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(fromJson)
          .toList();
    }

    DprCreator? creator;
    if (json['creator'] is Map<String, dynamic>) {
      creator = DprCreator.fromJson(json['creator'] as Map<String, dynamic>);
    }

    return DailyProjectReportDetail(
      id:                    int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      projectId:             int.tryParse(json['project_id']?.toString() ?? '0') ?? 0,
      reportNo:              json['report_no']?.toString() ?? '',
      reportDate:            json['report_date']?.toString(),
      reportDateRaw:         json['report_date_raw']?.toString(),
      weather:               json['weather']?.toString(),
      laborReport:           _parseList(json['labor_report'],      LaborReportRow.fromJson),
      progressPrevious:      _parseList(json['progress_previous'], ProgressPreviousRow.fromJson),
      worksPlanned:          _parseList(json['works_planned'],     WorksPlannedRow.fromJson),
      decisionsApprovals:    json['decisions_approvals']?.toString(),
      bottleNecks:           json['bottle_necks']?.toString(),
      changeAuthorizations:  json['change_authorizations']?.toString(),
      materialDelivered:     json['material_delivered']?.toString(),
      ehsIncidentReports:    json['ehs_incident_reports']?.toString(),
      photoUrls:             _parseList(json['photo_urls'],        DprPhotoUrl.fromJson),
      creator:               creator,
      createdAt:             json['created_at']?.toString(),
    );
  }
}