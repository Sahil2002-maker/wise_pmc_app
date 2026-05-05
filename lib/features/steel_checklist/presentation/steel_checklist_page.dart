// lib/features/steel_checklist/presentation/steel_checklist_page.dart
//
// Full CRUD page for Steel Checklist — UI layout now mirrors Shuttering Checklist.
// Tests 01-10 with a special "Weight per meter" sub-table for test 03.
//
// FIXES applied
// ─────────────
// 1. Print / Download: API returns base64-encoded bytes which are decoded,
//    written to the device's temp directory, and opened via open_filex (PDF)
//    or a WebView bottom-sheet (print HTML).
//
// 2. Edit position / serial: list is re-fetched silently after every mutating
//    operation AND the local list is updated in-place.
//
// 3. UPDATE FIX: LiteSpeed blocks raw PUT/PATCH at the server level.
//    Updates are sent as POST with _method=PATCH (Laravel method spoofing).

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_storage_service.dart';
import '../data/models/steel_checklist_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page entry-point
// ─────────────────────────────────────────────────────────────────────────────

class SteelChecklistPage extends StatefulWidget {
  final int projectId;
  final String projectName;

  const SteelChecklistPage({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<SteelChecklistPage> createState() => _SteelChecklistPageState();
}

class _SteelChecklistPageState extends State<SteelChecklistPage> {
  List<SteelChecklistModel> _checklists = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  Future<Map<String, String>> _headers() async {
    final token = await AuthStorageService.getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  dynamic _decode(String body) {
    if (body.isEmpty) return {};
    try {
      return jsonDecode(body);
    } catch (_) {
      return {'message': body};
    }
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

  // ── load list ──────────────────────────────────────────────────────────────

  Future<void> _load({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() { _isLoading = true; _error = null; });
    try {
      final url = Uri.parse(ApiConstants.steelChecklistIndex(widget.projectId));
      final res = await http
          .get(url, headers: await _headers())
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;
      final body = _decode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final raw = body['checklists'];
        setState(() {
          _checklists = raw is List
              ? raw
                  .whereType<Map>()
                  .map((e) => SteelChecklistModel.fromJson(
                      Map<String, dynamic>.from(e)))
                  .toList()
              : [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = (body is Map ? body['message']?.toString() : null) ??
              'Failed to load (${res.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  // ── generate checklist number ──────────────────────────────────────────────

  Future<String> _generateNumber() async {
    final url = Uri.parse(ApiConstants.steelChecklistCreate(widget.projectId));
    final res = await http
        .get(url, headers: await _headers())
        .timeout(const Duration(seconds: 20));
    final body = _decode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body['checklist_no']?.toString() ?? '';
    }
    return '';
  }

  // ── open create / edit modal ───────────────────────────────────────────────

  void _openForm({SteelChecklistModel? checklist}) async {
    String checklistNo = checklist?.checklistNo ?? '';
    if (checklist == null) {
      try {
        checklistNo = await _generateNumber();
      } catch (_) {}
    }
    if (!mounted) return;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SteelChecklistForm(
        projectId: widget.projectId,
        projectName: widget.projectName,
        checklist: checklist,
        prefilledChecklistNo: checklistNo,
        headers: _headers,
        decode: _decode,
      ),
    );

    if (saved == true) {
      _load(silent: true);
    }
  }

  // ── delete ─────────────────────────────────────────────────────────────────

  void _confirmDelete(SteelChecklistModel c) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Delete Checklist',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text(
            'Are you sure you want to delete ${c.checklistNo}? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _delete(c.id);
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Delete',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(int id) async {
    try {
      final url = Uri.parse(
          ApiConstants.steelChecklistDestroy(widget.projectId, id));

      final res = await http
          .post(
            url,
            headers: await _headers(),
            body: jsonEncode({'_method': 'DELETE'}),
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;
      if (res.statusCode >= 200 && res.statusCode < 300) {
        setState(() => _checklists.removeWhere((c) => c.id == id));
        _snack('Checklist deleted successfully', success: true);
      } else {
        final body = _decode(res.body);
        _snack((body is Map ? body['message']?.toString() : null) ??
            'Delete failed');
      }
    } catch (e) {
      _snack('Error: $e');
    }
  }

  // ── Print ──────────────────────────────────────────────────────────────────

  Future<void> _handlePrint(SteelChecklistModel c) async {
    _snack('Preparing print…');
    try {
      final url = Uri.parse(
          ApiConstants.steelChecklistPrint(widget.projectId, c.id));
      final res = await http
          .get(url, headers: await _headers())
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;

      final body = _decode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final htmlB64 = body['html']?.toString() ?? '';
        if (htmlB64.isEmpty) {
          _snack('Empty print response from server');
          return;
        }
        final htmlContent = utf8.decode(base64Decode(htmlB64));
        _openHtmlViewer(htmlContent, title: 'Print — ${c.checklistNo}');
      } else {
        _snack((body is Map ? body['message']?.toString() : null) ??
            'Print failed (${res.statusCode})');
      }
    } catch (e) {
      _snack('Print error: $e');
    }
  }

  void _openHtmlViewer(String html, {required String title}) {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HtmlViewerSheet(html: html, title: title),
    );
  }

  // ── Download ───────────────────────────────────────────────────────────────

  Future<void> _handleDownload(SteelChecklistModel c) async {
    _snack('Downloading PDF…');
    try {
      final url = Uri.parse(
          ApiConstants.steelChecklistDownload(widget.projectId, c.id));
      final res = await http
          .get(url, headers: await _headers())
          .timeout(const Duration(seconds: 60));
      if (!mounted) return;

      final body = _decode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final pdfB64 = body['pdf']?.toString() ?? '';
        final filename = body['filename']?.toString() ??
            'Steel_Checklist_${c.checklistNo.replaceAll('/', '_')}.pdf';

        if (pdfB64.isEmpty) {
          _snack('Empty PDF response from server');
          return;
        }

        final pdfBytes = base64Decode(pdfB64);
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$filename');
        await file.writeAsBytes(pdfBytes, flush: true);

        final result = await OpenFilex.open(file.path, type: 'application/pdf');
        if (result.type != ResultType.done && mounted) {
          _snack('Could not open PDF: ${result.message}');
        }
      } else {
        _snack((body is Map ? body['message']?.toString() : null) ??
            'Download failed (${res.statusCode})');
      }
    } catch (e) {
      _snack('Download error: $e');
    }
  }

  // ── snack helper ───────────────────────────────────────────────────────────

  void _snack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          success ? AppColors.primaryGreen : const Color(0xFFEF4444),
    ));
  }

  // ── view detail ────────────────────────────────────────────────────────────

  void _openView(SteelChecklistModel c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SteelChecklistViewSheet(
        checklist: c,
        projectName: widget.projectName,
      ),
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────

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
                  onRefresh: _load,
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

  // ── header card ────────────────────────────────────────────────────────────

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
                Icons.assignment_outlined,
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
                    'Steel Checklist',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'WR/EXE/05 — ${widget.projectName}',
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

  // ── checklist card ─────────────────────────────────────────────────────────

  Widget _buildCard(SteelChecklistModel c, int index) => Container(
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
            // ── card header ──────────────────────────────────────────────────
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
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D4ED8).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Steel',
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

            // ── card body ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _infoItem(
                          Icons.category_outlined, 'Material', c.material),
                      const SizedBox(width: 16),
                      _infoItem(
                          Icons.numbers_outlined, 'Quantity', c.quantity),
                      const SizedBox(width: 16),
                      _infoItem(Icons.local_shipping_outlined, 'Supplied By',
                          c.suppliedBy),
                    ],
                  ),
                  if (c.creatorName != 'N/A') ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.person_outline,
                            size: 13, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 5),
                        Text(
                          'Created by ${c.creatorName}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
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
                        onTap: () => _openView(c),
                      ),
                      _actionBtn(
                        label: 'Edit',
                        icon: Icons.edit_outlined,
                        color: const Color(0xFFF59E0B),
                        onTap: () => _openForm(checklist: c),
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

  // ── empty state ────────────────────────────────────────────────────────────

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
                  Icons.assignment_outlined,
                  size: 56,
                  color: AppColors.primaryGreen.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No Steel Checklists',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap the button below to create your first steel checklist.',
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

  // ── error state ────────────────────────────────────────────────────────────

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
                onPressed: _load,
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

// ─────────────────────────────────────────────────────────────────────────────
// In-app HTML viewer (for print preview)
// ─────────────────────────────────────────────────────────────────────────────

class _HtmlViewerSheet extends StatefulWidget {
  final String html;
  final String title;

  const _HtmlViewerSheet({required this.html, required this.title});

  @override
  State<_HtmlViewerSheet> createState() => _HtmlViewerSheetState();
}

class _HtmlViewerSheetState extends State<_HtmlViewerSheet> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(widget.html);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(children: [
            Expanded(
              child: Text(widget.title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8)),
                child:
                    const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ]),
        ),
        Expanded(child: WebViewWidget(controller: _controller)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// View sheet (read-only) — matches Shuttering view style
// ─────────────────────────────────────────────────────────────────────────────

class _SteelChecklistViewSheet extends StatelessWidget {
  final SteelChecklistModel checklist;
  final String projectName;

  const _SteelChecklistViewSheet({
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        // ── sheet header ───────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text(
                  'Steel Checklist',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  checklist.checklistNo,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12),
                ),
              ]),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8)),
                child:
                    const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ]),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Basic info section
              _sectionCard(
                context: context,
                title: 'WR/EXE/05 — Checklist for Steel',
                icon: Icons.assignment_outlined,
                children: [
                  _row2('Checklist No.', checklist.checklistNo, 'Date',
                      _fmtDate(checklist.checklistDate)),
                  const SizedBox(height: 10),
                  _infoRow('Project', projectName),
                  const SizedBox(height: 8),
                  _row2('Material', checklist.material, 'Quantity',
                      checklist.quantity),
                  const SizedBox(height: 8),
                  _infoRow('Supplied By', checklist.suppliedBy),
                  const SizedBox(height: 8),
                  _row2('Challan No.', checklist.challanNo ?? 'N/A',
                      'Challan Date',
                      _fmtDate(checklist.challanDate)),
                  const SizedBox(height: 8),
                  _row2('Trade Mark', checklist.tradeMark ?? 'N/A',
                      'Test Taken By',
                      checklist.testTakenBy ?? 'N/A'),
                ],
              ),
              const SizedBox(height: 12),

              // Tests section
              _sectionCard(
                context: context,
                title: 'Test Results',
                icon: Icons.science_outlined,
                children: [
                  if (checklist.testResults.isEmpty)
                    const Text(
                      'No test results recorded.',
                      style: TextStyle(
                          color: Color(0xFF94A3B8), fontSize: 13),
                    )
                  else
                    _testsTable(context),
                ],
              ),
              const SizedBox(height: 12),

              // Signatures
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(child: _sigBox('Contractor')),
                    const SizedBox(width: 20),
                    Expanded(child: _sigBox('CONSULTANT')),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _sectionCard({
    required BuildContext context,
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
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
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

  Widget _testsTable(BuildContext context) {
    final tests = checklist.testResults;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(children: [
          SizedBox(
              width: 32,
              child: Text('SR.',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569)))),
          Expanded(
              flex: 2,
              child: Text('TEST TAKEN',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569)))),
          Expanded(
              flex: 2,
              child: Text('RESULT OBTAINED',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569)))),
        ]),
      ),
      const SizedBox(height: 4),
      ...tests.asMap().entries.map((e) {
        final idx = e.key;
        final test = e.value;
        final testName = test['test_name']?.toString() ?? '';
        final result = test['result']?.toString() ?? '';
        final weightTable = test['weight_table'];

        return Container(
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
              width: 32,
              child: Text(
                (idx + 1).toString().padLeft(2, '0'),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryGreen),
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(testName,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B))),
                if (weightTable is List &&
                    (weightTable as List).isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _buildWeightTableView(
                      List<Map<String, dynamic>>.from(
                          (weightTable as List)
                              .whereType<Map>()
                              .map((e) =>
                                  Map<String, dynamic>.from(e)))),
                ],
              ]),
            ),
            Expanded(
              flex: 2,
              child: Text(
                  weightTable is List ? '' : result,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF334155))),
            ),
          ]),
        );
      }),
    ]);
  }

  Widget _buildWeightTableView(List<Map<String, dynamic>> rows) {
    return Table(
      border: TableBorder.all(color: const Color(0xFFE2E8F0)),
      columnWidths: const {
        0: FlexColumnWidth(0.6),
        1: FlexColumnWidth(0.8),
        2: FlexColumnWidth(1.2),
        3: FlexColumnWidth(1.2),
        4: FlexColumnWidth(1.0),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
          children: [
            _wCell('SR.', bold: true),
            _wCell('SIZE', bold: true),
            _wCell('THEO. (kg/m)', bold: true),
            _wCell('ACTUAL (kg/m)', bold: true),
            _wCell('DIFF.', bold: true),
          ],
        ),
        ...rows.map((r) => TableRow(children: [
              _wCell(r['sr_no']?.toString() ?? ''),
              _wCell(r['size']?.toString() ?? ''),
              _wCell(r['theoretical']?.toString() ?? ''),
              _wCell(r['actual']?.toString() ?? ''),
              _wCell(r['diff']?.toString() ?? ''),
            ])),
      ],
    );
  }

  Widget _wCell(String text, {bool bold = false}) => Padding(
        padding: const EdgeInsets.all(4),
        child: Text(text,
            style: TextStyle(
                fontSize: 10,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                color: const Color(0xFF1E293B))),
      );

  Widget _sigBox(String label) => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Divider(color: AppColors.primaryGreen),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Date:',
            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Weight table row model (for test 03)
// ─────────────────────────────────────────────────────────────────────────────

class _WeightRow {
  final TextEditingController srNo;
  final TextEditingController size;
  final TextEditingController theoretical;
  final TextEditingController actual;
  final TextEditingController diff;

  _WeightRow()
      : srNo = TextEditingController(),
        size = TextEditingController(),
        theoretical = TextEditingController(),
        actual = TextEditingController(),
        diff = TextEditingController();

  factory _WeightRow.fromMap(Map<String, dynamic> m) {
    final r = _WeightRow();
    r.srNo.text = m['sr_no']?.toString() ?? '';
    r.size.text = m['size']?.toString() ?? '';
    r.theoretical.text = m['theoretical']?.toString() ?? '';
    r.actual.text = m['actual']?.toString() ?? '';
    r.diff.text = m['diff']?.toString() ?? '';
    return r;
  }

  Map<String, dynamic> toMap() => {
        'sr_no': srNo.text.trim(),
        'size': size.text.trim(),
        'theoretical': theoretical.text.trim(),
        'actual': actual.text.trim(),
        'diff': diff.text.trim(),
      };

  void dispose() {
    srNo.dispose();
    size.dispose();
    theoretical.dispose();
    actual.dispose();
    diff.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Create / Edit form sheet
// ─────────────────────────────────────────────────────────────────────────────

class _SteelChecklistForm extends StatefulWidget {
  final int projectId;
  final String projectName;
  final SteelChecklistModel? checklist;
  final String prefilledChecklistNo;
  final Future<Map<String, String>> Function() headers;
  final dynamic Function(String) decode;

  const _SteelChecklistForm({
    required this.projectId,
    required this.projectName,
    required this.checklist,
    required this.prefilledChecklistNo,
    required this.headers,
    required this.decode,
  });

  @override
  State<_SteelChecklistForm> createState() => _SteelChecklistFormState();
}

class _SteelChecklistFormState extends State<_SteelChecklistForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool get _isEdit => widget.checklist != null;

  final _checklistNoCtrl = TextEditingController();
  final _checklistDateCtrl = TextEditingController();
  final _materialCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _suppliedByCtrl = TextEditingController();
  final _challanNoCtrl = TextEditingController();
  final _challanDateCtrl = TextEditingController();
  final _tradeMarkCtrl = TextEditingController();
  final _testTakenByCtrl = TextEditingController();

  late final List<TextEditingController> _testResultCtrls;
  final List<_WeightRow> _weightRows = [];

  static const List<String> _testNames = [
    'Tor marking',
    'Colour',
    'Weight per meter',
    'Pitch of twist of bar',
    'Bending for hardness',
    'Rusting',
    'Diameter of bar',
    'Length of bar',
    'Theoretical weight (as calculated)',
    'No. of bars per bundle',
  ];

  static const List<String?> _testHints = [
    "There is 'TOR' marking on every meter length.",
    "Steel Grey",
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
  ];

  @override
  void initState() {
    super.initState();
    _testResultCtrls = List.generate(10, (_) => TextEditingController());
    _weightRows.add(_WeightRow());
    _weightRows.add(_WeightRow());

    _checklistNoCtrl.text = widget.prefilledChecklistNo;
    final now = DateTime.now();
    _checklistDateCtrl.text =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final c = widget.checklist;
    if (c != null) {
      _checklistNoCtrl.text = c.checklistNo;
      _checklistDateCtrl.text = c.checklistDate;
      _materialCtrl.text = c.material;
      _quantityCtrl.text = c.quantity;
      _suppliedByCtrl.text = c.suppliedBy;
      _challanNoCtrl.text = c.challanNo ?? '';
      _challanDateCtrl.text = c.challanDate ?? '';
      _tradeMarkCtrl.text = c.tradeMark ?? '';
      _testTakenByCtrl.text = c.testTakenBy ?? '';

      for (final test in c.testResults) {
        final name = test['test_name']?.toString() ?? '';
        final idx = _testNames.indexOf(name);
        if (idx < 0) continue;
        if (name == 'Weight per meter') {
          _weightRows.clear();
          final wt = test['weight_table'];
          if (wt is List && wt.isNotEmpty) {
            for (final row in wt) {
              if (row is Map) {
                _weightRows.add(
                    _WeightRow.fromMap(Map<String, dynamic>.from(row)));
              }
            }
          }
          if (_weightRows.isEmpty) {
            _weightRows.add(_WeightRow());
            _weightRows.add(_WeightRow());
          }
        } else {
          _testResultCtrls[idx].text = test['result']?.toString() ?? '';
        }
      }
    }
  }

  @override
  void dispose() {
    _checklistNoCtrl.dispose();
    _checklistDateCtrl.dispose();
    _materialCtrl.dispose();
    _quantityCtrl.dispose();
    _suppliedByCtrl.dispose();
    _challanNoCtrl.dispose();
    _challanDateCtrl.dispose();
    _tradeMarkCtrl.dispose();
    _testTakenByCtrl.dispose();
    for (final c in _testResultCtrls) c.dispose();
    for (final r in _weightRows) r.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    DateTime initial = DateTime.now();
    if (ctrl.text.isNotEmpty) {
      try {
        final parts = ctrl.text.split('-');
        if (parts.length == 3) {
          initial = DateTime(
              int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        }
      } catch (_) {}
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
              colorScheme:
                  ColorScheme.light(primary: AppColors.primaryGreen)),
          child: child!),
    );
    if (picked != null && mounted) {
      ctrl.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() {});
    }
  }

  List<Map<String, dynamic>> _buildTestResults() {
    final results = <Map<String, dynamic>>[];
    for (int i = 0; i < _testNames.length; i++) {
      final name = _testNames[i];
      if (name == 'Weight per meter') {
        results.add({
          'test_name': name,
          'result': '',
          'weight_table': _weightRows.map((r) => r.toMap()).toList(),
        });
      } else {
        results.add({
          'test_name': name,
          'result': _testResultCtrls[i].text.trim(),
        });
      }
    }
    return results;
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);
    try {
      final testResults = _buildTestResults();
      final headers = await widget.headers();

      final payload = <String, dynamic>{
        'checklist_date': _checklistDateCtrl.text.trim(),
        'material': _materialCtrl.text.trim(),
        'quantity': _quantityCtrl.text.trim(),
        'supplied_by': _suppliedByCtrl.text.trim(),
        if (_challanNoCtrl.text.trim().isNotEmpty)
          'challan_no': _challanNoCtrl.text.trim(),
        if (_challanDateCtrl.text.trim().isNotEmpty)
          'challan_date': _challanDateCtrl.text.trim(),
        if (_tradeMarkCtrl.text.trim().isNotEmpty)
          'trade_mark': _tradeMarkCtrl.text.trim(),
        if (_testTakenByCtrl.text.trim().isNotEmpty)
          'test_taken_by': _testTakenByCtrl.text.trim(),
        'test_results': testResults,
      };

      late http.Response res;

      if (_isEdit) {
        payload['_method'] = 'PATCH';
        final url = Uri.parse(ApiConstants.steelChecklistUpdate(
            widget.projectId, widget.checklist!.id));
        developer.log(
            '[SteelChecklist] UPDATE → POST $url with _method=PATCH',
            name: 'SteelChecklist');
        res = await http
            .post(url, headers: headers, body: jsonEncode(payload))
            .timeout(const Duration(seconds: 30));
      } else {
        payload['checklist_no'] = _checklistNoCtrl.text.trim();
        final url =
            Uri.parse(ApiConstants.steelChecklistStore(widget.projectId));
        developer.log('[SteelChecklist] CREATE → POST $url',
            name: 'SteelChecklist');
        res = await http
            .post(url, headers: headers, body: jsonEncode(payload))
            .timeout(const Duration(seconds: 30));
      }

      if (!mounted) return;
      final body = widget.decode(res.body);

      developer.log(
          '[SteelChecklist] Response ${res.statusCode}: ${res.body}',
          name: 'SteelChecklist');

      if (res.statusCode >= 200 && res.statusCode < 300) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              (body is Map ? body['message']?.toString() : null) ??
                  (_isEdit
                      ? 'Steel checklist updated!'
                      : 'Steel checklist created!')),
          backgroundColor: AppColors.primaryGreen,
        ));
        Navigator.pop(context, true);
      } else {
        String msg = (body is Map ? body['message']?.toString() : null) ??
            'Save failed (${res.statusCode})';
        if (body is Map && body['errors'] is Map) {
          final errs = Map<String, dynamic>.from(body['errors'] as Map);
          if (errs.isNotEmpty) {
            final firstVal = errs.values.first;
            msg = firstVal is List
                ? firstVal.first.toString()
                : firstVal.toString();
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(msg),
            backgroundColor: const Color(0xFFEF4444)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFEF4444)));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── UI helpers ─────────────────────────────────────────────────────────────

  InputDecoration _deco({String? hint, Widget? suffix}) => InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
        suffixIcon: suffix,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                BorderSide(color: AppColors.primaryGreen, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFEF4444))),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        isDense: true,
      );

  Widget _label(String text, {bool required = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(text,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151))),
          if (required)
            const Text(' *',
                style:
                    TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
        ]),
      );

  Widget _dateField(TextEditingController ctrl,
          {String label = 'Date', bool req = false}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label(label, required: req),
        GestureDetector(
          onTap: () => _pickDate(ctrl),
          child: AbsorbPointer(
            child: TextFormField(
              controller: ctrl,
              validator: req
                  ? (v) => (v == null || v.isEmpty) ? 'Required' : null
                  : null,
              decoration: _deco(
                  hint: 'YYYY-MM-DD',
                  suffix: const Icon(Icons.calendar_today_outlined,
                      size: 16, color: Color(0xFF94A3B8))),
              style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
            ),
          ),
        ),
      ]);

  // ── weight table ───────────────────────────────────────────────────────────

  Widget _weightTable() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Weight per meter — sub-table',
          style: TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
              fontStyle: FontStyle.italic)),
      const SizedBox(height: 6),
      _wtHeaderRow(),
      ..._weightRows.asMap().entries.map((e) {
        final i = e.key;
        final r = e.value;
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            Expanded(child: _wtCell(r.srNo, hint: 'SR.')),
            const SizedBox(width: 4),
            Expanded(flex: 2, child: _wtCell(r.size, hint: 'Size')),
            const SizedBox(width: 4),
            Expanded(
                flex: 2,
                child: _wtCell(r.theoretical, hint: 'Theo. kg/m')),
            const SizedBox(width: 4),
            Expanded(
                flex: 2, child: _wtCell(r.actual, hint: 'Actual kg/m')),
            const SizedBox(width: 4),
            Expanded(
                flex: 2, child: _wtCell(r.diff, hint: 'Diff. kg/m')),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () {
                if (_weightRows.length > 1) {
                  setState(() {
                    _weightRows[i].dispose();
                    _weightRows.removeAt(i);
                  });
                }
              },
              child: const Icon(Icons.remove_circle_outline,
                  size: 18, color: Color(0xFFEF4444)),
            ),
          ]),
        );
      }),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: () => setState(() => _weightRows.add(_WeightRow())),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.add_circle_outline,
              size: 16, color: AppColors.primaryGreen),
          const SizedBox(width: 4),
          Text('Add row',
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    ]);
  }

  Widget _wtHeaderRow() {
    const style = TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: Color(0xFF64748B));
    return Row(children: [
      const Expanded(child: Text('SR.', style: style)),
      const SizedBox(width: 4),
      const Expanded(flex: 2, child: Text('SIZE', style: style)),
      const SizedBox(width: 4),
      const Expanded(flex: 2, child: Text('THEO. (kg/m)', style: style)),
      const SizedBox(width: 4),
      const Expanded(flex: 2, child: Text('ACTUAL (kg/m)', style: style)),
      const SizedBox(width: 4),
      const Expanded(flex: 2, child: Text('DIFF.', style: style)),
      const SizedBox(width: 22),
    ]);
  }

  Widget _wtCell(TextEditingController ctrl, {String? hint}) =>
      TextFormField(
        controller: ctrl,
        decoration: _deco(hint: hint),
        style: const TextStyle(fontSize: 11, color: Color(0xFF1E293B)),
      );

  // ── card wrapper (matches shuttering form style) ────────────────────────────

  Widget _formCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12),
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

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      height: mq.size.height * 0.94,
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        // ── sheet header ─────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    _isEdit
                        ? 'Edit Steel Checklist'
                        : 'New Steel Checklist',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                const Text('WR/EXE/05 — WISE REALTY',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontStyle: FontStyle.italic)),
              ]),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.close,
                    color: Colors.white, size: 18),
              ),
            ),
          ]),
        ),

        // ── form body ────────────────────────────────────────────────────────
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              children: [
                // Basic info card
                _formCard(
                  title: 'Basic Information',
                  icon: Icons.info_outline,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            _label('No.'),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 13),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                border: Border.all(
                                    color: const Color(0xFFE2E8F0)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _checklistNoCtrl.text.isEmpty
                                    ? 'Generating…'
                                    : _checklistNoCtrl.text,
                                style: TextStyle(
                                  fontSize: 13,
                                  color:
                                      _checklistNoCtrl.text.isEmpty
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _dateField(_checklistDateCtrl,
                                label: 'Date', req: true)),
                      ]),
                      const SizedBox(height: 12),
                      _label('Name of Project'),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 13),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          border: Border.all(
                              color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.projectName,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF64748B)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            _label('Material', required: true),
                            TextFormField(
                              controller: _materialCtrl,
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Required'
                                      : null,
                              decoration: _deco(),
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF1E293B)),
                            ),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            _label('Quantity', required: true),
                            TextFormField(
                              controller: _quantityCtrl,
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Required'
                                      : null,
                              decoration: _deco(),
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF1E293B)),
                            ),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      _label('Supplied By', required: true),
                      TextFormField(
                        controller: _suppliedByCtrl,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                        decoration: _deco(),
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                ),

                // Challan & Trade details card
                _formCard(
                  title: 'Challan & Trade Details',
                  icon: Icons.receipt_long_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            _label('Challan No.'),
                            TextFormField(
                              controller: _challanNoCtrl,
                              decoration: _deco(),
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF1E293B)),
                            ),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _dateField(_challanDateCtrl,
                                label: 'Challan Date')),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            _label('Trade Mark'),
                            TextFormField(
                              controller: _tradeMarkCtrl,
                              decoration: _deco(),
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF1E293B)),
                            ),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      _label('Test Taken By'),
                      TextFormField(
                        controller: _testTakenByCtrl,
                        decoration: _deco(),
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                ),

                // Tests card
                _formCard(
                  title: 'Test Particulars',
                  icon: Icons.science_outlined,
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(children: [
                        SizedBox(
                            width: 32,
                            child: Text('SR.',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF475569)))),
                        Expanded(
                            flex: 2,
                            child: Text('TEST TAKEN',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF475569)))),
                        SizedBox(width: 8),
                        Expanded(
                            flex: 2,
                            child: Text('RESULT OBTAINED',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF475569)))),
                      ]),
                    ),
                    const SizedBox(height: 4),
                    ..._testNames.asMap().entries.map((e) {
                      final i = e.key;
                      final name = e.value;
                      final srLabel =
                          (i + 1).toString().padLeft(2, '0');
                      final isWeight = name == 'Weight per meter';

                      return Container(
                        margin:
                            const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: const Color(0xFFE2E8F0)),
                        ),
                        child: isWeight
                            ? Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                Row(children: [
                                  SizedBox(
                                    width: 32,
                                    child: Text(srLabel,
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color:
                                                AppColors.primaryGreen)),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(name,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1E293B))),
                                  ),
                                ]),
                                const SizedBox(height: 8),
                                _weightTable(),
                              ])
                            : Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                SizedBox(
                                  width: 32,
                                  child: Text(srLabel,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color:
                                              AppColors.primaryGreen)),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(name,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1E293B))),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _testResultCtrls[i],
                                    decoration:
                                        _deco(hint: _testHints[i]),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF1E293B)),
                                  ),
                                ),
                              ]),
                      );
                    }),
                  ]),
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ),

        // ── footer buttons ───────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          decoration: const BoxDecoration(
              color: Colors.white,
              border:
                  Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed:
                    _isSaving ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF374151),
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
                child: const Text('Close',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        _isEdit
                            ? 'Update Checklist'
                            : 'Save Checklist',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}