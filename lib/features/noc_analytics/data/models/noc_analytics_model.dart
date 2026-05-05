// lib/features/noc_analytics/data/models/noc_analytics_model.dart

class NocOverallStatsModel {
  final int totalProjects;
  final int totalNocs;
  final int completedNocs;
  final int assignedNocs;
  final int pendingNocs;
  final double completionPercentage;

  const NocOverallStatsModel({
    required this.totalProjects,
    required this.totalNocs,
    required this.completedNocs,
    required this.assignedNocs,
    required this.pendingNocs,
    required this.completionPercentage,
  });

  factory NocOverallStatsModel.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] as Map<String, dynamic>? ?? json;
    return NocOverallStatsModel(
      totalProjects:        (stats['total_projects'] as num?)?.toInt() ?? 0,
      totalNocs:            (stats['total_nocs'] as num?)?.toInt() ?? 0,
      completedNocs:        (stats['completed_nocs'] as num?)?.toInt() ?? 0,
      assignedNocs:         (stats['assigned_nocs'] as num?)?.toInt() ?? 0,
      pendingNocs:          (stats['pending_nocs'] as num?)?.toInt() ?? 0,
      completionPercentage: (stats['completion_percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class NocProjectSummaryModel {
  final int id;
  final String societyName;
  final String? projectType;
  final String? status;
  final int totalNocs;
  final int completedNocs;
  final int assignedNocs;
  final int pendingNocs;
  final double completionPercentage;

  const NocProjectSummaryModel({
    required this.id,
    required this.societyName,
    this.projectType,
    this.status,
    required this.totalNocs,
    required this.completedNocs,
    required this.assignedNocs,
    required this.pendingNocs,
    required this.completionPercentage,
  });

  factory NocProjectSummaryModel.fromJson(Map<String, dynamic> json) {
    return NocProjectSummaryModel(
      id:                   (json['id'] as num?)?.toInt() ?? 0,
      societyName:          json['society_name']?.toString() ?? '',
      projectType:          json['project_type']?.toString(),
      status:               json['status']?.toString(),
      totalNocs:            (json['total_nocs'] as num?)?.toInt() ?? 0,
      completedNocs:        (json['completed_nocs'] as num?)?.toInt() ?? 0,
      assignedNocs:         (json['assigned_nocs'] as num?)?.toInt() ?? 0,
      pendingNocs:          (json['pending_nocs'] as num?)?.toInt() ?? 0,
      completionPercentage: (json['completion_percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// ── Detail screen models ─────────────────────────────────────────────────────

class NocAnalyticsDetailModel {
  final NocAnalyticsProjectModel project;
  final NocAnalyticsSummaryModel analytics;
  final NocBreakdownModel breakdown;

  const NocAnalyticsDetailModel({
    required this.project,
    required this.analytics,
    required this.breakdown,
  });

  factory NocAnalyticsDetailModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return NocAnalyticsDetailModel(
      project: NocAnalyticsProjectModel.fromJson(
          Map<String, dynamic>.from(data['project'] as Map? ?? {})),
      analytics: NocAnalyticsSummaryModel.fromJson(
          Map<String, dynamic>.from(data['analytics'] as Map? ?? {})),
      breakdown: NocBreakdownModel.fromJson(
          Map<String, dynamic>.from(data['breakdown'] as Map? ?? {})),
    );
  }
}

class NocAnalyticsProjectModel {
  final int id;
  final String societyName;
  final String? address;
  final String? societyEmail;
  final String? projectType;
  final String? status;

  const NocAnalyticsProjectModel({
    required this.id,
    required this.societyName,
    this.address,
    this.societyEmail,
    this.projectType,
    this.status,
  });

  factory NocAnalyticsProjectModel.fromJson(Map<String, dynamic> json) {
    return NocAnalyticsProjectModel(
      id:           (json['id'] as num?)?.toInt() ?? 0,
      societyName:  json['society_name']?.toString() ?? '',
      address:      json['address']?.toString(),
      societyEmail: json['society_email']?.toString(),
      projectType:  json['project_type']?.toString(),
      status:       json['status']?.toString(),
    );
  }
}

class NocAnalyticsSummaryModel {
  final int totalNocs;
  final int completedNocs;
  final int assignedNocs;
  final int pendingNocs;
  final double completionPercentage;

  const NocAnalyticsSummaryModel({
    required this.totalNocs,
    required this.completedNocs,
    required this.assignedNocs,
    required this.pendingNocs,
    required this.completionPercentage,
  });

  factory NocAnalyticsSummaryModel.fromJson(Map<String, dynamic> json) {
    return NocAnalyticsSummaryModel(
      totalNocs:            (json['total_nocs'] as num?)?.toInt() ?? 0,
      completedNocs:        (json['completed_nocs'] as num?)?.toInt() ?? 0,
      assignedNocs:         (json['assigned_nocs'] as num?)?.toInt() ?? 0,
      pendingNocs:          (json['pending_nocs'] as num?)?.toInt() ?? 0,
      completionPercentage: (json['completion_percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class NocBreakdownModel {
  final int completed;
  final int assigned;
  final int pending;
  final List<NocBreakdownDetailModel> details;

  const NocBreakdownModel({
    required this.completed,
    required this.assigned,
    required this.pending,
    required this.details,
  });

  factory NocBreakdownModel.fromJson(Map<String, dynamic> json) {
    return NocBreakdownModel(
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      assigned:  (json['assigned'] as num?)?.toInt() ?? 0,
      pending:   (json['pending'] as num?)?.toInt() ?? 0,
      details: (json['details'] as List? ?? [])
          .whereType<Map>()
          .map((e) => NocBreakdownDetailModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class NocBreakdownDetailModel {
  final int processId;
  final String processName;
  final int orderNo;
  final String? heading;
  final String status;
  final int statusCode;
  final String? assignedUser;
  final String? assignDate;
  final String? uploadedDate;

  const NocBreakdownDetailModel({
    required this.processId,
    required this.processName,
    required this.orderNo,
    this.heading,
    required this.status,
    required this.statusCode,
    this.assignedUser,
    this.assignDate,
    this.uploadedDate,
  });

  factory NocBreakdownDetailModel.fromJson(Map<String, dynamic> json) {
    return NocBreakdownDetailModel(
      processId:    (json['process_id'] as num?)?.toInt() ?? 0,
      processName:  json['process_name']?.toString() ?? '',
      orderNo:      (json['order_no'] as num?)?.toInt() ?? 0,
      heading:      json['heading']?.toString(),
      status:       json['status']?.toString() ?? 'Pending',
      statusCode:   (json['status_code'] as num?)?.toInt() ?? 0,
      assignedUser: json['assigned_user']?.toString(),
      assignDate:   json['assign_date']?.toString(),
      uploadedDate: json['uploaded_date']?.toString(),
    );
  }
}

// ── Grouped-by-heading models ────────────────────────────────────────────────

class NocGroupedSectionModel {
  final String heading;
  final int count;
  final List<NocGroupedProcessModel> processes;

  const NocGroupedSectionModel({
    required this.heading,
    required this.count,
    required this.processes,
  });

  factory NocGroupedSectionModel.fromJson(Map<String, dynamic> json) {
    return NocGroupedSectionModel(
      heading: json['heading']?.toString() ?? '',
      count:   (json['count'] as num?)?.toInt() ?? 0,
      processes: (json['processes'] as List? ?? [])
          .whereType<Map>()
          .map((e) => NocGroupedProcessModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class NocGroupedProcessModel {
  final int processId;
  final int orderNo;
  final String processName;
  final String status;
  final int statusCode;
  final String? assignedUser;
  final String? assignDate;
  final String? completionDate;

  const NocGroupedProcessModel({
    required this.processId,
    required this.orderNo,
    required this.processName,
    required this.status,
    required this.statusCode,
    this.assignedUser,
    this.assignDate,
    this.completionDate,
  });

  factory NocGroupedProcessModel.fromJson(Map<String, dynamic> json) {
    return NocGroupedProcessModel(
      processId:      (json['process_id'] as num?)?.toInt() ?? 0,
      orderNo:        (json['order_no'] as num?)?.toInt() ?? 0,
      processName:    json['process_name']?.toString() ?? '',
      status:         json['status']?.toString() ?? 'Pending',
      statusCode:     (json['status_code'] as num?)?.toInt() ?? 0,
      assignedUser:   json['assigned_user']?.toString(),
      assignDate:     json['assign_date']?.toString(),
      completionDate: json['completion_date']?.toString(),
    );
  }
}