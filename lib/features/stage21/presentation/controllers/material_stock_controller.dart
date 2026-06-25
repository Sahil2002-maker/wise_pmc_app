import 'package:flutter/material.dart';
import '../../data/models/material_stock_model.dart';
import '../../data/services/stage21_api_service.dart';

// Mutable row state for form
class StockRowState {
  TextEditingController date          = TextEditingController();
  TextEditingController material      = TextEditingController();
  TextEditingController unit          = TextEditingController();
  TextEditingController invoiceNo     = TextEditingController();
  TextEditingController totalReceived = TextEditingController();
  TextEditingController usedQty       = TextEditingController();
  TextEditingController recordHolder  = TextEditingController();
  TextEditingController remarks       = TextEditingController();

  void dispose() {
    date.dispose();
    material.dispose();
    unit.dispose();
    invoiceNo.dispose();
    totalReceived.dispose();
    usedQty.dispose();
    recordHolder.dispose();
    remarks.dispose();
  }

  Map<String, dynamic> toJson() => {
        'date':           date.text.trim(),
        'material':       material.text.trim(),
        'unit':           unit.text.trim(),
        'invoice_no':     invoiceNo.text.trim(),
        'total_received': totalReceived.text.trim(),
        'used_qty':       usedQty.text.trim(),
        'record_holder':  recordHolder.text.trim(),
        'remarks':        remarks.text.trim(),
      };

  bool get isEmpty =>
      date.text.trim().isEmpty &&
      material.text.trim().isEmpty &&
      unit.text.trim().isEmpty &&
      invoiceNo.text.trim().isEmpty &&
      totalReceived.text.trim().isEmpty &&
      usedQty.text.trim().isEmpty &&
      recordHolder.text.trim().isEmpty &&
      remarks.text.trim().isEmpty;
}

class MaterialStockController extends ChangeNotifier {
  final int projectId;
  final String projectName;

  MaterialStockController({
    required this.projectId,
    required this.projectName,
  });

  // ── List state ─────────────────────────────────────────────────────────────
  List<MaterialStockModel> stocks    = [];
  bool    listLoading                = false;
  String? listError;
  int     currentPage                = 1;
  int     lastPage                   = 1;
  int     total                      = 0;
  String  searchQuery                = '';
  bool    isLoadingMore              = false;

  // ── Form state ─────────────────────────────────────────────────────────────
  bool    formLoading                = false;
  String? formError;
  String  nextStockNo                = '';
  String  selectedMonth              = _currentYearMonth();
  List<StockRowState> rows           = [];

  static String _currentYearMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  // ── Load list ──────────────────────────────────────────────────────────────

  Future<void> loadStocks({bool refresh = false}) async {
    if (refresh) {
      currentPage = 1;
      stocks      = [];
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
      final result = await Stage21ApiService.fetchMaterialStocks(
        projectId: projectId,
        page:      currentPage,
        search:    searchQuery.isEmpty ? null : searchQuery,
      );
      final data = result['data'];
      if (data != null) {
        final List raw = data['data'] ?? [];
        final fetched  = raw
            .whereType<Map<String, dynamic>>()
            .map(MaterialStockModel.fromJson)
            .toList();
        if (currentPage == 1) {
          stocks = fetched;
        } else {
          stocks.addAll(fetched);
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
    loadStocks(refresh: true);
  }

  Future<void> loadMore() async {
    if (currentPage < lastPage && !isLoadingMore) {
      currentPage++;
      await loadStocks();
    }
  }

  // ── Form helpers ───────────────────────────────────────────────────────────

  Future<void> initCreateForm() async {
    rows          = List.generate(4, (_) => StockRowState());
    selectedMonth = _currentYearMonth();
    formError     = null;
    formLoading   = true;
    notifyListeners();
    try {
      nextStockNo = await Stage21ApiService.fetchNextStockNo(projectId);
    } catch (_) {
      nextStockNo = 'Auto';
    } finally {
      formLoading = false;
      notifyListeners();
    }
  }

  void initEditForm(MaterialStockModel stock) {
    nextStockNo   = stock.stockNo;
    selectedMonth = stock.registerMonth;
    formError     = null;
    rows          = stock.items.map((item) {
      final r           = StockRowState();
      r.date.text           = item.date ?? '';
      r.material.text       = item.material;
      r.unit.text           = item.unit ?? '';
      r.invoiceNo.text      = item.invoiceNo ?? '';
      r.totalReceived.text  =
          item.totalReceived != null ? item.totalReceived.toString() : '';
      r.usedQty.text        =
          item.usedQty != null ? item.usedQty.toString() : '';
      r.recordHolder.text   = item.recordHolder ?? '';
      r.remarks.text        = item.remarks ?? '';
      return r;
    }).toList();
    if (rows.isEmpty) rows.add(StockRowState());
    notifyListeners();
  }

  void addRow() {
    rows.add(StockRowState());
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
      formError = 'Please fill at least one material row.';
      notifyListeners();
      return false;
    }
    formError   = null;
    formLoading = true;
    notifyListeners();
    try {
      await Stage21ApiService.createMaterialStock(
        projectId:     projectId,
        registerMonth: selectedMonth,
        items:         items,
      );
      await loadStocks(refresh: true);
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

  Future<bool> saveEdit(int stockId) async {
    final items = validRows;
    if (items.isEmpty) {
      formError = 'Please fill at least one material row.';
      notifyListeners();
      return false;
    }
    formError   = null;
    formLoading = true;
    notifyListeners();
    try {
      await Stage21ApiService.updateMaterialStock(
        projectId:     projectId,
        id:            stockId,
        registerMonth: selectedMonth,
        items:         items,
      );
      await loadStocks(refresh: true);
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

  Future<bool> deleteStock(int stockId) async {
    try {
      await Stage21ApiService.deleteMaterialStock(projectId, stockId);
      stocks.removeWhere((s) => s.id == stockId);
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