// lib/features/excavation_checklist/presentation/excavation_checklist_page.dart
//
// UI layout now mirrors Shuttering Checklist:
//   - Scaffold with FAB instead of Column + inline button
//   - Header info card with count badge
//   - Outlined action buttons (border + tinted bg)
//   - Info items with icons (location, contractor, creator)
//   - Empty / error states match Shuttering style
//
// PRINT FIX (ERR_SSL_VERSION_OR_CIPHER_MISMATCH):
//   Fetch HTML via dart:io HttpClient with badCertificateCallback=true,
//   then render locally with flutter/printing — zero WebView involvement.

import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/api_exception.dart';
import '../data/models/excavation_checklist_model.dart';

// ── Particulars ──────────────────────────────────────────────────────────────
const _kParticulars = [
  'Job No / Drawing No',
  'Name of Contractor',
  'Volume of excavation involved',
  'Site grading OK  Yes / No',
  'Surface drains diverted  Yes/No / does not apply',
  'Bench marks fixed by:  Checked by:',
  'Grid lines marked by:  Checked by',
  'Centre lines marked by:  Checked by:',
  'Area to be excavated marked by:  Checked by:',
  'Bore holes and site subsoil conditions checked  Yes/No',
  'Adequacy of equipment / man power for excavation and dewatering checked  Yes / No',
  'Has arrangement for dumping / carting away of excavated spoils been made  Yes / No',
  'Shoring piles is required as per RCC Drawing  Yes / No',
  'If yes, have necessary arrangements for shoring being made  Yes / No.',
];

String _fmtDate(String? raw) {
  if (raw == null || raw.isEmpty) return 'N/A';
  try {
    final cleaned = raw.contains('T') ? raw.split('T').first : raw;
    final parts = cleaned.split('-');
    if (parts.length == 3) return '${parts[2]}/${parts[1]}/${parts[0]}';
    return raw;
  } catch (_) {
    return raw;
  }
}

String _todayIso() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

String _dateToIso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

// ═══════════════════════════════════════════════════════════════════════════
// ExcavationChecklistPage
// ═══════════════════════════════════════════════════════════════════════════

class ExcavationChecklistPage extends StatefulWidget {
  final int projectId;
  final String projectName;

  const ExcavationChecklistPage({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<ExcavationChecklistPage> createState() =>
      _ExcavationChecklistPageState();
}

class _ExcavationChecklistPageState extends State<ExcavationChecklistPage> {
  List<ExcavationChecklistModel> _checklists = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list =
          await ApiService.fetchExcavationChecklists(widget.projectId);
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

  void _openForm({ExcavationChecklistModel? existing}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ExcavationChecklistFormPage(
          projectId: widget.projectId,
          projectName: widget.projectName,
          existing: existing,
        ),
      ),
    );
    if (result == true) _load();
  }

  void _viewChecklist(ExcavationChecklistModel c) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExcavationChecklistDetailPage(
          checklist: c,
          projectName: widget.projectName,
          onEdit: () => _openForm(existing: c),
          onDelete: () async {
            Navigator.pop(context);
            await _deleteConfirm(c);
          },
        ),
      ),
    );
  }

  Future<void> _deleteConfirm(ExcavationChecklistModel c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Delete Checklist',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text(
            'Are you sure you want to delete checklist ${c.checklistNo}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.deleteExcavationChecklist(widget.projectId, c.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Checklist deleted successfully'),
        backgroundColor: AppColors.primaryGreen,
      ));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('Delete failed: ${e is ApiException ? e.message : e}'),
        backgroundColor: const Color(0xFFEF4444),
      ));
    }
  }

  // ── PRINT ──────────────────────────────────────────────────────────────────
  Future<void> _handlePrint(ExcavationChecklistModel c) async {
    final url =
        ApiConstants.excavationChecklistPrint(widget.projectId, c.id);
    developer.log('Print URL: $url', name: 'ExcavationChecklist');

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white),
          ),
          SizedBox(width: 12),
          Text('Preparing print preview…'),
        ]),
        duration: Duration(seconds: 60),
      ),
    );

    try {
      final html = await _fetchHtmlIgnoreSsl(url);
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      await Printing.layoutPdf(
        name: 'Excavation_${c.checklistNo.replaceAll('/', '_')}',
        onLayout: (PdfPageFormat format) async =>
            Printing.convertHtml(format: format, html: html),
      );
    } catch (e) {
      developer.log('Print error: $e', name: 'ExcavationChecklist');
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Print failed: $e'),
        backgroundColor: const Color(0xFFEF4444),
        duration: const Duration(seconds: 4),
      ));
    }
  }

  Future<String> _fetchHtmlIgnoreSsl(String url) async {
    final httpClient = HttpClient();
    httpClient.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
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

  // ── DOWNLOAD ──────────────────────────────────────────────────────────────
  Future<void> _handleDownload(ExcavationChecklistModel c) async {
    final url =
        ApiConstants.excavationChecklistDownload(widget.projectId, c.id);
    developer.log('Download URL: $url', name: 'ExcavationChecklist');

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Preparing PDF…'),
      duration: Duration(seconds: 2),
    ));

    try {
      final bytes = await ApiService.downloadBytes(url);
      final dir = await getTemporaryDirectory();
      final filename =
          'Excavation_${c.checklistNo.replaceAll('/', '_')}.pdf';
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      await OpenFilex.open(file.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Download failed: $e'),
        backgroundColor: const Color(0xFFEF4444),
      ));
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? Center(
              child:
                  CircularProgressIndicator(color: AppColors.primaryGreen))
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
                                (_, i) =>
                                    _buildCard(_checklists[i], i),
                                childCount: _checklists.length,
                              ),
                            ),
                      const SliverToBoxAdapter(
                          child: SizedBox(height: 80)),
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

  // ── Header card ────────────────────────────────────────────────────────────

  Widget _buildHeader() => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.primaryGreen.withValues(alpha: 0.2)),
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
                Icons.terrain_outlined,
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
                    'Excavation Checklist',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'WR/EXE/02 — ${widget.projectName}',
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

  // ── Checklist card ─────────────────────────────────────────────────────────

  Widget _buildCard(ExcavationChecklistModel c, int index) => Container(
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
            // ── card header ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: BoxDecoration(
                color:
                    AppColors.primaryGreen.withValues(alpha: 0.06),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12)),
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
                          _fmtDate(c.checklistDate),
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
                      color: const Color(0xFF0F766E)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Excavation',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF0F766E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── card body ──────────────────────────────────────────────────
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
                      _infoItem(
                        Icons.engineering_outlined,
                        'Contractor',
                        c.contractorName,
                      ),
                      const SizedBox(width: 16),
                      _infoItem(
                        Icons.person_outline,
                        'Created By',
                        c.creator?.name,
                      ),
                    ],
                  ),
                  if (c.partWing != null &&
                      c.partWing!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.view_quilt_outlined,
                            size: 13, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 5),
                        Text(
                          'Part/Wing: ${c.partWing}',
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
                        onTap: () => _viewChecklist(c),
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
                        onTap: () => _deleteConfirm(c),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _infoItem(IconData icon, String label, String? value) =>
      Expanded(
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
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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

  // ── Empty state ────────────────────────────────────────────────────────────

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
                  Icons.terrain_outlined,
                  size: 56,
                  color:
                      AppColors.primaryGreen.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No Excavation Checklists',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap the button below to create your first excavation checklist.',
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

// ═══════════════════════════════════════════════════════════════════════════
// Form Page
// ═══════════════════════════════════════════════════════════════════════════

class ExcavationChecklistFormPage extends StatefulWidget {
  final int projectId;
  final String projectName;
  final ExcavationChecklistModel? existing;

  const ExcavationChecklistFormPage({
    super.key,
    required this.projectId,
    required this.projectName,
    this.existing,
  });

  @override
  State<ExcavationChecklistFormPage> createState() =>
      _ExcavationChecklistFormPageState();
}

class _ExcavationChecklistFormPageState
    extends State<ExcavationChecklistFormPage> {
  final _formKey = GlobalKey<FormState>();

  String _checklistNo = '';
  final _checklistDateCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _partWingCtrl = TextEditingController();
  final _activityDateCtrl = TextEditingController();
  final _jobNoCtrl = TextEditingController();
  final _drawingNoCtrl = TextEditingController();
  final _contractorCtrl = TextEditingController();
  final _volumeCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();

  late List<String?> _checks;
  late List<TextEditingController> _remarkCtrls;

  bool _isLoadingNo = true;
  bool _isSaving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _checks = List.filled(14, null);
    _remarkCtrls = List.generate(14, (_) => TextEditingController());
    if (_isEdit) {
      _populateFromExisting();
    } else {
      _checklistDateCtrl.text = _todayIso();
      _activityDateCtrl.text = _todayIso();
      _fetchChecklistNo();
    }
  }

  @override
  void dispose() {
    _checklistDateCtrl.dispose();
    _locationCtrl.dispose();
    _partWingCtrl.dispose();
    _activityDateCtrl.dispose();
    _jobNoCtrl.dispose();
    _drawingNoCtrl.dispose();
    _contractorCtrl.dispose();
    _volumeCtrl.dispose();
    _remarksCtrl.dispose();
    for (final c in _remarkCtrls) c.dispose();
    super.dispose();
  }

  void _populateFromExisting() {
    final c = widget.existing!;
    _checklistNo = c.checklistNo;
    _checklistDateCtrl.text = c.checklistDate;
    _locationCtrl.text = c.location ?? '';
    _partWingCtrl.text = c.partWing ?? '';
    _activityDateCtrl.text = c.activityDate ?? '';
    _jobNoCtrl.text = c.jobNo ?? '';
    _drawingNoCtrl.text = c.drawingNo ?? '';
    _contractorCtrl.text = c.contractorName ?? '';
    _volumeCtrl.text = c.excavationVolume ?? '';
    _remarksCtrl.text = c.remarks ?? '';
    for (int i = 0; i < c.checklistItems.length && i < 14; i++) {
      _checks[i] = c.checklistItems[i].check;
      _remarkCtrls[i].text = c.checklistItems[i].remark ?? '';
    }
    setState(() => _isLoadingNo = false);
  }

  Future<void> _fetchChecklistNo() async {
    try {
      final no = await ApiService.generateExcavationChecklistNumber(
          widget.projectId);
      if (!mounted) return;
      setState(() {
        _checklistNo = no;
        _isLoadingNo = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingNo = false);
    }
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    DateTime initial;
    try {
      final text =
          ctrl.text.isEmpty ? _todayIso() : ctrl.text;
      final cleaned =
          text.contains('T') ? text.split('T').first : text;
      final parts = cleaned.split('-');
      initial = parts.length == 3
          ? DateTime(int.parse(parts[0]), int.parse(parts[1]),
              int.parse(parts[2]))
          : DateTime.now();
    } catch (_) {
      initial = DateTime.now();
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme:
                ColorScheme.light(primary: AppColors.primaryGreen)),
        child: child!,
      ),
    );
    if (picked != null && mounted)
      ctrl.text = _dateToIso(picked);
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final items = List<Map<String, dynamic>>.generate(
        14,
        (i) => {
              'check': _checks[i] ?? '',
              'remark': _remarkCtrls[i].text.trim(),
            });

    setState(() => _isSaving = true);
    try {
      if (_isEdit) {
        await ApiService.updateExcavationChecklist(
          projectId: widget.projectId,
          id: widget.existing!.id,
          checklistNo: _checklistNo,
          checklistDate: _checklistDateCtrl.text.trim(),
          location: _locationCtrl.text.trim(),
          partWing: _partWingCtrl.text.trim(),
          activityDate: _activityDateCtrl.text.trim(),
          jobNo: _jobNoCtrl.text.trim(),
          drawingNo: _drawingNoCtrl.text.trim(),
          contractorName: _contractorCtrl.text.trim(),
          excavationVolume: _volumeCtrl.text.trim(),
          checklistItems: items,
          remarks: _remarksCtrl.text.trim(),
        );
      } else {
        await ApiService.createExcavationChecklist(
          projectId: widget.projectId,
          checklistNo: _checklistNo,
          checklistDate: _checklistDateCtrl.text.trim(),
          location: _locationCtrl.text.trim(),
          partWing: _partWingCtrl.text.trim(),
          activityDate: _activityDateCtrl.text.trim(),
          jobNo: _jobNoCtrl.text.trim(),
          drawingNo: _drawingNoCtrl.text.trim(),
          contractorName: _contractorCtrl.text.trim(),
          excavationVolume: _volumeCtrl.text.trim(),
          checklistItems: items,
          remarks: _remarksCtrl.text.trim(),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEdit
            ? 'Checklist updated successfully!'
            : 'Checklist created successfully!'),
        backgroundColor: AppColors.primaryGreen,
      ));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('Error: ${e is ApiException ? e.message : e}'),
        backgroundColor: const Color(0xFFEF4444),
      ));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.close, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(
            _isEdit
                ? 'Edit Excavation Checklist'
                : 'New Excavation Checklist',
            style: const TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w700,
                fontSize: 16),
          ),
          Text(widget.projectName,
              style: const TextStyle(
                  color: Color(0xFF64748B), fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _isSaving ? null : _submit,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(
                      _isEdit ? 'Update' : 'Save',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
            ),
          ),
        ],
      ),
      body: _isLoadingNo
          ? Center(
              child: CircularProgressIndicator(
                  color: AppColors.primaryGreen))
          : Form(
              key: _formKey,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                      child: _buildHeaderCard()),
                  SliverToBoxAdapter(
                      child: _buildInfoCard()),
                  SliverToBoxAdapter(
                      child: _buildChecklistTable()),
                  SliverToBoxAdapter(
                      child: _buildRemarksCard()),
                  SliverToBoxAdapter(
                      child: _buildSignatureSection()),
                  const SliverToBoxAdapter(
                      child: SizedBox(height: 40)),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard() => _card(
        title: 'Checklist Details',
        icon: Icons.info_outline,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                _label('Checklist No.'),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    border: Border.all(
                        color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        _checklistNo.isEmpty
                            ? 'Generating…'
                            : _checklistNo,
                        style: TextStyle(
                          fontSize: 13,
                          color: _checklistNo.isEmpty
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    if (_checklistNo.isEmpty)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                  ]),
                ),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                _label('Date of Checklist *'),
                _datePicker(ctrl: _checklistDateCtrl),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          _label('Project Name'),
          _readOnlyField(widget.projectName),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                _label('Date of Activity'),
                _datePicker(ctrl: _activityDateCtrl),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: _inputField(
                    _locationCtrl, 'Location',
                    hint: 'Enter location')),
            const SizedBox(width: 12),
            Expanded(
                child: _inputField(
                    _partWingCtrl, 'Part / Wing',
                    hint: 'e.g. Wing A')),
          ]),
        ]),
      );

  Widget _buildInfoCard() => _card(
        title: 'Site Information',
        icon: Icons.terrain_outlined,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(children: [
            Expanded(
                child: _inputField(
                    _jobNoCtrl, 'Job No.',
                    hint: 'Job number')),
            const SizedBox(width: 12),
            Expanded(
                child: _inputField(
                    _drawingNoCtrl, 'Drawing No.',
                    hint: 'Drawing number')),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _inputField(
                    _contractorCtrl, 'Contractor Name',
                    hint: 'Name of contractor')),
            const SizedBox(width: 12),
            Expanded(
                child: _inputField(
                    _volumeCtrl, 'Excavation Volume',
                    hint: 'Volume involved')),
          ]),
          const SizedBox(height: 8),
          const Text(
            'Architectural / Plumbing / Electrical Drawings on site',
            style: TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
                fontStyle: FontStyle.italic),
          ),
        ]),
      );

  Widget _buildChecklistTable() => _card(
        title: 'Checklist Particulars',
        icon: Icons.list_alt_outlined,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6)),
            child: const Row(children: [
              SizedBox(
                  width: 28,
                  child: Text('SR',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569)))),
              SizedBox(width: 8),
              Expanded(
                  flex: 4,
                  child: Text('PARTICULARS',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569)))),
              SizedBox(width: 8),
              SizedBox(
                  width: 72,
                  child: Text('CHECK',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569)))),
              SizedBox(width: 8),
              SizedBox(
                  width: 90,
                  child: Text('REMARK',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569)))),
            ]),
          ),
          const SizedBox(height: 4),

          // Row 0 — Job No / Drawing No (inline fields)
          _checklistRowWidget(
            index: 0,
            particular: Row(children: [
              Expanded(
                  child: _inlineField(
                      label: 'Job No:',
                      controller: _jobNoCtrl)),
              const SizedBox(width: 8),
              Expanded(
                  child: _inlineField(
                      label: 'Drawing No.:',
                      controller: _drawingNoCtrl)),
            ]),
          ),

          // Row 1 — Contractor
          _checklistRowWidget(
            index: 1,
            particular: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
              const Text('Name of Contractor:',
                  style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF374151))),
              const SizedBox(height: 4),
              _inlineField(
                  label: 'Contractor name',
                  controller: _contractorCtrl,
                  noLabel: true),
            ]),
          ),

          // Row 2 — Volume
          _checklistRowWidget(
            index: 2,
            particular: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
              const Text(
                  'Volume of excavation involved',
                  style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF374151))),
              const SizedBox(height: 4),
              _inlineField(
                  label: 'Volume',
                  controller: _volumeCtrl,
                  noLabel: true),
            ]),
          ),

          // Rows 3-13 — plain text particulars
          ...List.generate(11, (i) {
            final idx = i + 3;
            return _checklistRowWidget(
              index: idx,
              particular: Text(_kParticulars[idx],
                  style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF374151),
                      height: 1.4)),
            );
          }),
        ]),
      );

  Widget _checklistRowWidget({
    required int index,
    required Widget particular,
  }) =>
      Container(
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
              width: 28,
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(flex: 4, child: particular),
            const SizedBox(width: 8),
            SizedBox(
              width: 72,
              child: Column(children: [
                _radioCheck(
                  'Yes',
                  'yes',
                  _checks[index],
                  (v) => setState(() => _checks[index] = v),
                ),
                const SizedBox(height: 4),
                _radioCheck(
                  'No',
                  'no',
                  _checks[index],
                  (v) => setState(() => _checks[index] = v),
                ),
              ]),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 90,
              child: TextField(
                controller: _remarkCtrls[index],
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF1E293B)),
                decoration: InputDecoration(
                  hintText: 'Remark',
                  hintStyle: const TextStyle(
                      fontSize: 10, color: Color(0xFFCBD5E1)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(
                          color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(
                          color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                          color: AppColors.primaryGreen,
                          width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
                  isDense: true,
                ),
                maxLines: 2,
              ),
            ),
          ],
        ),
      );

  Widget _buildRemarksCard() => _card(
        title: 'Additional Remarks',
        icon: Icons.notes_outlined,
        child: TextField(
          controller: _remarksCtrl,
          maxLines: 4,
          style: const TextStyle(
              fontSize: 13, color: Color(0xFF1E293B)),
          decoration: InputDecoration(
            hintText: 'Any other remarks…',
            hintStyle: const TextStyle(
                fontSize: 13, color: Color(0xFFCBD5E1)),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                    color: AppColors.primaryGreen, width: 1.5)),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      );

  Widget _buildSignatureSection() => _card(
        title: 'Signatures',
        icon: Icons.draw_outlined,
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 48),
                Divider(color: AppColors.primaryGreen),
                const Text('Approved By',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text('Date:',
                    style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8))),
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
                const Text('Checked By',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text('Date:',
                    style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8))),
              ],
            ),
          ),
        ]),
      );

  // ── shared form helpers ────────────────────────────────────────────────────

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
              color: AppColors.primaryGreen
                  .withValues(alpha: 0.2)),
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
              padding:
                  const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen
                    .withValues(alpha: 0.06),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12)),
              ),
              child: Row(children: [
                Icon(icon,
                    size: 15, color: AppColors.primaryGreen),
                const SizedBox(width: 8),
                Text(title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryGreen,
                    )),
              ]),
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
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151))),
      );

  Widget _readOnlyField(String value) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          border:
              Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(value,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF64748B))),
      );

  Widget _inputField(
    TextEditingController ctrl,
    String label, {
    String? hint,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          TextField(
            controller: ctrl,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF1E293B)),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                  fontSize: 13, color: Color(0xFFCBD5E1)),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                      color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                      color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                      color: AppColors.primaryGreen,
                      width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 11),
              isDense: true,
            ),
          ),
        ],
      );

  Widget _datePicker({required TextEditingController ctrl}) =>
      GestureDetector(
        onTap: () => _pickDate(ctrl),
        child: AbsorbPointer(
          child: TextField(
            controller: ctrl,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF1E293B)),
            decoration: InputDecoration(
              hintText: 'yyyy-MM-dd',
              hintStyle: const TextStyle(
                  fontSize: 13, color: Color(0xFFCBD5E1)),
              suffixIcon: const Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: Color(0xFF94A3B8)),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                      color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                      color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                      color: AppColors.primaryGreen,
                      width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 11),
              isDense: true,
            ),
          ),
        ),
      );

  Widget _inlineField({
    required String label,
    required TextEditingController controller,
    bool noLabel = false,
  }) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        if (!noLabel) ...[
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF374151))),
          const SizedBox(height: 2),
        ],
        TextField(
          controller: controller,
          style: const TextStyle(
              fontSize: 11, color: Color(0xFF1E293B)),
          decoration: InputDecoration(
            hintText: noLabel ? label : null,
            hintStyle: const TextStyle(
                fontSize: 10, color: Color(0xFFCBD5E1)),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(
                    color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(
                    color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                    color: AppColors.primaryGreen,
                    width: 1)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 6, vertical: 6),
            isDense: true,
          ),
        ),
      ]);

  Widget _radioCheck(
    String label,
    String value,
    String? groupValue,
    ValueChanged<String?> onChanged,
  ) {
    final selected = groupValue == value;
    final color = value == 'yes'
        ? const Color(0xFF22C55E)
        : const Color(0xFFEF4444);
    return GestureDetector(
      onTap: () => onChanged(selected ? null : value),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.12)
              : Colors.white,
          border: Border.all(
              color: selected
                  ? color
                  : const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            selected
                ? (value == 'yes'
                    ? Icons.check_circle
                    : Icons.cancel)
                : Icons.radio_button_unchecked,
            size: 12,
            color:
                selected ? color : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: selected
                      ? color
                      : const Color(0xFF64748B),
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Detail Page
// ═══════════════════════════════════════════════════════════════════════════

class ExcavationChecklistDetailPage extends StatelessWidget {
  final ExcavationChecklistModel checklist;
  final String projectName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ExcavationChecklistDetailPage({
    super.key,
    required this.checklist,
    required this.projectName,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          const Text('Excavation Checklist',
              style: TextStyle(
                  color: Color(0xFF1E293B),
                  fontWeight: FontWeight.w700,
                  fontSize: 16)),
          Text(checklist.checklistNo,
              style: const TextStyle(
                  color: Color(0xFF64748B), fontSize: 12)),
        ]),
        actions: [
          IconButton(
              icon: const Icon(Icons.edit_outlined,
                  color: Color(0xFFF59E0B)),
              onPressed: onEdit,
              tooltip: 'Edit'),
          IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Color(0xFFEF4444)),
              onPressed: onDelete,
              tooltip: 'Delete'),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionCard(
              title: 'WR/EXE/02 — Checklist for Excavation',
              icon: Icons.terrain_outlined,
              children: [
                _row2('Checklist No.', checklist.checklistNo,
                    'Date', _fmtDate(checklist.checklistDate)),
                const SizedBox(height: 10),
                _infoRow('Project', projectName),
                const SizedBox(height: 8),
                _row2('Location', checklist.location,
                    'Part / Wing', checklist.partWing),
                const SizedBox(height: 8),
                _row2('Date of Activity',
                    _fmtDate(checklist.activityDate),
                    'Contractor', checklist.contractorName),
                const SizedBox(height: 8),
                _row2('Job No.', checklist.jobNo,
                    'Drawing No.', checklist.drawingNo),
                const SizedBox(height: 8),
                _infoRow('Excavation Volume',
                    checklist.excavationVolume),
              ],
            ),
            const SizedBox(height: 12),
            _sectionCard(
              title: 'Checklist Items',
              icon: Icons.list_alt_outlined,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Table(
                    border: TableBorder.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1),
                    columnWidths: const {
                      0: FixedColumnWidth(28),
                      1: FlexColumnWidth(4),
                      2: FixedColumnWidth(52),
                      3: FlexColumnWidth(2),
                    },
                    children: [
                      const TableRow(
                        decoration: BoxDecoration(
                            color: Color(0xFFF1F5F9)),
                        children: [
                          _StaticTh('SR'),
                          _StaticTh('PARTICULARS'),
                          _StaticTh('CHECK'),
                          _StaticTh('REMARK'),
                        ],
                      ),
                      ...List.generate(14, (i) {
                        final item =
                            i < checklist.checklistItems.length
                                ? checklist.checklistItems[i]
                                : null;
                        final checkVal =
                            item?.check?.toUpperCase() ?? '—';
                        final remarkVal = item?.remark ?? '';
                        final particular = i == 0
                            ? 'Job No: ${checklist.jobNo ?? '—'}  |  Drawing No: ${checklist.drawingNo ?? '—'}'
                            : i == 1
                                ? 'Contractor: ${checklist.contractorName ?? '—'}'
                                : i == 2
                                    ? 'Volume: ${checklist.excavationVolume ?? '—'}'
                                    : _kParticulars[i];
                        return TableRow(children: [
                          _td('${i + 1}'),
                          _tdLeft(particular),
                          _tdCheck(checkVal),
                          _tdLeft(remarkVal.isEmpty
                              ? '—'
                              : remarkVal),
                        ]);
                      }),
                    ],
                  ),
                ),
              ],
            ),
            if (checklist.remarks != null &&
                checklist.remarks!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _sectionCard(
                title: 'Additional Remarks',
                icon: Icons.notes_outlined,
                children: [
                  Text(checklist.remarks!,
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF374151),
                          height: 1.5)),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.center,
                    children: const [
                      SizedBox(height: 40),
                      Divider(color: Color(0xFF1E293B)),
                      Text('Approved By',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.center,
                    children: const [
                      SizedBox(height: 40),
                      Divider(color: Color(0xFF1E293B)),
                      Text('Checked By',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ]),
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
            padding:
                const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen
                  .withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10)),
            ),
            child: Row(children: [
              Icon(icon,
                  size: 15, color: AppColors.primaryGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryGreen,
                    )),
              ),
            ]),
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

  Widget _row2(
          String l1, String? v1, String l2, String? v2) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Expanded(child: _infoRow(l1, v1)),
        const SizedBox(width: 12),
        Expanded(child: _infoRow(l2, v2)),
      ]);

  Widget _infoRow(String label, String? value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3)),
          const SizedBox(height: 2),
          Text(
            value?.isNotEmpty == true ? value! : 'N/A',
            style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w500),
          ),
        ],
      );

  static Widget _td(String text) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 11, color: Color(0xFF1E293B))),
      );

  static Widget _tdLeft(String text) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11, color: Color(0xFF1E293B))),
      );

  static Widget _tdCheck(String checkVal) {
    Color color;
    IconData icon;
    String label;
    if (checkVal == 'YES') {
      color = const Color(0xFF22C55E);
      icon = Icons.check_circle;
      label = 'Yes';
    } else if (checkVal == 'NO') {
      color = const Color(0xFFEF4444);
      icon = Icons.cancel;
      label = 'No';
    } else {
      color = const Color(0xFF94A3B8);
      icon = Icons.remove;
      label = '—';
    }
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

// ── Static table header cell ───────────────────────────────────────────────

class _StaticTh extends StatelessWidget {
  final String text;
  const _StaticTh(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569))),
      );
}