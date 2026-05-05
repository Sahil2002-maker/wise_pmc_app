// lib/features/excavation_checklist/data/models/excavation_checklist_model.dart

class ExcavationChecklistItem {
  final String? check; // 'yes' or 'no'
  final String? remark;

  ExcavationChecklistItem({this.check, this.remark});

  factory ExcavationChecklistItem.fromJson(Map<String, dynamic> json) {
    return ExcavationChecklistItem(
      check: json['check']?.toString(),
      remark: json['remark']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'check': check ?? '',
        'remark': remark ?? '',
      };

  ExcavationChecklistItem copyWith({String? check, String? remark}) {
    return ExcavationChecklistItem(
      check: check ?? this.check,
      remark: remark ?? this.remark,
    );
  }
}

class ExcavationChecklistCreator {
  final int? id;
  final String? name;
  final String? email;

  ExcavationChecklistCreator({this.id, this.name, this.email});

  factory ExcavationChecklistCreator.fromJson(Map<String, dynamic> json) {
    return ExcavationChecklistCreator(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? ''),
      name: json['name']?.toString(),
      email: json['email']?.toString(),
    );
  }
}

class ExcavationChecklistModel {
  final int id;
  final int projectId;
  final String checklistNo;
  final String checklistDate;
  final String? location;
  final String? partWing;
  final String? activityDate;
  final String? jobNo;
  final String? drawingNo;
  final String? contractorName;
  final String? excavationVolume;
  final List<ExcavationChecklistItem> checklistItems;
  final String? remarks;
  final int? createdBy;
  final ExcavationChecklistCreator? creator;
  final String? createdAt;
  final String? updatedAt;

  ExcavationChecklistModel({
    required this.id,
    required this.projectId,
    required this.checklistNo,
    required this.checklistDate,
    this.location,
    this.partWing,
    this.activityDate,
    this.jobNo,
    this.drawingNo,
    this.contractorName,
    this.excavationVolume,
    required this.checklistItems,
    this.remarks,
    this.createdBy,
    this.creator,
    this.createdAt,
    this.updatedAt,
  });

  factory ExcavationChecklistModel.fromJson(Map<String, dynamic> json) {
    List<ExcavationChecklistItem> items = [];
    final rawItems = json['checklist_items'];
    if (rawItems is List) {
      items = rawItems
          .whereType<Map>()
          .map((e) =>
              ExcavationChecklistItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    ExcavationChecklistCreator? creator;
    if (json['creator'] is Map) {
      creator = ExcavationChecklistCreator.fromJson(
          Map<String, dynamic>.from(json['creator'] as Map));
    }

    return ExcavationChecklistModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      projectId: json['project_id'] is int
          ? json['project_id']
          : int.tryParse(json['project_id']?.toString() ?? '0') ?? 0,
      checklistNo: json['checklist_no']?.toString() ?? '',
      checklistDate: json['checklist_date']?.toString() ?? '',
      location: json['location']?.toString(),
      partWing: json['part_wing']?.toString(),
      activityDate: json['activity_date']?.toString(),
      jobNo: json['job_no']?.toString(),
      drawingNo: json['drawing_no']?.toString(),
      contractorName: json['contractor_name']?.toString(),
      excavationVolume: json['excavation_volume']?.toString(),
      checklistItems: items,
      remarks: json['remarks']?.toString(),
      createdBy: json['created_by'] is int
          ? json['created_by']
          : int.tryParse(json['created_by']?.toString() ?? ''),
      creator: creator,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'project_id': projectId,
        'checklist_no': checklistNo,
        'checklist_date': checklistDate,
        'location': location,
        'part_wing': partWing,
        'activity_date': activityDate,
        'job_no': jobNo,
        'drawing_no': drawingNo,
        'contractor_name': contractorName,
        'excavation_volume': excavationVolume,
        'checklist_items': checklistItems.map((e) => e.toJson()).toList(),
        'remarks': remarks,
      };
}