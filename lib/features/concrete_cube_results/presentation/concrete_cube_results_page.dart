// lib/features/concrete_cube_results/presentation/concrete_cube_results_page.dart
//
// CHANGES vs original:
//   • _launchUrl() removed — replaced with PrintDownloadService calls
//   • Print button  → PrintDownloadService.printDocument(context, url, title)
//   • PDF button    → PrintDownloadService.downloadPdf(context, url, fileName)

import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../../../../core/services/api_service.dart';
import '../../../../core/services/print_download_service.dart'; // ← NEW
import '../../../../core/utils/api_exception.dart';
import '../data/models/concrete_cube_result_model.dart';
import 'concrete_cube_result_form_page.dart';
import 'concrete_cube_result_view_page.dart';

class ConcreteCubeResultsPage extends StatefulWidget {
  final int projectId;
  final String projectName;

  const ConcreteCubeResultsPage({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<ConcreteCubeResultsPage> createState() =>
      _ConcreteCubeResultsPageState();
}

class _ConcreteCubeResultsPageState extends State<ConcreteCubeResultsPage> {
  List<ConcreteCubeResultModel> _results = [];
  bool _isLoading = true;
  String? _error;

  static const _accent = Color(0xFF1565C0);
  static const _accentLight = Color(0xFF1E88E5);

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list =
          await ApiService.fetchConcreteCubeResults(widget.projectId);
      list.sort((a, b) => a.resultNo.compareTo(b.resultNo));
      if (!mounted) return;
      setState(() {
        _results = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openForm({ConcreteCubeResultModel? existing}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ConcreteCubeResultFormPage(
          projectId: widget.projectId,
          projectName: widget.projectName,
          existing: existing,
        ),
        fullscreenDialog: true,
      ),
    );
    if (result == true) _loadResults();
  }

  void _openView(ConcreteCubeResultModel r) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConcreteCubeResultViewPage(
          result: r,
          projectName: widget.projectName,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(ConcreteCubeResultModel r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Test',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text('Delete ${r.uniqueNumber}? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiService.deleteConcreteCubeResult(widget.projectId, r.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Test deleted successfully'),
        backgroundColor: Color(0xFF22C55E),
      ));
      _loadResults();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: const Color(0xFFEF4444),
      ));
    }
  }

  // ── Print / Download ──────────────────────────────────────────────────────

  Future<void> _print(ConcreteCubeResultModel r) async {
    final url =
        ApiService.concreteCubeResultPrintUrl(widget.projectId, r.id);
    await PrintDownloadService.printDocument(
      context,
      url: url,
      title: 'Print — ${r.uniqueNumber}',
    );
  }

  Future<void> _download(ConcreteCubeResultModel r) async {
    final url =
        ApiService.concreteCubeResultDownloadUrl(widget.projectId, r.id);
    await PrintDownloadService.downloadPdf(
      context,
      url: url,
      fileName: 'concrete_cube_${r.uniqueNumber}.pdf',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────

  String _fmtDate(String? d) {
    if (d == null || d.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(d);
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return d;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _accent))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadResults,
                  color: _accent,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _buildHeader()),
                      _results.isEmpty
                          ? SliverFillRemaining(child: _buildEmpty())
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (_, i) => _buildCard(_results[i], i),
                                childCount: _results.length,
                              ),
                            ),
                      const SliverToBoxAdapter(child: SizedBox(height: 96)),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Test',
            style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 3,
      ),
    );
  }

  Widget _buildHeader() => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_accent, _accentLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: _accent.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.science_outlined,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const Text('Concrete Cube Tests',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              const SizedBox(height: 2),
              Text(
                widget.projectName,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              const Text('WR/EXE/05 — Testing of Concrete Cubes',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_results.length}',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15),
            ),
          ),
        ]),
      );

  Widget _buildCard(ConcreteCubeResultModel r, int index) {
    final avg7 = r.avg7Days;
    final avg28 = r.avg28Days;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Card header
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.06),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Row(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_accent, _accentLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(8),
              ),
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
                Text(r.uniqueNumber,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _accent)),
                if (r.firstDateOfTesting.isNotEmpty)
                  Text(
                    _fmtDate(r.firstDateOfTesting),
                    style:
                        const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Test #${r.resultNo}',
                style: const TextStyle(
                    fontSize: 10,
                    color: _accent,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),

        // Card body
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              _infoItem(Icons.layers_outlined, 'Grade', r.firstGrade),
              const SizedBox(width: 10),
              _infoItem(
                  Icons.location_on_outlined, 'Location', r.firstLocation),
              const SizedBox(width: 10),
              _infoItem(Icons.hourglass_bottom_outlined, 'Age of Cube',
                  r.firstAgeOfCube),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _strengthChip(
                label: '7-Day Avg',
                value: avg7 != null
                    ? '${avg7.toStringAsFixed(2)} N/mm²'
                    : 'N/A',
                color: avg7 != null
                    ? const Color(0xFF0891B2)
                    : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 10),
              _strengthChip(
                label: '28-Day Avg',
                value: avg28 != null
                    ? '${avg28.toStringAsFixed(2)} N/mm²'
                    : 'N/A',
                color: avg28 != null
                    ? const Color(0xFF059669)
                    : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 10),
              _infoItem(
                  Icons.list_alt_outlined, 'Entries', '${r.testData.length}'),
            ]),

            if (r.creator != null && r.creator!.name.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.account_circle_outlined,
                    size: 13, color: Color(0xFF94A3B8)),
                const SizedBox(width: 5),
                Text('Created by ${r.creator!.name}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF64748B))),
              ]),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),

            // ── Action buttons ────────────────────────────────────────
            Wrap(spacing: 8, runSpacing: 8, children: [
              _actionBtn(
                  label: 'View',
                  icon: Icons.visibility_outlined,
                  color: const Color(0xFF0EA5E9),
                  onTap: () => _openView(r)),
              _actionBtn(
                  label: 'Edit',
                  icon: Icons.edit_outlined,
                  color: const Color(0xFFF59E0B),
                  onTap: () => _openForm(existing: r)),

              // ── FIXED: now opens in-app print preview ──────────────
              _actionBtn(
                  label: 'Print',
                  icon: Icons.print_outlined,
                  color: const Color(0xFF22C55E),
                  onTap: () => _print(r)),

              // ── FIXED: now downloads PDF and opens with viewer ─────
              _actionBtn(
                  label: 'PDF',
                  icon: Icons.download_outlined,
                  color: const Color(0xFF8B5CF6),
                  onTap: () => _download(r)),

              _actionBtn(
                  label: 'Delete',
                  icon: Icons.delete_outline,
                  color: const Color(0xFFEF4444),
                  onTap: () => _confirmDelete(r)),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _infoItem(IconData icon, String label, String? value) => Expanded(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                (value != null && value.isNotEmpty) ? value : 'N/A',
                style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ]),
      );

  Widget _strengthChip(
          {required String label,
          required String value,
          required Color color}) =>
      Expanded(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 9,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3)),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(value,
                style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      );

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  Widget _buildEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.science_outlined, size: 56, color: _accent),
            ),
            const SizedBox(height: 20),
            const Text('No Concrete Cube Tests',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            const Text(
              'Tap the button below to create your first concrete cube test.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
          ]),
        ),
      );

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline,
                color: Color(0xFFEF4444), size: 48),
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF1E293B))),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadResults,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _accent, foregroundColor: Colors.white),
            ),
          ]),
        ),
      );
}