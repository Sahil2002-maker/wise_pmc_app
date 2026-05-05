// lib/features/cement_checklist/presentation/cement_checklist_page.dart
//
// UI updated to match the Steel Checklist screen style exactly.
// All functionality is unchanged.

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_storage_service.dart';
import '../data/models/cement_checklist_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Fixed list of 8 tests
// ─────────────────────────────────────────────────────────────────────────────
const _kTestNames = [
  'Grade and colour',
  'Fineness test',
  'Freshness test Manufacturing date',
  'Lump test',
  'Average weight (average of 5 bags)',
  'Packing',
  'Paste test',
  'Floating test',
];

// ═════════════════════════════════════════════════════════════════════════════
// CementChecklistPage
// ═════════════════════════════════════════════════════════════════════════════

class CementChecklistPage extends StatefulWidget {
  final int projectId;
  final String projectName;

  const CementChecklistPage({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<CementChecklistPage> createState() => _CementChecklistPageState();
}

class _CementChecklistPageState extends State<CementChecklistPage> {
  List<CementChecklistModel> _checklists = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── API helpers ─────────────────────────────────────────────────────────────

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
    try {
      return jsonDecode(body);
    } catch (_) {
      return {};
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() { _isLoading = true; _error = null; });
    try {
      final url = Uri.parse(ApiConstants.cementChecklistIndex(widget.projectId));
      final res = await http
          .get(url, headers: await _headers())
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      final body = _decode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final raw = body['checklists'];
        final fetched = (raw is List)
            ? raw
                .whereType<Map>()
                .map((e) => CementChecklistModel.fromJson(
                    Map<String, dynamic>.from(e)))
                .toList()
            : <CementChecklistModel>[];

        fetched.sort((a, b) => a.id.compareTo(b.id));

        setState(() {
          _checklists = fetched;
          _isLoading = false;
          _error = null;
        });
      } else {
        setState(() {
          _error = body['message']?.toString() ?? 'Failed to load';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<String> _generateNumber() async {
    try {
      final url = Uri.parse(ApiConstants.cementChecklistCreate(widget.projectId));
      final res = await http
          .get(url, headers: await _headers())
          .timeout(const Duration(seconds: 15));
      final body = _decode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return body['checklist_no']?.toString() ?? '';
      }
    } catch (_) {}
    return '';
  }

  // ── DELETE ─────────────────────────────────────────────────────────────────
  Future<void> _delete(int id) async {
    final url = Uri.parse(
      '${ApiConstants.cementChecklistDestroy(widget.projectId, id)}/delete',
    );
    try {
      final res = await http
          .post(url, headers: await _headers())
          .timeout(const Duration(seconds: 20));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        await _load(silent: true);
        if (mounted) _showSnack('Cement Checklist deleted successfully!', success: true);
      } else {
        final body = _decode(res.body);
        if (mounted) {
          _showSnack(body['message']?.toString() ?? 'Delete failed');
        }
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e');
    }
  }

  // ── PRINT ──────────────────────────────────────────────────────────────────
  Future<void> _openPrint(CementChecklistModel c) async {
    await _fetchAndOpenPdf(
      url: ApiConstants.cementChecklistDownload(widget.projectId, c.id),
      fileName: 'cement_print_${c.checklistNo.replaceAll('/', '-')}.pdf',
      label: 'Preparing print…',
      saveToDocuments: false,
    );
  }

  // ── DOWNLOAD ───────────────────────────────────────────────────────────────
  Future<void> _openDownload(CementChecklistModel c) async {
    await _fetchAndOpenPdf(
      url: ApiConstants.cementChecklistDownload(widget.projectId, c.id),
      fileName: 'cement_checklist_${c.checklistNo.replaceAll('/', '-')}.pdf',
      label: 'Downloading PDF…',
      saveToDocuments: true,
    );
  }

  Future<void> _fetchAndOpenPdf({
    required String url,
    required String fileName,
    required String label,
    required bool saveToDocuments,
  }) async {
    if (!mounted) return;

    if (Platform.isAndroid && saveToDocuments) {
      final sdk = await _androidSdk();
      if (sdk != null && sdk < 33) {
        final status = await Permission.storage.request();
        if (status.isDenied || status.isPermanentlyDenied) {
          _showSnack('Storage permission required to save PDF.');
          return;
        }
      }
    }

    double progress = 0;
    OverlayEntry? overlay;
    overlay = OverlayEntry(
      builder: (_) => _PdfProgressOverlay(
        progress: progress,
        label: label,
        onCancel: () { overlay?.remove(); overlay = null; },
      ),
    );
    if (mounted) Overlay.of(context).insert(overlay!);

    try {
      final token = await AuthStorageService.getToken();
      final dir = saveToDocuments
          ? await getApplicationDocumentsDirectory()
          : await getTemporaryDirectory();

      final safeFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._\-]'), '_');
      final savePath = '${dir.path}/$safeFileName';

      final dio = Dio();
      await dio.download(
        url,
        savePath,
        options: Options(
          receiveTimeout: const Duration(minutes: 2),
          headers: {
            'Accept': 'application/pdf,*/*',
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            progress = received / total;
            overlay?.markNeedsBuild();
          }
        },
      );

      overlay?.remove();
      overlay = null;

      final file = File(savePath);
      if (!await file.exists() || await file.length() == 0) {
        throw Exception('Downloaded file is empty or missing.');
      }
      final header = await _readBytes(file, 5);
      if (!_isPdf(header)) {
        final snippet = await _readText(file, 400);
        debugPrint('[CementChecklist] Server returned non-PDF: $snippet');
        if (mounted) {
          _showSnack(
            'Server did not return a PDF.\nCheck authentication or server logs.',
          );
        }
        return;
      }

      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done && mounted) {
        _showSnack(
          'No PDF viewer found. Please install Adobe Acrobat or similar.',
        );
      }
    } catch (e) {
      overlay?.remove();
      overlay = null;
      if (mounted) _showSnack('Failed: $e');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          success ? AppColors.primaryGreen : const Color(0xFFEF4444),
    ));
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return 'N/A';
    try {
      final d = DateTime.parse(raw);
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.year}';
    } catch (_) {
      return raw;
    }
  }

  static Future<int?> _androidSdk() async {
    try {
      final r = await Process.run('getprop', ['ro.build.version.sdk']);
      return int.tryParse(r.stdout.toString().trim());
    } catch (_) {
      return null;
    }
  }

  static Future<List<int>> _readBytes(File f, int n) async {
    try {
      final out = <int>[];
      await for (final chunk in f.openRead(0, n)) {
        out.addAll(chunk);
        if (out.length >= n) break;
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  static bool _isPdf(List<int> b) =>
      b.length >= 4 &&
      b[0] == 0x25 &&
      b[1] == 0x50 &&
      b[2] == 0x44 &&
      b[3] == 0x46;

  static Future<String> _readText(File f, int maxBytes) async {
    try {
      final bytes = await f.openRead(0, maxBytes).expand((c) => c).toList();
      return String.fromCharCodes(bytes);
    } catch (_) {
      return '';
    }
  }

  // ── Sheet openers ──────────────────────────────────────────────────────────

  Future<void> _openForm({CementChecklistModel? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CementChecklistFormSheet(
        projectId: widget.projectId,
        projectName: widget.projectName,
        existing: existing,
        onGenerateNumber: _generateNumber,
      ),
    );
    if (saved == true) await _load(silent: true);
  }

  Future<void> _openView(CementChecklistModel c) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CementChecklistViewSheet(
        checklist: c,
        projectName: widget.projectName,
        formatDate: _formatDate,
      ),
    );
  }

  Future<void> _confirmDelete(CementChecklistModel c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Checklist?'),
        content: Text(
            'Delete checklist ${c.checklistNo}? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await _delete(c.id);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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

  // ── Header — matches Steel Checklist header card ──────────────────────────
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
                Icons.inventory_2_outlined,
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
                    'Cement Checklist',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'WR/EXE/04 — ${widget.projectName}',
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

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen));
    }
    if (_error != null) {
      return _buildError();
    }
    if (_checklists.isEmpty) {
      return _buildEmpty();
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primaryGreen,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
        itemCount: _checklists.length,
        itemBuilder: (_, i) => _buildCard(_checklists[i], i),
      ),
    );
  }

  // ── Card — matches Steel Checklist card style ─────────────────────────────
  Widget _buildCard(CementChecklistModel c, int index) {
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
          // ── card header (tinted background like Steel) ───────────────────
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
                    color: AppColors.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Cement',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.primaryGreen,
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
                        Icons.scale_outlined, 'Quantity', c.quantity),
                    const SizedBox(width: 16),
                    _infoItem(Icons.local_shipping_outlined, 'Supplied By',
                        c.suppliedBy),
                  ],
                ),
                if (c.creatorName != null && c.creatorName!.isNotEmpty) ...[
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
                // ── Action buttons — outlined style matching Steel Checklist ──
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
                      onTap: () => _openPrint(c),
                    ),
                    _actionBtn(
                      label: 'PDF',
                      icon: Icons.download_outlined,
                      color: const Color(0xFF8B5CF6),
                      onTap: () => _openDownload(c),
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
  }

  // ── Info item — matches Steel Checklist info item style ───────────────────
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

  // ── Action button — outlined style matching Steel Checklist ───────────────
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

  // ── Empty state — matches Steel Checklist empty style ─────────────────────
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
                  Icons.inventory_2_outlined,
                  size: 56,
                  color: AppColors.primaryGreen.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No Cement Checklists',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap the button below to create your first cement checklist.',
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

  // ── Error state ────────────────────────────────────────────────────────────
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

// ═════════════════════════════════════════════════════════════════════════════
// _CementChecklistFormSheet  — Create / Edit (unchanged functionality,
// updated visual style to match Steel Checklist form)
// ═════════════════════════════════════════════════════════════════════════════

class _CementChecklistFormSheet extends StatefulWidget {
  final int projectId;
  final String projectName;
  final CementChecklistModel? existing;
  final Future<String> Function() onGenerateNumber;

  const _CementChecklistFormSheet({
    required this.projectId,
    required this.projectName,
    required this.existing,
    required this.onGenerateNumber,
  });

  @override
  State<_CementChecklistFormSheet> createState() =>
      _CementChecklistFormSheetState();
}

class _CementChecklistFormSheetState
    extends State<_CementChecklistFormSheet> {
  final _checklistNoCtrl   = TextEditingController();
  final _checklistDateCtrl = TextEditingController();
  final _materialCtrl      = TextEditingController();
  final _quantityCtrl      = TextEditingController();
  final _suppliedByCtrl    = TextEditingController();
  final _challanNoCtrl     = TextEditingController();
  final _challanDateCtrl   = TextEditingController();
  final _tradeMarkCtrl     = TextEditingController();
  final _testTakenByCtrl   = TextEditingController();
  late final List<TextEditingController> _testCtrls;

  bool _isSaving    = false;
  bool _isLoadingNo = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _testCtrls = List.generate(8, (_) => TextEditingController());

    if (_isEdit) {
      final c = widget.existing!;
      _checklistNoCtrl.text = c.checklistNo;
      _checklistDateCtrl.text = c.checklistDate.length >= 10
          ? c.checklistDate.substring(0, 10)
          : c.checklistDate;
      _materialCtrl.text   = c.material;
      _quantityCtrl.text   = c.quantity;
      _suppliedByCtrl.text = c.suppliedBy;
      _challanNoCtrl.text  = c.challanNo ?? '';
      _challanDateCtrl.text =
          (c.challanDate != null && c.challanDate!.length >= 10)
              ? c.challanDate!.substring(0, 10)
              : (c.challanDate ?? '');
      _tradeMarkCtrl.text   = c.tradeMark ?? '';
      _testTakenByCtrl.text = c.testTakenBy ?? '';
      for (int i = 0; i < c.testResults.length && i < 8; i++) {
        _testCtrls[i].text = c.testResults[i].result;
      }
    } else {
      final now = DateTime.now();
      _checklistDateCtrl.text =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      _fetchNumber();
    }
  }

  @override
  void dispose() {
    for (final c in [
      _checklistNoCtrl, _checklistDateCtrl, _materialCtrl, _quantityCtrl,
      _suppliedByCtrl,  _challanNoCtrl,    _challanDateCtrl, _tradeMarkCtrl,
      _testTakenByCtrl, ..._testCtrls,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchNumber() async {
    setState(() => _isLoadingNo = true);
    final no = await widget.onGenerateNumber();
    if (mounted) {
      setState(() { _checklistNoCtrl.text = no; _isLoadingNo = false; });
    }
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    DateTime initial = DateTime.now();
    try {
      if (ctrl.text.isNotEmpty) initial = DateTime.parse(ctrl.text);
    } catch (_) {}
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2099),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme:
                ColorScheme.light(primary: AppColors.primaryGreen)),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      ctrl.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _submit() async {
    if (_isSaving) return;

    if (_checklistDateCtrl.text.trim().isEmpty) {
      _snack('Checklist date is required'); return;
    }
    if (_materialCtrl.text.trim().isEmpty) {
      _snack('Material is required'); return;
    }
    if (_quantityCtrl.text.trim().isEmpty) {
      _snack('Quantity is required'); return;
    }
    if (_suppliedByCtrl.text.trim().isEmpty) {
      _snack('Supplied By is required'); return;
    }

    setState(() => _isSaving = true);

    final testResults = List.generate(8, (i) => <String, dynamic>{
          'test_name': _kTestNames[i],
          'result':    _testCtrls[i].text.trim(),
        });

    final payload = <String, dynamic>{
      if (!_isEdit) 'checklist_no': _checklistNoCtrl.text.trim(),
      'checklist_date': _checklistDateCtrl.text.trim(),
      'material':       _materialCtrl.text.trim(),
      'quantity':       _quantityCtrl.text.trim(),
      'supplied_by':    _suppliedByCtrl.text.trim(),
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

    try {
      final token = await AuthStorageService.getToken();
      final headers = {
        'Accept':           'application/json',
        'Content-Type':     'application/json',
        'X-Requested-With': 'XMLHttpRequest',
        if (token != null && token.isNotEmpty)
          'Authorization': 'Bearer $token',
      };

      late final http.Response res;

      if (_isEdit) {
        final url = Uri.parse(
          '${ApiConstants.cementChecklistUpdate(widget.projectId, widget.existing!.id)}/update',
        );
        res = await http
            .post(url, headers: headers, body: jsonEncode(payload))
            .timeout(const Duration(seconds: 30));
      } else {
        final url =
            Uri.parse(ApiConstants.cementChecklistStore(widget.projectId));
        res = await http
            .post(url, headers: headers, body: jsonEncode(payload))
            .timeout(const Duration(seconds: 30));
      }

      if (!mounted) return;

      dynamic decoded;
      try {
        decoded = jsonDecode(res.body);
      } catch (_) {
        decoded = {'message': res.body};
      }

      if (res.statusCode >= 200 && res.statusCode < 300) {
        _snack(decoded['message']?.toString() ??
            (_isEdit
                ? 'Checklist updated successfully!'
                : 'Checklist created successfully!'),
            success: true);
        if (mounted) Navigator.pop(context, true);
      } else {
        String msg = decoded['message']?.toString() ?? 'Save failed';
        if (decoded is Map && decoded['errors'] is Map) {
          final errs =
              Map<String, dynamic>.from(decoded['errors'] as Map);
          if (errs.isNotEmpty) {
            final first = errs.values.first;
            if (first is List && first.isNotEmpty) {
              msg = first.first.toString();
            }
          }
        }
        _snack(msg);
      }
    } catch (e) {
      if (mounted) _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          success ? AppColors.primaryGreen : const Color(0xFFEF4444),
    ));
  }

  // ── Input decoration ──────────────────────────────────────────────────────
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
                style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
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
              decoration: _deco(
                  hint: 'YYYY-MM-DD',
                  suffix: const Icon(Icons.calendar_today_outlined,
                      size: 16, color: Color(0xFF94A3B8))),
              style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
            ),
          ),
        ),
      ]);

  // ── Card wrapper — matches Steel Checklist form card style ────────────────
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
        // ── Sheet header ─────────────────────────────────────────────────────
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
                      ? 'Edit Cement Checklist'
                      : 'New Cement Checklist',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                const Text('WR/EXE/04 — WISE REALTY',
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
                      color: Colors.white, size: 18)),
            ),
          ]),
        ),

        // ── Form body ────────────────────────────────────────────────────────
        Expanded(
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
                            child: _isLoadingNo
                                ? Row(children: [
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          color: AppColors.primaryGreen),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('Generating…',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF94A3B8))),
                                  ])
                                : Text(
                                    _checklistNoCtrl.text.isEmpty
                                        ? 'Auto-generated'
                                        : _checklistNoCtrl.text,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _checklistNoCtrl.text.isEmpty
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
                              label: 'Date *', req: true)),
                    ]),
                    const SizedBox(height: 12),
                    _label('Name of Project'),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 13),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        border:
                            Border.all(color: const Color(0xFFE2E8F0)),
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
                            decoration: _deco(hint: 'e.g. OPC 53 Grade'),
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF1E293B)),
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
                            decoration: _deco(hint: 'e.g. 50 bags'),
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF1E293B)),
                          ),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    _label('Supplied By', required: true),
                    TextFormField(
                      controller: _suppliedByCtrl,
                      decoration: _deco(hint: 'Supplier name'),
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
                            decoration: _deco(hint: 'Optional'),
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF1E293B)),
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
                            decoration: _deco(hint: 'Optional'),
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF1E293B)),
                          ),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    _label('Test Taken By'),
                    TextFormField(
                      controller: _testTakenByCtrl,
                      decoration: _deco(hint: 'Optional'),
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
                  ...List.generate(_kTestNames.length, (i) {
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border:
                            Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        SizedBox(
                          width: 32,
                          child: Text(
                              (i + 1).toString().padLeft(2, '0'),
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryGreen)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(_kTestNames[i],
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B))),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _testCtrls[i],
                            decoration: _deco(hint: 'Enter result'),
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

              // Signatures
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.primaryGreen.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Expanded(child: _SignatureBox(label: 'Contractor')),
                    const SizedBox(width: 20),
                    Expanded(child: _SignatureBox(label: 'Consultant')),
                  ],
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),

        // ── Footer buttons ───────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
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
                child: const Text('Cancel',
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
                        _isEdit ? 'Update Checklist' : 'Save Checklist',
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

// ═════════════════════════════════════════════════════════════════════════════
// _CementChecklistViewSheet — updated to match Steel Checklist view style
// ═════════════════════════════════════════════════════════════════════════════

class _CementChecklistViewSheet extends StatelessWidget {
  final CementChecklistModel checklist;
  final String projectName;
  final String Function(String?) formatDate;

  const _CementChecklistViewSheet({
    required this.checklist,
    required this.projectName,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final c = checklist;
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(children: [
        // ── Sheet header ───────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20))),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Cement Checklist',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  c.checklistNo,
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
                  child: const Icon(Icons.close,
                      color: Colors.white, size: 18)),
            ),
          ]),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Basic info section card
              _sectionCard(
                context: context,
                title: 'WR/EXE/04 — Checklist for Cement',
                icon: Icons.inventory_2_outlined,
                children: [
                  _row2('Checklist No.', c.checklistNo, 'Date',
                      formatDate(c.checklistDate)),
                  const SizedBox(height: 10),
                  _infoRow('Name of Project', projectName),
                  const SizedBox(height: 8),
                  _row2('Material', c.material, 'Quantity', c.quantity),
                  const SizedBox(height: 8),
                  _infoRow('Supplied By', c.suppliedBy),
                  const SizedBox(height: 8),
                  _row2('Challan No.', c.challanNo ?? 'N/A',
                      'Challan Date', formatDate(c.challanDate)),
                  const SizedBox(height: 8),
                  _row2('Trade Mark', c.tradeMark ?? 'N/A',
                      'Test Taken By', c.testTakenBy ?? 'N/A'),
                ],
              ),
              const SizedBox(height: 12),

              // Tests section card
              _sectionCard(
                context: context,
                title: 'Test Results',
                icon: Icons.science_outlined,
                children: [
                  if (c.testResults.isEmpty)
                    const Text(
                      'No test results recorded.',
                      style: TextStyle(
                          color: Color(0xFF94A3B8), fontSize: 13),
                    )
                  else
                    _testsTable(c),
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
                    Expanded(child: _sigBox('Consultant')),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ]),
          ),
        ),

        // Close button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
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
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children),
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

  Widget _testsTable(CementChecklistModel c) {
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
      ...c.testResults.asMap().entries.map((e) {
        final i = e.key;
        final t = e.value;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(children: [
            SizedBox(
              width: 32,
              child: Text(
                  (i + 1).toString().padLeft(2, '0'),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryGreen)),
            ),
            Expanded(
                flex: 2,
                child: Text(t.testName,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B)))),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Text(
                  t.result.isEmpty ? 'N/A' : t.result,
                  style: TextStyle(
                      fontSize: 11,
                      color: t.result.isEmpty
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF334155))),
            ),
          ]),
        );
      }),
    ]);
  }

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

// ═════════════════════════════════════════════════════════════════════════════
// PDF progress overlay (unchanged)
// ═════════════════════════════════════════════════════════════════════════════

class _PdfProgressOverlay extends StatelessWidget {
  final double progress;
  final String label;
  final VoidCallback onCancel;

  const _PdfProgressOverlay({
    required this.progress,
    required this.label,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black54,
        child: Center(
          child: Container(
            width: 240,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.picture_as_pdf,
                    size: 32, color: Color(0xFF1565C0)),
              ),
              const SizedBox(height: 14),
              Text(label,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B))),
              const SizedBox(height: 4),
              const Text('Please wait…',
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress > 0 ? progress : null,
                  backgroundColor: const Color(0xFFE2E8F0),
                  color: const Color(0xFF1565C0),
                  minHeight: 7,
                ),
              ),
              if (progress > 0) ...[
                const SizedBox(height: 6),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1565C0)),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Shared small widgets
// ═════════════════════════════════════════════════════════════════════════════

class _SignatureBox extends StatelessWidget {
  final String label;
  const _SignatureBox({required this.label});

  @override
  Widget build(BuildContext context) => Column(
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