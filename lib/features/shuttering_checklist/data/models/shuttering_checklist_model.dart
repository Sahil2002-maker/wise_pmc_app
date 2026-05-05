// lib/features/shuttering_checklist/data/models/shuttering_checklist_model.dart

class ShutteringChecklistModel {
  final int id;
  final int projectId;
  final String checklistNo;
  final String checklistDate;
  final String? location;
  final String? wing;
  final String? castingDate;
  final String? slabLevel;
  final String? areaOfSlab;
  final String? typeOfShuttering;
  final String? contractor;
  final bool hfl;
  final bool level;
  final bool shuttering;
  final bool reinforcement;
  final bool electrical;
  final bool plumbing;
  final bool architect;
  final String? rcc;
  final String? electricalDetail;
  final String? plumbingDetail;
  final String? architectDetail;
  final List<ShutteringTestResult> testResults;
  final String? additionalObservations;
  final int? createdBy;
  final ShutteringCreator? creator;
  final String? createdAt;

  const ShutteringChecklistModel({
    required this.id,
    required this.projectId,
    required this.checklistNo,
    required this.checklistDate,
    this.location,
    this.wing,
    this.castingDate,
    this.slabLevel,
    this.areaOfSlab,
    this.typeOfShuttering,
    this.contractor,
    required this.hfl,
    required this.level,
    required this.shuttering,
    required this.reinforcement,
    required this.electrical,
    required this.plumbing,
    required this.architect,
    this.rcc,
    this.electricalDetail,
    this.plumbingDetail,
    this.architectDetail,
    required this.testResults,
    this.additionalObservations,
    this.createdBy,
    this.creator,
    this.createdAt,
  });

  factory ShutteringChecklistModel.fromJson(Map<String, dynamic> json) {
    List<ShutteringTestResult> testResults = [];
    final rawResults = json['test_results'];
    if (rawResults is List) {
      testResults = rawResults
          .whereType<Map>()
          .map((e) => ShutteringTestResult.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    ShutteringCreator? creator;
    if (json['creator'] is Map) {
      creator = ShutteringCreator.fromJson(
          Map<String, dynamic>.from(json['creator'] as Map));
    }

    return ShutteringChecklistModel(
      id: _parseInt(json['id']),
      projectId: _parseInt(json['project_id']),
      checklistNo: json['checklist_no']?.toString() ?? '',
      checklistDate: json['checklist_date']?.toString() ?? '',
      location: json['location']?.toString(),
      wing: json['wing']?.toString(),
      castingDate: json['casting_date']?.toString(),
      slabLevel: json['slab_level']?.toString(),
      areaOfSlab: json['area_of_slab']?.toString(),
      typeOfShuttering: json['type_of_shuttering']?.toString(),
      contractor: json['contractor']?.toString(),
      hfl: _parseBool(json['hfl']),
      level: _parseBool(json['level']),
      shuttering: _parseBool(json['shuttering']),
      reinforcement: _parseBool(json['reinforcement']),
      electrical: _parseBool(json['electrical']),
      plumbing: _parseBool(json['plumbing']),
      architect: _parseBool(json['architect']),
      rcc: json['rcc']?.toString(),
      electricalDetail: json['electrical_detail']?.toString(),
      plumbingDetail: json['plumbing_detail']?.toString(),
      architectDetail: json['architect_detail']?.toString(),
      testResults: testResults,
      additionalObservations: json['additional_observations']?.toString(),
      createdBy: json['created_by'] != null ? _parseInt(json['created_by']) : null,
      creator: creator,
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'checklist_no': checklistNo,
      'checklist_date': checklistDate,
      'location': location,
      'wing': wing,
      'casting_date': castingDate,
      'slab_level': slabLevel,
      'area_of_slab': areaOfSlab,
      'type_of_shuttering': typeOfShuttering,
      'contractor': contractor,
      'hfl': hfl,
      'level': level,
      'shuttering': shuttering,
      'reinforcement': reinforcement,
      'electrical': electrical,
      'plumbing': plumbing,
      'architect': architect,
      'rcc': rcc,
      'electrical_detail': electricalDetail,
      'plumbing_detail': plumbingDetail,
      'architect_detail': architectDetail,
      'test_results': testResults.map((e) => e.toJson()).toList(),
      'additional_observations': additionalObservations,
    };
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      return value == '1' || value.toLowerCase() == 'true';
    }
    return false;
  }
}

class ShutteringTestResult {
  final String srNo;
  final String particulars;
  final String? check; // 'yes', 'no', or null
  final String remark;

  const ShutteringTestResult({
    required this.srNo,
    required this.particulars,
    this.check,
    required this.remark,
  });

  factory ShutteringTestResult.fromJson(Map<String, dynamic> json) {
    return ShutteringTestResult(
      srNo: json['sr_no']?.toString() ?? '',
      particulars: json['particulars']?.toString() ?? '',
      check: json['check']?.toString(),
      remark: json['remark']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sr_no': srNo,
      'particulars': particulars,
      'check': check,
      'remark': remark,
    };
  }

  ShutteringTestResult copyWith({
    String? srNo,
    String? particulars,
    String? check,
    String? remark,
  }) {
    return ShutteringTestResult(
      srNo: srNo ?? this.srNo,
      particulars: particulars ?? this.particulars,
      check: check ?? this.check,
      remark: remark ?? this.remark,
    );
  }
}

class ShutteringCreator {
  final int id;
  final String name;

  const ShutteringCreator({required this.id, required this.name});

  factory ShutteringCreator.fromJson(Map<String, dynamic> json) {
    return ShutteringCreator(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }
}

/// Default particulars list matching the blade template exactly
const List<Map<String, String>> kShutteringParticulars = [
  {'sr_no': 'a', 'particulars': 'Dimensions, diagonals of gala as per drawing.'},
  {'sr_no': 'b', 'particulars': 'Beam is in line & level, and sides are in plumb.'},
  {'sr_no': 'c', 'particulars': 'Where ever plywood/ timber is used as filler it should be of full opening size in one piece.'},
  {'sr_no': 'd', 'particulars': 'Shuttering oil is applied on all inner side.'},
  {'sr_no': 'e', 'particulars': 'Stoppers are vertical & as per remark on drawing or as per instruction of RCC consultant. (Generally avoid)'},
  {'sr_no': 'f', 'particulars': 'Gaps in shuttering are filled properly with cement & grease. (More than 1-mm gaps are no allowed )'},
  {'sr_no': 'g', 'particulars': 'The inner side shuttering of beam, for sunken slab are supported by wooden lapha supports.'},
  {'sr_no': 'h', 'particulars': 'No binding wires are used for supporting work.'},
  {'sr_no': 'i', 'particulars': 'All spans checked for proper wailing Patti @ 9" for beam Side, studs/ lapha @1\'-6", shikanja @1\'-6"'},
  {'sr_no': 'j', 'particulars': 'Defective spans & props – rejected'},
  {'sr_no': 'k', 'particulars': 'All spans have shear keys / if no wedge added.'},
  {'sr_no': 'l', 'particulars': 'All spans have additional central M.S. prop.'},
  {'sr_no': 'm', 'particulars': 'All spans have min 1\'-6" over lap.'},
  {'sr_no': 'n', 'particulars': 'All spans have properly fixed with Teer lapha.'},
  {'sr_no': 'o', 'particulars': 'Props are vertical. All props are M.S props and are equally and suitably spaced, lateral supports for vertical side to beams are rigidly connected to cross runner. For beam bottom 1" at 9" from column face & others @ 1\'-6".'},
  {'sr_no': 'p', 'particulars': 'Supporting system vertical gaps not more than 15" for Beam sides.'},
  {'sr_no': 'q', 'particulars': 'Sprinkle the water over slab shuttering & check below, No water Leakage coming through shuttering.'},
  {'sr_no': 'r', 'particulars': 'Adjustment of height by timber wedges from bottom and at top chabhi is fixed.'},
  {'sr_no': 's', 'particulars': 'Runners are of proper size and strength. Side supports to beams are rigid and stable.'},
  {'sr_no': 't', 'particulars': 'Camber in slab/ beam should be provided as per the specification ( 1 in 250)'},
  {'sr_no': 'u', 'particulars': 'Only in beam sides & lift well, shutting is equally supported horizontal support gaps are 12" to 15" in one vertical plane.'},
  {'sr_no': 'v', 'particulars': 'Depth/ thickness of slab should be uniform.'},
];