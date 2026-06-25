// lib/features/stage21/data/models/mwm_deleted_entry_model.dart
//
// Model for Audit Trail – Removed Entries.
// Mirrors the MwmDeletedEntry shape returned by
// MobileMaterialWeightMeasurementController@deletedEntries.

class MwmDeletedEntryModel {
  final int id;

  /// The MWM serial number the entry belonged to (e.g. "WR/MWM/131/20260617/003")
  final String mwmNo;

  /// Formatted measurement date ("dd/MM/yyyy")
  final String measurementDate;

  /// 1-based entry position in the original record (backend returns index+1)
  final int originalEntryIndex;

  final String vehicleNumber;
  final String challanNumber;
  final String materialTypeName;

  /// Formatted to 3 decimal places by the backend
  final String grossWeight;
  final String tareWeight;

  /// Net material weight — highlighted red in the web UI
  final String netMaterialWeight;

  final String originalCreatedBy;
  final String originalCreatedAt;
  final String deletedBy;
  final String deletedAt;

  const MwmDeletedEntryModel({
    required this.id,
    required this.mwmNo,
    required this.measurementDate,
    required this.originalEntryIndex,
    required this.vehicleNumber,
    required this.challanNumber,
    required this.materialTypeName,
    required this.grossWeight,
    required this.tareWeight,
    required this.netMaterialWeight,
    required this.originalCreatedBy,
    required this.originalCreatedAt,
    required this.deletedBy,
    required this.deletedAt,
  });

  /// Safely converts any value to a non-empty string, falling back to '—'.
  static String _str(dynamic val, [String fallback = '—']) {
    if (val == null) return fallback;
    final s = val.toString().trim();
    return s.isEmpty || s == 'null' ? fallback : s;
  }

  factory MwmDeletedEntryModel.fromJson(Map<String, dynamic> json) {
    return MwmDeletedEntryModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id'].toString()) ?? 0,
      mwmNo: _str(json['mwm_no']),
      measurementDate: _str(json['measurement_date']),
      originalEntryIndex: json['original_entry_index'] is int
          ? json['original_entry_index'] as int
          : int.tryParse(json['original_entry_index'].toString()) ?? 1,
      vehicleNumber: _str(json['vehicle_number']),
      challanNumber: _str(json['challan_number']),
      materialTypeName: _str(json['material_type_name']),
      grossWeight: _str(json['gross_weight']),
      tareWeight: _str(json['tare_weight']),
      netMaterialWeight: _str(json['net_material_weight']),
      originalCreatedBy: _str(json['original_created_by']),
      originalCreatedAt: _str(json['original_created_at']),
      deletedBy: _str(json['deleted_by']),
      deletedAt: _str(json['deleted_at']),
    );
  }
}