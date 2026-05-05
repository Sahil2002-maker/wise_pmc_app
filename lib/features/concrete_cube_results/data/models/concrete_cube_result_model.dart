// lib/features/concrete_cube_results/data/models/concrete_cube_result_model.dart

class ConcreteCubeCreator {
  final int id;
  final String name;

  ConcreteCubeCreator({required this.id, required this.name});

  factory ConcreteCubeCreator.fromJson(Map<String, dynamic> json) {
    return ConcreteCubeCreator(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }
}

class WeightDimension {
  final String weight;
  final String length;
  final String breadth;

  WeightDimension({
    required this.weight,
    required this.length,
    required this.breadth,
  });

  factory WeightDimension.fromJson(Map<String, dynamic> json) {
    return WeightDimension(
      weight: json['weight']?.toString() ?? '',
      length: json['length']?.toString() ?? '',
      breadth: json['breadth']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'weight': weight,
        'length': length,
        'breadth': breadth,
      };
}

class ConcreteCubeTestEntry {
  final String dateOfTesting;
  final String gradeOfConcrete;
  final String location;
  final String totalQty;
  final String ageOfCube;
  final List<WeightDimension> weightDimensions;
  final List<String> maxLoad7Days;
  final List<String> compressiveStrength7Days;
  final List<String> maxLoad28Days;
  final List<String> compressiveStrength28Days;
  final String remarks;

  ConcreteCubeTestEntry({
    required this.dateOfTesting,
    required this.gradeOfConcrete,
    required this.location,
    required this.totalQty,
    required this.ageOfCube,
    required this.weightDimensions,
    required this.maxLoad7Days,
    required this.compressiveStrength7Days,
    required this.maxLoad28Days,
    required this.compressiveStrength28Days,
    required this.remarks,
  });

  factory ConcreteCubeTestEntry.fromJson(Map<String, dynamic> json) {
    List<WeightDimension> wds = [];
    if (json['weight_dimensions'] is List) {
      wds = (json['weight_dimensions'] as List)
          .whereType<Map>()
          .map((e) => WeightDimension.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    List<String> toStringList(dynamic val) {
      if (val is List) return val.map((e) => e?.toString() ?? '').toList();
      return [];
    }

    return ConcreteCubeTestEntry(
      dateOfTesting: json['date_of_testing']?.toString() ?? '',
      gradeOfConcrete: json['grade_of_concrete']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      totalQty: json['total_qty']?.toString() ?? '',
      ageOfCube: json['age_of_cube']?.toString() ?? '',
      weightDimensions: wds,
      maxLoad7Days: toStringList(json['max_load_7_days']),
      compressiveStrength7Days:
          toStringList(json['compressive_strength_7_days']),
      maxLoad28Days: toStringList(json['max_load_28_days']),
      compressiveStrength28Days:
          toStringList(json['compressive_strength_28_days']),
      remarks: json['remarks']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'date_of_testing': dateOfTesting,
        'grade_of_concrete': gradeOfConcrete,
        'location': location,
        'total_qty': totalQty,
        'age_of_cube': ageOfCube,
        'weight_dimensions': weightDimensions.map((e) => e.toJson()).toList(),
        'max_load_7_days': maxLoad7Days,
        'compressive_strength_7_days': compressiveStrength7Days,
        'max_load_28_days': maxLoad28Days,
        'compressive_strength_28_days': compressiveStrength28Days,
        'remarks': remarks,
      };

  double? get avg7Days {
    final vals = compressiveStrength7Days
        .map((v) => double.tryParse(v))
        .whereType<double>()
        .where((v) => v > 0)
        .toList();
    if (vals.isEmpty) return null;
    return vals.reduce((a, b) => a + b) / vals.length;
  }

  double? get avg28Days {
    final vals = compressiveStrength28Days
        .map((v) => double.tryParse(v))
        .whereType<double>()
        .where((v) => v > 0)
        .toList();
    if (vals.isEmpty) return null;
    return vals.reduce((a, b) => a + b) / vals.length;
  }
}

class ConcreteCubeResultModel {
  final int id;
  final int projectId;
  final int resultNo;
  final String uniqueNumber;
  final List<ConcreteCubeTestEntry> testData;
  final double? avg7Days;
  final double? avg28Days;
  final String? checkedBy;
  final String? qaBy;
  final String? preparedBy;
  final int? createdBy;
  final ConcreteCubeCreator? creator;
  final String? createdAt;
  final String? updatedAt;

  ConcreteCubeResultModel({
    required this.id,
    required this.projectId,
    required this.resultNo,
    required this.uniqueNumber,
    required this.testData,
    this.avg7Days,
    this.avg28Days,
    this.checkedBy,
    this.qaBy,
    this.preparedBy,
    this.createdBy,
    this.creator,
    this.createdAt,
    this.updatedAt,
  });

  factory ConcreteCubeResultModel.fromJson(Map<String, dynamic> json) {
    List<ConcreteCubeTestEntry> entries = [];
    if (json['test_data'] is List) {
      entries = (json['test_data'] as List)
          .whereType<Map>()
          .map((e) =>
              ConcreteCubeTestEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    ConcreteCubeCreator? creator;
    if (json['creator'] is Map) {
      creator = ConcreteCubeCreator.fromJson(
          Map<String, dynamic>.from(json['creator']));
    }

    return ConcreteCubeResultModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      projectId: int.tryParse(json['project_id']?.toString() ?? '0') ?? 0,
      resultNo: int.tryParse(json['result_no']?.toString() ?? '0') ?? 0,
      uniqueNumber: json['unique_number']?.toString() ?? '',
      testData: entries,
      avg7Days: double.tryParse(json['avg_7_days']?.toString() ?? ''),
      avg28Days: double.tryParse(json['avg_28_days']?.toString() ?? ''),
      checkedBy: json['checked_by']?.toString(),
      qaBy: json['qa_by']?.toString(),
      preparedBy: json['prepared_by']?.toString(),
      createdBy: int.tryParse(json['created_by']?.toString() ?? ''),
      creator: creator,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  // Convenience getters from first test entry
  String get firstDateOfTesting =>
      testData.isNotEmpty ? testData[0].dateOfTesting : '';
  String get firstGrade =>
      testData.isNotEmpty ? testData[0].gradeOfConcrete : '';
  String get firstLocation =>
      testData.isNotEmpty ? testData[0].location : '';
  String get firstAgeOfCube =>
      testData.isNotEmpty ? testData[0].ageOfCube : '';
}