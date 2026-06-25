import 'package:flutter/material.dart';
import '../../data/models/material_quotation_model.dart';
import '../../data/services/stage21_api_service.dart';

class QuotationRowState {
  TextEditingController date            = TextEditingController();
  TextEditingController quotationName   = TextEditingController();
  TextEditingController unit            = TextEditingController();
  TextEditingController quotationNumber = TextEditingController();
  TextEditingController totalRate       = TextEditingController();
  TextEditingController recordHolder    = TextEditingController();
  TextEditingController remarks         = TextEditingController();

  void dispose() {
    date.dispose();
    quotationName.dispose();
    unit.dispose();
    quotationNumber.dispose();
    totalRate.dispose();
    recordHolder.dispose();
    remarks.dispose();
  }

  Map<String, dynamic> toJson() => {
        'date':             date.text.trim(),
        'quotation_name':   quotationName.text.trim(),
        'unit':             unit.text.trim(),
        'quotation_number': quotationNumber.text.trim(),
        'total_rate':       totalRate.text.trim(),
        'record_holder':    recordHolder.text.trim(),
        'remarks':          remarks.text.trim(),
      };

  bool get isEmpty =>
      date.text.trim().isEmpty &&
      quotationName.text.trim().isEmpty &&
      unit.text.trim().isEmpty &&
      quotationNumber.text.trim().isEmpty &&
      totalRate.text.trim().isEmpty &&
      recordHolder.text.trim().isEmpty &&
      remarks.text.trim().isEmpty;
}

class MaterialQuotationController extends ChangeNotifier {
  final int projectId;
  final String projectName;

  MaterialQuotationController({
    required this.projectId,
    required this.projectName,
  });

  // ── List state ─────────────────────────────────────────────────────────────
  List<MaterialQuotationModel> quotations = [];
  bool    listLoading                     = false;
  String? listError;
  int     currentPage                     = 1;
  int     lastPage                        = 1;
  int     total                           = 0;
  String  searchQuery                     = '';
  bool    isLoadingMore                   = false;

  // ── Form state ─────────────────────────────────────────────────────────────
  bool    formLoading                     = false;
  String? formError;
  String  nextQuotationNo                 = '';
  String  selectedMonth                   = _currentYearMonth();
  List<QuotationRowState> rows            = [];

  static String _currentYearMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  // ── Load list ──────────────────────────────────────────────────────────────

  Future<void> loadQuotations({bool refresh = false}) async {
    if (refresh) {
      currentPage = 1;
      quotations  = [];
    }
    if (currentPage == 1) {
      listLoading = true;
      listError   = null;
      notifyListeners();
    } else {
      isLoadingMore = true;
      notifyListeners();
    }

    try {
      final result = await Stage21ApiService.fetchMaterialQuotations(
        projectId: projectId,
        page:      currentPage,
        search:    searchQuery.isEmpty ? null : searchQuery,
      );
      final data = result['data'];
      if (data != null) {
        final List raw = data['data'] ?? [];
        final fetched  = raw
            .whereType<Map<String, dynamic>>()
            .map(MaterialQuotationModel.fromJson)
            .toList();
        if (currentPage == 1) {
          quotations = fetched;
        } else {
          quotations.addAll(fetched);
        }
        lastPage = data['last_page'] ?? 1;
        total    = data['total'] ?? 0;
      }
    } catch (e) {
      listError = e.toString();
    } finally {
      listLoading   = false;
      isLoadingMore = false;
      notifyListeners();
    }
  }

  void onSearch(String query) {
    searchQuery = query;
    loadQuotations(refresh: true);
  }

  Future<void> loadMore() async {
    if (currentPage < lastPage && !isLoadingMore) {
      currentPage++;
      await loadQuotations();
    }
  }

  // ── Form helpers ───────────────────────────────────────────────────────────

  Future<void> initCreateForm() async {
    rows          = List.generate(4, (_) => QuotationRowState());
    selectedMonth = _currentYearMonth();
    formError     = null;
    formLoading   = true;
    notifyListeners();
    try {
      nextQuotationNo =
          await Stage21ApiService.fetchNextQuotationNo(projectId);
    } catch (_) {
      nextQuotationNo = 'Auto';
    } finally {
      formLoading = false;
      notifyListeners();
    }
  }

  void initEditForm(MaterialQuotationModel quotation) {
    nextQuotationNo = quotation.quotationNo;
    selectedMonth   = quotation.registerMonth;
    formError       = null;
    rows            = quotation.items.map((item) {
      final r               = QuotationRowState();
      r.date.text               = item.date ?? '';
      r.quotationName.text      = item.quotationName;
      r.unit.text               = item.unit ?? '';
      r.quotationNumber.text    = item.quotationNumber ?? '';
      r.totalRate.text          =
          item.totalRate != null ? item.totalRate.toString() : '';
      r.recordHolder.text       = item.recordHolder ?? '';
      r.remarks.text            = item.remarks ?? '';
      return r;
    }).toList();
    if (rows.isEmpty) rows.add(QuotationRowState());
    notifyListeners();
  }

  void addRow() {
    rows.add(QuotationRowState());
    notifyListeners();
  }

  void removeRow(int index) {
    if (rows.length <= 1) return;
    rows[index].dispose();
    rows.removeAt(index);
    notifyListeners();
  }

  void setMonth(String month) {
    selectedMonth = month;
    notifyListeners();
  }

  List<Map<String, dynamic>> get validRows =>
      rows.where((r) => !r.isEmpty).map((r) => r.toJson()).toList();

  // ── CRUD operations ────────────────────────────────────────────────────────

  Future<bool> saveCreate() async {
    final items = validRows;
    if (items.isEmpty) {
      formError = 'Please fill at least one quotation row.';
      notifyListeners();
      return false;
    }
    formError   = null;
    formLoading = true;
    notifyListeners();
    try {
      await Stage21ApiService.createMaterialQuotation(
        projectId:     projectId,
        registerMonth: selectedMonth,
        items:         items,
      );
      await loadQuotations(refresh: true);
      return true;
    } catch (e) {
      formError = e.toString();
      notifyListeners();
      return false;
    } finally {
      formLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveEdit(int quotationId) async {
    final items = validRows;
    if (items.isEmpty) {
      formError = 'Please fill at least one quotation row.';
      notifyListeners();
      return false;
    }
    formError   = null;
    formLoading = true;
    notifyListeners();
    try {
      await Stage21ApiService.updateMaterialQuotation(
        projectId:     projectId,
        id:            quotationId,
        registerMonth: selectedMonth,
        items:         items,
      );
      await loadQuotations(refresh: true);
      return true;
    } catch (e) {
      formError = e.toString();
      notifyListeners();
      return false;
    } finally {
      formLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteQuotation(int quotationId) async {
    try {
      await Stage21ApiService.deleteMaterialQuotation(projectId, quotationId);
      quotations.removeWhere((q) => q.id == quotationId);
      total = (total - 1).clamp(0, total);
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  void dispose() {
    for (final r in rows) {
      r.dispose();
    }
    super.dispose();
  }
}