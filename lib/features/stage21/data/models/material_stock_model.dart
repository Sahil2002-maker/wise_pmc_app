class MaterialStockItem {
  final String? date;
  final String material;
  final String? unit;
  final String? invoiceNo;
  final double? totalReceived;
  final double? usedQty;
  final String? recordHolder;
  final String? remarks;

  const MaterialStockItem({
    this.date,
    required this.material,
    this.unit,
    this.invoiceNo,
    this.totalReceived,
    this.usedQty,
    this.recordHolder,
    this.remarks,
  });

  factory MaterialStockItem.fromJson(Map<String, dynamic> json) {
    return MaterialStockItem(
      date:          json['date']?.toString(),
      material:      json['material']?.toString() ?? '',
      unit:          json['unit']?.toString(),
      invoiceNo:     json['invoice_no']?.toString(),
      totalReceived: _parseDouble(json['total_received']),
      usedQty:       _parseDouble(json['used_qty']),
      recordHolder:  json['record_holder']?.toString(),
      remarks:       json['remarks']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'date':           date,
        'material':       material,
        'unit':           unit ?? '',
        'invoice_no':     invoiceNo ?? '',
        'total_received': totalReceived,
        'used_qty':       usedQty,
        'record_holder':  recordHolder ?? '',
        'remarks':        remarks ?? '',
      };

  static double? _parseDouble(dynamic v) {
    if (v == null || v.toString().isEmpty) return null;
    return double.tryParse(v.toString());
  }

  MaterialStockItem copyWith({
    String? date,
    String? material,
    String? unit,
    String? invoiceNo,
    double? totalReceived,
    double? usedQty,
    String? recordHolder,
    String? remarks,
  }) {
    return MaterialStockItem(
      date:          date          ?? this.date,
      material:      material      ?? this.material,
      unit:          unit          ?? this.unit,
      invoiceNo:     invoiceNo     ?? this.invoiceNo,
      totalReceived: totalReceived ?? this.totalReceived,
      usedQty:       usedQty       ?? this.usedQty,
      recordHolder:  recordHolder  ?? this.recordHolder,
      remarks:       remarks       ?? this.remarks,
    );
  }
}

class MaterialStockModel {
  final int id;
  final int projectId;
  final String stockNo;
  final String registerMonth;
  final List<MaterialStockItem> items;
  final String? creatorName;
  final String? createdAt;

  const MaterialStockModel({
    required this.id,
    required this.projectId,
    required this.stockNo,
    required this.registerMonth,
    required this.items,
    this.creatorName,
    this.createdAt,
  });

  factory MaterialStockModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    List<MaterialStockItem> items = [];
    if (rawItems is List) {
      items = rawItems
          .whereType<Map<String, dynamic>>()
          .map(MaterialStockItem.fromJson)
          .toList();
    }

    return MaterialStockModel(
      id:             int.tryParse(json['id'].toString()) ?? 0,
      projectId:      int.tryParse(json['project_id'].toString()) ?? 0,
      stockNo:        json['stock_no']?.toString() ?? '',
      registerMonth:  json['register_month']?.toString() ?? '',
      items:          items,
      creatorName:    json['creator'] is Map
                          ? json['creator']['name']?.toString()
                          : null,
      createdAt:      json['created_at']?.toString(),
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