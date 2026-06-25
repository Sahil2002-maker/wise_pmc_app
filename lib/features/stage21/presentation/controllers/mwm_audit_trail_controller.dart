// lib/features/stage21/presentation/controllers/mwm_audit_trail_controller.dart
//
// ChangeNotifier controller for the Audit Trail – Removed Entries section.
// Handles loading, client-side search, and pagination.

import 'package:flutter/foundation.dart';
import '../../data/models/mwm_deleted_entry_model.dart';
import '../../data/services/mwm_audit_trail_service.dart';

class MwmAuditTrailController extends ChangeNotifier {
  final int projectId;

  MwmAuditTrailController({required this.projectId});

  // ── Raw data ─────────────────────────────────────────────────────────────────

  List<MwmDeletedEntryModel> _all = [];

  // ── Filtered + paginated view ─────────────────────────────────────────────────

  List<MwmDeletedEntryModel> _filtered = [];

  /// Currently visible page of filtered results.
  List<MwmDeletedEntryModel> get currentPage {
    final start = (_currentPage - 1) * _pageSize;
    final end = (start + _pageSize).clamp(0, _filtered.length);
    if (start >= _filtered.length) return [];
    return _filtered.sublist(start, end);
  }

  int get totalFiltered => _filtered.length;
  int get totalAll => _all.length;

  // ── Pagination ────────────────────────────────────────────────────────────────

  int _currentPage = 1;
  final int _pageSize = 10;

  int get currentPageNumber => _currentPage;
  int get totalPages => (_filtered.length / _pageSize).ceil().clamp(1, 99999);
  bool get hasPrev => _currentPage > 1;
  bool get hasNext => _currentPage < totalPages;

  void nextPage() {
    if (hasNext) {
      _currentPage++;
      notifyListeners();
    }
  }

  void prevPage() {
    if (hasPrev) {
      _currentPage--;
      notifyListeners();
    }
  }

  void goToPage(int page) {
    if (page >= 1 && page <= totalPages) {
      _currentPage = page;
      notifyListeners();
    }
  }

  // ── Search ────────────────────────────────────────────────────────────────────

  String _searchQuery = '';

  void onSearch(String q) {
    _searchQuery = q.toLowerCase().trim();
    _applyFilter();
    _currentPage = 1;
    notifyListeners();
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filtered = List.from(_all);
      return;
    }
    _filtered = _all.where((e) {
      return e.mwmNo.toLowerCase().contains(_searchQuery) ||
          e.measurementDate.toLowerCase().contains(_searchQuery) ||
          e.vehicleNumber.toLowerCase().contains(_searchQuery) ||
          e.challanNumber.toLowerCase().contains(_searchQuery) ||
          e.materialTypeName.toLowerCase().contains(_searchQuery) ||
          e.originalCreatedBy.toLowerCase().contains(_searchQuery) ||
          e.deletedBy.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  // ── Loading state ─────────────────────────────────────────────────────────────

  bool loading = false;
  String? error;

  // ── Load ──────────────────────────────────────────────────────────────────────

  Future<void> load({bool refresh = false}) async {
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();

    try {
      _all = await MwmAuditTrailService.fetchDeletedEntries(projectId);
      _applyFilter();
      _currentPage = 1;
    } catch (e) {
      error = e.toString().replaceAll('Exception: ', '');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  /// Returns a 1-based display string for the current page range.
  /// e.g. "Showing 1 to 10 of 23 entries"
  String get pageRangeText {
    if (_filtered.isEmpty) return 'No entries found';
    final start = (_currentPage - 1) * _pageSize + 1;
    final end = (start + _pageSize - 1).clamp(1, _filtered.length);
    return 'Showing $start to $end of ${_filtered.length} entries';
  }
}