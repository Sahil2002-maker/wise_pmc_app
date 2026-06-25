// lib/features/stage21/presentation/controllers/material_weight_measurement_controller.dart
//
// UPDATED: Works with the new MwmFileSlot.existingPhotos list.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/models/material_weight_measurement_model.dart';
import '../../data/services/mwm_api_service.dart';

enum MwmFileSlotKey {
  grossWeightSlip,
  vehicleWithMaterialImage,
  tareWeightSlip
}

class MaterialWeightMeasurementController extends ChangeNotifier {
  final int projectId;
  final String projectName;

  MaterialWeightMeasurementController({
    required this.projectId,
    required this.projectName,
  });

  // ── List state ─────────────────────────────────────────────────────────────

  List<MwmListModel> _allRecords = [];
  List<MwmListModel> _filtered = [];
  List<MwmListModel> get records => _filtered;
  int get total => _allRecords.length;

  bool listLoading = false;
  String? listError;

  // ── Form state ─────────────────────────────────────────────────────────────

  bool formLoading = false;
  bool formSaving = false;
  String? formError;

  String? formMwmNo;
  String? formDate;
  String? formRemarks;
  List<MwmEntryForm> formEntries = [];

  // Material types (shared, loaded once)
  List<MwmMaterialTypeModel> materialTypes = [];
  bool typesLoaded = false;

  // Tracks original indices removed during edit
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

  // ── Load material types (once) ─────────────────────────────────────────────

  Future<void> ensureMaterialTypes() async {
    if (typesLoaded && materialTypes.isNotEmpty) return;
    try {
      materialTypes = await MwmApiService.fetchMaterialTypes();
      typesLoaded = true;
      notifyListeners();
    } catch (_) {}
  }

  // ── Init create form ───────────────────────────────────────────────────────

  Future<void> initCreateForm() async {
    formLoading = true;
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

  // ── Init edit form ─────────────────────────────────────────────────────────

  Future<void> initEditForm(int id) async {
    formLoading = true;
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
        final entry = e.value;
        MwmMaterialTypeModel? matched;
        try {
          matched =
              materialTypes.firstWhere((t) => t.id == entry.materialTypeId);
        } catch (_) {}
        return MwmEntryForm.fromEdit(entry, e.key, matched);
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

  void addEntry() {
    formEntries = [...formEntries, MwmEntryForm()];
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

  // ── File slot management ───────────────────────────────────────────────────

  Future<MwmGeoPoint?> captureGeo() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
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

  /// Sets a freshly picked/captured file for the given entry/slot.
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
            // Keep existing photos visible — new file is ADDED on top
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
    }
    updateEntry(entryIndex, updated);
  }

  /// Clears a slot — removes new file and/or marks existing server files for removal.
  void clearEntryFile(int entryIndex, MwmFileSlotKey slotKey) {
    final entry = formEntries[entryIndex];

    MwmEntryForm updated;
    switch (slotKey) {
      case MwmFileSlotKey.grossWeightSlip:
        final hadExisting =
            entry.grossWeightSlip.existingPhotos.isNotEmpty;
        updated = entry.copyWith(
          grossWeightSlip: entry.grossWeightSlip.copyWith(
            clearNewFile: true,
            clearGeo: true,
            removed: hadExisting,
            existingPhotos: const [],
          ),
        );
        break;
      case MwmFileSlotKey.vehicleWithMaterialImage:
        final hadExisting =
            entry.vehicleWithMaterialImage.existingPhotos.isNotEmpty;
        updated = entry.copyWith(
          vehicleWithMaterialImage: entry.vehicleWithMaterialImage.copyWith(
            clearNewFile: true,
            clearGeo: true,
            removed: hadExisting,
            existingPhotos: const [],
          ),
        );
        break;
      case MwmFileSlotKey.tareWeightSlip:
        final hadExisting = entry.tareWeightSlip.existingPhotos.isNotEmpty;
        updated = entry.copyWith(
          tareWeightSlip: entry.tareWeightSlip.copyWith(
            clearNewFile: true,
            clearGeo: true,
            removed: hadExisting,
            existingPhotos: const [],
          ),
        );
        break;
    }
    updateEntry(entryIndex, updated);
  }

  // ── Save (create) ──────────────────────────────────────────────────────────

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
      formSaving = false;
      notifyListeners();
      return false;
    }
  }

  // ── Save (update) ──────────────────────────────────────────────────────────

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
      formSaving = false;
      notifyListeners();
      return false;
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
    } catch (e) {
      return false;
    }
  }

  // ── Computed totals for form UI ────────────────────────────────────────────

  double get formTotalNet =>
      formEntries.fold(0.0, (sum, e) => sum + e.netWeight);

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
      if (e.grossWeight <= 0 || e.tareWeight <= 0) {
        formError =
            'Please enter valid Loaded and Empty weights for each entry.';
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