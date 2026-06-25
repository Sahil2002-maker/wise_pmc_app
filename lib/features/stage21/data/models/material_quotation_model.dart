class MaterialQuotationItem {
  final String? date;
  final String quotationName;
  final String? unit;
  final String? quotationNumber;
  final double? totalRate;
  final String? recordHolder;
  final String? remarks;

  const MaterialQuotationItem({
    this.date,
    required this.quotationName,
    this.unit,
    this.quotationNumber,
    this.totalRate,
    this.recordHolder,
    this.remarks,
  });

  factory MaterialQuotationItem.fromJson(Map<String, dynamic> json) {
    return MaterialQuotationItem(
      date:             json['date']?.toString(),
      quotationName:    json['quotation_name']?.toString() ?? '',
      unit:             json['unit']?.toString(),
      quotationNumber:  json['quotation_number']?.toString(),
      totalRate:        _parseDouble(json['total_rate']),
      recordHolder:     json['record_holder']?.toString(),
      remarks:          json['remarks']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'date':             date,
        'quotation_name':   quotationName,
        'unit':             unit ?? '',
        'quotation_number': quotationNumber ?? '',
        'total_rate':       totalRate,
        'record_holder':    recordHolder ?? '',
        'remarks':          remarks ?? '',
      };

  static double? _parseDouble(dynamic v) {
    if (v == null || v.toString().isEmpty) return null;
    return double.tryParse(v.toString());
  }

  MaterialQuotationItem copyWith({
    String? date,
    String? quotationName,
    String? unit,
    String? quotationNumber,
    double? totalRate,
    String? recordHolder,
    String? remarks,
  }) {
    return MaterialQuotationItem(
      date:            date            ?? this.date,
      quotationName:   quotationName   ?? this.quotationName,
      unit:            unit            ?? this.unit,
      quotationNumber: quotationNumber ?? this.quotationNumber,
      totalRate:       totalRate       ?? this.totalRate,
      recordHolder:    recordHolder    ?? this.recordHolder,
      remarks:         remarks         ?? this.remarks,
    );
  }
}

class MaterialQuotationModel {
  final int id;
  final int projectId;
  final String quotationNo;
  final String registerMonth;
  final List<MaterialQuotationItem> items;
  final String? creatorName;
  final String? createdAt;

  const MaterialQuotationModel({
    required this.id,
    required this.projectId,
    required this.quotationNo,
    required this.registerMonth,
    required this.items,
    this.creatorName,
    this.createdAt,
  });

  factory MaterialQuotationModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    List<MaterialQuotationItem> items = [];
    if (rawItems is List) {
      items = rawItems
          .whereType<Map<String, dynamic>>()
          .map(MaterialQuotationItem.fromJson)
          .toList();
    }

    return MaterialQuotationModel(
      id:            int.tryParse(json['id'].toString()) ?? 0,
      projectId:     int.tryParse(json['project_id'].toString()) ?? 0,
      quotationNo:   json['quotation_no']?.toString() ?? '',
      registerMonth: json['register_month']?.toString() ?? '',
      items:         items,
      creatorName:   json['creator'] is Map
                         ? json['creator']['name']?.toString()
                         : null,
      createdAt:     json['created_at']?.toString(),
    );
  }

  String get formattedMonth {
    if (registerMonth.isEmpty) return 'N/A';
    try {
      final parts = registerMonth.split('-');
      if (parts.length < 2) return registerMonth;
      final months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      final idx = int.tryParse(parts[1]) ?? 0;
      return '${months[idx - 1]} ${parts[0]}';
    } catch (_) {
      return registerMonth;
    }
  }
}