// lib/features/stage21/presentation/pages/material_weight_measurement_list_page.dart
//
// UPDATED: Added "Audit Trail – Removed Entries" section below the main list.
// The audit section is implemented as a self-contained widget
// (MwmAuditTrailSection) with its own controller and search/pagination.

import 'package:flutter/material.dart';
import '../controllers/material_weight_measurement_controller.dart';
import '../../data/models/material_weight_measurement_model.dart';
import '../../data/services/mwm_api_service.dart';
import '../../data/services/pdf_download_service.dart';
import '../widgets/mwm_audit_trail_section.dart';
import 'material_weight_measurement_form_page.dart';
import 'material_weight_measurement_view_page.dart';

class MaterialWeightMeasurementListPage extends StatefulWidget {
  final int projectId;
  final String projectName;

  const MaterialWeightMeasurementListPage({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<MaterialWeightMeasurementListPage> createState() =>
      _MaterialWeightMeasurementListPageState();
}

class _MaterialWeightMeasurementListPageState
    extends State<MaterialWeightMeasurementListPage> {
  late MaterialWeightMeasurementController _ctrl;
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  static const Color _accent =
      Color(0xFF059669); // teal-green — distinct from DPR/Stock/Quote

  int? _downloadingId;

  @override
  void initState() {
    super.initState();
    _ctrl = MaterialWeightMeasurementController(
      projectId: widget.projectId,
      projectName: widget.projectName,
    );
    _ctrl.loadRecords(refresh: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ──────────────────────────────────────────────────────────────

  Future<void> _openCreate() async {
    await _ctrl.initCreateForm();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MaterialWeightMeasurementFormPage(
          controller: _ctrl,
          isEdit: false,
        ),
      ),
    );
  }

  Future<void> _openEdit(MwmListModel record) async {
    await _ctrl.initEditForm(record.id);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MaterialWeightMeasurementFormPage(
          controller: _ctrl,
          isEdit: true,
          recordId: record.id,
        ),
      ),
    );
  }

  Future<void> _openView(MwmListModel record) async {
    try {
      final detail =
          await MwmApiService.fetchDetail(widget.projectId, record.id);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              MaterialWeightMeasurementViewPage(detail: detail),
        ),
      );
    } catch (e) {
      _showSnack(
        e.toString().replaceAll('Exception: ', ''),
        color: const Color(0xFFEF4444),
      );
    }
  }

  // ── PDF download (authenticated) ────────────────────────────────────────────

  Future<void> _downloadPdf(MwmListModel record) async {
    if (_downloadingId != null) return;
    setState(() => _downloadingId = record.id);

    final url = MwmApiService.downloadUrl(widget.projectId, record.id);
    final result = await PdfDownloadService.downloadAndOpen(
      url: url,
      fileName: 'MWM-${record.mwmNo.replaceAll('/', '-')}.pdf',
    );

    if (!mounted) return;
    setState(() => _downloadingId = null);

    if (!result.ok) {
      _showSnack(
        result.errorMessage ?? 'Failed to download PDF.',
        color: const Color(0xFFEF4444),
      );
    }
  }

  // ── Delete ──────────────────────────────────────────────────────────────────

  Future<void> _confirmDelete(MwmListModel record) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Record',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
            'Delete MWM "${record.mwmNo}"? This will soft-delete the record.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final success = await _ctrl.deleteRecord(record.id);
      if (mounted) {
        _showSnack(
          success ? 'Record deleted.' : 'Failed to delete record.',
          color: success
              ? const Color(0xFF16A34A)
              : const Color(0xFFEF4444),
        );
      }
    }
  }

  void _showSnack(String msg, {required Color color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          if (_ctrl.listLoading) {
            return const Center(
                child:
                    CircularProgressIndicator(color: _accent));
          }
          if (_ctrl.listError != null) return _buildError();
          return RefreshIndicator(
            onRefresh: () => _ctrl.loadRecords(refresh: true),
            color: _accent,
            child: CustomScrollView(
              controller: _scrollCtrl,
              slivers: [
                // ── Header + search (existing) ────────────────────────────
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(child: _buildSearch()),

                // ── Main records list (existing) ──────────────────────────
                _ctrl.records.isEmpty
                    ? SliverFillRemaining(child: _buildMainEmpty())
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) =>
                              _buildCard(_ctrl.records[i], i),
                          childCount: _ctrl.records.length,
                        ),
                      ),

                // ── Divider before audit section ──────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          'AUDIT TRAIL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade500,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ]),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 10)),

                // ── ✅ NEW: Audit Trail – Removed Entries ─────────────────
                SliverToBoxAdapter(
                  child: MwmAuditTrailSection(
                      projectId: widget.projectId),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 90)),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Measurement',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  // ── Header card (existing, unchanged) ─────────────────────────────────────

  Widget _buildHeader() => AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: _accent.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.local_shipping_outlined,
                  color: _accent, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Material Weight Measurement',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _accent),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.projectName,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(20)),
              child: Text(
                '${_ctrl.total}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
            ),
          ]),
        ),
      );

  // ── Search bar (existing, unchanged) ──────────────────────────────────────

  Widget _buildSearch() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: TextField(
          controller: _searchCtrl,
          onChanged: _ctrl.onSearch,
          decoration: InputDecoration(
            hintText: 'Search by MWM No., date, creator…',
            hintStyle: const TextStyle(
                color: Color(0xFFB0BAC9), fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded,
                color: _accent, size: 18),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: _accent.withValues(alpha: 0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: _accent.withValues(alpha: 0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: _accent, width: 1.5),
            ),
          ),
          style: const TextStyle(fontSize: 13),
        ),
      );

  // ── Error state ────────────────────────────────────────────────────────────

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFEF4444), size: 48),
              const SizedBox(height: 12),
              Text(_ctrl.listError ?? 'Error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF64748B))),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _ctrl.loadRecords(refresh: true),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      );

  // ── Empty state for main list ──────────────────────────────────────────────

  Widget _buildMainEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.local_shipping_outlined,
                    size: 56,
                    color: _accent.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: 20),
              const Text('No measurements yet.',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B))),
              const SizedBox(height: 8),
              const Text(
                "Tap 'New Measurement' to add the first one.",
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Color(0xFF94A3B8), fontSize: 13),
              ),
            ],
          ),
        ),
      );

  // ── Record card (existing, unchanged) ─────────────────────────────────────

  Widget _buildCard(MwmListModel record, int index) {
    final isDownloading = _downloadingId == record.id;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(children: [
        // ── Card header ────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.06),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(8)),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.mwmNo,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _accent),
                  ),
                  Text(
                    record.measurementDate,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'MWM',
                style: TextStyle(
                    fontSize: 10,
                    color: _accent,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),

        // ── Card body ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                _infoItem(
                  Icons.format_list_numbered_outlined,
                  'Entries',
                  '${record.entryCount}',
                ),
                const SizedBox(width: 16),
                _infoItem(
                  Icons.scale_outlined,
                  'Total Net Wt.',
                  '${record.totalNetWeight} kg',
                ),
                const SizedBox(width: 16),
                _infoItem(
                  Icons.person_outline,
                  'Created By',
                  record.creatorName ?? 'N/A',
                ),
              ]),
              if (record.remarks != null &&
                  record.remarks!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.notes_outlined,
                      size: 12, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      record.remarks!,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ],
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 10),

              // ── Action buttons ─────────────────────────────────────────
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ActionBtn(
                    icon: Icons.visibility_outlined,
                    label: 'View',
                    color: const Color(0xFF0EA5E9),
                    onTap: () => _openView(record),
                  ),
                  _ActionBtn(
                    icon: Icons.edit_outlined,
                    label: 'Edit',
                    color: const Color(0xFFF59E0B),
                    onTap: () => _openEdit(record),
                  ),
                  _ActionBtn(
                    icon: Icons.picture_as_pdf_outlined,
                    label:
                        isDownloading ? 'Downloading…' : 'Print / PDF',
                    color: const Color(0xFF22C55E),
                    onTap: isDownloading
                        ? null
                        : () => _downloadPdf(record),
                    isLoading: isDownloading,
                  ),
                  _ActionBtn(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete',
                    color: const Color(0xFFEF4444),
                    onTap: () => _confirmDelete(record),
                  ),
                ],
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _infoItem(IconData icon, String label, String value) =>
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3)),
            const SizedBox(height: 2),
            Row(children: [
              Icon(icon, size: 11, color: const Color(0xFF64748B)),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  value.isNotEmpty ? value : 'N/A',
                  style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ],
        ),
      );
}

// ─── Reusable action button (unchanged from original) ─────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool isLoading;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null && !isLoading;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: disabled ? 0.04 : 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: color.withValues(
                  alpha: disabled ? 0.12 : 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    valueColor: AlwaysStoppedAnimation<Color>(color)),
              )
            else
              Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }
}