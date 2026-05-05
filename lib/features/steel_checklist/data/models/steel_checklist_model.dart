// lib/features/steel_checklist/data/models/steel_checklist_model.dart

class SteelChecklistModel {
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
  final List<Map<String, dynamic>> testResults;
  final int? createdBy;
  final Map<String, dynamic>? creator;

  const SteelChecklistModel({
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
    this.createdBy,
    this.creator,
  });

  factory SteelChecklistModel.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> parseTestResults(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    }

    // Normalize date strings — backend may return full datetime
    String normalizeDate(dynamic val) {
      if (val == null) return '';
      final s = val.toString();
      if (s.contains('T')) return s.split('T').first;
      if (s.contains(' ')) return s.split(' ').first;
      return s;
    }

    return SteelChecklistModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      projectId: int.tryParse(json['project_id']?.toString() ?? '0') ?? 0,
      checklistNo: json['checklist_no']?.toString() ?? '',
      checklistDate: normalizeDate(json['checklist_date']),
      material: json['material']?.toString() ?? '',
      quantity: json['quantity']?.toString() ?? '',
      suppliedBy: json['supplied_by']?.toString() ?? '',
      challanNo: json['challan_no']?.toString(),
      challanDate: json['challan_date'] != null
          ? normalizeDate(json['challan_date'])
          : null,
      tradeMark: json['trade_mark']?.toString(),
      testTakenBy: json['test_taken_by']?.toString(),
      testResults: parseTestResults(json['test_results']),
      createdBy: int.tryParse(json['created_by']?.toString() ?? ''),
      creator: json['creator'] is Map
          ? Map<String, dynamic>.from(json['creator'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'project_id': projectId,
        'checklist_no': checklistNo,
        'checklist_date': checklistDate,
        'material': material,
        'quantity': quantity,
        'supplied_by': suppliedBy,
        'challan_no': challanNo,
        'challan_date': challanDate,
        'trade_mark': tradeMark,
        'test_taken_by': testTakenBy,
        'test_results': testResults,
        'created_by': createdBy,
        'creator': creator,
      };

  /// Convenience: find a test result by test_name
  String resultFor(String testName) {
    for (final t in testResults) {
      if (t['test_name']?.toString() == testName) {
        return t['result']?.toString() ?? '';
      }
    }
    return '';
  }

  /// Weight table rows for test index 2 ("Weight per meter")
  List<Map<String, dynamic>> get weightTableRows {
    for (final t in testResults) {
      if (t['test_name']?.toString() == 'Weight per meter') {
        final wt = t['weight_table'];
        if (wt is List) {
          return wt
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    }
    return [];
  }

  String get creatorName => creator?['name']?.toString() ?? 'N/A';

  /// Format date dd-MM-yyyy for display
  String get formattedChecklistDate => _fmtDate(checklistDate);
  String get formattedChallanDate =>
      challanDate != null && challanDate!.isNotEmpty
          ? _fmtDate(challanDate!)
          : 'N/A';

  static String _fmtDate(String iso) {
    if (iso.isEmpty) return 'N/A';
    try {
      final parts = iso.split('-');
      if (parts.length == 3) return '${parts[2]}-${parts[1]}-${parts[0]}';
    } catch (_) {}
    return iso;
  }
}