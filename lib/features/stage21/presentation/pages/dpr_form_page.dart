// lib/features/stage21/presentation/pages/dpr_form_page.dart

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/daily_project_report_model.dart';
import '../../data/services/dpr_api_service.dart';
import '../../../../core/utils/api_exception.dart';

// ─── Controllers for dynamic table rows ──────────────────────────────────────

class _LaborRowCtrl {
  final TextEditingController agency      = TextEditingController();
  final TextEditingController daySup      = TextEditingController();
  final TextEditingController daySkilled  = TextEditingController();
  final TextEditingController dayUnsk     = TextEditingController();
  final TextEditingController nightSup    = TextEditingController();
  final TextEditingController nightSkilled= TextEditingController();
  final TextEditingController nightUnsk   = TextEditingController();
  final TextEditingController remarks     = TextEditingController();

  void fill(LaborReportRow r) {
    agency.text       = r.agency ?? '';
    daySup.text       = _fmt(r.daySup);
    daySkilled.text   = _fmt(r.daySkilled);
    dayUnsk.text      = _fmt(r.dayUnskilled);
    nightSup.text     = _fmt(r.nightSup);
    nightSkilled.text = _fmt(r.nightSkilled);
    nightUnsk.text    = _fmt(r.nightUnskilled);
    remarks.text      = r.remarks ?? '';
  }

  double get total =>
      _n(daySup) + _n(daySkilled) + _n(dayUnsk) +
      _n(nightSup) + _n(nightSkilled) + _n(nightUnsk);

  static double _n(TextEditingController c) =>
      double.tryParse(c.text.trim()) ?? 0;

  static String _fmt(double v) => v == 0 ? '' : (v == v.truncateToDouble()
      ? v.toInt().toString() : v.toStringAsFixed(2));

  Map<String, dynamic> toJson() => {
        'agency':          agency.text.trim(),
        'day_sup':         _n(daySup),
        'day_skilled':     _n(daySkilled),
        'day_unskilled':   _n(dayUnsk),
        'night_sup':       _n(nightSup),
        'night_skilled':   _n(nightSkilled),
        'night_unskilled': _n(nightUnsk),
        'total':           total,
        'remarks':         remarks.text.trim(),
      };

  void dispose() {
    agency.dispose(); daySup.dispose(); daySkilled.dispose();
    dayUnsk.dispose(); nightSup.dispose(); nightSkilled.dispose();
    nightUnsk.dispose(); remarks.dispose();
  }
}

class _ProgressRowCtrl {
  final TextEditingController activity    = TextEditingController();
  final TextEditingController plannedPct  = TextEditingController();
  final TextEditingController actualPct   = TextEditingController();
  final TextEditingController plannedCum  = TextEditingController();
  final TextEditingController actualCum   = TextEditingController();
  final TextEditingController remarks     = TextEditingController();

  void fill(ProgressPreviousRow r) {
    activity.text   = r.activity ?? '';
    plannedPct.text = _fmt(r.plannedPct);
    actualPct.text  = _fmt(r.actualPct);
    plannedCum.text = _fmt(r.plannedCumulative);
    actualCum.text  = _fmt(r.actualCumulative);
    remarks.text    = r.remarks ?? '';
  }

  static String _fmt(double v) => v == 0 ? '' : (v == v.truncateToDouble()
      ? v.toInt().toString() : v.toStringAsFixed(2));

  Map<String, dynamic> toJson() => {
        'activity':           activity.text.trim(),
        'planned_pct':        double.tryParse(plannedPct.text.trim()) ?? 0,
        'actual_pct':         double.tryParse(actualPct.text.trim()) ?? 0,
        'planned_cumulative': double.tryParse(plannedCum.text.trim()) ?? 0,
        'actual_cumulative':  double.tryParse(actualCum.text.trim()) ?? 0,
        'remarks':            remarks.text.trim(),
      };

  void dispose() {
    activity.dispose(); plannedPct.dispose(); actualPct.dispose();
    plannedCum.dispose(); actualCum.dispose(); remarks.dispose();
  }
}

class _WorksRowCtrl {
  final TextEditingController activity   = TextEditingController();
  final TextEditingController plannedQty = TextEditingController();
  final TextEditingController remarks    = TextEditingController();

  void fill(WorksPlannedRow r) {
    activity.text   = r.activity ?? '';
    plannedQty.text = r.plannedQty ?? '';
    remarks.text    = r.remarks ?? '';
  }

  Map<String, dynamic> toJson() => {
        'activity':    activity.text.trim(),
        'planned_qty': plannedQty.text.trim(),
        'remarks':     remarks.text.trim(),
      };

  void dispose() {
    activity.dispose(); plannedQty.dispose(); remarks.dispose();
  }
}

// ─── Form Page ────────────────────────────────────────────────────────────────

class DprFormPage extends StatefulWidget {
  final int projectId;
  final String projectName;
  final int? editId;

  const DprFormPage({
    super.key,
    required this.projectId,
    required this.projectName,
    this.editId,
  });

  bool get isEdit => editId != null;

  @override
  State<DprFormPage> createState() => _DprFormPageState();
}

class _DprFormPageState extends State<DprFormPage> {
  static const Color _accent = Color(0xFF7C3AED);

  final _formKey = GlobalKey<FormState>();

  // ── Controllers ───────────────────────────────────────────────────────────
  final TextEditingController _reportDateCtrl    = TextEditingController();
  final TextEditingController _decisionsCtrl     = TextEditingController();
  final TextEditingController _bottleNecksCtrl   = TextEditingController();
  final TextEditingController _changeAuthCtrl    = TextEditingController();
  final TextEditingController _materialCtrl      = TextEditingController();
  final TextEditingController _ehsCtrl           = TextEditingController();

  String? _reportNo;
  String? _weatherValue;
  bool _loadingInit  = false;
  bool _saving       = false;
  String? _initError;

  // ── Dynamic rows ──────────────────────────────────────────────────────────
  final List<_LaborRowCtrl>    _laborRows    = [];
  final List<_ProgressRowCtrl> _progressRows = [];
  final List<_WorksRowCtrl>    _worksRows    = [];

  // ── Photos ────────────────────────────────────────────────────────────────
  final List<File>   _newPhotos     = [];
  final List<String> _deletedPhotos = [];
  List<DprPhotoUrl>  _existingPhotos = [];

  static const List<String> _weatherOptions = [
    'Sunny', 'Cloudy', 'Rainy', 'Windy', 'Foggy', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    _reportDateCtrl.text =
        DateFormat('yyyy-MM-dd').format(DateTime.now());
    _initDefaults();
    if (widget.isEdit) {
      _loadForEdit();
    } else {
      _fetchNextReportNo();
      _addDefaultRows();
    }
  }

  void _initDefaults() {
    // 5 empty labor rows
    for (int i = 0; i < 5; i++) _laborRows.add(_LaborRowCtrl());
    for (int i = 0; i < 5; i++) _progressRows.add(_ProgressRowCtrl());
    for (int i = 0; i < 3; i++) _worksRows.add(_WorksRowCtrl());
  }

  void _addDefaultRows() {}   // already done in _initDefaults

  Future<void> _fetchNextReportNo() async {
    try {
      final no = await DprApiService.fetchNextReportNo(widget.projectId);
      if (mounted) setState(() => _reportNo = no);
    } catch (_) {}
  }

  Future<void> _loadForEdit() async {
    if (!mounted) return;
    setState(() { _loadingInit = true; _initError = null; });

    try {
      final detail = await DprApiService.fetchReport(
          widget.projectId, widget.editId!);

      if (!mounted) return;

      // Clear defaults and fill
      for (final c in _laborRows)    c.dispose();
      for (final c in _progressRows) c.dispose();
      for (final c in _worksRows)    c.dispose();
      _laborRows.clear();
      _progressRows.clear();
      _worksRows.clear();

      _reportNo = detail.reportNo;
      _reportDateCtrl.text = detail.reportDateRaw ?? '';
      _weatherValue = detail.weather;
      _decisionsCtrl.text   = detail.decisionsApprovals ?? '';
      _bottleNecksCtrl.text = detail.bottleNecks ?? '';
      _changeAuthCtrl.text  = detail.changeAuthorizations ?? '';
      _materialCtrl.text    = detail.materialDelivered ?? '';
      _ehsCtrl.text         = detail.ehsIncidentReports ?? '';
      _existingPhotos       = detail.photoUrls;

      if (detail.laborReport.isEmpty) {
        _laborRows.add(_LaborRowCtrl());
      } else {
        for (final row in detail.laborReport) {
          final c = _LaborRowCtrl()..fill(row);
          _laborRows.add(c);
        }
      }
      if (detail.progressPrevious.isEmpty) {
        _progressRows.add(_ProgressRowCtrl());
      } else {
        for (final row in detail.progressPrevious) {
          final c = _ProgressRowCtrl()..fill(row);
          _progressRows.add(c);
        }
      }
      if (detail.worksPlanned.isEmpty) {
        _worksRows.add(_WorksRowCtrl());
      } else {
        for (final row in detail.worksPlanned) {
          final c = _WorksRowCtrl()..fill(row);
          _worksRows.add(c);
        }
      }

      setState(() => _loadingInit = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _initError  = e is ApiException ? e.message : e.toString();
          _loadingInit = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _reportDateCtrl.dispose();
    _decisionsCtrl.dispose();
    _bottleNecksCtrl.dispose();
    _changeAuthCtrl.dispose();
    _materialCtrl.dispose();
    _ehsCtrl.dispose();
    for (final c in _laborRows)    c.dispose();
    for (final c in _progressRows) c.dispose();
    for (final c in _worksRows)    c.dispose();
    super.dispose();
  }

  // ── Date picker ───────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    DateTime initial = DateTime.now();
    try {
      if (_reportDateCtrl.text.isNotEmpty) {
        initial = DateTime.parse(_reportDateCtrl.text);
      }
    } catch (_) {}

    final picked = await showDatePicker(
      context:      context,
      initialDate:  initial,
      firstDate:    DateTime(2020),
      lastDate:     DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF7C3AED),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        _reportDateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  // ── Photo picker ──────────────────────────────────────────────────────────

  Future<void> _pickPhotos() async {
    final result = await FilePicker.platform.pickFiles(
      type:          FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'pdf'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    final files = result.files
        .where((f) => f.path != null)
        .map((f) => File(f.path!))
        .toList();

    if (mounted) setState(() => _newPhotos.addAll(files));
  }

  void _removeNewPhoto(int idx) {
    setState(() => _newPhotos.removeAt(idx));
  }

  void _removeExistingPhoto(DprPhotoUrl photo) {
    setState(() {
      _deletedPhotos.add(photo.path);
      _existingPhotos.remove(photo);
    });
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_reportDateCtrl.text.isEmpty) {
      _showSnackBar('Please select a report date.', error: true);
      return;
    }

    setState(() => _saving = true);

    try {
      final laborData    = _laborRows.map((c) => c.toJson()).toList();
      final progressData = _progressRows.map((c) => c.toJson()).toList();
      final worksData    = _worksRows.map((c) => c.toJson()).toList();

      if (widget.isEdit) {
        await DprApiService.updateReport(
          projectId:            widget.projectId,
          id:                   widget.editId!,
          reportDate:           _reportDateCtrl.text,
          weather:              _weatherValue,
          laborReport:          laborData,
          progressPrevious:     progressData,
          worksPlanned:         worksData,
          decisionsApprovals:   _decisionsCtrl.text,
          bottleNecks:          _bottleNecksCtrl.text,
          changeAuthorizations: _changeAuthCtrl.text,
          materialDelivered:    _materialCtrl.text,
          ehsIncidentReports:   _ehsCtrl.text,
          newProgressPhotos:    _newPhotos,
          deletedPhotos:        _deletedPhotos,
        );
        if (mounted) {
          _showSnackBar('Report updated successfully.');
          Navigator.pop(context, true);
        }
      } else {
        await DprApiService.createReport(
          projectId:            widget.projectId,
          reportDate:           _reportDateCtrl.text,
          weather:              _weatherValue,
          laborReport:          laborData,
          progressPrevious:     progressData,
          worksPlanned:         worksData,
          decisionsApprovals:   _decisionsCtrl.text,
          bottleNecks:          _bottleNecksCtrl.text,
          changeAuthorizations: _changeAuthCtrl.text,
          materialDelivered:    _materialCtrl.text,
          ehsIncidentReports:   _ehsCtrl.text,
          progressPhotos:       _newPhotos,
        );
        if (mounted) {
          _showSnackBar('Report created successfully.');
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          e is ApiException ? e.message : e.toString(),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnackBar(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: error
            ? const Color(0xFFEF4444)
            : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isEdit
                  ? 'Edit Daily Project Report'
                  : 'New Daily Project Report',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800),
            ),
            if (_reportNo != null)
              Text('No. $_reportNo',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.75))),
          ],
        ),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loadingInit
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
          : _initError != null
              ? _buildInitError()
              : _buildForm(),
      bottomNavigationBar: _loadingInit || _initError != null
          ? null
          : _buildSaveBar(),
    );
  }

  Widget _buildInitError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded,
                color: Color(0xFFEF4444), size: 48),
            const SizedBox(height: 12),
            Text(_initError!, textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadForEdit,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
              ),
            ),
          ]),
        ),
      );

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Meta ─────────────────────────────────────────────────────
            _FormCard(
              child: Column(children: [
                // Date
                TextFormField(
                  controller:    _reportDateCtrl,
                  readOnly:      true,
                  onTap:         _pickDate,
                  decoration: _dec(
                    label: 'Report Date *',
                    hint:  'Select date',
                    icon:  Icons.calendar_today_rounded,
                    suffix: const Icon(Icons.calendar_month_rounded,
                        size: 18, color: Color(0xFF7C3AED)),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Date is required' : null,
                ),
                const SizedBox(height: 14),

                // Weather
                DropdownButtonFormField<String>(
                  value: _weatherValue,
                  decoration: _dec(
                      label: 'Weather', icon: Icons.wb_sunny_outlined),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('-- Select --')),
                    ..._weatherOptions.map(
                      (w) => DropdownMenuItem(value: w, child: Text(w)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _weatherValue = v),
                ),
              ]),
            ),

            const SizedBox(height: 16),

            // ── Section A: Labor ──────────────────────────────────────────
            _SectionLabel(label: 'A. Detailed Labor Report'),
            _DynamicTable<_LaborRowCtrl>(
              rows:    _laborRows,
              onAdd:   () => setState(() => _laborRows.add(_LaborRowCtrl())),
              onRemove:(i) => setState(() {
                _laborRows[i].dispose();
                _laborRows.removeAt(i);
              }),
              headerBuilder: () => const SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _ColHead(label: 'Agency', width: 130),
                  _ColHead(label: 'D-Sup', width: 60),
                  _ColHead(label: 'D-Skl', width: 60),
                  _ColHead(label: 'D-Unsk', width: 70),
                  _ColHead(label: 'N-Sup', width: 60),
                  _ColHead(label: 'N-Skl', width: 60),
                  _ColHead(label: 'N-Unsk', width: 70),
                  _ColHead(label: 'Remarks', width: 120),
                  _ColHead(label: '', width: 36),
                ]),
              ),
              rowBuilder: (ctrl, idx, onRemove) =>
                  _LaborRowWidget(ctrl: ctrl, onRemove: onRemove),
            ),

            const SizedBox(height: 16),

            // ── Section B: Progress Previous ──────────────────────────────
            _SectionLabel(label: 'B. Progress Achieved on Previous Day'),
            _DynamicTable<_ProgressRowCtrl>(
              rows:    _progressRows,
              onAdd:   () => setState(
                  () => _progressRows.add(_ProgressRowCtrl())),
              onRemove:(i) => setState(() {
                _progressRows[i].dispose();
                _progressRows.removeAt(i);
              }),
              headerBuilder: () => const SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _ColHead(label: 'Activity', width: 150),
                  _ColHead(label: 'Plan %', width: 70),
                  _ColHead(label: 'Act %', width: 70),
                  _ColHead(label: 'Plan Cum', width: 80),
                  _ColHead(label: 'Act Cum', width: 80),
                  _ColHead(label: 'Remarks', width: 120),
                  _ColHead(label: '', width: 36),
                ]),
              ),
              rowBuilder: (ctrl, idx, onRemove) =>
                  _ProgressRowWidget(ctrl: ctrl, onRemove: onRemove),
            ),

            const SizedBox(height: 16),

            // ── Section B2: Works Planned ─────────────────────────────────
            _SectionLabel(label: 'B. Works Planned for Today'),
            _DynamicTable<_WorksRowCtrl>(
              rows:    _worksRows,
              onAdd:   () =>
                  setState(() => _worksRows.add(_WorksRowCtrl())),
              onRemove:(i) => setState(() {
                _worksRows[i].dispose();
                _worksRows.removeAt(i);
              }),
              headerBuilder: () => const SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _ColHead(label: 'Activity', width: 180),
                  _ColHead(label: 'Planned Qty', width: 110),
                  _ColHead(label: 'Remarks', width: 130),
                  _ColHead(label: '', width: 36),
                ]),
              ),
              rowBuilder: (ctrl, idx, onRemove) =>
                  _WorksRowWidget(ctrl: ctrl, onRemove: onRemove),
            ),

            const SizedBox(height: 16),

            // ── Text sections ─────────────────────────────────────────────
            _SectionLabel(label: 'C. Decisions / Approvals'),
            _FormCard(
              child: _textarea(
                  ctrl: _decisionsCtrl,
                  hint: 'Enter decisions or approvals...'),
            ),

            const SizedBox(height: 12),
            _SectionLabel(label: 'Bottle Necks / Problem Areas'),
            _FormCard(
              child: _textarea(
                  ctrl: _bottleNecksCtrl,
                  hint: 'Enter bottle necks or problem areas...'),
            ),

            const SizedBox(height: 12),
            _SectionLabel(label: 'Change Authorizations / RFIs Submitted'),
            _FormCard(
              child: _textarea(
                  ctrl: _changeAuthCtrl,
                  hint: 'Enter change authorizations / RFIs...'),
            ),

            const SizedBox(height: 12),
            _SectionLabel(label: 'Material Delivered to Site This Date'),
            _FormCard(
              child: _textarea(
                  ctrl: _materialCtrl,
                  hint: 'List materials delivered today...'),
            ),

            const SizedBox(height: 12),
            _SectionLabel(
                label: 'EHS Incident Reports / Near Misses This Date'),
            _FormCard(
              child: _textarea(
                  ctrl: _ehsCtrl,
                  hint: 'Enter EHS incident reports or near misses...'),
            ),

            const SizedBox(height: 16),

            // ── Photos ────────────────────────────────────────────────────
            _SectionLabel(label: 'Progress Photos'),
            _FormCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                // Existing photos (edit mode)
                if (_existingPhotos.isNotEmpty) ...[
                  const Text('Existing Photos',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    ..._existingPhotos.map((p) => _ExistingPhotoThumb(
                          photo:    p,
                          onRemove: () => _removeExistingPhoto(p),
                        )),
                  ]),
                  const SizedBox(height: 12),
                ],

                // New photos preview
                if (_newPhotos.isNotEmpty) ...[
                  const Text('New Photos',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    ..._newPhotos.asMap().entries.map(
                          (e) => _NewPhotoThumb(
                            file:     e.value,
                            onRemove: () => _removeNewPhoto(e.key),
                          ),
                        ),
                  ]),
                  const SizedBox(height: 12),
                ],

                // Upload button
                OutlinedButton.icon(
                  onPressed: _pickPhotos,
                  icon: const Icon(Icons.add_photo_alternate_rounded,
                      size: 16),
                  label: const Text('Add Photos / PDFs'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _accent,
                    side: const BorderSide(color: Color(0xFF7C3AED)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'JPG, PNG, GIF, PDF — max 10 MB each',
                  style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textarea(
          {required TextEditingController ctrl, required String hint}) =>
      TextFormField(
        controller: ctrl,
        maxLines:   4,
        decoration: _dec(label: '', hint: hint).copyWith(
          labelText:   null,
          prefixIcon:  null,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      );

  InputDecoration _dec({
    required String label,
    String hint = '',
    IconData? icon,
    Widget? suffix,
  }) =>
      InputDecoration(
        labelText: label.isEmpty ? null : label,
        hintText:  hint,
        prefixIcon: icon != null
            ? Icon(icon, size: 18, color: const Color(0xFF94A3B8))
            : null,
        suffixIcon: suffix,
        filled:     true,
        fillColor:  const Color(0xFFF8FAFC),
        labelStyle: const TextStyle(
            fontSize: 12, color: Color(0xFF94A3B8)),
        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
      );

  Widget _buildSaveBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 12,
              offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: ElevatedButton.icon(
          onPressed: _saving ? null : _submit,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.save_rounded),
          label: Text(
            _saving
                ? 'Saving…'
                : (widget.isEdit ? 'Update Report' : 'Save Report'),
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _accent,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
      ),
    );
  }
}

// ─── Dynamic table wrapper ────────────────────────────────────────────────────

class _DynamicTable<T> extends StatelessWidget {
  final List<T> rows;
  final VoidCallback onAdd;
  final void Function(int idx) onRemove;
  final Widget Function() headerBuilder;
  final Widget Function(T ctrl, int idx, VoidCallback onRemove) rowBuilder;

  const _DynamicTable({
    required this.rows,
    required this.onAdd,
    required this.onRemove,
    required this.headerBuilder,
    required this.rowBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          color: const Color(0xFFF1F5F9),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: headerBuilder(),
        ),
        // Rows
        ...rows.asMap().entries.map((e) => Column(children: [
              rowBuilder(e.value, e.key, () => onRemove(e.key)),
              if (e.key < rows.length - 1)
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
            ])),
        // Add row button
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_circle_rounded, size: 16),
          label: const Text('Add Row'),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF7C3AED),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            textStyle: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ]),
    );
  }
}

// ─── Column header ────────────────────────────────────────────────────────────

class _ColHead extends StatelessWidget {
  final String label;
  final double width;
  const _ColHead({required this.label, required this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(label,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B))),
    );
  }
}

// ─── Labor row widget ─────────────────────────────────────────────────────────

class _LaborRowWidget extends StatefulWidget {
  final _LaborRowCtrl ctrl;
  final VoidCallback onRemove;
  const _LaborRowWidget({required this.ctrl, required this.onRemove});

  @override
  State<_LaborRowWidget> createState() => _LaborRowWidgetState();
}

class _LaborRowWidgetState extends State<_LaborRowWidget> {
  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final c = widget.ctrl;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _cell(c.agency,       width: 130, hint: 'Agency'),
          _numCell(c.daySup,    width: 60,  onChanged: _rebuild),
          _numCell(c.daySkilled,width: 60,  onChanged: _rebuild),
          _numCell(c.dayUnsk,   width: 70,  onChanged: _rebuild),
          _numCell(c.nightSup,  width: 60,  onChanged: _rebuild),
          _numCell(c.nightSkilled,width: 60,onChanged: _rebuild),
          _numCell(c.nightUnsk, width: 70,  onChanged: _rebuild),
          // Total (read-only)
          SizedBox(
            width: 55,
            child: Text(
              _fmt(c.total),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF7C3AED)),
            ),
          ),
          _cell(c.remarks, width: 120, hint: 'Remarks'),
          _removeBtn(widget.onRemove),
        ]),
      ),
    );
  }

  static String _fmt(double v) => v == 0 ? '—' : v.toStringAsFixed(0);
}

// ─── Progress row widget ──────────────────────────────────────────────────────

class _ProgressRowWidget extends StatelessWidget {
  final _ProgressRowCtrl ctrl;
  final VoidCallback onRemove;
  const _ProgressRowWidget(
      {required this.ctrl, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final c = ctrl;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _cell(c.activity,   width: 150, hint: 'Activity'),
          _numCell(c.plannedPct, width: 70),
          _numCell(c.actualPct,  width: 70),
          _numCell(c.plannedCum, width: 80),
          _numCell(c.actualCum,  width: 80),
          _cell(c.remarks,    width: 120, hint: 'Remarks'),
          _removeBtn(onRemove),
        ]),
      ),
    );
  }
}

// ─── Works row widget ─────────────────────────────────────────────────────────

class _WorksRowWidget extends StatelessWidget {
  final _WorksRowCtrl ctrl;
  final VoidCallback onRemove;
  const _WorksRowWidget({required this.ctrl, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final c = ctrl;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _cell(c.activity,   width: 180, hint: 'Activity'),
          _cell(c.plannedQty, width: 110, hint: 'Planned Qty'),
          _cell(c.remarks,    width: 130, hint: 'Remarks'),
          _removeBtn(onRemove),
        ]),
      ),
    );
  }
}

// ─── Shared row field builders ────────────────────────────────────────────────

Widget _cell(TextEditingController ctrl,
    {required double width, String hint = ''}) {
  return SizedBox(
    width: width,
    child: Padding(
      padding: const EdgeInsets.only(right: 6),
      child: TextFormField(
        controller: ctrl,
        style: const TextStyle(fontSize: 11),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          filled:     true,
          fillColor:  const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(
                color: Color(0xFF7C3AED), width: 1.5),
          ),
        ),
      ),
    ),
  );
}

Widget _numCell(TextEditingController ctrl,
    {required double width, VoidCallback? onChanged}) {
  return SizedBox(
    width: width,
    child: Padding(
      padding: const EdgeInsets.only(right: 6),
      child: TextFormField(
        controller:  ctrl,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        onChanged:   onChanged != null ? (_) => onChanged() : null,
        style:       const TextStyle(fontSize: 11),
        textAlign:   TextAlign.center,
        decoration: InputDecoration(
          hintText:  '0',
          hintStyle:
              const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
          filled:     true,
          fillColor:  const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(
                color: Color(0xFF7C3AED), width: 1.5),
          ),
        ),
      ),
    ),
  );
}

Widget _removeBtn(VoidCallback onTap) {
  return SizedBox(
    width: 30,
    height: 30,
    child: IconButton(
      padding:  EdgeInsets.zero,
      icon:     const Icon(Icons.remove_circle_rounded,
          color: Color(0xFFEF4444), size: 20),
      onPressed: onTap,
    ),
  );
}

// ─── Form card ────────────────────────────────────────────────────────────────

class _FormCard extends StatelessWidget {
  final Widget child;
  const _FormCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFF7C3AED),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B))),
        ),
      ]),
    );
  }
}

// ─── Photo thumbnails ─────────────────────────────────────────────────────────

class _ExistingPhotoThumb extends StatelessWidget {
  final DprPhotoUrl photo;
  final VoidCallback onRemove;
  const _ExistingPhotoThumb({required this.photo, required this.onRemove});

  bool get _isImage {
    final ext = photo.path.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          clipBehavior: Clip.antiAlias,
          child: _isImage
              ? Image.network(photo.url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image_rounded,
                      color: Color(0xFFCBD5E1)))
              : const Center(
                  child: Icon(Icons.picture_as_pdf_rounded,
                      color: Color(0xFFEF4444), size: 28)),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 12),
            ),
          ),
        ),
      ],
    );
  }
}

class _NewPhotoThumb extends StatelessWidget {
  final File file;
  final VoidCallback onRemove;
  const _NewPhotoThumb({required this.file, required this.onRemove});

  bool get _isImage {
    final ext = file.path.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          clipBehavior: Clip.antiAlias,
          child: _isImage
              ? Image.file(file, fit: BoxFit.cover)
              : const Center(
                  child: Icon(Icons.picture_as_pdf_rounded,
                      color: Color(0xFFEF4444), size: 28)),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 12),
            ),
          ),
        ),
      ],
    );
  }
}