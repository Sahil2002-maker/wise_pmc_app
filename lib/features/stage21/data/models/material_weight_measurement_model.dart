// lib/features/stage21/data/models/material_weight_measurement_model.dart
//
// UPDATED: Full Steel + Cement + Other dual/triple-type support, matching
// the web backend exactly.
// Each entry now has an `entryType` field ('steel' | 'cement' | 'other').
// Steel entries:  gross/tare weights (kg)               + 3 photo slots.
// Cement entries: ordered/received bag counts            + 2 photo slots.
// Other entries:  gross/tare weights (kg | brass | nos)  + 3 photo slots
//                 — physically identical to Steel on the wire, plus a
//                 `unit` field. This mirrors how the Laravel backend
//                 stores "Other" entries under the same photo/weight keys
//                 as Steel so show/edit/print/download logic stays unified.
// Multi-photo arrays are used throughout (matching the web backend).

import 'dart:io';

// ─── List row (index) ──────────────────────────────────────────────────────

class MwmListModel {
  final int id;
  final String mwmNo;
  final String measurementDate;
  final int entryCount;
  final String totalNetWeight;
  final String? totalReceivedBags;
  final String? totalOther;
  final String? remarks;
  final String? creatorName;

  MwmListModel({
    required this.id,
    required this.mwmNo,
    required this.measurementDate,
    required this.entryCount,
    required this.totalNetWeight,
    this.totalReceivedBags,
    this.totalOther,
    this.remarks,
    this.creatorName,
  });

  factory MwmListModel.fromJson(Map<String, dynamic> json) {
    final creator = json['creator'];
    return MwmListModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id'].toString()) ?? 0,
      mwmNo: json['mwm_no']?.toString() ?? '',
      measurementDate: json['measurement_date']?.toString() ?? '',
      entryCount: json['entry_count'] is int
          ? json['entry_count'] as int
          : int.tryParse(json['entry_count'].toString()) ?? 0,
      totalNetWeight: json['total_net_weight']?.toString() ?? '0.000',
      totalReceivedBags: json['total_received_bags']?.toString(),
      totalOther: json['total_other']?.toString(),
      remarks: json['remarks']?.toString(),
      creatorName: creator is Map ? creator['name']?.toString() : null,
    );
  }
}

// ─── Geo point ─────────────────────────────────────────────────────────────

class MwmGeoPoint {
  final double lat;
  final double lng;
  final double? accuracy;
  final String? capturedAt;

  MwmGeoPoint({
    required this.lat,
    required this.lng,
    this.accuracy,
    this.capturedAt,
  });

  factory MwmGeoPoint.fromJson(Map<String, dynamic> json) => MwmGeoPoint(
        lat: double.tryParse(json['lat'].toString()) ?? 0,
        lng: double.tryParse(json['lng'].toString()) ?? 0,
        accuracy: json['accuracy'] != null
            ? double.tryParse(json['accuracy'].toString())
            : null,
        capturedAt: json['captured_at']?.toString() ??
            json['timestamp']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        if (accuracy != null) 'accuracy': accuracy,
        if (capturedAt != null) 'captured_at': capturedAt,
      };

  static MwmGeoPoint? tryParse(dynamic json) {
    if (json == null) return null;
    if (json is Map<String, dynamic> && json.containsKey('lat')) {
      return MwmGeoPoint.fromJson(json);
    }
    return null;
  }
}

// ─── Single photo item ─────────────────────────────────────────────────────

class MwmPhotoItem {
  final String path;
  final String? url;
  final MwmGeoPoint? geo;

  MwmPhotoItem({required this.path, this.url, this.geo});

  bool get isImage {
    if (path.isEmpty) return false;
    final ext = path.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
  }

  bool get isPdf => path.split('.').last.toLowerCase() == 'pdf';

  factory MwmPhotoItem.fromJson(Map<String, dynamic> json) => MwmPhotoItem(
        path: json['path']?.toString() ?? '',
        url: json['url']?.toString(),
        geo: MwmGeoPoint.tryParse(json['geo']),
      );

  /// Parse any shape the API might return for a photo slot.
  static List<MwmPhotoItem> parseSlot(dynamic raw) {
    if (raw == null) return [];
    if (raw is String) {
      final s = raw.trim();
      if (s.isEmpty || s == 'null') return [];
      return [MwmPhotoItem(path: s)];
    }
    if (raw is Map<String, dynamic>) {
      final path = raw['path']?.toString() ?? '';
      if (path.isEmpty) return [];
      return [MwmPhotoItem.fromJson(raw)];
    }
    if (raw is List) {
      final items = <MwmPhotoItem>[];
      for (final item in raw) {
        if (item is String && item.trim().isNotEmpty && item != 'null') {
          items.add(MwmPhotoItem(path: item.trim()));
        } else if (item is Map<String, dynamic>) {
          final path = item['path']?.toString() ?? '';
          if (path.isNotEmpty) items.add(MwmPhotoItem.fromJson(item));
        }
      }
      return items;
    }
    return [];
  }
}

// ─── Entry type enum ───────────────────────────────────────────────────────

enum MwmEntryType { steel, cement, other }

/// Units available for the "Other" material category.
const List<String> kMwmOtherUnits = ['kg', 'brass', 'nos'];

extension MwmEntryTypeX on MwmEntryType {
  String get value => name; // 'steel' | 'cement' | 'other'

  static MwmEntryType from(String? s) {
    if (s == 'cement') return MwmEntryType.cement;
    if (s == 'other') return MwmEntryType.other;
    return MwmEntryType.steel;
  }
}

String normalizeMwmUnit(String? unit) =>
    kMwmOtherUnits.contains(unit) ? unit! : 'kg';

// ─── Detail entry (view) ───────────────────────────────────────────────────

class MwmEntryModel {
  final MwmEntryType entryType;

  // Shared
  final String vehicleNumber;
  final String challanNumber;
  final int materialTypeId;
  final String materialTypeName;

  // Steel / Other (unit applies to Other only — steel is always 'kg')
  final String unit;
  final double grossWeight;
  final String grossWeightFormatted;
  final List<MwmPhotoItem> grossWeightSlipPhotos;
  final List<MwmPhotoItem> vehicleWithMaterialImagePhotos;
  final double tareWeight;
  final String tareWeightFormatted;
  final List<MwmPhotoItem> tareWeightSlipPhotos;
  final double netWeight;
  final String netWeightFormatted;

  // Cement-only
  final int totalOrderedBags;
  final int totalReceivedBags;
  final int remainingBags;
  final List<MwmPhotoItem> orderedBagReceiptImagePhotos;
  final List<MwmPhotoItem> receivedBagImagePhotos;

  MwmEntryModel({
    required this.entryType,
    required this.vehicleNumber,
    required this.challanNumber,
    required this.materialTypeId,
    required this.materialTypeName,
    this.unit = 'kg',
    this.grossWeight = 0,
    this.grossWeightFormatted = '0.000',
    this.grossWeightSlipPhotos = const [],
    this.vehicleWithMaterialImagePhotos = const [],
    this.tareWeight = 0,
    this.tareWeightFormatted = '0.000',
    this.tareWeightSlipPhotos = const [],
    this.netWeight = 0,
    this.netWeightFormatted = '0.000',
    this.totalOrderedBags = 0,
    this.totalReceivedBags = 0,
    this.remainingBags = 0,
    this.orderedBagReceiptImagePhotos = const [],
    this.receivedBagImagePhotos = const [],
  });

  bool get isCement => entryType == MwmEntryType.cement;
  bool get isSteel => entryType == MwmEntryType.steel;
  bool get isOther => entryType == MwmEntryType.other;

  factory MwmEntryModel.fromJson(Map<String, dynamic> json) {
    final type = MwmEntryTypeX.from(json['entry_type']?.toString());

    List<MwmPhotoItem> photos(String photosKey) =>
        MwmPhotoItem.parseSlot(json[photosKey]);

    if (type == MwmEntryType.cement) {
      return MwmEntryModel(
        entryType: type,
        vehicleNumber: json['vehicle_number']?.toString() ?? '',
        challanNumber: json['challan_number']?.toString() ?? '',
        materialTypeId: _parseInt(json['material_type_id']),
        materialTypeName: json['material_type_name']?.toString() ?? '—',
        totalOrderedBags: _parseInt(json['total_ordered_bags']),
        totalReceivedBags: _parseInt(json['total_received_bags']),
        remainingBags: _parseInt(json['remaining_bags'] ?? json['remaining_bags_fmt']),
        orderedBagReceiptImagePhotos: photos('ordered_bag_receipt_image_photos'),
        receivedBagImagePhotos: photos('received_bag_image_photos'),
      );
    }

    // Steel OR Other — same physical keys, differ only by `unit`.
    final gross = _parseDouble(json['gross_weight']);
    final tare  = _parseDouble(json['tare_weight']);
    final net   = _parseDouble(json['net_material_weight']);
    return MwmEntryModel(
      entryType: type,
      unit: type == MwmEntryType.other ? normalizeMwmUnit(json['unit']?.toString()) : 'kg',
      vehicleNumber: json['vehicle_number']?.toString() ?? '',
      challanNumber: json['challan_number']?.toString() ?? '',
      materialTypeId: _parseInt(json['material_type_id']),
      materialTypeName: json['material_type_name']?.toString() ?? '—',
      grossWeight: gross,
      grossWeightFormatted:
          json['gross_weight_fmt']?.toString() ?? gross.toStringAsFixed(3),
      grossWeightSlipPhotos: photos('gross_weight_slip_photos'),
      vehicleWithMaterialImagePhotos: photos('vehicle_with_material_image_photos'),
      tareWeight: tare,
      tareWeightFormatted:
          json['tare_weight_fmt']?.toString() ?? tare.toStringAsFixed(3),
      tareWeightSlipPhotos: photos('tare_weight_slip_photos'),
      netWeight: net,
      netWeightFormatted:
          json['net_weight_fmt']?.toString() ?? net.toStringAsFixed(3),
    );
  }
}

// ─── Detail (full record) ──────────────────────────────────────────────────

class MwmDetailModel {
  final int id;
  final String mwmNo;
  final String measurementDateFormatted;
  final String? remarks;
  final String? creatorName;
  final String totalNet;
  final List<MwmEntryModel> entries;

  MwmDetailModel({
    required this.id,
    required this.mwmNo,
    required this.measurementDateFormatted,
    this.remarks,
    this.creatorName,
    required this.totalNet,
    required this.entries,
  });

  factory MwmDetailModel.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'] as List? ?? [];
    return MwmDetailModel(
      id: _parseInt(json['id']),
      mwmNo: json['mwm_no']?.toString() ?? '',
      measurementDateFormatted:
          json['measurement_date_formatted']?.toString() ?? '',
      remarks: json['remarks']?.toString(),
      creatorName: json['creator_name']?.toString(),
      totalNet: json['total_net']?.toString() ?? '0.000',
      entries: rawEntries
          .whereType<Map<String, dynamic>>()
          .map(MwmEntryModel.fromJson)
          .toList(),
    );
  }
}

// ─── Edit-prefill entry ────────────────────────────────────────────────────

class MwmEditEntry {
  final MwmEntryType entryType;
  final String vehicleNumber;
  final String challanNumber;
  final int materialTypeId;

  // Steel / Other
  final String unit;
  final double grossWeight;
  final List<MwmPhotoItem> grossWeightSlipPhotos;
  final List<MwmPhotoItem> vehicleWithMaterialImagePhotos;
  final double tareWeight;
  final List<MwmPhotoItem> tareWeightSlipPhotos;

  // Cement
  final int totalOrderedBags;
  final int totalReceivedBags;
  final List<MwmPhotoItem> orderedBagReceiptImagePhotos;
  final List<MwmPhotoItem> receivedBagImagePhotos;

  MwmEditEntry({
    required this.entryType,
    required this.vehicleNumber,
    required this.challanNumber,
    required this.materialTypeId,
    this.unit = 'kg',
    this.grossWeight = 0,
    this.grossWeightSlipPhotos = const [],
    this.vehicleWithMaterialImagePhotos = const [],
    this.tareWeight = 0,
    this.tareWeightSlipPhotos = const [],
    this.totalOrderedBags = 0,
    this.totalReceivedBags = 0,
    this.orderedBagReceiptImagePhotos = const [],
    this.receivedBagImagePhotos = const [],
  });

  factory MwmEditEntry.fromJson(Map<String, dynamic> json) {
    final type = MwmEntryTypeX.from(json['entry_type']?.toString());
    List<MwmPhotoItem> photos(String key) => MwmPhotoItem.parseSlot(json[key]);

    if (type == MwmEntryType.cement) {
      return MwmEditEntry(
        entryType: type,
        vehicleNumber: json['vehicle_number']?.toString() ?? '',
        challanNumber: json['challan_number']?.toString() ?? '',
        materialTypeId: _parseInt(json['material_type_id']),
        totalOrderedBags: _parseInt(json['total_ordered_bags']),
        totalReceivedBags: _parseInt(json['total_received_bags']),
        orderedBagReceiptImagePhotos: photos('ordered_bag_receipt_image_photos'),
        receivedBagImagePhotos: photos('received_bag_image_photos'),
      );
    }

    return MwmEditEntry(
      entryType: type,
      unit: type == MwmEntryType.other ? normalizeMwmUnit(json['unit']?.toString()) : 'kg',
      vehicleNumber: json['vehicle_number']?.toString() ?? '',
      challanNumber: json['challan_number']?.toString() ?? '',
      materialTypeId: _parseInt(json['material_type_id']),
      grossWeight: _parseDouble(json['gross_weight']),
      grossWeightSlipPhotos: photos('gross_weight_slip_photos'),
      vehicleWithMaterialImagePhotos: photos('vehicle_with_material_image_photos'),
      tareWeight: _parseDouble(json['tare_weight']),
      tareWeightSlipPhotos: photos('tare_weight_slip_photos'),
    );
  }
}

class MwmEditModel {
  final int id;
  final String mwmNo;
  final String measurementDateFormatted;
  final String? remarks;
  final List<MwmEditEntry> entries;

  MwmEditModel({
    required this.id,
    required this.mwmNo,
    required this.measurementDateFormatted,
    this.remarks,
    required this.entries,
  });

  factory MwmEditModel.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'] as List? ?? [];
    return MwmEditModel(
      id: _parseInt(json['id']),
      mwmNo: json['mwm_no']?.toString() ?? '',
      measurementDateFormatted:
          json['measurement_date_formatted']?.toString() ?? '',
      remarks: json['remarks']?.toString(),
      entries: rawEntries
          .whereType<Map<String, dynamic>>()
          .map(MwmEditEntry.fromJson)
          .toList(),
    );
  }
}

// ─── Material type ─────────────────────────────────────────────────────────

class MwmMaterialTypeModel {
  final int id;
  final String name;

  MwmMaterialTypeModel({required this.id, required this.name});

  factory MwmMaterialTypeModel.fromJson(Map<String, dynamic> json) =>
      MwmMaterialTypeModel(
        id: _parseInt(json['id']),
        name: json['name']?.toString() ?? '',
      );

  @override
  bool operator ==(Object other) =>
      other is MwmMaterialTypeModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ─── File slot (single-pick, for the mobile form) ─────────────────────────

class MwmFileSlot {
  final File? newFile;
  final bool removed;
  final MwmGeoPoint? geo;
  final List<MwmPhotoItem> existingPhotos;

  const MwmFileSlot({
    this.newFile,
    this.removed = false,
    this.geo,
    this.existingPhotos = const [],
  });

  MwmPhotoItem? get firstExisting =>
      (!removed && existingPhotos.isNotEmpty) ? existingPhotos.first : null;

  bool get hasExisting => !removed && existingPhotos.isNotEmpty && newFile == null;
  bool get hasNew => newFile != null;
  bool get isEmpty => !hasExisting && !hasNew;

  String? get displayUrl {
    if (hasNew) return newFile!.path;
    return firstExisting?.url;
  }

  String? get existingUrl => firstExisting?.url;
  bool get existingIsImage => firstExisting?.isImage ?? false;
  bool get existingIsPdf => firstExisting?.isPdf ?? false;

  MwmFileSlot copyWith({
    File? newFile,
    bool clearNewFile = false,
    bool? removed,
    MwmGeoPoint? geo,
    bool clearGeo = false,
    List<MwmPhotoItem>? existingPhotos,
  }) =>
      MwmFileSlot(
        newFile: clearNewFile ? null : (newFile ?? this.newFile),
        removed: removed ?? this.removed,
        geo: clearGeo ? null : (geo ?? this.geo),
        existingPhotos: existingPhotos ?? this.existingPhotos,
      );
}

// ─── Form entry (create/edit working copy) ────────────────────────────────

class MwmEntryForm {
  final MwmEntryType entryType;
  String vehicleNumber;
  String challanNumber;
  MwmMaterialTypeModel? materialType;

  // Steel / Other (unit only meaningful for Other)
  String unit;
  double grossWeight;
  double tareWeight;
  MwmFileSlot grossWeightSlip;
  MwmFileSlot vehicleWithMaterialImage;
  MwmFileSlot tareWeightSlip;

  // Cement
  int totalOrderedBags;
  int totalReceivedBags;
  MwmFileSlot orderedBagReceiptImage;
  MwmFileSlot receivedBagImage;

  final int? originalIndex;

  MwmEntryForm({
    this.entryType = MwmEntryType.steel,
    this.vehicleNumber = '',
    this.challanNumber = '',
    this.materialType,
    this.unit = 'kg',
    this.grossWeight = 0.0,
    this.tareWeight = 0.0,
    MwmFileSlot? grossWeightSlip,
    MwmFileSlot? vehicleWithMaterialImage,
    MwmFileSlot? tareWeightSlip,
    this.totalOrderedBags = 0,
    this.totalReceivedBags = 0,
    MwmFileSlot? orderedBagReceiptImage,
    MwmFileSlot? receivedBagImage,
    this.originalIndex,
  })  : grossWeightSlip = grossWeightSlip ?? const MwmFileSlot(),
        vehicleWithMaterialImage =
            vehicleWithMaterialImage ?? const MwmFileSlot(),
        tareWeightSlip = tareWeightSlip ?? const MwmFileSlot(),
        orderedBagReceiptImage =
            orderedBagReceiptImage ?? const MwmFileSlot(),
        receivedBagImage = receivedBagImage ?? const MwmFileSlot();

  factory MwmEntryForm.fromEdit(
    MwmEditEntry e,
    int originalIndex,
    MwmMaterialTypeModel? matchedType,
  ) {
    if (e.entryType == MwmEntryType.cement) {
      return MwmEntryForm(
        entryType: MwmEntryType.cement,
        vehicleNumber: e.vehicleNumber,
        challanNumber: e.challanNumber,
        materialType: matchedType,
        totalOrderedBags: e.totalOrderedBags,
        totalReceivedBags: e.totalReceivedBags,
        orderedBagReceiptImage:
            MwmFileSlot(existingPhotos: e.orderedBagReceiptImagePhotos),
        receivedBagImage:
            MwmFileSlot(existingPhotos: e.receivedBagImagePhotos),
        originalIndex: originalIndex,
      );
    }
    return MwmEntryForm(
      entryType: e.entryType, // steel or other
      unit: e.unit,
      vehicleNumber: e.vehicleNumber,
      challanNumber: e.challanNumber,
      materialType: matchedType,
      grossWeight: e.grossWeight,
      tareWeight: e.tareWeight,
      grossWeightSlip: MwmFileSlot(existingPhotos: e.grossWeightSlipPhotos),
      vehicleWithMaterialImage:
          MwmFileSlot(existingPhotos: e.vehicleWithMaterialImagePhotos),
      tareWeightSlip: MwmFileSlot(existingPhotos: e.tareWeightSlipPhotos),
      originalIndex: originalIndex,
    );
  }

  bool get isCement => entryType == MwmEntryType.cement;
  bool get isSteel => entryType == MwmEntryType.steel;
  bool get isOther => entryType == MwmEntryType.other;

  double get netWeight {
    final n = grossWeight - tareWeight;
    return n < 0 ? 0 : n;
  }

  int get remainingBags {
    final r = totalOrderedBags - totalReceivedBags;
    return r < 0 ? 0 : r;
  }

  MwmEntryForm copyWith({
    MwmEntryType? entryType,
    String? vehicleNumber,
    String? challanNumber,
    MwmMaterialTypeModel? materialType,
    bool clearMaterialType = false,
    String? unit,
    double? grossWeight,
    double? tareWeight,
    MwmFileSlot? grossWeightSlip,
    MwmFileSlot? vehicleWithMaterialImage,
    MwmFileSlot? tareWeightSlip,
    int? totalOrderedBags,
    int? totalReceivedBags,
    MwmFileSlot? orderedBagReceiptImage,
    MwmFileSlot? receivedBagImage,
  }) =>
      MwmEntryForm(
        entryType: entryType ?? this.entryType,
        vehicleNumber: vehicleNumber ?? this.vehicleNumber,
        challanNumber: challanNumber ?? this.challanNumber,
        materialType:
            clearMaterialType ? null : (materialType ?? this.materialType),
        unit: unit ?? this.unit,
        grossWeight: grossWeight ?? this.grossWeight,
        tareWeight: tareWeight ?? this.tareWeight,
        grossWeightSlip: grossWeightSlip ?? this.grossWeightSlip,
        vehicleWithMaterialImage:
            vehicleWithMaterialImage ?? this.vehicleWithMaterialImage,
        tareWeightSlip: tareWeightSlip ?? this.tareWeightSlip,
        totalOrderedBags: totalOrderedBags ?? this.totalOrderedBags,
        totalReceivedBags: totalReceivedBags ?? this.totalReceivedBags,
        orderedBagReceiptImage:
            orderedBagReceiptImage ?? this.orderedBagReceiptImage,
        receivedBagImage: receivedBagImage ?? this.receivedBagImage,
        originalIndex: originalIndex,
      );
}

// ─── Helpers ───────────────────────────────────────────────────────────────

int _parseInt(dynamic v) =>
    v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;

double _parseDouble(dynamic v) =>
    v is double ? v : double.tryParse(v?.toString() ?? '') ?? 0.0;