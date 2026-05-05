// lib/features/re_execution/presentation/re_execution_form_page.dart
//
// Matches the blade form exactly:
//  A. Detailed Labor Report       ← horizontal-scrollable table
//  B. Progress (Previous Day)     ← horizontal-scrollable table
//     Works Planned for Today     ← horizontal-scrollable table
//  C. Decisions / Approvals
//  Progress Photos
//  Bottle Necks / Problem Areas
//  Change Authorizations / RFIs Submitted
//  Material Delivered to Site (This Date)
//  EHS Incident Reports / Near Misses (This Date)

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/auth_storage_service.dart';
import '../../../../core/utils/api_exception.dart';
import '../data/models/re_execution_model.dart';
import '../data/services/re_execution_api_service.dart';

// ─── Column width constants ───────────────────────────────────────────────────
const double _kAgencyCol   = 130.0;
const double _kNumCol      =  64.0;
const double _kTotalCol    =  72.0;
const double _kRemarksCol  = 120.0;
const double _kActivityCol = 160.0;
const double _kPctCol      =  64.0;
const double _kQtyCol      =  72.0;
const double _kPlannedQCol =  80.0;

class ReExecutionFormPage extends StatefulWidget {
  final int projectId;
  final String projectName;
  final int? reportId;

  const ReExecutionFormPage({
    super.key,
    required this.projectId,
    required this.projectName,
    this.reportId,
  });

  @override
  State<ReExecutionFormPage> createState() => _ReExecutionFormPageState();
}

class _ReExecutionFormPageState extends State<ReExecutionFormPage> {
  final _formKey = GlobalKey<FormState>();

  // ── Report date ────────────────────────────────────────────────────────────
  DateTime _reportDate = DateTime.now();

  // ── Labor agencies ─────────────────────────────────────────────────────────
  final List<Map<String, TextEditingController>> _laborRows = [];

  // ── Progress tables ────────────────────────────────────────────────────────
  final List<Map<String, TextEditingController>> _progressRows = [];
  final List<Map<String, TextEditingController>> _plannedRows  = [];

  // ── Text-area controllers ──────────────────────────────────────────────────
  final _decisionsCtrl   = TextEditingController();
  final _bottleNecksCtrl = TextEditingController();
  final _changeAuthCtrl  = TextEditingController();
  final _materialCtrl    = TextEditingController();
  final _ehsCtrl         = TextEditingController();

  // ── Photo upload ───────────────────────────────────────────────────────────
  final List<PlatformFile>       _newPhotos       = [];
  List<Map<String, dynamic>>     _existingPhotos  = [];
  final List<String>             _deletedPhotoIds = [];
  bool _isPickingPhoto = false;

  // ── State flags ────────────────────────────────────────────────────────────
  bool    _isLoadingEdit = false;
  bool    _isSaving      = false;
  String? _loadError;

  bool get _isEdit => widget.reportId != null;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _addLaborRow();
    _addProgressRow();
    _addPlannedRow();
    if (_isEdit) _loadExisting();
  }

  @override
  void dispose() {
    for (final row in _laborRows)    { row.values.forEach((c) => c.dispose()); }
    for (final row in _progressRows) { row.values.forEach((c) => c.dispose()); }
    for (final row in _plannedRows)  { row.values.forEach((c) => c.dispose()); }
    _decisionsCtrl.dispose();
    _bottleNecksCtrl.dispose();
    _changeAuthCtrl.dispose();
    _materialCtrl.dispose();
    _ehsCtrl.dispose();
    super.dispose();
  }

  // ── Row helpers ────────────────────────────────────────────────────────────

  void _addLaborRow({Map<String, dynamic>? data}) {
    _laborRows.add({
      'agency':          TextEditingController(text: data?['agency']?.toString() ?? ''),
      'sup_day':         TextEditingController(text: data?['sup_day']?.toString() ?? '0'),
      'skilled_day':     TextEditingController(text: data?['skilled_day']?.toString() ?? '0'),
      'unskilled_day':   TextEditingController(text: data?['unskilled_day']?.toString() ?? '0'),
      'sup_night':       TextEditingController(text: data?['sup_night']?.toString() ?? '0'),
      'skilled_night':   TextEditingController(text: data?['skilled_night']?.toString() ?? '0'),
      'unskilled_night': TextEditingController(text: data?['unskilled_night']?.toString() ?? '0'),
      'remarks':         TextEditingController(text: data?['remarks']?.toString() ?? ''),
    });
  }

  void _removeLaborRow(int i) {
    if (_laborRows.length <= 1) return;
    _laborRows[i].values.forEach((c) => c.dispose());
    setState(() => _laborRows.removeAt(i));
  }

  void _addProgressRow({Map<String, dynamic>? data}) {
    _progressRows.add({
      'activity':           TextEditingController(text: data?['activity']?.toString() ?? ''),
      'planned_percentage': TextEditingController(text: data?['planned_percentage']?.toString() ?? ''),
      'actual_percentage':  TextEditingController(text: data?['actual_percentage']?.toString() ?? ''),
      'planned_qty':        TextEditingController(text: data?['planned_qty']?.toString() ?? ''),
      'actual_qty':         TextEditingController(text: data?['actual_qty']?.toString() ?? ''),
      'remarks':            TextEditingController(text: data?['remarks']?.toString() ?? ''),
    });
  }

  void _removeProgressRow(int i) {
    if (_progressRows.length <= 1) return;
    _progressRows[i].values.forEach((c) => c.dispose());
    setState(() => _progressRows.removeAt(i));
  }

  void _addPlannedRow({Map<String, dynamic>? data}) {
    _plannedRows.add({
      'activity':         TextEditingController(text: data?['activity']?.toString() ?? ''),
      'planned_quantity': TextEditingController(text: data?['planned_quantity']?.toString() ?? ''),
      'remarks':          TextEditingController(text: data?['remarks']?.toString() ?? ''),
    });
  }

  void _removePlannedRow(int i) {
    if (_plannedRows.length <= 1) return;
    _plannedRows[i].values.forEach((c) => c.dispose());
    setState(() => _plannedRows.removeAt(i));
  }

  // ── Photo helpers ──────────────────────────────────────────────────────────

  Future<void> _pickPhotos() async {
    if (_isPickingPhoto) return;
    setState(() => _isPickingPhoto = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: false,
        type: FileType.any,
      );
      if (result != null && result.files.isNotEmpty && mounted) {
        setState(() => _newPhotos.addAll(result.files));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not open file picker: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ));
      }
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  void _removeNewPhoto(int i) => setState(() => _newPhotos.removeAt(i));

  void _markExistingPhotoDeleted(String photoId) {
    setState(() {
      _deletedPhotoIds.add(photoId);
      _existingPhotos.removeWhere((p) => p['id']?.toString() == photoId);
    });
  }

  String _formatBytes(dynamic bytes) {
    final b = int.tryParse(bytes?.toString() ?? '0') ?? 0;
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ── Load existing (edit mode) ──────────────────────────────────────────────

  Future<void> _loadExisting() async {
    if (!mounted) return;
    setState(() { _isLoadingEdit = true; _loadError = null; });
    try {
      final r = await ReExecutionApiService.fetchReportDetail(
        projectId: widget.projectId,
        reportId:  widget.reportId!,
      );
      if (!mounted) return;

      if (r.reportDate != null) {
        final parts = r.reportDate!.split('-');
        if (parts.length == 3) {
          _reportDate = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
        }
      }

      for (final row in _laborRows) { row.values.forEach((c) => c.dispose()); }
      _laborRows.clear();
      if (r.laborAgencies.isNotEmpty) {
        for (final l in r.laborAgencies) _addLaborRow(data: l);
      } else {
        _addLaborRow();
      }

      for (final row in _progressRows) { row.values.forEach((c) => c.dispose()); }
      _progressRows.clear();
      if (r.previousProgress.isNotEmpty) {
        for (final p in r.previousProgress) _addProgressRow(data: p);
      } else {
        _addProgressRow();
      }

      for (final row in _plannedRows) { row.values.forEach((c) => c.dispose()); }
      _plannedRows.clear();
      if (r.plannedWorks.isNotEmpty) {
        for (final w in r.plannedWorks) _addPlannedRow(data: w);
      } else {
        _addPlannedRow();
      }

      _decisionsCtrl.text   = r.decisionsApprovals;
      _existingPhotos       = List<Map<String, dynamic>>.from(r.progressPhotos);
      _bottleNecksCtrl.text = r.bottleNecks;
      _changeAuthCtrl.text  = r.changeAuthorizations;
      _materialCtrl.text    = r.materialDelivered;
      _ehsCtrl.text         = r.ehsIncidentReports;

      setState(() => _isLoadingEdit = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError     = e is ApiException ? e.message : e.toString();
        _isLoadingEdit = false;
      });
    }
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final dateStr =
        '${_reportDate.year}-${_reportDate.month.toString().padLeft(2, '0')}-${_reportDate.day.toString().padLeft(2, '0')}';

    final laborData = _laborRows
        .where((r) => r['agency']!.text.trim().isNotEmpty)
        .map((r) => {
              'agency':          r['agency']!.text.trim(),
              'sup_day':         int.tryParse(r['sup_day']!.text) ?? 0,
              'skilled_day':     int.tryParse(r['skilled_day']!.text) ?? 0,
              'unskilled_day':   int.tryParse(r['unskilled_day']!.text) ?? 0,
              'sup_night':       int.tryParse(r['sup_night']!.text) ?? 0,
              'skilled_night':   int.tryParse(r['skilled_night']!.text) ?? 0,
              'unskilled_night': int.tryParse(r['unskilled_night']!.text) ?? 0,
              'remarks':         r['remarks']!.text.trim(),
            })
        .toList();

    final progressData = _progressRows
        .where((r) => r['activity']!.text.trim().isNotEmpty)
        .map((r) => {
              'activity':           r['activity']!.text.trim(),
              'planned_percentage': r['planned_percentage']!.text.trim(),
              'actual_percentage':  r['actual_percentage']!.text.trim(),
              'planned_qty':        r['planned_qty']!.text.trim(),
              'actual_qty':         r['actual_qty']!.text.trim(),
              'remarks':            r['remarks']!.text.trim(),
            })
        .toList();

    final plannedData = _plannedRows
        .where((r) => r['activity']!.text.trim().isNotEmpty)
        .map((r) => {
              'activity':         r['activity']!.text.trim(),
              'planned_quantity': r['planned_quantity']!.text.trim(),
              'remarks':          r['remarks']!.text.trim(),
            })
        .toList();

    try {
      final token = await AuthStorageService.getToken();
      if (token == null) throw ApiException('Session expired.');

      final endpoint = _isEdit
          ? ApiConstants.reExecutionUpdate(widget.projectId, widget.reportId!)
          : ApiConstants.reExecutionCreate(widget.projectId);

      final uri     = Uri.parse(endpoint);
      final request = http.MultipartRequest('POST', uri);

      if (_isEdit) request.fields['_method'] = 'PUT';

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept']        = 'application/json';

      request.fields['report_date']           = dateStr;
      request.fields['decisions_approvals']   = _decisionsCtrl.text;
      request.fields['bottle_necks']          = _bottleNecksCtrl.text;
      request.fields['change_authorizations'] = _changeAuthCtrl.text;
      request.fields['material_delivered']    = _materialCtrl.text;
      request.fields['ehs_incident_reports']  = _ehsCtrl.text;

      for (int i = 0; i < laborData.length; i++) {
        final l = laborData[i];
        request.fields['labor_agencies[$i][agency]']          = l['agency'].toString();
        request.fields['labor_agencies[$i][sup_day]']         = l['sup_day'].toString();
        request.fields['labor_agencies[$i][skilled_day]']     = l['skilled_day'].toString();
        request.fields['labor_agencies[$i][unskilled_day]']   = l['unskilled_day'].toString();
        request.fields['labor_agencies[$i][sup_night]']       = l['sup_night'].toString();
        request.fields['labor_agencies[$i][skilled_night]']   = l['skilled_night'].toString();
        request.fields['labor_agencies[$i][unskilled_night]'] = l['unskilled_night'].toString();
        request.fields['labor_agencies[$i][remarks]']         = l['remarks'].toString();
      }

      for (int i = 0; i < progressData.length; i++) {
        final p = progressData[i];
        request.fields['previous_progress[$i][activity]']           = p['activity'].toString();
        request.fields['previous_progress[$i][planned_percentage]'] = p['planned_percentage'].toString();
        request.fields['previous_progress[$i][actual_percentage]']  = p['actual_percentage'].toString();
        request.fields['previous_progress[$i][planned_qty]']        = p['planned_qty'].toString();
        request.fields['previous_progress[$i][actual_qty]']         = p['actual_qty'].toString();
        request.fields['previous_progress[$i][remarks]']            = p['remarks'].toString();
      }

      for (int i = 0; i < plannedData.length; i++) {
        final w = plannedData[i];
        request.fields['planned_works[$i][activity]']         = w['activity'].toString();
        request.fields['planned_works[$i][planned_quantity]'] = w['planned_quantity'].toString();
        request.fields['planned_works[$i][remarks]']          = w['remarks'].toString();
      }

      for (int i = 0; i < _deletedPhotoIds.length; i++) {
        request.fields['deleted_photos[$i]'] = _deletedPhotoIds[i];
      }

      for (final f in _newPhotos) {
        if (f.path == null) continue;
        final mime  = lookupMimeType(f.path!) ?? 'application/octet-stream';
        final parts = mime.split('/');
        request.files.add(await http.MultipartFile.fromPath(
          'progress_photos[]',
          f.path!,
          filename: f.name,
          contentType: MediaType(parts[0], parts[1]),
        ));
      }

      final streamed = await request.send().timeout(const Duration(seconds: 120));
      final response = await http.Response.fromStream(streamed);

      if (!mounted) return;

      dynamic decoded;
      try { decoded = jsonDecode(response.body); } catch (_) { decoded = {'message': response.body}; }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            (decoded is Map ? decoded['message']?.toString() : null) ??
                (_isEdit ? 'Report updated successfully' : 'Report created successfully'),
          ),
          backgroundColor: AppColors.primaryGreen,
        ));
        Navigator.pop(context, true);
      } else {
        final msg = (decoded is Map ? decoded['message']?.toString() : null) ??
            'Save failed (${response.statusCode})';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: const Color(0xFFEF4444),
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: const Color(0xFFEF4444),
      ));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Date picker ────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _reportDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.light(primary: AppColors.primaryGreen)),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _reportDate = picked);
  }

  String get _formattedDate =>
      '${_reportDate.day.toString().padLeft(2, '0')} '
      '${_monthName(_reportDate.month)} '
      '${_reportDate.year}';

  String _monthName(int m) =>
      ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
       'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            _isEdit ? 'Edit Daily Progress Report' : 'New Daily Progress Report',
            style: const TextStyle(
                color: Color(0xFF1E293B), fontWeight: FontWeight.w700, fontSize: 15),
          ),
          Text(widget.projectName,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
        ]),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(
                    _isEdit ? 'Update' : 'Submit',
                    style: TextStyle(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w700),
                  ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE2E8F0)),
        ),
      ),
      body: _isLoadingEdit
          ? Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : _loadError != null
              ? _buildErrorBody()
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildDateCard(),
                      const SizedBox(height: 12),

                      // A. Labor table
                      _buildLaborSection(),
                      const SizedBox(height: 12),

                      // B. Progress (previous day) table
                      _buildProgressSection(),
                      const SizedBox(height: 12),

                      // B. Works planned for today table
                      _buildPlannedWorksSection(),
                      const SizedBox(height: 12),

                      // C. Decisions / Approvals
                      _buildTextareaSection(
                        'C. Decisions / Approvals',
                        _decisionsCtrl,
                        Icons.gavel_outlined,
                      ),
                      const SizedBox(height: 12),

                      // Progress Photos
                      _buildPhotosSection(),
                      const SizedBox(height: 12),

                      // Bottle Necks
                      _buildTextareaSection(
                        'Bottle Necks / Problem Areas',
                        _bottleNecksCtrl,
                        Icons.warning_amber_outlined,
                        hint: 'Describe any bottlenecks or problem areas encountered...',
                      ),
                      const SizedBox(height: 12),

                      // Change Authorizations
                      _buildTextareaSection(
                        'Change Authorizations / RFIs Submitted',
                        _changeAuthCtrl,
                        Icons.swap_horiz_outlined,
                        hint: 'List any change authorizations or RFIs submitted...',
                      ),
                      const SizedBox(height: 12),

                      // Material Delivered
                      _buildTextareaSection(
                        'Material Delivered to Site (This Date)',
                        _materialCtrl,
                        Icons.local_shipping_outlined,
                        hint: 'List materials delivered to the site...',
                      ),
                      const SizedBox(height: 12),

                      // EHS
                      _buildTextareaSection(
                        'EHS Incident Reports / Near Misses (This Date)',
                        _ehsCtrl,
                        Icons.health_and_safety_outlined,
                        hint: 'Report any EHS incidents or near misses...',
                      ),
                      const SizedBox(height: 24),

                      ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text(
                                _isEdit ? 'Update Report' : 'Submit Report',
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorBody() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_outlined, color: Color(0xFFEF4444), size: 48),
          const SizedBox(height: 12),
          Text(_loadError!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadExisting,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white),
            child: const Text('Retry'),
          ),
        ]),
      );

  // ── Date card ──────────────────────────────────────────────────────────────

  Widget _buildDateCard() => _sectionCard(
        title: 'Report Date',
        icon: Icons.calendar_today_outlined,
        children: [
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFD1D5DB)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Expanded(
                  child: Text(_formattedDate,
                      style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B))),
                ),
                Icon(Icons.calendar_today_outlined,
                    size: 18, color: AppColors.primaryGreen),
              ]),
            ),
          ),
        ],
      );

  // ═══════════════════════════════════════════════════════════════════════════
  // A. DETAILED LABOR REPORT — horizontal scrollable table
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildLaborSection() {
    // Compute column totals
    int totalSupDay = 0, totalSkdDay = 0, totalUskDay = 0;
    int totalSupNgt = 0, totalSkdNgt = 0, totalUskNgt = 0;
    for (final row in _laborRows) {
      totalSupDay += int.tryParse(row['sup_day']!.text) ?? 0;
      totalSkdDay += int.tryParse(row['skilled_day']!.text) ?? 0;
      totalUskDay += int.tryParse(row['unskilled_day']!.text) ?? 0;
      totalSupNgt += int.tryParse(row['sup_night']!.text) ?? 0;
      totalSkdNgt += int.tryParse(row['skilled_night']!.text) ?? 0;
      totalUskNgt += int.tryParse(row['unskilled_night']!.text) ?? 0;
    }
    final dayTotal   = totalSupDay + totalSkdDay + totalUskDay;
    final nightTotal = totalSupNgt + totalSkdNgt + totalUskNgt;

    // Table total row width
    const double tableWidth = 36 + _kAgencyCol + _kNumCol * 6 + _kTotalCol + _kRemarksCol + 40;

    return _sectionCard(
      title: 'A. Detailed Labor Report',
      icon: Icons.people_outline,
      noPadding: true,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ──────────────────────────────────────────────
              _laborHeaderRow(),

              // ── Data rows ───────────────────────────────────────────────
              ..._laborRows.asMap().entries.map((e) => _laborDataRow(e.key, e.value)),

              // ── Column totals row ───────────────────────────────────────
              _laborTotalsRow(
                totalSupDay, totalSkdDay, totalUskDay,
                totalSupNgt, totalSkdNgt, totalUskNgt,
              ),

              // ── Day / Night total row ───────────────────────────────────
              Container(
                width: tableWidth,
                color: const Color(0xFFF1F5F9),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _totalBadge('Day Total:', dayTotal),
                    const SizedBox(width: 24),
                    _totalBadge('Night Total:', nightTotal),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Add Row button ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: _addRowButton(() => setState(() => _addLaborRow())),
        ),
      ],
    );
  }

  Widget _laborHeaderRow() {
    const hStyle = TextStyle(
        fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF374151));
    return Container(
      color: const Color(0xFFE5E7EB),
      child: Row(children: [
        // SR.NO
        _hCell('SR.NO', width: 36, center: true),
        // Agency
        _hCell('AGENCY', width: _kAgencyCol),
        // Manpower Day group
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: _kNumCol * 3,
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFD1D5DB))),
            ),
            child: const Text('MANPOWER (DAY)', style: hStyle),
          ),
          Row(children: [
            _hCell('SUP',      width: _kNumCol, center: true),
            _hCell('SKILLED',  width: _kNumCol, center: true),
            _hCell('UNSKILLED',width: _kNumCol, center: true),
          ]),
        ]),
        // Manpower Night group
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: _kNumCol * 3,
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFD1D5DB))),
            ),
            child: const Text('MANPOWER YESTERDAY (NIGHT)', style: hStyle),
          ),
          Row(children: [
            _hCell('SUP',      width: _kNumCol, center: true),
            _hCell('SKILLED',  width: _kNumCol, center: true),
            _hCell('UNSKILLED',width: _kNumCol, center: true),
          ]),
        ]),
        _hCell('TOTAL\nMANPOWER', width: _kTotalCol, center: true),
        _hCell('REMARKS',         width: _kRemarksCol),
        // action col
        const SizedBox(width: 40),
      ]),
    );
  }

  Widget _laborDataRow(int idx, Map<String, TextEditingController> row) {
    return StatefulBuilder(builder: (context, localSet) {
      // recompute total manpower for this row on each rebuild
      final total = (int.tryParse(row['sup_day']!.text) ?? 0)
          + (int.tryParse(row['skilled_day']!.text) ?? 0)
          + (int.tryParse(row['unskilled_day']!.text) ?? 0)
          + (int.tryParse(row['sup_night']!.text) ?? 0)
          + (int.tryParse(row['skilled_night']!.text) ?? 0)
          + (int.tryParse(row['unskilled_night']!.text) ?? 0);

      void refresh() { localSet(() {}); setState(() {}); }

      final bg = idx.isOdd ? const Color(0xFFF9FAFB) : Colors.white;
      return Container(
        color: bg,
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // SR.NO
          _srCell(idx + 1),
          // Agency
          _tableInputCell(row['agency']!, width: _kAgencyCol, hint: 'Agency name'),
          // Day nums
          _tableNumCell(row['sup_day']!,       width: _kNumCol, onChanged: (_) => refresh()),
          _tableNumCell(row['skilled_day']!,   width: _kNumCol, onChanged: (_) => refresh()),
          _tableNumCell(row['unskilled_day']!, width: _kNumCol, onChanged: (_) => refresh()),
          // Night nums
          _tableNumCell(row['sup_night']!,       width: _kNumCol, onChanged: (_) => refresh()),
          _tableNumCell(row['skilled_night']!,   width: _kNumCol, onChanged: (_) => refresh()),
          _tableNumCell(row['unskilled_night']!, width: _kNumCol, onChanged: (_) => refresh()),
          // Total manpower
          SizedBox(
            width: _kTotalCol,
            child: Center(
              child: Text(
                '$total',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryGreen),
              ),
            ),
          ),
          // Remarks
          _tableInputCell(row['remarks']!, width: _kRemarksCol, hint: 'Remarks'),
          // Remove
          _removeBtn(() => _removeLaborRow(idx), show: _laborRows.length > 1),
        ]),
      );
    });
  }

  Widget _laborTotalsRow(
      int supD, int skdD, int uskD, int supN, int skdN, int uskN) {
    const style = TextStyle(
        fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151));
    return Container(
      color: const Color(0xFFF1F5F9),
      child: Row(children: [
        const SizedBox(width: 36),
        SizedBox(
          width: _kAgencyCol,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Text('Total', style: style),
          ),
        ),
        _totalNumCell(supD),
        _totalNumCell(skdD),
        _totalNumCell(uskD),
        _totalNumCell(supN),
        _totalNumCell(skdN),
        _totalNumCell(uskN),
        const SizedBox(width: _kTotalCol),
        const SizedBox(width: _kRemarksCol),
        const SizedBox(width: 40),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // B. PROGRESS ACHIEVED (Previous Day) — horizontal scrollable table
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildProgressSection() {
    return _sectionCard(
      title: 'B. Progress Achieved (Previous Day)',
      icon: Icons.trending_up_outlined,
      noPadding: true,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _progressHeaderRow(),
              // Data rows
              ..._progressRows.asMap().entries.map((e) => _progressDataRow(e.key, e.value)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: _addRowButton(() => setState(() => _addProgressRow())),
        ),
      ],
    );
  }

  Widget _progressHeaderRow() {
    return Container(
      color: const Color(0xFFE5E7EB),
      child: Row(children: [
        _hCell('SR.NO',    width: 36, center: true),
        _hCell('ACTIVITY', width: _kActivityCol),
        // Percentage group
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _groupHeader('PERCENTAGE', width: _kPctCol * 2),
          Row(children: [
            _hCell('PLANNED', width: _kPctCol, center: true),
            _hCell('ACTUAL',  width: _kPctCol, center: true),
          ]),
        ]),
        // Cumulative Qty group
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _groupHeader('CUMULATIVE QTY', width: _kQtyCol * 2),
          Row(children: [
            _hCell('PLANNED', width: _kQtyCol, center: true),
            _hCell('ACTUAL',  width: _kQtyCol, center: true),
          ]),
        ]),
        _hCell('REMARKS / REASONS OF DELAY\n(IF ANY)', width: _kRemarksCol + 60),
        const SizedBox(width: 40),
      ]),
    );
  }

  Widget _progressDataRow(int idx, Map<String, TextEditingController> row) {
    final bg = idx.isOdd ? const Color(0xFFF9FAFB) : Colors.white;
    return Container(
      color: bg,
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        _srCell(idx + 1),
        _tableInputCell(row['activity']!,           width: _kActivityCol,       hint: 'Activity'),
        _tableInputCell(row['planned_percentage']!, width: _kPctCol,  hint: '', center: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true)),
        _tableInputCell(row['actual_percentage']!,  width: _kPctCol,  hint: '', center: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true)),
        _tableInputCell(row['planned_qty']!,        width: _kQtyCol,  hint: '', center: true),
        _tableInputCell(row['actual_qty']!,         width: _kQtyCol,  hint: '', center: true),
        _tableInputCell(row['remarks']!,            width: _kRemarksCol + 60,   hint: 'Remarks / Reason'),
        _removeBtn(() => _removeProgressRow(idx), show: _progressRows.length > 1),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // B. WORKS PLANNED FOR TODAY — horizontal scrollable table
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPlannedWorksSection() {
    return _sectionCard(
      title: 'Works Planned for Today',
      icon: Icons.checklist_outlined,
      noPadding: true,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _plannedHeaderRow(),
              // Data rows
              ..._plannedRows.asMap().entries.map((e) => _plannedDataRow(e.key, e.value)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: _addRowButton(() => setState(() => _addPlannedRow())),
        ),
      ],
    );
  }

  Widget _plannedHeaderRow() {
    return Container(
      color: const Color(0xFFE5E7EB),
      child: Row(children: [
        _hCell('S.NO',             width: 36, center: true),
        _hCell('ACTIVITY',         width: _kActivityCol),
        _hCell('PLANNED\nQUANTITY', width: _kPlannedQCol, center: true),
        _hCell('REMARKS',          width: _kRemarksCol + 80),
        const SizedBox(width: 40),
      ]),
    );
  }

  Widget _plannedDataRow(int idx, Map<String, TextEditingController> row) {
    final bg = idx.isOdd ? const Color(0xFFF9FAFB) : Colors.white;
    return Container(
      color: bg,
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        _srCell(idx + 1),
        _tableInputCell(row['activity']!,         width: _kActivityCol,      hint: 'Activity'),
        _tableInputCell(row['planned_quantity']!, width: _kPlannedQCol,      hint: '', center: true),
        _tableInputCell(row['remarks']!,          width: _kRemarksCol + 80,  hint: 'Remarks'),
        _removeBtn(() => _removePlannedRow(idx), show: _plannedRows.length > 1),
      ]),
    );
  }

  // ── Progress Photos section ────────────────────────────────────────────────

  Widget _buildPhotosSection() => _sectionCard(
        title: 'Progress Photos',
        icon: Icons.photo_library_outlined,
        children: [
          GestureDetector(
            onTap: _isPickingPhoto ? null : _pickPhotos,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                    color: AppColors.primaryGreen.withValues(alpha: 0.5),
                    style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(8),
                color: AppColors.primaryGreen.withValues(alpha: 0.04),
              ),
              child: _isPickingPhoto
                  ? Center(
                      child: SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primaryGreen),
                      ),
                    )
                  : Column(children: [
                      Icon(Icons.cloud_upload_outlined,
                          size: 36, color: AppColors.primaryGreen),
                      const SizedBox(height: 8),
                      Text('Upload Files (Images, Videos, Documents)',
                          style: TextStyle(
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                      const SizedBox(height: 4),
                      const Text('Maximum file size: 50MB per file',
                          style: TextStyle(
                              color: Color(0xFF94A3B8), fontSize: 11)),
                    ]),
            ),
          ),
          if (_newPhotos.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('${_newPhotos.length} file(s) selected:',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: Color(0xFF374151))),
            const SizedBox(height: 6),
            ..._newPhotos.asMap().entries.map((e) {
              final idx = e.key;
              final f   = e.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: AppColors.primaryGreen.withValues(alpha: 0.25)),
                ),
                child: Row(children: [
                  Icon(_fileIcon(f.extension), size: 16, color: AppColors.primaryGreen),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(f.name,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500,
                            color: Color(0xFF1E293B)),
                        overflow: TextOverflow.ellipsis),
                    Text(_formatBytes(f.size),
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF94A3B8))),
                  ])),
                  GestureDetector(
                    onTap: () => _removeNewPhoto(idx),
                    child: const Icon(Icons.close,
                        size: 16, color: Color(0xFF94A3B8)),
                  ),
                ]),
              );
            }),
          ],
          if (_existingPhotos.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('Uploaded Files:',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: Color(0xFF374151))),
            const SizedBox(height: 8),
            ..._existingPhotos.map((photo) {
              final photoId    = photo['id']?.toString() ?? '';
              final name       = photo['original_name']?.toString() ?? 'File';
              final mime       = photo['mimeType']?.toString() ?? '';
              final link       = photo['webViewLink']?.toString() ?? '';
              final size       = photo['size'];
              final uploadedAt = photo['uploaded_at']?.toString() ?? '';
              final isImage    = mime.contains('image');

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: isImage && link.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              photo['thumbnailLink']?.toString() ?? link,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                  Icons.image_outlined,
                                  color: AppColors.primaryGreen),
                            ),
                          )
                        : Icon(_fileIconFromMime(mime),
                            color: AppColors.primaryGreen),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500,
                            color: Color(0xFF1E293B)),
                        overflow: TextOverflow.ellipsis),
                    if (size != null)
                      Text(_formatBytes(size),
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFF94A3B8))),
                    if (uploadedAt.isNotEmpty)
                      Text(uploadedAt,
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFF94A3B8))),
                  ])),
                  if (link.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Link: $link'),
                          action: SnackBarAction(
                            label: 'Copy',
                            onPressed: () =>
                                Clipboard.setData(ClipboardData(text: link)),
                          ),
                        ));
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('View',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  GestureDetector(
                    onTap: () => _confirmDeleteExistingPhoto(photoId, name),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Delete',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              );
            }),
          ],
          if (_existingPhotos.isEmpty && _newPhotos.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, size: 16, color: Color(0xFF3B82F6)),
                SizedBox(width: 8),
                Expanded(
                    child: Text('No files uploaded yet.',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF1D4ED8)))),
              ]),
            ),
        ],
      );

  Future<void> _confirmDeleteExistingPhoto(String photoId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete File'),
        content: Text(
            'Delete "$name"? This file will be removed from Google Drive when you save.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) _markExistingPhotoDeleted(photoId);
  }

  // ── Textarea section ───────────────────────────────────────────────────────

  Widget _buildTextareaSection(
    String title,
    TextEditingController ctrl,
    IconData icon, {
    String hint = 'Enter details…',
  }) =>
      _sectionCard(
        title: title,
        icon: icon,
        children: [
          TextFormField(
            controller: ctrl,
            maxLines: 4,
            decoration: _inputDeco(hint),
            style: const TextStyle(fontSize: 13),
          ),
        ],
      );

  // ═══════════════════════════════════════════════════════════════════════════
  // Shared table cell helpers
  // ═══════════════════════════════════════════════════════════════════════════

  /// Group header (spans multiple columns)
  Widget _groupHeader(String label, {required double width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFD1D5DB))),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: Color(0xFF374151))),
    );
  }

  /// Column header cell
  Widget _hCell(String label, {required double width, bool center = false}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Color(0xFFD1D5DB), width: 0.5)),
      ),
      child: Text(label,
          textAlign: center ? TextAlign.center : TextAlign.left,
          style: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: Color(0xFF374151))),
    );
  }

  /// SR.NO cell
  Widget _srCell(int n) {
    return Container(
      width: 36,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Color(0xFFE5E7EB), width: 0.5)),
      ),
      child: Text('$n',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280))),
    );
  }

  /// Text input cell inside a table row
  Widget _tableInputCell(
    TextEditingController ctrl, {
    required double width,
    required String hint,
    bool center = false,
    TextInputType? keyboardType,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Color(0xFFE5E7EB), width: 0.5)),
      ),
      child: TextFormField(
        controller: ctrl,
        textAlign: center ? TextAlign.center : TextAlign.start,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: AppColors.primaryGreen, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          isDense: true,
        ),
      ),
    );
  }

  /// Number input cell (digits only) inside a table row
  Widget _tableNumCell(
    TextEditingController ctrl, {
    required double width,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Color(0xFFE5E7EB), width: 0.5)),
      ),
      child: TextFormField(
        controller: ctrl,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: onChanged,
        style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
        decoration: InputDecoration(
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: AppColors.primaryGreen, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          isDense: true,
        ),
      ),
    );
  }

  /// Total row cell (read-only number display)
  Widget _totalNumCell(int value) {
    return SizedBox(
      width: _kNumCol,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('$value',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF374151))),
        ),
      ),
    );
  }

  /// Day/Night total badge
  Widget _totalBadge(String label, int value) {
    return Row(children: [
      Text(label,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: Color(0xFF374151))),
      const SizedBox(width: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: Text('$value',
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B))),
      ),
    ]);
  }

  /// Red "–" remove button for a table row
  Widget _removeBtn(VoidCallback onTap, {required bool show}) {
    return SizedBox(
      width: 40,
      child: show
          ? Center(
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.remove,
                      size: 16, color: Colors.white),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  /// Green "+ Add Row" button
  Widget _addRowButton(VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(Icons.add, size: 16, color: AppColors.primaryGreen),
      label: Text('+ Add Row',
          style: TextStyle(
              color: AppColors.primaryGreen, fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: AppColors.primaryGreen),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  // ── Section card shell ─────────────────────────────────────────────────────

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    bool noPadding = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Row(children: [
            Icon(icon, size: 16, color: AppColors.primaryGreen),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryGreen)),
            ),
          ]),
        ),
        Divider(height: 1, color: AppColors.primaryGreen.withValues(alpha: 0.15)),

        // Body
        if (noPadding)
          ...children
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children),
          ),
      ]),
    );
  }

  // ── Misc helpers ───────────────────────────────────────────────────────────

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.primaryGreen, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        isDense: true,
      );

  IconData _fileIcon(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'pdf':  return Icons.picture_as_pdf_outlined;
      case 'doc':
      case 'docx': return Icons.description_outlined;
      case 'xls':
      case 'xlsx': return Icons.table_chart_outlined;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp': return Icons.image_outlined;
      case 'mp4':
      case 'mov':
      case 'avi':  return Icons.play_circle_outline;
      default:     return Icons.insert_drive_file_outlined;
    }
  }

  IconData _fileIconFromMime(String mime) {
    if (mime.contains('image')) return Icons.image_outlined;
    if (mime.contains('video')) return Icons.play_circle_outline;
    if (mime.contains('pdf'))   return Icons.picture_as_pdf_outlined;
    return Icons.insert_drive_file_outlined;
  }
}