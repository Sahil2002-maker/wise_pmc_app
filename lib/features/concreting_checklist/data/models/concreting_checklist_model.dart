// lib/features/concreting_checklist/data/models/concreting_checklist_model.dart

class ConcretingChecklistCreator {
  final int id;
  final String name;

  const ConcretingChecklistCreator({required this.id, required this.name});

  factory ConcretingChecklistCreator.fromJson(Map<String, dynamic> json) {
    return ConcretingChecklistCreator(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }
}

class ConcretingTestResult {
  final String srNo;
  final String particulars;
  final bool checkYes;
  final bool checkNo;
  final String remark;

  const ConcretingTestResult({
    required this.srNo,
    required this.particulars,
    required this.checkYes,
    required this.checkNo,
    required this.remark,
  });

  /// Convenience getter: 'yes' | 'no' | null
  String? get check {
    if (checkYes) return 'yes';
    if (checkNo) return 'no';
    return null;
  }

  factory ConcretingTestResult.fromJson(Map<String, dynamic> json) {
    return ConcretingTestResult(
      srNo: json['sr_no']?.toString() ?? '',
      particulars: json['particulars']?.toString() ?? '',
      checkYes: json['check_yes'] == true ||
          json['check_yes'] == 1 ||
          json['check_yes'] == '1',
      checkNo: json['check_no'] == true ||
          json['check_no'] == 1 ||
          json['check_no'] == '1',
      remark: json['remark']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'sr_no': srNo,
        'particulars': particulars,
        'check_yes': checkYes,
        'check_no': checkNo,
        'remark': remark,
      };
}

class ConcretingChecklistModel {
  final int id;
  final int projectId;
  final String checklistNo;
  final String checklistDate;
  final String? location;
  final String? partWing;
  final String? dateOfCasting;
  final String? hflReference;
  final String? shuttering;
  final String? reinforcement;
  final String? electrical;
  final String? plumbing;
  final String? general;
  final String? rcc;
  final String? rccDrawing;
  final String? plumbingDrawing;
  final String? architectDrawing;
  final List<ConcretingTestResult> testResults;
  final String? additionalObservations;
  final ConcretingChecklistCreator? creator;

  const ConcretingChecklistModel({
    required this.id,
    required this.projectId,
    required this.checklistNo,
    required this.checklistDate,
    this.location,
    this.partWing,
    this.dateOfCasting,
    this.hflReference,
    this.shuttering,
    this.reinforcement,
    this.electrical,
    this.plumbing,
    this.general,
    this.rcc,
    this.rccDrawing,
    this.plumbingDrawing,
    this.architectDrawing,
    required this.testResults,
    this.additionalObservations,
    this.creator,
  });

  factory ConcretingChecklistModel.fromJson(Map<String, dynamic> json) {
    List<ConcretingTestResult> results = [];
    final raw = json['test_results'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          results.add(ConcretingTestResult.fromJson(item));
        }
      }
    }

    ConcretingChecklistCreator? creator;
    if (json['creator'] is Map<String, dynamic>) {
      creator = ConcretingChecklistCreator.fromJson(
          json['creator'] as Map<String, dynamic>);
    }

    return ConcretingChecklistModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      projectId:
          int.tryParse(json['project_id']?.toString() ?? '0') ?? 0,
      checklistNo: json['checklist_no']?.toString() ?? '',
      checklistDate: json['checklist_date']?.toString() ?? '',
      location: json['location']?.toString(),
      partWing: json['part_wing']?.toString(),
      dateOfCasting: json['date_of_casting']?.toString(),
      hflReference: json['hfl_reference']?.toString(),
      shuttering: json['shuttering']?.toString(),
      reinforcement: json['reinforcement']?.toString(),
      electrical: json['electrical']?.toString(),
      plumbing: json['plumbing']?.toString(),
      general: json['general']?.toString(),
      rcc: json['rcc']?.toString(),
      rccDrawing: json['rcc_drawing']?.toString(),
      plumbingDrawing: json['plumbing_drawing']?.toString(),
      architectDrawing: json['architect_drawing']?.toString(),
      testResults: results,
      additionalObservations: json['additional_observations']?.toString(),
      creator: creator,
    );
  }
}