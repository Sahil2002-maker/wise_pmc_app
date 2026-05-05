// lib/features/concreting_checklist/presentation/concreting_checklist_page.dart

import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_saver/file_saver.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/utils/api_exception.dart';
import '../data/models/concreting_checklist_model.dart';
import 'concreting_checklist_form_page.dart';
import 'concreting_checklist_view_page.dart';

class ConcretingChecklistPage extends StatefulWidget {
  final int projectId;
  final String projectName;

  const ConcretingChecklistPage({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<ConcretingChecklistPage> createState() =>
      _ConcretingChecklistPageState();
}

class _ConcretingChecklistPageState extends State<ConcretingChecklistPage> {
  List<ConcretingChecklistModel> _checklists = [];
  bool _isLoading = true;
  String? _error;
  final Set<int> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _loadChecklists();
  }

  Future<void> _loadChecklists() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await ApiService.fetchConcretingChecklists(widget.projectId);

      if (!mounted) return;
      setState(() {
        _checklists = list;
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

  Future<void> _openForm({ConcretingChecklistModel? existing}) async {
    ConcretingChecklistModel? latest = existing;

    if (existing != null) {
      try {
        _setBusy(existing.id, true);
        latest = await ApiService.fetchConcretingChecklistForEdit(
          widget.projectId,
          existing.id,
        );
      } catch (e) {
        if (!mounted) return;
        _showSnack(
          e is ApiException ? e.message : 'Failed to load checklist for edit',
          isError: true,
        );
        _setBusy(existing.id, false);
        return;
      } finally {
        _setBusy(existing.id, false);
      }
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ConcretingChecklistFormPage(
          projectId: widget.projectId,
          projectName: widget.projectName,
          existing: latest,
        ),
        fullscreenDialog: true,
      ),
    );

    if (result == true) {
      await _loadChecklists();
    }
  }

  void _setBusy(int id, bool value) {
    if (!mounted) return;
    setState(() {
      if (value) {
        _busyIds.add(id);
      } else {
        _busyIds.remove(id);
      }
    });
  }

  bool _isBusy(int id) => _busyIds.contains(id);

  Future<void> _confirmDelete(ConcretingChecklistModel c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Delete Checklist',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text(
          'Delete checklist ${c.checklistNo}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      _setBusy(c.id, true);
      await ApiService.deleteConcretingChecklist(widget.projectId, c.id);

      if (!mounted) return;
      _showSnack('Checklist deleted successfully');
      await _loadChecklists();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error: $e', isError: true);
    } finally {
      _setBusy(c.id, false);
    }
  }

  void _openView(ConcretingChecklistModel c) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConcretingChecklistViewPage(
          checklist: c,
          projectName: widget.projectName,
        ),
      ),
    );
  }

  Future<void> _printChecklist(ConcretingChecklistModel c) async {
    try {
      _setBusy(c.id, true);

      final bytes = await ApiService.fetchConcretingChecklistPdfBytes(
        widget.projectId,
        c.id,
      );

      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'Concreting_${c.checklistNo.replaceAll('/', '_')}',
      );
    } catch (e) {
      if (!mounted) return;
      developer.log('Print error: $e', name: 'ConcretingChecklistPage');
      _showSnack(
        e is ApiException ? e.message : 'Unable to print checklist',
        isError: true,
      );
    } finally {
      _setBusy(c.id, false);
    }
  }

  Future<void> _downloadChecklist(ConcretingChecklistModel c) async {
  try {
    _setBusy(c.id, true);

    final bytes = await ApiService.fetchConcretingChecklistPdfBytes(
      widget.projectId,
      c.id,
    );

    final safeName = 'Concreting_${c.checklistNo.replaceAll('/', '_')}';

    await FileSaver.instance.saveFile(
      name: safeName,
      bytes: bytes,
      ext: 'pdf',
      mimeType: MimeType.pdf,
    );

    if (!mounted) return;
    _showSnack('Checklist PDF saved successfully');
  } catch (e) {
    if (!mounted) return;
    developer.log('Download error: $e', name: 'ConcretingChecklistPage');
    _showSnack(
      e is ApiException ? e.message : 'Unable to save checklist PDF',
      isError: true,
    );
  } finally {
    _setBusy(c.id, false);
  }
}

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? const Color(0xFFEF4444) : AppColors.primaryGreen,
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final d = DateTime.parse(dateStr);
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            )
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadChecklists,
                  color: AppColors.primaryGreen,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _buildHeader()),
                      _checklists.isEmpty
                          ? SliverFillRemaining(child: _buildEmpty())
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (_, i) => _buildCard(_checklists[i], i),
                                childCount: _checklists.length,
                              ),
                            ),
                      const SliverToBoxAdapter(child: SizedBox(height: 80)),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'New Checklist',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildHeader() => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primaryGreen.withValues(alpha: 0.2),
          ),
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
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.layers_outlined,
                color: AppColors.primaryGreen,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Concreting Checklist',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'WR/EXE/06 — ${widget.projectName}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_checklists.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildCard(ConcretingChecklistModel c, int index) => Container(
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
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.06),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
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
                          c.checklistNo,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        Text(
                          _formatDate(c.checklistDate),
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
                      color: const Color(0xFF064E3B).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Concreting',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF064E3B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _infoItem(Icons.location_on_outlined, 'Location', c.location),
                      const SizedBox(width: 16),
                      _infoItem(Icons.business_outlined, 'Part/Wing', c.partWing),
                      const SizedBox(width: 16),
                      _infoItem(
                        Icons.calendar_today_outlined,
                        'Date of Casting',
                        _formatDate(c.dateOfCasting),
                      ),
                    ],
                  ),
                  if (c.creator != null && c.creator!.name.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 13,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Created by ${c.creator!.name}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (c.testResults.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildTestSummaryRow(c.testResults),
                  ],
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _actionBtn(
                        label: 'View',
                        icon: Icons.visibility_outlined,
                        color: const Color(0xFF0EA5E9),
                        onTap: _isBusy(c.id) ? null : () => _openView(c),
                      ),
                      _actionBtn(
                        label: _isBusy(c.id) ? 'Loading...' : 'Edit',
                        icon: Icons.edit_outlined,
                        color: const Color(0xFFF59E0B),
                        onTap: _isBusy(c.id) ? null : () => _openForm(existing: c),
                      ),
                      _actionBtn(
                        label: _isBusy(c.id) ? 'Working...' : 'Print',
                        icon: Icons.print_outlined,
                        color: const Color(0xFF22C55E),
                        onTap: _isBusy(c.id) ? null : () => _printChecklist(c),
                      ),
                      _actionBtn(
                        label: _isBusy(c.id) ? 'Working...' : 'PDF',
                        icon: Icons.download_outlined,
                        color: const Color(0xFF8B5CF6),
                        onTap: _isBusy(c.id) ? null : () => _downloadChecklist(c),
                      ),
                      _actionBtn(
                        label: 'Delete',
                        icon: Icons.delete_outline,
                        color: const Color(0xFFEF4444),
                        onTap: _isBusy(c.id) ? null : () => _confirmDelete(c),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildTestSummaryRow(List<ConcretingTestResult> results) {
    final yes = results.where((r) => r.checkYes).length;
    final no = results.where((r) => r.checkNo).length;
    final pending = results.length - yes - no;

    return Row(
      children: [
        _summaryPill('$yes ✓', const Color(0xFF22C55E)),
        const SizedBox(width: 6),
        _summaryPill('$no ✗', const Color(0xFFEF4444)),
        const SizedBox(width: 6),
        _summaryPill('$pending —', const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Text(
          'of ${results.length} items',
          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
        ),
      ],
    );
  }

  Widget _summaryPill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _infoItem(IconData icon, String label, String? value) => Expanded(
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
                    value?.isNotEmpty == true ? value! : 'N/A',
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

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.5 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.layers_outlined,
                  size: 56,
                  color: AppColors.primaryGreen.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No Concreting Checklists',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap the button below to create your first concreting checklist.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
            ],
          ),
        ),
      );

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: Color(0xFFEF4444), size: 48),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadChecklists,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
}