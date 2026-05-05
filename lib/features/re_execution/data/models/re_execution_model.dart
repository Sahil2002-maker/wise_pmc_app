// lib/features/re_execution/data/models/re_execution_model.dart

// ─────────────────────────────────────────────────────────────────────────────
// List item model  (used in the paginated list)
// ─────────────────────────────────────────────────────────────────────────────
class ReExecutionModel {
  final int id;
  final int projectId;
  final String? reportDate;
  final String? reportDateDisplay;

  // manpower totals (pre-computed by backend)
  final int totalSupDay;
  final int totalSkilledDay;
  final int totalUnskilledDay;
  final int totalSupNight;
  final int totalSkilledNight;
  final int totalUnskilledNight;

  final int photoCount;
  final String? createdByName;
  final String? createdAt;

  const ReExecutionModel({
    required this.id,
    required this.projectId,
    this.reportDate,
    this.reportDateDisplay,
    this.totalSupDay = 0,
    this.totalSkilledDay = 0,
    this.totalUnskilledDay = 0,
    this.totalSupNight = 0,
    this.totalSkilledNight = 0,
    this.totalUnskilledNight = 0,
    this.photoCount = 0,
    this.createdByName,
    this.createdAt,
  });

  int get totalDayManpower =>
      totalSupDay + totalSkilledDay + totalUnskilledDay;

  int get totalNightManpower =>
      totalSupNight + totalSkilledNight + totalUnskilledNight;

  factory ReExecutionModel.fromJson(Map<String, dynamic> json) {
    int _i(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;

    return ReExecutionModel(
      id:                   _i(json['id']),
      projectId:            _i(json['project_id']),
      reportDate:           json['report_date']?.toString(),
      reportDateDisplay:    json['report_date_display']?.toString(),
      totalSupDay:          _i(json['total_sup_day']),
      totalSkilledDay:      _i(json['total_skilled_day']),
      totalUnskilledDay:    _i(json['total_unskilled_day']),
      totalSupNight:        _i(json['total_sup_night']),
      totalSkilledNight:    _i(json['total_skilled_night']),
      totalUnskilledNight:  _i(json['total_unskilled_night']),
      photoCount:           _i(json['photo_count']),
      createdByName:        json['created_by_name']?.toString(),
      createdAt:            json['created_at']?.toString(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail model  (used in the form + detail page)
// ─────────────────────────────────────────────────────────────────────────────
class ReExecutionDetailModel {
  final int id;
  final int projectId;
  final String? reportDate;
  final String? reportDateDisplay;

  // A. Labor
  final List<Map<String, dynamic>> laborAgencies;
  final int totalSupDay;
  final int totalSkilledDay;
  final int totalUnskilledDay;
  final int totalSupNight;
  final int totalSkilledNight;
  final int totalUnskilledNight;

  // B. Progress
  final List<Map<String, dynamic>> previousProgress;
  final List<Map<String, dynamic>> plannedWorks;

  // C. Text fields
  final String decisionsApprovals;

  // Progress Photos
  final List<Map<String, dynamic>> progressPhotos;

  // Extra text fields (matching blade order)
  final String bottleNecks;
  final String changeAuthorizations;
  final String materialDelivered;
  final String ehsIncidentReports;

  // Meta
  final String? createdByName;
  final String? createdAt;
  final String? updatedAt;

  const ReExecutionDetailModel({
    required this.id,
    required this.projectId,
    this.reportDate,
    this.reportDateDisplay,
    this.laborAgencies = const [],
    this.totalSupDay = 0,
    this.totalSkilledDay = 0,
    this.totalUnskilledDay = 0,
    this.totalSupNight = 0,
    this.totalSkilledNight = 0,
    this.totalUnskilledNight = 0,
    this.previousProgress = const [],
    this.plannedWorks = const [],
    this.decisionsApprovals = '',
    this.progressPhotos = const [],
    this.bottleNecks = '',
    this.changeAuthorizations = '',
    this.materialDelivered = '',
    this.ehsIncidentReports = '',
    this.createdByName,
    this.createdAt,
    this.updatedAt,
  });

  int get totalDayManpower =>
      totalSupDay + totalSkilledDay + totalUnskilledDay;

  int get totalNightManpower =>
      totalSupNight + totalSkilledNight + totalUnskilledNight;

  factory ReExecutionDetailModel.fromJson(Map<String, dynamic> json) {
    int _i(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;

    List<Map<String, dynamic>> _list(dynamic v) {
      if (v == null) return [];
      if (v is List) {
        return v
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    }

    return ReExecutionDetailModel(
      id:                   _i(json['id']),
      projectId:            _i(json['project_id']),
      reportDate:           json['report_date']?.toString(),
      reportDateDisplay:    json['report_date_display']?.toString(),
      laborAgencies:        _list(json['labor_agencies']),
      totalSupDay:          _i(json['total_sup_day']),
      totalSkilledDay:      _i(json['total_skilled_day']),
      totalUnskilledDay:    _i(json['total_unskilled_day']),
      totalSupNight:        _i(json['total_sup_night']),
      totalSkilledNight:    _i(json['total_skilled_night']),
      totalUnskilledNight:  _i(json['total_unskilled_night']),
      previousProgress:     _list(json['previous_progress']),
      plannedWorks:         _list(json['planned_works']),
      decisionsApprovals:   json['decisions_approvals']?.toString() ?? '',
      progressPhotos:       _list(json['progress_photos']),
      bottleNecks:          json['bottle_necks']?.toString() ?? '',
      changeAuthorizations: json['change_authorizations']?.toString() ?? '',
      materialDelivered:    json['material_delivered']?.toString() ?? '',
      ehsIncidentReports:   json['ehs_incident_reports']?.toString() ?? '',
      createdByName:        json['created_by_name']?.toString(),
      createdAt:            json['created_at']?.toString(),
      updatedAt:            json['updated_at']?.toString(),
    );
  }
}