// lib/features/.../presentation/pages/material_quotation_list_page.dart
//
// UI restyled to match the Cement Checklist screen pattern exactly
// (header info-card, tinted card header with numbered badge + tag chip,
// info row, outlined action chips). All functionality is unchanged.

import 'package:flutter/material.dart';
import '../controllers/material_quotation_controller.dart';
import '../../data/models/material_quotation_model.dart';
import '../../data/services/pdf_download_service.dart';
import 'material_quotation_form_page.dart';
import 'material_quotation_view_page.dart';
import '../../../../core/constants/api_constants.dart';

class MaterialQuotationListPage extends StatefulWidget {
  final int    projectId;
  final String projectName;

  const MaterialQuotationListPage({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<MaterialQuotationListPage> createState() =>
      _MaterialQuotationListPageState();
}

class _MaterialQuotationListPageState
    extends State<MaterialQuotationListPage> {
  late MaterialQuotationController _ctrl;
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController      _scrollCtrl = ScrollController();

  static const Color _accent = Color(0xFF7C3AED);

  // ── PDF download/print state ───────────────────────────────────────────
  int? _downloadingId; // id of the quotation currently being downloaded

  @override
  void initState() {
    super.initState();
    _ctrl = MaterialQuotationController(
      projectId:   widget.projectId,
      projectName: widget.projectName,
    );
    _ctrl.loadQuotations(refresh: true);
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      _ctrl.loadMore();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _openCreate() async {
    await _ctrl.initCreateForm();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MaterialQuotationFormPage(
          controller: _ctrl,
          isEdit:     false,
        ),
      ),
    );
  }

  Future<void> _openEdit(MaterialQuotationModel quotation) async {
    _ctrl.initEditForm(quotation);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MaterialQuotationFormPage(
          controller: _ctrl,
          isEdit:     true,
          quotationId: quotation.id,
        ),
      ),
    );
  }

  void _openView(MaterialQuotationModel quotation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MaterialQuotationViewPage(quotation: quotation),
      ),
    );
  }

  // ── Download / Print ────────────────────────────────────────────────────
  Future<void> _downloadPdf(MaterialQuotationModel quotation) async {
    if (_downloadingId != null) return; // prevent double taps
    setState(() => _downloadingId = quotation.id);

    final url =
        '${ApiConstants.baseUrl}/api/mobile/material-quotation/${widget.projectId}/${quotation.id}/pdf';

    final result = await PdfDownloadService.downloadAndOpen(
      url: url,
      fileName: 'Material-Quotation-${quotation.quotationNo}.pdf',
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

  Future<void> _confirmDelete(MaterialQuotationModel quotation) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Quotation',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
            'Delete quotation "${quotation.quotationNo}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
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
      final success = await _ctrl.deleteQuotation(quotation.id);
      if (mounted) {
        _showSnack(
          success ? 'Quotation deleted.' : 'Failed to delete quotation.',
          color: success ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
        );
      }
    }
  }

  void _showSnack(String msg, {required Color color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                child: CircularProgressIndicator(color: _accent));
          }
          if (_ctrl.listError != null) {
            return _buildError();
          }
          return RefreshIndicator(
            onRefresh: () => _ctrl.loadQuotations(refresh: true),
            color: _accent,
            child: CustomScrollView(
              controller: _scrollCtrl,
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(child: _buildSearch()),
                _ctrl.quotations.isEmpty
                    ? SliverFillRemaining(child: _buildEmpty())
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) {
                            if (i == _ctrl.quotations.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: CircularProgressIndicator(
                                      color: _accent),
                                ),
                              );
                            }
                            final quotation = _ctrl.quotations[i];
                            return _buildCard(quotation, i);
                          },
                          childCount: _ctrl.quotations.length +
                              (_ctrl.isLoadingMore ? 1 : 0),
                        ),
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
        label: const Text('New Quotation',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  // ── Header — matches Cement Checklist header card ─────────────────────────
  Widget _buildHeader() => AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _accent.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.description_outlined,
                    color: _accent, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Material Quotation',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _accent,
                      ),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_ctrl.total}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildSearch() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: TextField(
          controller: _searchCtrl,
          onChanged: _ctrl.onSearch,
          decoration: InputDecoration(
            hintText: 'Search quotations…',
            hintStyle:
                const TextStyle(color: Color(0xFFB0BAC9), fontSize: 13),
            prefixIcon:
                const Icon(Icons.search_rounded, color: _accent, size: 18),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _accent.withValues(alpha: 0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _accent.withValues(alpha: 0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _accent, width: 1.5),
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
                onPressed: () => _ctrl.loadQuotations(refresh: true),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );

  // ── Empty state — matches Cement Checklist empty style ─────────────────────
  Widget _buildEmpty() => Center(
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
                child: Icon(Icons.description_outlined,
                    size: 56, color: _accent.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: 20),
              const Text('No material quotations found.',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B))),
              const SizedBox(height: 8),
              const Text(
                "Tap 'New Quotation' to add the first one.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
            ],
          ),
        ),
      );

  // ── Card — matches Cement Checklist card style ─────────────────────────────
  Widget _buildCard(MaterialQuotationModel quotation, int index) {
    final isDownloading = _downloadingId == quotation.id;
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
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── card header (tinted background) ─────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quotation.quotationNo,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _accent,
                        ),
                      ),
                      Text(
                        quotation.formattedMonth,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Quotation',
                    style: TextStyle(
                      fontSize: 10,
                      color: _accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── card body ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _infoItem(Icons.calendar_today_outlined, 'Month',
                        quotation.formattedMonth),
                    const SizedBox(width: 16),
                    _infoItem(Icons.list_alt_outlined, 'Items',
                        '${quotation.items.length}'),
                    const SizedBox(width: 16),
                    _infoItem(Icons.person_outline, 'Created By',
                        quotation.creatorName ?? 'N/A'),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),
                // ── Action buttons — outlined style matching Cement Checklist ──
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ActionBtn(
                      icon:  Icons.visibility_outlined,
                      label: 'View',
                      color: const Color(0xFF0EA5E9),
                      onTap: () => _openView(quotation),
                    ),
                    _ActionBtn(
                      icon:  Icons.edit_outlined,
                      label: 'Edit',
                      color: const Color(0xFFF59E0B),
                      onTap: () => _openEdit(quotation),
                    ),
                    _ActionBtn(
                      icon:      Icons.picture_as_pdf_outlined,
                      label:     isDownloading ? 'Please wait…' : 'Print / PDF',
                      color:     const Color(0xFF22C55E),
                      onTap:     isDownloading ? null : () => _downloadPdf(quotation),
                      isLoading: isDownloading,
                    ),
                    _ActionBtn(
                      icon:  Icons.delete_outline_rounded,
                      label: 'Delete',
                      color: const Color(0xFFEF4444),
                      onTap: () => _confirmDelete(quotation),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Info item — matches Cement Checklist info item style ──────────────────
  Widget _infoItem(IconData icon, String label, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(icon, size: 11, color: const Color(0xFF64748B)),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    value.isNotEmpty ? value : 'N/A',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

// ── Action button — outlined style matching Cement Checklist ────────────────

class _ActionBtn extends StatelessWidget {
  final IconData      icon;
  final String        label;
  final Color         color;
  final VoidCallback? onTap;
  final bool          isLoading;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool disabled = onTap == null && !isLoading;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: disabled ? 0.04 : 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: color.withValues(alpha: disabled ? 0.12 : 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width:  13,
                height: 13,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  valueColor:  AlwaysStoppedAnimation<Color>(color),
                ),
              )
            else
              Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize:   11,
                fontWeight: FontWeight.w600,
                color:      color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}