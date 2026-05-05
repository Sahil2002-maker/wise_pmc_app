// lib/features/cement_checklist/data/models/cement_checklist_model.dart

class CementChecklistTestResult {
  final String testName;
  final String result;

  const CementChecklistTestResult({
    required this.testName,
    required this.result,
  });

  factory CementChecklistTestResult.fromJson(Map<String, dynamic> json) {
    return CementChecklistTestResult(
      testName: json['test_name']?.toString() ?? '',
      result: json['result']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'test_name': testName,
        'result': result,
      };
}

class CementChecklistModel {
  final int id;
  final int projectId;
  final String checklistNo;
  final String checklistDate;
  final String material;
  final String quantity;
  final String suppliedBy;
  final String? challanNo;
  final String? challanDate;
  final String? tradeMark;
  final String? testTakenBy;
  final List<CementChecklistTestResult> testResults;
  final String? creatorName;
  final String? createdAt;

  const CementChecklistModel({
    required this.id,
    required this.projectId,
    required this.checklistNo,
    required this.checklistDate,
    required this.material,
    required this.quantity,
    required this.suppliedBy,
    this.challanNo,
    this.challanDate,
    this.tradeMark,
    this.testTakenBy,
    required this.testResults,
    this.creatorName,
    this.createdAt,
  });

  factory CementChecklistModel.fromJson(Map<String, dynamic> json) {
    final rawTests = json['test_results'];
    final List<CementChecklistTestResult> tests = [];
    if (rawTests is List) {
      for (final t in rawTests) {
        if (t is Map<String, dynamic>) {
          tests.add(CementChecklistTestResult.fromJson(t));
        }
      }
    }

    final creator = json['creator'];
    String? creatorName;
    if (creator is Map) {
      creatorName = creator['name']?.toString();
    }

    return CementChecklistModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      projectId: int.tryParse(json['project_id']?.toString() ?? '') ?? 0,
      checklistNo: json['checklist_no']?.toString() ?? '',
      checklistDate: json['checklist_date']?.toString() ?? '',
      material: json['material']?.toString() ?? '',
      quantity: json['quantity']?.toString() ?? '',
      suppliedBy: json['supplied_by']?.toString() ?? '',
      challanNo: json['challan_no']?.toString(),
      challanDate: json['challan_date']?.toString(),
      tradeMark: json['trade_mark']?.toString(),
      testTakenBy: json['test_taken_by']?.toString(),
      testResults: tests,
      creatorName: creatorName,
      createdAt: json['created_at']?.toString(),
    );
  }
}