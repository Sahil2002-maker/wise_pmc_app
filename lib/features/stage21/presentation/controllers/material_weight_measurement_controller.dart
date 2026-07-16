// lib/features/stage21/presentation/controllers/material_weight_measurement_controller.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/models/material_weight_measurement_model.dart';
import '../../data/services/mwm_api_service.dart';

/// File slot keys are shared between Steel and Other (identical wire shape);
/// only the API field names they get posted under differ, which the API
/// service handles based on entry type.
enum MwmFileSlotKey {
  // Steel / Other
  grossWeightSlip,
  vehicleWithMaterialImage,
  tareWeightSlip,
  // Cement
  orderedBagReceiptImage,
  receivedBagImage,
}

class MaterialWeightMeasurementController extends ChangeNotifier {
  final int projectId;
  final String projectName;

  MaterialWeightMeasurementController({
    required this.projectId,
    required this.projectName,
  });

  // ── List ───────────────────────────────────────────────────────────────────

  List<MwmListModel> _allRecords = [];
  List<MwmListModel> _filtered = [];
  List<MwmListModel> get records => _filtered;
  int get total => _allRecords.length;

  bool listLoading = false;
  String? listError;

  // ── Form ───────────────────────────────────────────────────────────────────

  bool formLoading = false;
  bool formSaving = false; // ← always reset at init
  String? formError;

  String? formMwmNo;
  String? formDate;
  String? formRemarks;
  List<MwmEntryForm> formEntries = [];

  List<MwmMaterialTypeModel> materialTypes = [];
  bool typesLoaded = false;

  final List<int> _removedOriginalIndices = [];
  List<int> get removedOriginalIndices =>
      List.unmodifiable(_removedOriginalIndices);

  // ── Search ─────────────────────────────────────────────────────────────────

  String _searchQuery = '';

  void onSearch(String q) {
    _searchQuery = q.toLowerCase().trim();
    _applyFilter();
    notifyListeners();
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filtered = List.from(_allRecords);
    } else {
      _filtered = _allRecords.where((r) {
        return r.mwmNo.toLowerCase().contains(_searchQuery) ||
            r.measurementDate.toLowerCase().contains(_searchQuery) ||
            (r.creatorName ?? '').toLowerCase().contains(_searchQuery) ||
            (r.remarks ?? '').toLowerCase().contains(_searchQuery);
      }).toList();
    }
  }

  // ── Load list ──────────────────────────────────────────────────────────────

  Future<void> loadRecords({bool refresh = false}) async {
    if (listLoading) return;
    listLoading = true;
    listError = null;
    notifyListeners();
    try {
      _allRecords = await MwmApiService.fetchList(projectId);
      _applyFilter();
    } catch (e) {
      listError = e.toString().replaceAll('Exception: ', '');
    } finally {
      listLoading = false;
      notifyListeners();
    }
  }

  // ── Material types ─────────────────────────────────────────────────────────

  Future<void> ensureMaterialTypes() async {
    if (typesLoaded && materialTypes.isNotEmpty) return;
    try {
      materialTypes = await MwmApiService.fetchMaterialTypes();
      typesLoaded = true;
      notifyListeners();
    } catch (_) {}
  }

  // ── Init create ────────────────────────────────────────────────────────────

  Future<void> initCreateForm() async {
    // ✅ FIX: Always reset formSaving before entering the form
    formLoading = true;
    formSaving = false;
    formError = null;
    formMwmNo = null;
    formDate = null;
    formRemarks = null;
    formEntries = [MwmEntryForm()];
    _removedOriginalIndices.clear();
    notifyListeners();

    try {
      await ensureMaterialTypes();
      final meta = await MwmApiService.fetchCreateMeta(projectId);
      formMwmNo = meta['mwm_no'];
      formDate = meta['today'];
    } catch (e) {
      formError = e.toString().replaceAll('Exception: ', '');
    } finally {
      formLoading = false;
      notifyListeners();
    }
  }

  // ── Init edit ──────────────────────────────────────────────────────────────

  Future<void> initEditForm(int id) async {
    // ✅ FIX: Always reset formSaving before entering the form
    formLoading = true;
    formSaving = false;
    formError = null;
    formEntries = [];
    _removedOriginalIndices.clear();
    notifyListeners();

    try {
      await ensureMaterialTypes();
      final data = await MwmApiService.fetchEdit(projectId, id);
      formMwmNo = data.mwmNo;
      formDate = data.measurementDateFormatted;
      formRemarks = data.remarks;
      formEntries = data.entries.asMap().entries.map((e) {
        MwmMaterialTypeModel? matched;
        try {
          matched =
              materialTypes.firstWhere((t) => t.id == e.value.materialTypeId);
        } catch (_) {}
        return MwmEntryForm.fromEdit(e.value, e.key, matched);
      }).toList();
      if (formEntries.isEmpty) formEntries = [MwmEntryForm()];
    } catch (e) {
      formError = e.toString().replaceAll('Exception: ', '');
    } finally {
      formLoading = false;
      notifyListeners();
    }
  }

  // ── Entry management ───────────────────────────────────────────────────────

  void addEntry({MwmEntryType type = MwmEntryType.steel}) {
    formEntries = [
      ...formEntries,
      MwmEntryForm(entryType: type, unit: type == MwmEntryType.other ? 'kg' : 'kg'),
    ];
    notifyListeners();
  }

  void removeEntry(int index) {
    if (formEntries.length <= 1) return;
    final entry = formEntries[index];
    if (entry.originalIndex != null &&
        !_removedOriginalIndices.contains(entry.originalIndex)) {
      _removedOriginalIndices.add(entry.originalIndex!);
    }
    formEntries = List.from(formEntries)..removeAt(index);
    notifyListeners();
  }

  void updateEntry(int index, MwmEntryForm updated) {
    formEntries = List.from(formEntries)..[index] = updated;
    notifyListeners();
  }

  // ── Geo capture ────────────────────────────────────────────────────────────

  Future<MwmGeoPoint?> captureGeo() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return null;
      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      return MwmGeoPoint(
        lat: position.latitude,
        lng: position.longitude,
        accuracy: position.accuracy,
        capturedAt: DateTime.now().toIso8601String(),
      );
    } catch (_) {
      return null;
    }
  }

  // ── Set file ───────────────────────────────────────────────────────────────

  Future<void> setEntryFile(
    int entryIndex,
    MwmFileSlotKey slotKey,
    File file,
  ) async {
    final entry = formEntries[entryIndex];
    final geo = await captureGeo();

    MwmEntryForm updated;
    switch (slotKey) {
      case MwmFileSlotKey.grossWeightSlip:
        updated = entry.copyWith(
          grossWeightSlip: entry.grossWeightSlip.copyWith(
            newFile: file,
            removed: false,
            geo: geo,
            existingPhotos: entry.grossWeightSlip.existingPhotos,
          ),
        );
        break;
      case MwmFileSlotKey.vehicleWithMaterialImage:
        updated = entry.copyWith(
          vehicleWithMaterialImage: entry.vehicleWithMaterialImage.copyWith(
            newFile: file,
            removed: false,
            geo: geo,
            existingPhotos: entry.vehicleWithMaterialImage.existingPhotos,
          ),
        );
        break;
      case MwmFileSlotKey.tareWeightSlip:
        updated = entry.copyWith(
          tareWeightSlip: entry.tareWeightSlip.copyWith(
            newFile: file,
            removed: false,
            geo: geo,
            existingPhotos: entry.tareWeightSlip.existingPhotos,
          ),
        );
        break;
      case MwmFileSlotKey.orderedBagReceiptImage:
        updated = entry.copyWith(
          orderedBagReceiptImage: entry.orderedBagReceiptImage.copyWith(
            newFile: file,
            removed: false,
            geo: geo,
            existingPhotos: entry.orderedBagReceiptImage.existingPhotos,
          ),
        );
        break;
      case MwmFileSlotKey.receivedBagImage:
        updated = entry.copyWith(
          receivedBagImage: entry.receivedBagImage.copyWith(
            newFile: file,
            removed: false,
            geo: geo,
            existingPhotos: entry.receivedBagImage.existingPhotos,
          ),
        );
        break;
    }
    updateEntry(entryIndex, updated);
  }

  // ── Clear file ─────────────────────────────────────────────────────────────

  void clearEntryFile(int entryIndex, MwmFileSlotKey slotKey) {
    final entry = formEntries[entryIndex];

    MwmEntryForm updated;
    switch (slotKey) {
      case MwmFileSlotKey.grossWeightSlip:
        final had = entry.grossWeightSlip.existingPhotos.isNotEmpty;
        updated = entry.copyWith(
          grossWeightSlip: entry.grossWeightSlip.copyWith(
            clearNewFile: true,
            clearGeo: true,
            removed: had,
            existingPhotos: const [],
          ),
        );
        break;
      case MwmFileSlotKey.vehicleWithMaterialImage:
        final had = entry.vehicleWithMaterialImage.existingPhotos.isNotEmpty;
        updated = entry.copyWith(
          vehicleWithMaterialImage: entry.vehicleWithMaterialImage.copyWith(
            clearNewFile: true,
            clearGeo: true,
            removed: had,
            existingPhotos: const [],
          ),
        );
        break;
      case MwmFileSlotKey.tareWeightSlip:
        final had = entry.tareWeightSlip.existingPhotos.isNotEmpty;
        updated = entry.copyWith(
          tareWeightSlip: entry.tareWeightSlip.copyWith(
            clearNewFile: true,
            clearGeo: true,
            removed: had,
            existingPhotos: const [],
          ),
        );
        break;
      case MwmFileSlotKey.orderedBagReceiptImage:
        final had = entry.orderedBagReceiptImage.existingPhotos.isNotEmpty;
        updated = entry.copyWith(
          orderedBagReceiptImage: entry.orderedBagReceiptImage.copyWith(
            clearNewFile: true,
            clearGeo: true,
            removed: had,
            existingPhotos: const [],
          ),
        );
        break;
      case MwmFileSlotKey.receivedBagImage:
        final had = entry.receivedBagImage.existingPhotos.isNotEmpty;
        updated = entry.copyWith(
          receivedBagImage: entry.receivedBagImage.copyWith(
            clearNewFile: true,
            clearGeo: true,
            removed: had,
            existingPhotos: const [],
          ),
        );
        break;
    }
    updateEntry(entryIndex, updated);
  }

  // ── Save create ────────────────────────────────────────────────────────────

  Future<bool> saveCreate() async {
    if (!_validateEntries()) return false;
    formSaving = true;
    formError = null;
    notifyListeners();
    try {
      await MwmApiService.create(
        projectId,
        remarks: formRemarks,
        entries: formEntries,
      );
      await loadRecords(refresh: true);
      return true;
    } catch (e) {
      formError = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      // ✅ FIX: Always reset formSaving in finally block
      formSaving = false;
      notifyListeners();
    }
  }

  // ── Save update ────────────────────────────────────────────────────────────

  Future<bool> saveUpdate(int id) async {
    if (!_validateEntries()) return false;
    formSaving = true;
    formError = null;
    notifyListeners();
    try {
      await MwmApiService.update(
        projectId,
        id,
        remarks: formRemarks,
        entries: formEntries,
        removedOriginalIndices: _removedOriginalIndices,
      );
      await loadRecords(refresh: true);
      return true;
    } catch (e) {
      formError = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      // ✅ FIX: Always reset formSaving in finally block
      formSaving = false;
      notifyListeners();
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<bool> deleteRecord(int id) async {
    try {
      await MwmApiService.delete(projectId, id);
      _allRecords = _allRecords.where((r) => r.id != id).toList();
      _applyFilter();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Computed ───────────────────────────────────────────────────────────────

  double get formTotalNet => formEntries
      .where((e) => e.isSteel)
      .fold(0.0, (s, e) => s + e.netWeight);

  int get formTotalReceivedBags => formEntries
      .where((e) => e.isCement)
      .fold(0, (s, e) => s + e.totalReceivedBags);

  /// Groups "Other" entries' net weight by unit, e.g. {'brass': 2.5, 'nos': 12}.
  Map<String, double> get formTotalOtherByUnit {
    final map = <String, double>{};
    for (final e in formEntries.where((e) => e.isOther)) {
      map[e.unit] = (map[e.unit] ?? 0) + e.netWeight;
    }
    return map;
  }

  // ── Validation ─────────────────────────────────────────────────────────────

  bool _validateEntries() {
    for (final e in formEntries) {
      if (e.vehicleNumber.trim().isEmpty ||
          e.challanNumber.trim().isEmpty ||
          e.materialType == null) {
        formError = 'Please fill in all required fields for each entry.';
        notifyListeners();
        return false;
      }
      if (e.isSteel && (e.grossWeight <= 0 || e.tareWeight <= 0)) {
        formError =
            'Please enter valid Loaded and Empty weights for steel entries.';
        notifyListeners();
        return false;
      }
      if (e.isOther && (e.grossWeight <= 0 || e.tareWeight <= 0)) {
        formError =
            'Please enter valid Loaded and Empty weights for "Other" entries.';
        notifyListeners();
        return false;
      }
      if (e.isCement &&
          (e.totalOrderedBags <= 0 || e.totalReceivedBags <= 0)) {
        formError =
            'Please enter valid Ordered and Received bag counts for cement entries.';
        notifyListeners();
        return false;
      }
    }
    return true;
  }

  void clearFormError() {
    formError = null;
    notifyListeners();
  }
}