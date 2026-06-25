// lib/features/stage21/presentation/pages/stage21_tab_page.dart
//
// Stage 2.1 sub-tabs: DPR | Stock | Quotation | MWM
// The MWM tab is added as the 4th sub-tab following the same pattern.

import 'package:flutter/material.dart';

import '../../data/models/material_quotation_model.dart';
import '../../data/models/material_stock_model.dart';
import '../../data/services/dpr_api_service.dart';
import '../../data/services/mwm_api_service.dart';
import '../../data/services/stage21_api_service.dart';
import 'dpr_list_page.dart';
import 'material_quotation_list_page.dart';
import 'material_stock_list_page.dart';
import 'material_weight_measurement_list_page.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────

const _kDprColor   = Color(0xFF7C3AED); // purple
const _kStockColor = Color(0xFF2563EB); // blue
const _kQuoteColor = Color(0xFF7C3AED); // purple
const _kMwmColor   = Color(0xFF059669); // teal-green — distinct MWM accent

// ─── Stage21TabPage ───────────────────────────────────────────────────────────

class Stage21TabPage extends StatefulWidget {
  final int    projectId;
  final String projectName;

  /// Callback fired after counts load so the parent can update its badge count.
  final void Function(int totalCount)? onCountChanged;

  const Stage21TabPage({
    super.key,
    required this.projectId,
    required this.projectName,
    this.onCountChanged,
  });

  @override
  State<Stage21TabPage> createState() => _Stage21TabPageState();
}

class _Stage21TabPageState extends State<Stage21TabPage>
    with SingleTickerProviderStateMixin {
  late TabController _subTabCtrl;

  // ── Lightweight counts (tab badges only — content is rendered by embedded pages)
  int _dprCount   = 0;
  int _stockCount = 0;
  int _quoteCount = 0;
  int _mwmCount   = 0;

  @override
  void initState() {
    super.initState();
    _subTabCtrl = TabController(length: 4, vsync: this);
    _subTabCtrl.addListener(_onSubTabChanged);
    _loadCounts();
  }

  @override
  void dispose() {
    _subTabCtrl.dispose();
    super.dispose();
  }

  void _onSubTabChanged() {
    setState(() {}); // refresh badge highlighting
  }

  // ── Count loaders ──────────────────────────────────────────────────────────

  Future<void> _loadCounts() async {
    await Future.wait([
      _loadDprCount(),
      _loadStockCount(),
      _loadQuoteCount(),
      _loadMwmCount(),
    ]);
    _notifyCount();
  }

  Future<void> _loadDprCount() async {
    try {
      final list = await DprApiService.fetchReports(widget.projectId);
      if (mounted) setState(() => _dprCount = list.length);
    } catch (_) {}
    _notifyCount();
  }

  Future<void> _loadStockCount() async {
    try {
      final raw  = await Stage21ApiService.fetchMaterialStocks(projectId: widget.projectId);
      final list = _extractList<MaterialStockModel>(raw, MaterialStockModel.fromJson);
      if (mounted) setState(() => _stockCount = list.length);
    } catch (_) {}
    _notifyCount();
  }

  Future<void> _loadQuoteCount() async {
    try {
      final raw  = await Stage21ApiService.fetchMaterialQuotations(projectId: widget.projectId);
      final list = _extractList<MaterialQuotationModel>(raw, MaterialQuotationModel.fromJson);
      if (mounted) setState(() => _quoteCount = list.length);
    } catch (_) {}
    _notifyCount();
  }

  Future<void> _loadMwmCount() async {
    try {
      final list = await MwmApiService.fetchList(widget.projectId);
      if (mounted) setState(() => _mwmCount = list.length);
    } catch (_) {}
    _notifyCount();
  }

  void _notifyCount() {
    widget.onCountChanged
        ?.call(_dprCount + _stockCount + _quoteCount + _mwmCount);
  }

  static List<T> _extractList<T>(
      dynamic raw, T Function(Map<String, dynamic>) fromJson) {
    if (raw == null) return [];
    if (raw is List) {
      return raw.whereType<Map<String, dynamic>>().map(fromJson).toList();
    }
    if (raw is Map<String, dynamic>) {
      final data = raw['data'];
      if (data is List) {
        return data.whereType<Map<String, dynamic>>().map(fromJson).toList();
      }
    }
    return [];
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Sub-tab bar ──────────────────────────────────────────────────────
      Material(
        color: Colors.white,
        child: TabBar(
          controller:           _subTabCtrl,
          labelColor:           _kDprColor,
          unselectedLabelColor: const Color(0xFF94A3B8),
          indicatorColor:       _kDprColor,
          indicatorWeight:      2.5,
          isScrollable:         true,
          tabAlignment:         TabAlignment.start,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 12),
          unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500, fontSize: 12),
          tabs: [
            _subTab('DPR',      _dprCount,   0, _kDprColor),
            _subTab('Stock',    _stockCount, 1, _kStockColor),
            _subTab('Quotation',_quoteCount, 2, _kQuoteColor),
            _subTab('MWM',      _mwmCount,   3, _kMwmColor),
          ],
        ),
      ),

      // ── Sub-tab views ────────────────────────────────────────────────────
      Expanded(
        child: TabBarView(
          controller: _subTabCtrl,
          children: [
            DprListPage(
              projectId:   widget.projectId,
              projectName: widget.projectName,
            ),
            MaterialStockListPage(
              projectId:   widget.projectId,
              projectName: widget.projectName,
            ),
            MaterialQuotationListPage(
              projectId:   widget.projectId,
              projectName: widget.projectName,
            ),
            // ── NEW: Material Weight Measurement tab ─────────────────────
            MaterialWeightMeasurementListPage(
              projectId:   widget.projectId,
              projectName: widget.projectName,
            ),
          ],
        ),
      ),
    ]);
  }

  Tab _subTab(String label, int count, int idx, Color accentColor) {
    final isSelected = _subTabCtrl.index == idx;
    return Tab(
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color:        isSelected ? accentColor : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize:   10,
              fontWeight: FontWeight.w700,
              color:      isSelected ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ),
      ]),
    );
  }
}