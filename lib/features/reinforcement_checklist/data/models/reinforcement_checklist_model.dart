// lib/features/reinforcement_checklist/data/models/reinforcement_checklist_model.dart

class ReinforcementChecklistModel {
  final int id;
  final int projectId;
  final String checklistNo;
  final String? projectName;
  final String? location;
  final String dateOfChecking;
  final String? partWing;
  final String? dateOfCasting;
  final String? hflReference;
  final String? level;
  final String? shuttering;
  final String? reinforcement;
  final String? electrical;
  final String? plumbing;
  final String? general;
  final String? rccDrawing;
  final String? electricalDrawing;
  final String? plumbingDrawing;
  final String? architectDrawing;
  final List<Map<String, dynamic>> checklistItems;
  final String? additionalObservations;
  final int? createdBy;
  final ReinforcementCreator? creator;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ReinforcementChecklistModel({
    required this.id,
    required this.projectId,
    required this.checklistNo,
    this.projectName,
    this.location,
    required this.dateOfChecking,
    this.partWing,
    this.dateOfCasting,
    this.hflReference,
    this.level,
    this.shuttering,
    this.reinforcement,
    this.electrical,
    this.plumbing,
    this.general,
    this.rccDrawing,
    this.electricalDrawing,
    this.plumbingDrawing,
    this.architectDrawing,
    required this.checklistItems,
    this.additionalObservations,
    this.createdBy,
    this.creator,
    this.createdAt,
    this.updatedAt,
  });

  factory ReinforcementChecklistModel.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> items = [];
    final rawItems = json['checklist_items'];
    if (rawItems is List) {
      items = rawItems
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    return ReinforcementChecklistModel(
      id: _parseInt(json['id']),
      projectId: _parseInt(json['project_id']),
      checklistNo: json['checklist_no']?.toString() ?? '',
      projectName: json['project_name']?.toString(),
      location: json['location']?.toString(),
      dateOfChecking: json['date_of_checking']?.toString() ?? '',
      partWing: json['part_wing']?.toString(),
      dateOfCasting: json['date_of_casting']?.toString(),
      hflReference: json['hfl_reference']?.toString(),
      level: json['level']?.toString(),
      shuttering: json['shuttering']?.toString(),
      reinforcement: json['reinforcement']?.toString(),
      electrical: json['electrical']?.toString(),
      plumbing: json['plumbing']?.toString(),
      general: json['general']?.toString(),
      rccDrawing: json['rcc_drawing']?.toString(),
      electricalDrawing: json['electrical_drawing']?.toString(),
      plumbingDrawing: json['plumbing_drawing']?.toString(),
      architectDrawing: json['architect_drawing']?.toString(),
      checklistItems: items,
      additionalObservations: json['additional_observations']?.toString(),
      createdBy: json['created_by'] != null
          ? _parseInt(json['created_by'])
          : null,
      creator: json['creator'] is Map
          ? ReinforcementCreator.fromJson(
              Map<String, dynamic>.from(json['creator'] as Map))
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  static int _parseInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '0') ?? 0;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'project_id': projectId,
        'checklist_no': checklistNo,
        'project_name': projectName,
        'location': location,
        'date_of_checking': dateOfChecking,
        'part_wing': partWing,
        'date_of_casting': dateOfCasting,
        'hfl_reference': hflReference,
        'level': level,
        'shuttering': shuttering,
        'reinforcement': reinforcement,
        'electrical': electrical,
        'plumbing': plumbing,
        'general': general,
        'rcc_drawing': rccDrawing,
        'electrical_drawing': electricalDrawing,
        'plumbing_drawing': plumbingDrawing,
        'architect_drawing': architectDrawing,
        'checklist_items': checklistItems,
        'additional_observations': additionalObservations,
        'created_by': createdBy,
      };
}

class ReinforcementCreator {
  final int id;
  final String name;
  final String? email;

  const ReinforcementCreator({
    required this.id,
    required this.name,
    this.email,
  });

  factory ReinforcementCreator.fromJson(Map<String, dynamic> json) {
    return ReinforcementCreator(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString(),
    );
  }
}