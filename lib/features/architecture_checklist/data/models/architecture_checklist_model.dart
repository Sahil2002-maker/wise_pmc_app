// lib/features/architecture_checklist/data/models/architecture_checklist_model.dart

class ArchitectureChecklistCreator {
  final int id;
  final String name;

  const ArchitectureChecklistCreator({required this.id, required this.name});

  factory ArchitectureChecklistCreator.fromJson(Map<String, dynamic> json) {
    return ArchitectureChecklistCreator(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }
}

class ArchitectureChecklistModel {
  final int id;
  final int projectId;
  final String checklistNo;
  final String checklistDate;
  final String? jobNo;
  final String? projectName;

  // Section 1
  final bool beamNotInLine;
  final bool columnNotPlumb;
  final String? honeycombColumn;
  final String? beamNo;

  // Section 2 - Inspection items
  final List<Map<String, dynamic>> inspectionItems;

  // Section 3 - Graphical representation
  final String? barChartAvailable;
  final bool workInProgress;
  final bool timeLimitAvailable;
  final String? balanceWorkMonths;
  final String? lastDateTimePeriod;
  final String? sanctionDate;

  // Section 4 - Open space data
  final List<Map<String, dynamic>> openSpaceData;

  // Section 5 & 6
  final String? constructionStatement;
  final String? additionalInstructions;

  // Signatures
  final String? architectSignature;
  final String? clientSignature;

  final ArchitectureChecklistCreator? creator;
  final String? createdAt;
  final String? updatedAt;

  const ArchitectureChecklistModel({
    required this.id,
    required this.projectId,
    required this.checklistNo,
    required this.checklistDate,
    this.jobNo,
    this.projectName,
    required this.beamNotInLine,
    required this.columnNotPlumb,
    this.honeycombColumn,
    this.beamNo,
    required this.inspectionItems,
    this.barChartAvailable,
    required this.workInProgress,
    required this.timeLimitAvailable,
    this.balanceWorkMonths,
    this.lastDateTimePeriod,
    this.sanctionDate,
    required this.openSpaceData,
    this.constructionStatement,
    this.additionalInstructions,
    this.architectSignature,
    this.clientSignature,
    this.creator,
    this.createdAt,
    this.updatedAt,
  });

  factory ArchitectureChecklistModel.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> parseList(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    }

    bool parseBool(dynamic val) {
      if (val == null) return false;
      if (val is bool) return val;
      if (val is int) return val == 1;
      final s = val.toString().toLowerCase();
      return s == 'true' || s == '1' || s == 'yes';
    }

    return ArchitectureChecklistModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      projectId:
          int.tryParse(json['project_id']?.toString() ?? '0') ?? 0,
      checklistNo: json['checklist_no']?.toString() ?? '',
      checklistDate: json['checklist_date']?.toString() ?? '',
      jobNo: json['job_no']?.toString(),
      projectName: json['project_name']?.toString(),
      beamNotInLine: parseBool(json['beam_not_in_line']),
      columnNotPlumb: parseBool(json['column_not_plumb']),
      honeycombColumn: json['honeycomb_column']?.toString(),
      beamNo: json['beam_no']?.toString(),
      inspectionItems: parseList(json['inspection_items']),
      barChartAvailable: json['bar_chart_available']?.toString(),
      workInProgress: parseBool(json['work_in_progress']),
      timeLimitAvailable: parseBool(json['time_limit_available']),
      balanceWorkMonths: json['balance_work_months']?.toString(),
      lastDateTimePeriod: json['last_date_time_period']?.toString(),
      sanctionDate: json['sanction_date']?.toString(),
      openSpaceData: parseList(json['open_space_data']),
      constructionStatement: json['construction_statement']?.toString(),
      additionalInstructions: json['additional_instructions']?.toString(),
      architectSignature: json['architect_signature']?.toString(),
      clientSignature: json['client_signature']?.toString(),
      creator: json['creator'] is Map
          ? ArchitectureChecklistCreator.fromJson(
              Map<String, dynamic>.from(json['creator'] as Map))
          : null,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'project_id': projectId,
        'checklist_no': checklistNo,
        'checklist_date': checklistDate,
        'job_no': jobNo,
        'project_name': projectName,
        'beam_not_in_line': beamNotInLine,
        'column_not_plumb': columnNotPlumb,
        'honeycomb_column': honeycombColumn,
        'beam_no': beamNo,
        'inspection_items': inspectionItems,
        'bar_chart_available': barChartAvailable,
        'work_in_progress': workInProgress,
        'time_limit_available': timeLimitAvailable,
        'balance_work_months': balanceWorkMonths,
        'last_date_time_period': lastDateTimePeriod,
        'sanction_date': sanctionDate,
        'open_space_data': openSpaceData,
        'construction_statement': constructionStatement,
        'additional_instructions': additionalInstructions,
        'architect_signature': architectSignature,
        'client_signature': clientSignature,
      };
}