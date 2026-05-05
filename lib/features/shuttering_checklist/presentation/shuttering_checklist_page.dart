// lib/features/shuttering_checklist/presentation/shuttering_checklist_page.dart

import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/utils/api_exception.dart';
import '../data/models/shuttering_checklist_model.dart';

class ShutteringChecklistPage extends StatefulWidget {
  final int projectId;
  final String projectName;

  const ShutteringChecklistPage({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<ShutteringChecklistPage> createState() =>
      _ShutteringChecklistPageState();
}

class _ShutteringChecklistPageState extends State<ShutteringChecklistPage> {
  List<ShutteringChecklistModel> _checklists = [];
  bool _isLoading = true;
  String? _error;

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
      final list = await ApiService.fetchShutteringChecklists(widget.projectId);
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

  Future<void> _openForm({ShutteringChecklistModel? existing}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _ShutteringChecklistFormPage(
          projectId: widget.projectId,
          projectName: widget.projectName,
          existing: existing,
        ),
        fullscreenDialog: true,
      ),
    );
    if (result == true) _loadChecklists();
  }

  Future<void> _confirmDelete(ShutteringChecklistModel c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Delete Checklist',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text(
          'Are you sure you want to delete checklist ${c.checklistNo}? This cannot be undone.',
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
      await ApiService.deleteShutteringChecklist(widget.projectId, c.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checklist deleted successfully'),
          backgroundColor: Color(0xFF22C55E),
        ),
      );
      _loadChecklists();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : 'Error: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  void _openView(ShutteringChecklistModel c) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ShutteringChecklistViewPage(
          checklist: c,
          projectName: widget.projectName,
        ),
      ),
    );
  }

  Future<void> _handlePrint(ShutteringChecklistModel c) async {
    final url = ApiService.shutteringChecklistPrintUrl(widget.projectId, c.id);
    developer.log('Print URL: $url', name: 'ShutteringChecklist');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text('Preparing print preview…'),
          ],
        ),
        duration: Duration(seconds: 60),
      ),
    );

    try {
      final html = await _fetchHtmlIgnoreSsl(url);

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      await Printing.layoutPdf(
        name: 'Shuttering_${c.checklistNo.replaceAll('/', '_')}',
        onLayout: (PdfPageFormat format) async {
          return await Printing.convertHtml(
            format: format,
            html: html,
          );
        },
      );
    } catch (e) {
      developer.log('Print error: $e', name: 'ShutteringChecklist');
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Print failed: $e'),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<String> _fetchHtmlIgnoreSsl(String url) async {
    final httpClient = HttpClient();
    httpClient.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      return true;
    };
    httpClient.connectionTimeout = const Duration(seconds: 30);

    final uri = Uri.parse(url);
    final request = await httpClient.getUrl(uri);

    final token = ApiService.authToken;
    if (token.isNotEmpty) {
      request.headers.set('Authorization', 'Bearer $token');
    }
    request.headers.set('Accept', 'text/html,application/xhtml+xml');

    final response = await request.close();

    if (response.statusCode == 200) {
      final bytes =
          await response.fold<List<int>>([], (buf, chunk) => buf..addAll(chunk));
      return String.fromCharCodes(bytes);
    }

    httpClient.close();
    throw Exception('Server returned HTTP ${response.statusCode}');
  }

  Future<void> _handleDownload(ShutteringChecklistModel c) async {
    final url =
        ApiService.shutteringChecklistDownloadUrl(widget.projectId, c.id);
    developer.log('Download URL: $url', name: 'ShutteringChecklist');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Preparing PDF…'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final bytes = await ApiService.downloadBytes(url);
      final dir = await getTemporaryDirectory();
      final filename = 'Shuttering_${c.checklistNo.replaceAll('/', '_')}.pdf';
      final file = File('${dir.path}/$filename');

      await file.writeAsBytes(bytes);
      await OpenFilex.open(file.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isError ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final clean = dateStr.length > 10 ? dateStr.substring(0, 10) : dateStr;
      final d = DateTime.parse(clean);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
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
              child:
                  CircularProgressIndicator(color: AppColors.primaryGreen),
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
                Icons.grid_on_outlined,
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
                    'Shuttering Checklist',
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
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
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

  Widget _buildCard(ShutteringChecklistModel c, int index) => Container(
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D4ED8).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Shuttering',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF1D4ED8),
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
                      _infoItem(
                        Icons.location_on_outlined,
                        'Location',
                        c.location,
                      ),
                      const SizedBox(width: 16),
                      _infoItem(Icons.business_outlined, 'Wing', c.wing),
                      const SizedBox(width: 16),
                      _infoItem(
                        Icons.layers_outlined,
                        'Slab Level',
                        c.slabLevel,
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
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _drawingBadge('HFL', c.hfl),
                      _drawingBadge('Level', c.level),
                      _drawingBadge('Shuttering', c.shuttering),
                      _drawingBadge('Reinforcement', c.reinforcement),
                      _drawingBadge('Electrical', c.electrical),
                      _drawingBadge('Plumbing', c.plumbing),
                      _drawingBadge('Architect', c.architect),
                    ],
                  ),
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
                        onTap: () => _openView(c),
                      ),
                      _actionBtn(
                        label: 'Edit',
                        icon: Icons.edit_outlined,
                        color: const Color(0xFFF59E0B),
                        onTap: () => _openForm(existing: c),
                      ),
                      _actionBtn(
                        label: 'Print',
                        icon: Icons.print_outlined,
                        color: const Color(0xFF22C55E),
                        onTap: () => _handlePrint(c),
                      ),
                      _actionBtn(
                        label: 'PDF',
                        icon: Icons.download_outlined,
                        color: const Color(0xFF8B5CF6),
                        onTap: () => _handleDownload(c),
                      ),
                      _actionBtn(
                        label: 'Delete',
                        icon: Icons.delete_outline,
                        color: const Color(0xFFEF4444),
                        onTap: () => _confirmDelete(c),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
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

  Widget _drawingBadge(String label, bool checked) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: checked
              ? const Color(0xFF22C55E).withValues(alpha: 0.12)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: checked
                ? const Color(0xFF22C55E).withValues(alpha: 0.4)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              checked ? Icons.check : Icons.close,
              size: 10,
              color: checked
                  ? const Color(0xFF22C55E)
                  : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: checked
                    ? const Color(0xFF166534)
                    : const Color(0xFF94A3B8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
                  Icons.grid_on_outlined,
                  size: 56,
                  color: AppColors.primaryGreen.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No Shuttering Checklists',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap the button below to create your first shuttering checklist.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13,
                ),
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
              const Icon(
                Icons.error_outline,
                color: Color(0xFFEF4444),
                size: 48,
              ),
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

// ═══════════════════════════════════════════════════════════════════════════
// View Page
// ═══════════════════════════════════════════════════════════════════════════

class _ShutteringChecklistViewPage extends StatelessWidget {
  final ShutteringChecklistModel checklist;
  final String projectName;

  const _ShutteringChecklistViewPage({
    required this.checklist,
    required this.projectName,
  });

  String _fmtDate(String? d) {
    if (d == null || d.isEmpty) return 'N/A';
    try {
      final clean = d.length > 10 ? d.substring(0, 10) : d;
      final dt = DateTime.parse(clean);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return d;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Shuttering Checklist',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            Text(
              checklist.checklistNo,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionCard(
              title: 'WR/EXE/06 — Checklist for Shuttering',
              icon: Icons.grid_on_outlined,
              children: [
                _row2(
                  'Checklist No.',
                  checklist.checklistNo,
                  'Date',
                  _fmtDate(checklist.checklistDate),
                ),
                const SizedBox(height: 10),
                _infoRow('Project', projectName),
                const SizedBox(height: 8),
                _row2('Location', checklist.location, 'Part / Wing', checklist.wing),
                const SizedBox(height: 8),
                _infoRow('Date of Casting', _fmtDate(checklist.castingDate)),
              ],
            ),
            const SizedBox(height: 12),
            _sectionCard(
              title: 'Drawings Available',
              icon: Icons.check_box_outlined,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _badge('HFL', checklist.hfl),
                    _badge('Level', checklist.level),
                    _badge('Shuttering', checklist.shuttering),
                    _badge('Reinforcement', checklist.reinforcement),
                    _badge('Electrical', checklist.electrical),
                    _badge('Plumbing', checklist.plumbing),
                    _badge('Architect', checklist.architect),
                  ],
                ),
                const SizedBox(height: 12),
                _row2('RCC', checklist.rcc, 'Electrical', checklist.electricalDetail),
                const SizedBox(height: 8),
                _row2('Plumbing', checklist.plumbingDetail, 'Architect', checklist.architectDetail),
              ],
            ),
            const SizedBox(height: 12),
            _sectionCard(
              title: 'Checklist Items',
              icon: Icons.list_alt_outlined,
              children: [
                if (checklist.testResults.isEmpty)
                  const Text(
                    'No checklist items recorded.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Table(
                      border: TableBorder.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                      columnWidths: const {
                        0: FixedColumnWidth(32),
                        1: FlexColumnWidth(4),
                        2: FixedColumnWidth(56),
                        3: FlexColumnWidth(2),
                      },
                      children: [
                        const TableRow(
                          decoration: BoxDecoration(color: Color(0xFFF1F5F9)),
                          children: [
                            _StaticTh('SR'),
                            _StaticTh('PARTICULARS'),
                            _StaticTh('CHECK'),
                            _StaticTh('REMARK'),
                          ],
                        ),
                        ...checklist.testResults.map(
                          (t) => TableRow(
                            children: [
                              _td(t.srNo.toUpperCase()),
                              _tdLeft(t.particulars),
                              _tdCheck(t.check),
                              _tdLeft(t.remark),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (checklist.additionalObservations?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              _sectionCard(
                title: 'Additional Observations',
                icon: Icons.notes_outlined,
                children: [
                  Text(
                    checklist.additionalObservations!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1E293B),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: const [
                        SizedBox(height: 40),
                        Divider(color: Color(0xFF1E293B)),
                        Text(
                          'Contractor Representative',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: const [
                        SizedBox(height: 40),
                        Divider(color: Color(0xFF1E293B)),
                        Text(
                          'Project Engineer / Client',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 15, color: AppColors.primaryGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryGreen,
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
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row2(String l1, String? v1, String l2, String? v2) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _infoRow(l1, v1)),
          const SizedBox(width: 12),
          Expanded(child: _infoRow(l2, v2)),
        ],
      );

  Widget _infoRow(String label, String? value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value?.isNotEmpty == true ? value! : 'N/A',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );

  Widget _badge(String label, bool active) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF22C55E).withValues(alpha: 0.12)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active
                ? const Color(0xFF22C55E).withValues(alpha: 0.5)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? Icons.check_circle : Icons.cancel,
              size: 12,
              color: active
                  ? const Color(0xFF22C55E)
                  : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: active
                    ? const Color(0xFF166534)
                    : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      );

  Widget _td(String text) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF1E293B),
          ),
        ),
      );

  Widget _tdLeft(String text) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF1E293B),
          ),
        ),
      );

  Widget _tdCheck(String? check) {
    Color color;
    String label;
    IconData icon;

    if (check == 'yes') {
      color = const Color(0xFF22C55E);
      label = 'Yes';
      icon = Icons.check_circle;
    } else if (check == 'no') {
      color = const Color(0xFFEF4444);
      label = 'No';
      icon = Icons.cancel;
    } else {
      color = const Color(0xFF94A3B8);
      label = '—';
      icon = Icons.remove;
    }

    return Padding(
      padding: const EdgeInsets.all(6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 10, color: color),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaticTh extends StatelessWidget {
  final String text;

  const _StaticTh(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF475569),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Form Page (Create / Edit)
// ═══════════════════════════════════════════════════════════════════════════

class _ShutteringChecklistFormPage extends StatefulWidget {
  final int projectId;
  final String projectName;
  final ShutteringChecklistModel? existing;

  const _ShutteringChecklistFormPage({
    required this.projectId,
    required this.projectName,
    this.existing,
  });

  @override
  State<_ShutteringChecklistFormPage> createState() =>
      _ShutteringChecklistFormPageState();
}

class _ShutteringChecklistFormPageState
    extends State<_ShutteringChecklistFormPage> {
  final _scrollCtrl = ScrollController();

  String _checklistNo = '';
  DateTime? _checklistDate;
  DateTime? _castingDate;

  final _locationCtrl = TextEditingController();
  final _wingCtrl = TextEditingController();
  final _slabLevelCtrl = TextEditingController();
  final _areaOfSlabCtrl = TextEditingController();
  final _typeOfShutteringCtrl = TextEditingController();
  final _contractorCtrl = TextEditingController();
  final _rccCtrl = TextEditingController();
  final _electricalDetailCtrl = TextEditingController();
  final _plumbingDetailCtrl = TextEditingController();
  final _architectDetailCtrl = TextEditingController();
  final _observationsCtrl = TextEditingController();

  bool _hfl = false, _level = false, _shuttering = false;
  bool _reinforcement = false, _electrical = false;
  bool _plumbing = false, _architect = false;

  late List<_TestRow> _testRows;
  bool _isSaving = false;
  bool _isLoadingNo = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _initTestRows();
    if (_isEditing) {
      _populateFromExisting();
    } else {
      _checklistDate = DateTime.now();
      _loadChecklistNumber();
    }
  }

  void _initTestRows() {
    _testRows = kShutteringParticulars
        .map(
          (p) => _TestRow(
            srNo: p['sr_no']!,
            particulars: p['particulars']!,
            check: null,
            remarkCtrl: TextEditingController(),
          ),
        )
        .toList();
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final clean = raw.length > 10 ? raw.substring(0, 10) : raw;
      return DateTime.parse(clean);
    } catch (_) {
      return null;
    }
  }

  void _populateFromExisting() {
    final c = widget.existing!;
    _checklistNo = c.checklistNo;
    _checklistDate = _parseDate(c.checklistDate) ?? DateTime.now();
    _castingDate = _parseDate(c.castingDate);

    _locationCtrl.text = c.location ?? '';
    _wingCtrl.text = c.wing ?? '';
    _slabLevelCtrl.text = c.slabLevel ?? '';
    _areaOfSlabCtrl.text = c.areaOfSlab ?? '';
    _typeOfShutteringCtrl.text = c.typeOfShuttering ?? '';
    _contractorCtrl.text = c.contractor ?? '';
    _rccCtrl.text = c.rcc ?? '';
    _electricalDetailCtrl.text = c.electricalDetail ?? '';
    _plumbingDetailCtrl.text = c.plumbingDetail ?? '';
    _architectDetailCtrl.text = c.architectDetail ?? '';
    _observationsCtrl.text = c.additionalObservations ?? '';

    _hfl = c.hfl;
    _level = c.level;
    _shuttering = c.shuttering;
    _reinforcement = c.reinforcement;
    _electrical = c.electrical;
    _plumbing = c.plumbing;
    _architect = c.architect;

    for (int i = 0; i < _testRows.length && i < c.testResults.length; i++) {
      _testRows[i].check = c.testResults[i].check;
      _testRows[i].remarkCtrl.text = c.testResults[i].remark;
    }
  }

  Future<void> _loadChecklistNumber() async {
    if (!mounted) return;
    setState(() => _isLoadingNo = true);
    try {
      final no =
          await ApiService.generateShutteringChecklistNumber(widget.projectId);
      if (mounted) setState(() => _checklistNo = no);
    } catch (_) {}
    if (mounted) setState(() => _isLoadingNo = false);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _locationCtrl.dispose();
    _wingCtrl.dispose();
    _slabLevelCtrl.dispose();
    _areaOfSlabCtrl.dispose();
    _typeOfShutteringCtrl.dispose();
    _contractorCtrl.dispose();
    _rccCtrl.dispose();
    _electricalDetailCtrl.dispose();
    _plumbingDetailCtrl.dispose();
    _architectDetailCtrl.dispose();
    _observationsCtrl.dispose();
    for (final r in _testRows) {
      r.remarkCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(bool isCasting) async {
    final initial =
        isCasting ? (_castingDate ?? DateTime.now()) : (_checklistDate ?? DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: AppColors.primaryGreen),
        ),
        child: child!,
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        if (isCasting) {
          _castingDate = picked;
        } else {
          _checklistDate = picked;
        }
      });
    }
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return 'Select date';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (_isSaving) return;
    if (_checklistDate == null) {
      _showError('Please select a checklist date.');
      return;
    }

    setState(() => _isSaving = true);

    final testResults = _testRows
        .map(
          (r) => {
            'sr_no': r.srNo,
            'particulars': r.particulars,
            'check': r.check,
            'remark': r.remarkCtrl.text.trim(),
          },
        )
        .toList();

    try {
      if (_isEditing) {
        await ApiService.updateShutteringChecklist(
          projectId: widget.projectId,
          id: widget.existing!.id,
          checklistDate: _isoDate(_checklistDate!),
          location: _locationCtrl.text.trim(),
          wing: _wingCtrl.text.trim(),
          castingDate: _castingDate != null ? _isoDate(_castingDate!) : null,
          slabLevel: _slabLevelCtrl.text.trim(),
          areaOfSlab: _areaOfSlabCtrl.text.trim(),
          typeOfShuttering: _typeOfShutteringCtrl.text.trim(),
          contractor: _contractorCtrl.text.trim(),
          hfl: _hfl,
          level: _level,
          shuttering: _shuttering,
          reinforcement: _reinforcement,
          electrical: _electrical,
          plumbing: _plumbing,
          architect: _architect,
          rcc: _rccCtrl.text.trim(),
          electricalDetail: _electricalDetailCtrl.text.trim(),
          plumbingDetail: _plumbingDetailCtrl.text.trim(),
          architectDetail: _architectDetailCtrl.text.trim(),
          testResults: testResults,
          additionalObservations: _observationsCtrl.text.trim(),
        );
      } else {
        await ApiService.createShutteringChecklist(
          projectId: widget.projectId,
          checklistNo: _checklistNo,
          checklistDate: _isoDate(_checklistDate!),
          location: _locationCtrl.text.trim(),
          wing: _wingCtrl.text.trim(),
          castingDate: _castingDate != null ? _isoDate(_castingDate!) : null,
          slabLevel: _slabLevelCtrl.text.trim(),
          areaOfSlab: _areaOfSlabCtrl.text.trim(),
          typeOfShuttering: _typeOfShutteringCtrl.text.trim(),
          contractor: _contractorCtrl.text.trim(),
          hfl: _hfl,
          level: _level,
          shuttering: _shuttering,
          reinforcement: _reinforcement,
          electrical: _electrical,
          plumbing: _plumbing,
          architect: _architect,
          rcc: _rccCtrl.text.trim(),
          electricalDetail: _electricalDetailCtrl.text.trim(),
          plumbingDetail: _plumbingDetailCtrl.text.trim(),
          architectDetail: _architectDetailCtrl.text.trim(),
          testResults: testResults,
          additionalObservations: _observationsCtrl.text.trim(),
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Checklist updated successfully!'
                : 'Checklist created successfully!',
          ),
          backgroundColor: AppColors.primaryGreen,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showError(e is ApiException ? e.message : e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFEF4444),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing
                  ? 'Edit Shuttering Checklist'
                  : 'New Shuttering Checklist',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            Text(
              widget.projectName,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _isSaving ? null : _submit,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _isEditing ? 'Update' : 'Save',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          SliverToBoxAdapter(child: _buildBasicInfoSection()),
          SliverToBoxAdapter(child: _buildDrawingsSection()),
          SliverToBoxAdapter(child: _buildChecklistTableSection()),
          SliverToBoxAdapter(child: _buildObservationsSection()),
          SliverToBoxAdapter(child: _buildSignatureSection()),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection() => _card(
        title: 'Basic Information',
        icon: Icons.info_outline,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Checklist No.'),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _isLoadingNo ? 'Generating…' : _checklistNo,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _isLoadingNo
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            if (_isLoadingNo)
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Date *'),
                      _datePicker(
                        value: _checklistDate,
                        hint: 'Select date',
                        onTap: () => _pickDate(false),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _label('Project Name'),
            _readOnlyField(widget.projectName),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _inputField(
                    _locationCtrl,
                    'Location',
                    hint: 'Enter location',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _inputField(
                    _wingCtrl,
                    'Part / Wing',
                    hint: 'Enter wing',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Date of Casting'),
                      _datePicker(
                        value: _castingDate,
                        hint: 'Optional',
                        onTap: () => _pickDate(true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _inputField(
                    _slabLevelCtrl,
                    'Slab Level',
                    hint: 'e.g. GF Slab',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _inputField(
                    _areaOfSlabCtrl,
                    'Area of Slab',
                    hint: 'sq. m',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _inputField(
                    _typeOfShutteringCtrl,
                    'Type of Shuttering',
                    hint: 'e.g. Conventional',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _inputField(
                    _contractorCtrl,
                    'Contractor',
                    hint: 'Contractor name',
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _buildDrawingsSection() => _card(
        title: 'Drawings Available',
        icon: Icons.check_box_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _checkbox(
                        'HFL. Reference point.',
                        _hfl,
                        (v) => setState(() => _hfl = v),
                      ),
                      _checkbox(
                        'Level',
                        _level,
                        (v) => setState(() => _level = v),
                      ),
                      _checkbox(
                        'Shuttering',
                        _shuttering,
                        (v) => setState(() => _shuttering = v),
                      ),
                      _checkbox(
                        'Reinforcement',
                        _reinforcement,
                        (v) => setState(() => _reinforcement = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    children: [
                      _checkbox(
                        'Electrical',
                        _electrical,
                        (v) => setState(() => _electrical = v),
                      ),
                      _checkbox(
                        'Plumbing',
                        _plumbing,
                        (v) => setState(() => _plumbing = v),
                      ),
                      _checkbox(
                        'Architect',
                        _architect,
                        (v) => setState(() => _architect = v),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 14),
            _label('Drawing Details'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _inputField(
                    _rccCtrl,
                    'RCC',
                    hint: 'RCC drawing no.',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _inputField(
                    _electricalDetailCtrl,
                    'Electrical',
                    hint: 'Electrical drawing no.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _inputField(
                    _plumbingDetailCtrl,
                    'Plumbing',
                    hint: 'Plumbing drawing no.',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _inputField(
                    _architectDetailCtrl,
                    'Architect',
                    hint: 'Architect drawing no.',
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _buildChecklistTableSection() => _card(
        title: 'Checklist Particulars',
        icon: Icons.list_alt_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      'SR',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    flex: 4,
                    child: Text(
                      'PARTICULARS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  SizedBox(
                    width: 72,
                    child: Text(
                      'CHECK',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  SizedBox(
                    width: 90,
                    child: Text(
                      'REMARK',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            ..._testRows.map(
              (row) => Container(
                margin: const EdgeInsets.symmetric(vertical: 3),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 28,
                      child: Center(
                        child: Text(
                          row.srNo.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: Text(
                        row.particulars,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF1E293B),
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 72,
                      child: Column(
                        children: [
                          _radioCheck(
                            'Yes',
                            'yes',
                            row.check,
                            (v) => setState(() => row.check = v),
                          ),
                          const SizedBox(height: 4),
                          _radioCheck(
                            'No',
                            'no',
                            row.check,
                            (v) => setState(() => row.check = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: row.remarkCtrl,
                        decoration: InputDecoration(
                          hintText: 'Remark',
                          hintStyle: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFCBD5E1),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(
                              color: AppColors.primaryGreen,
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          isDense: true,
                        ),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildObservationsSection() => _card(
        title: 'Additional Observations',
        icon: Icons.notes_outlined,
        child: TextField(
          controller: _observationsCtrl,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Enter any additional observations (optional)…',
            hintStyle: const TextStyle(
              fontSize: 13,
              color: Color(0xFFCBD5E1),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: AppColors.primaryGreen,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF1E293B),
          ),
        ),
      );

  Widget _buildSignatureSection() => _card(
        title: 'Signatures',
        icon: Icons.draw_outlined,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 48),
                  Divider(color: AppColors.primaryGreen),
                  const Text(
                    'Contractor Representative',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Date:',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 48),
                  Divider(color: AppColors.primaryGreen),
                  const Text(
                    'Project Engineer / Client',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Date:',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _card({
    required String title,
    required IconData icon,
    required Widget child,
  }) =>
      Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primaryGreen.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                  Icon(icon, size: 15, color: AppColors.primaryGreen),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: child,
            ),
          ],
        ),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
      );

  Widget _readOnlyField(String value) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
          ),
        ),
      );

  Widget _inputField(
    TextEditingController ctrl,
    String label, {
    String? hint,
    TextInputType? type,
    int maxLines = 1,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          TextField(
            controller: ctrl,
            keyboardType: type,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                fontSize: 13,
                color: Color(0xFFCBD5E1),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: AppColors.primaryGreen,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 11,
              ),
              isDense: true,
            ),
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      );

  Widget _datePicker({
    required DateTime? value,
    required String hint,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value != null ? _fmtDate(value) : hint,
                  style: TextStyle(
                    fontSize: 13,
                    color: value != null
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFCBD5E1),
                  ),
                ),
              ),
              Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: value != null
                    ? AppColors.primaryGreen
                    : const Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      );

  Widget _checkbox(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) =>
      GestureDetector(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: value ? AppColors.primaryGreen : Colors.white,
                  border: Border.all(
                    color: value
                        ? AppColors.primaryGreen
                        : const Color(0xFFD1D5DB),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: value
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _radioCheck(
    String label,
    String value,
    String? groupValue,
    ValueChanged<String?> onChanged,
  ) {
    final selected = groupValue == value;
    final color =
        value == 'yes' ? const Color(0xFF22C55E) : const Color(0xFFEF4444);

    return GestureDetector(
      onTap: () => onChanged(selected ? null : value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.white,
          border: Border.all(
            color: selected ? color : const Color(0xFFE2E8F0),
          ),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected
                  ? (value == 'yes'
                      ? Icons.check_circle
                      : Icons.cancel)
                  : Icons.radio_button_unchecked,
              size: 12,
              color: selected ? color : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: selected ? color : const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TestRow {
  final String srNo;
  final String particulars;
  String? check;
  final TextEditingController remarkCtrl;

  _TestRow({
    required this.srNo,
    required this.particulars,
    required this.check,
    required this.remarkCtrl,
  });
}