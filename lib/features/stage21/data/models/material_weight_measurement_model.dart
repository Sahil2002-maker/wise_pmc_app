// lib/features/stage21/data/models/material_weight_measurement_model.dart
//
// UPDATED: Full multi-photo support per slot.
// The backend now returns *_photos arrays (list of {path, url, geo}).
// Single-photo convenience fields (*_url, *_geo) are kept for compatibility.

import 'dart:io';

// ─── List row (index) ──────────────────────────────────────────────────────

class MwmListModel {
  final int id;
  final String mwmNo;
  final String measurementDate;
  final int entryCount;
  final String totalNetWeight;
  final String? remarks;
  final String? creatorName;

  MwmListModel({
    required this.id,
    required this.mwmNo,
    required this.measurementDate,
    required this.entryCount,
    required this.totalNetWeight,
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

// ─── Single photo item (one photo in a multi-photo slot) ──────────────────
//
// Mirrors the backend shape: { path: string, url: string|null, geo: {...}|null }

class MwmPhotoItem {
  /// Raw S3 key, e.g. "MWM/MWM_131_E0GrossSlip_abc123_1234567890.jpg"
  /// Used to determine file type (image vs PDF) and as a stable identifier.
  final String path;

  /// Signed S3 URL. Valid for ~120 minutes. Use this to display/open the file.
  final String? url;

  /// GPS location captured at photo time (may be null).
  final MwmGeoPoint? geo;

  MwmPhotoItem({
    required this.path,
    this.url,
    this.geo,
  });

  /// Whether this is an image file (jpg/jpeg/png/gif/webp).
  bool get isImage {
    if (path.isEmpty) return false;
    final ext = path.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
  }

  /// Whether this is a PDF file.
  bool get isPdf => path.split('.').last.toLowerCase() == 'pdf';

  factory MwmPhotoItem.fromJson(Map<String, dynamic> json) {
    final rawPath = json['path']?.toString() ?? '';
    return MwmPhotoItem(
      path: rawPath,
      url: json['url']?.toString(),
      geo: MwmGeoPoint.tryParse(json['geo']),
    );
  }

  /// Parse a raw slot value from the API into a list of MwmPhotoItem.
  ///
  /// Handles every shape the backend may return:
  ///   - null                              → []
  ///   - ""                               → []
  ///   - "MWM/xyz.jpg"                    → single item (old scalar, no URL)
  ///   - { path, url, geo }               → single item
  ///   - [{ path, url, geo }, ...]        → multiple items  ✓ (new format)
  static List<MwmPhotoItem> parseSlot(dynamic raw) {
    if (raw == null) return [];

    // Plain string (old format — no signed URL included)
    if (raw is String) {
      final s = raw.trim();
      if (s.isEmpty || s == 'null') return [];
      return [MwmPhotoItem(path: s, url: null, geo: null)];
    }

    // Single map { path, url, geo }
    if (raw is Map<String, dynamic>) {
      final path = raw['path']?.toString() ?? '';
      if (path.isEmpty) return [];
      return [MwmPhotoItem.fromJson(raw)];
    }

    // Array
    if (raw is List) {
      final items = <MwmPhotoItem>[];
      for (final item in raw) {
        if (item is String && item.trim().isNotEmpty && item != 'null') {
          items.add(MwmPhotoItem(path: item.trim(), url: null, geo: null));
        } else if (item is Map<String, dynamic>) {
          final path = item['path']?.toString() ?? '';
          if (path.isNotEmpty) {
            items.add(MwmPhotoItem.fromJson(item));
          }
        }
      }
      return items;
    }

    return [];
  }
}

// ─── Detail entry (full, read-only view) ──────────────────────────────────

class MwmEntryModel {
  final String vehicleNumber;
  final String challanNumber;
  final int materialTypeId;
  final String materialTypeName;

  final double grossWeight;
  final String grossWeightFormatted;

  /// Multi-photo list for the gross weight slip slot.
  final List<MwmPhotoItem> grossWeightSlipPhotos;

  /// Multi-photo list for the vehicle-with-material-image slot.
  final List<MwmPhotoItem> vehicleWithMaterialImagePhotos;

  final double tareWeight;
  final String tareWeightFormatted;

  /// Multi-photo list for the tare weight slip slot.
  final List<MwmPhotoItem> tareWeightSlipPhotos;

  final double netWeight;
  final String netWeightFormatted;

  MwmEntryModel({
    required this.vehicleNumber,
    required this.challanNumber,
    required this.materialTypeId,
    required this.materialTypeName,
    required this.grossWeight,
    required this.grossWeightFormatted,
    required this.grossWeightSlipPhotos,
    required this.vehicleWithMaterialImagePhotos,
    required this.tareWeight,
    required this.tareWeightFormatted,
    required this.tareWeightSlipPhotos,
    required this.netWeight,
    required this.netWeightFormatted,
  });

  // ── Convenience getters (first photo of each slot) ──────────────────────

  MwmPhotoItem? get grossWeightSlipFirst =>
      grossWeightSlipPhotos.isNotEmpty ? grossWeightSlipPhotos.first : null;

  MwmPhotoItem? get vehicleWithMaterialImageFirst =>
      vehicleWithMaterialImagePhotos.isNotEmpty
          ? vehicleWithMaterialImagePhotos.first
          : null;

  MwmPhotoItem? get tareWeightSlipFirst =>
      tareWeightSlipPhotos.isNotEmpty ? tareWeightSlipPhotos.first : null;

  factory MwmEntryModel.fromJson(Map<String, dynamic> json) {
    // ── Parse multi-photo slots ─────────────────────────────────────────────
    //
    // Priority (for each slot):
    //  1. *_photos  array  — new format returned by updated mobile controller
    //  2. *_slip / *_image scalar + *_slip_url — old single-photo format
    //
    // This ensures both old and new records display correctly.

    List<MwmPhotoItem> parseWithFallback(
      String photosKey,
      String pathKey,
      String urlKey,
      String geoKey,
    ) {
      // Try the new *_photos array first
      final photosRaw = json[photosKey];
      if (photosRaw is List && photosRaw.isNotEmpty) {
        return MwmPhotoItem.parseSlot(photosRaw);
      }

      // Fall back to the scalar path + url fields
      final path = json[pathKey]?.toString();
      final url  = json[urlKey]?.toString();

      if (path != null && path.isNotEmpty && path != 'null') {
        return [
          MwmPhotoItem(
            path: path,
            url: (url != null && url.isNotEmpty && url != 'null') ? url : null,
            geo: MwmGeoPoint.tryParse(json[geoKey]),
          ),
        ];
      }

      // Nothing found
      return [];
    }

    final grossPhotos = parseWithFallback(
      'gross_weight_slip_photos',
      'gross_weight_slip',
      'gross_weight_slip_url',
      'gross_weight_slip_geo',
    );
    final vehiclePhotos = parseWithFallback(
      'vehicle_with_material_image_photos',
      'vehicle_with_material_image',
      'vehicle_with_material_image_url',
      'vehicle_with_material_image_geo',
    );
    final tarePhotos = parseWithFallback(
      'tare_weight_slip_photos',
      'tare_weight_slip',
      'tare_weight_slip_url',
      'tare_weight_slip_geo',
    );

    final grossWeight =
        double.tryParse(json['gross_weight'].toString()) ?? 0;
    final tareWeight =
        double.tryParse(json['tare_weight'].toString()) ?? 0;
    final netWeight =
        double.tryParse(json['net_material_weight'].toString()) ?? 0;

    return MwmEntryModel(
      vehicleNumber: json['vehicle_number']?.toString() ?? '',
      challanNumber: json['challan_number']?.toString() ?? '',
      materialTypeId: json['material_type_id'] is int
          ? json['material_type_id'] as int
          : int.tryParse(json['material_type_id'].toString()) ?? 0,
      materialTypeName: json['material_type_name']?.toString() ?? '—',
      grossWeight: grossWeight,
      grossWeightFormatted: json['gross_weight_fmt']?.toString() ??
          grossWeight.toStringAsFixed(3),
      grossWeightSlipPhotos: grossPhotos,
      vehicleWithMaterialImagePhotos: vehiclePhotos,
      tareWeight: tareWeight,
      tareWeightFormatted: json['tare_weight_fmt']?.toString() ??
          tareWeight.toStringAsFixed(3),
      tareWeightSlipPhotos: tarePhotos,
      netWeight: netWeight,
      netWeightFormatted: json['net_weight_fmt']?.toString() ??
          netWeight.toStringAsFixed(3),
    );
  }
}

// ─── Detail (full record for View page) ───────────────────────────────────

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
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id'].toString()) ?? 0,
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
  final String vehicleNumber;
  final String challanNumber;
  final int materialTypeId;

  final double grossWeight;

  /// Photos for the gross weight slip slot (edit prefill).
  final List<MwmPhotoItem> grossWeightSlipPhotos;

  /// Photos for the vehicle-with-material-image slot (edit prefill).
  final List<MwmPhotoItem> vehicleWithMaterialImagePhotos;

  final double tareWeight;

  /// Photos for the tare weight slip slot (edit prefill).
  final List<MwmPhotoItem> tareWeightSlipPhotos;

  MwmEditEntry({
    required this.vehicleNumber,
    required this.challanNumber,
    required this.materialTypeId,
    required this.grossWeight,
    required this.grossWeightSlipPhotos,
    required this.vehicleWithMaterialImagePhotos,
    required this.tareWeight,
    required this.tareWeightSlipPhotos,
  });

  factory MwmEditEntry.fromJson(Map<String, dynamic> json) {
    List<MwmPhotoItem> parseWithFallback(
      String photosKey,
      String pathKey,
      String urlKey,
      String geoKey,
    ) {
      final photosRaw = json[photosKey];
      if (photosRaw is List && photosRaw.isNotEmpty) {
        return MwmPhotoItem.parseSlot(photosRaw);
      }
      final path = json[pathKey]?.toString();
      final url  = json[urlKey]?.toString();
      if (path != null && path.isNotEmpty && path != 'null') {
        return [
          MwmPhotoItem(
            path: path,
            url: (url != null && url.isNotEmpty && url != 'null') ? url : null,
            geo: MwmGeoPoint.tryParse(json[geoKey]),
          ),
        ];
      }
      return [];
    }

    return MwmEditEntry(
      vehicleNumber: json['vehicle_number']?.toString() ?? '',
      challanNumber: json['challan_number']?.toString() ?? '',
      materialTypeId: json['material_type_id'] is int
          ? json['material_type_id'] as int
          : int.tryParse(json['material_type_id'].toString()) ?? 0,
      grossWeight: double.tryParse(json['gross_weight'].toString()) ?? 0,
      grossWeightSlipPhotos: parseWithFallback(
        'gross_weight_slip_photos',
        'gross_weight_slip',
        'gross_weight_slip_url',
        'gross_weight_slip_geo',
      ),
      vehicleWithMaterialImagePhotos: parseWithFallback(
        'vehicle_with_material_image_photos',
        'vehicle_with_material_image',
        'vehicle_with_material_image_url',
        'vehicle_with_material_image_geo',
      ),
      tareWeight: double.tryParse(json['tare_weight'].toString()) ?? 0,
      tareWeightSlipPhotos: parseWithFallback(
        'tare_weight_slip_photos',
        'tare_weight_slip',
        'tare_weight_slip_url',
        'tare_weight_slip_geo',
      ),
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
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id'].toString()) ?? 0,
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

// ─── Material type (dropdown option) ───────────────────────────────────────

class MwmMaterialTypeModel {
  final int id;
  final String name;

  MwmMaterialTypeModel({required this.id, required this.name});

  factory MwmMaterialTypeModel.fromJson(Map<String, dynamic> json) =>
      MwmMaterialTypeModel(
        id: json['id'] is int
            ? json['id'] as int
            : int.tryParse(json['id'].toString()) ?? 0,
        name: json['name']?.toString() ?? '',
      );

  @override
  bool operator ==(Object other) =>
      other is MwmMaterialTypeModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ─── File slot state (used inside MwmEntryForm) ───────────────────────────
//
// Now supports multiple existing photos per slot (from the server) and one
// new file picked/captured by the user for upload.

class MwmFileSlot {
  /// New file selected by the user (gallery or camera). Only one per slot
  /// for the mobile create/edit flow (keeps the upload simple).
  final File? newFile;

  /// True when the user removed the existing file(s) and no new file chosen.
  final bool removed;

  /// Geo for the newly captured photo.
  final MwmGeoPoint? geo;

  /// Existing photos from the server (may be multiple).
  final List<MwmPhotoItem> existingPhotos;

  MwmFileSlot({
    this.newFile,
    this.removed = false,
    this.geo,
    this.existingPhotos = const [],
  });

  // ── Convenience getters ──────────────────────────────────────────────────

  /// First existing photo (for display when no new file chosen).
  MwmPhotoItem? get firstExisting =>
      (!removed && existingPhotos.isNotEmpty) ? existingPhotos.first : null;

  /// True when the slot has a usable existing photo (not removed).
  bool get hasExisting => !removed && existingPhotos.isNotEmpty && newFile == null;

  bool get hasNew => newFile != null;
  bool get isEmpty => !hasExisting && !hasNew;

  /// The display URL — new file's local path or first existing signed URL.
  String? get displayUrl {
    if (hasNew) return newFile!.path;
    return firstExisting?.url;
  }

  /// Signed URL of the first existing server photo.
  /// Used by the edit form to preview the current server-side file.
  String? get existingUrl => firstExisting?.url;

  /// True when the existing content is an image.
  bool get existingIsImage => firstExisting?.isImage ?? false;

  /// True when the existing content is a PDF.
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
  String vehicleNumber;
  String challanNumber;
  MwmMaterialTypeModel? materialType;
  double grossWeight;
  double tareWeight;

  final int? originalIndex;

  MwmFileSlot grossWeightSlip;
  MwmFileSlot vehicleWithMaterialImage;
  MwmFileSlot tareWeightSlip;

  MwmEntryForm({
    this.vehicleNumber = '',
    this.challanNumber = '',
    this.materialType,
    this.grossWeight = 0.0,
    this.tareWeight = 0.0,
    this.originalIndex,
    MwmFileSlot? grossWeightSlip,
    MwmFileSlot? vehicleWithMaterialImage,
    MwmFileSlot? tareWeightSlip,
  })  : grossWeightSlip = grossWeightSlip ?? MwmFileSlot(),
        vehicleWithMaterialImage =
            vehicleWithMaterialImage ?? MwmFileSlot(),
        tareWeightSlip = tareWeightSlip ?? MwmFileSlot();

  factory MwmEntryForm.fromEdit(
    MwmEditEntry e,
    int originalIndex,
    MwmMaterialTypeModel? matchedType,
  ) =>
      MwmEntryForm(
        vehicleNumber: e.vehicleNumber,
        challanNumber: e.challanNumber,
        materialType: matchedType,
        grossWeight: e.grossWeight,
        tareWeight: e.tareWeight,
        originalIndex: originalIndex,
        grossWeightSlip: MwmFileSlot(
          existingPhotos: e.grossWeightSlipPhotos,
        ),
        vehicleWithMaterialImage: MwmFileSlot(
          existingPhotos: e.vehicleWithMaterialImagePhotos,
        ),
        tareWeightSlip: MwmFileSlot(
          existingPhotos: e.tareWeightSlipPhotos,
        ),
      );

  double get netWeight {
    final n = grossWeight - tareWeight;
    return n < 0 ? 0 : n;
  }

  MwmEntryForm copyWith({
    String? vehicleNumber,
    String? challanNumber,
    MwmMaterialTypeModel? materialType,
    bool clearMaterialType = false,
    double? grossWeight,
    double? tareWeight,
    MwmFileSlot? grossWeightSlip,
    MwmFileSlot? vehicleWithMaterialImage,
    MwmFileSlot? tareWeightSlip,
  }) =>
      MwmEntryForm(
        vehicleNumber: vehicleNumber ?? this.vehicleNumber,
        challanNumber: challanNumber ?? this.challanNumber,
        materialType:
            clearMaterialType ? null : (materialType ?? this.materialType),
        grossWeight: grossWeight ?? this.grossWeight,
        tareWeight: tareWeight ?? this.tareWeight,
        originalIndex: originalIndex,
        grossWeightSlip: grossWeightSlip ?? this.grossWeightSlip,
        vehicleWithMaterialImage:
            vehicleWithMaterialImage ?? this.vehicleWithMaterialImage,
        tareWeightSlip: tareWeightSlip ?? this.tareWeightSlip,
      );
}