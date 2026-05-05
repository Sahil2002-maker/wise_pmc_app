// lib/features/concreting_checklist/presentation/concreting_checklist_form_page.dart

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/utils/api_exception.dart';
import '../data/models/concreting_checklist_model.dart';
import 'concreting_checklist_particulars.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Mutable state for one test row
// ─────────────────────────────────────────────────────────────────────────────

class _TestRow {
  final String srNo;
  final String particulars;
  String? check; // 'yes' | 'no' | null
  final TextEditingController remarkCtrl;

  _TestRow({
    required this.srNo,
    required this.particulars,
    required this.check,
    required this.remarkCtrl,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Form Page
// ─────────────────────────────────────────────────────────────────────────────

class ConcretingChecklistFormPage extends StatefulWidget {
  final int projectId;
  final String projectName;
  final ConcretingChecklistModel? existing;

  const ConcretingChecklistFormPage({
    super.key,
    required this.projectId,
    required this.projectName,
    this.existing,
  });

  @override
  State<ConcretingChecklistFormPage> createState() =>
      _ConcretingChecklistFormPageState();
}

class _ConcretingChecklistFormPageState
    extends State<ConcretingChecklistFormPage> {
  // ── Basic fields ──────────────────────────────────────────────────────────
  String _checklistNo = '';
  DateTime? _checklistDate;
  DateTime? _dateOfCasting;

  final _locationCtrl = TextEditingController();
  final _partWingCtrl = TextEditingController();

  // ── Check following points ────────────────────────────────────────────────
  final _hflCtrl = TextEditingController();
  final _shutteringCtrl = TextEditingController();
  final _reinforcementCtrl = TextEditingController();
  final _electricalCtrl = TextEditingController();
  final _plumbingCtrl = TextEditingController();
  final _generalCtrl = TextEditingController();

  // ── Drawings available ────────────────────────────────────────────────────
  final _rccCtrl = TextEditingController();
  final _rccDrawingCtrl = TextEditingController();
  final _plumbingDrawingCtrl = TextEditingController();
  final _architectDrawingCtrl = TextEditingController();

  // ── Additional observations ───────────────────────────────────────────────
  final _observationsCtrl = TextEditingController();

  // ── Test rows ──────────────────────────────────────────────────────────────
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
    _testRows = kConcretingParticulars
        .map((p) => _TestRow(
              srNo: p['sr_no']!,
              particulars: p['particulars']!,
              check: null,
              remarkCtrl: TextEditingController(),
            ))
        .toList();
  }

  void _populateFromExisting() {
    final c = widget.existing!;
    _checklistNo = c.checklistNo;

    try {
      _checklistDate = DateTime.parse(c.checklistDate);
    } catch (_) {
      _checklistDate = DateTime.now();
    }

    if (c.dateOfCasting != null && c.dateOfCasting!.isNotEmpty) {
      try {
        _dateOfCasting = DateTime.parse(c.dateOfCasting!);
      } catch (_) {}
    }

    _locationCtrl.text = c.location ?? '';
    _partWingCtrl.text = c.partWing ?? '';
    _hflCtrl.text = c.hflReference ?? '';
    _shutteringCtrl.text = c.shuttering ?? '';
    _reinforcementCtrl.text = c.reinforcement ?? '';
    _electricalCtrl.text = c.electrical ?? '';
    _plumbingCtrl.text = c.plumbing ?? '';
    _generalCtrl.text = c.general ?? '';
    _rccCtrl.text = c.rcc ?? '';
    _rccDrawingCtrl.text = c.rccDrawing ?? '';
    _plumbingDrawingCtrl.text = c.plumbingDrawing ?? '';
    _architectDrawingCtrl.text = c.architectDrawing ?? '';
    _observationsCtrl.text = c.additionalObservations ?? '';

    // Map saved test results back to rows by index
    if (c.testResults.isNotEmpty) {
      for (int i = 0;
          i < _testRows.length && i < c.testResults.length;
          i++) {
        _testRows[i].check = c.testResults[i].check;
        _testRows[i].remarkCtrl.text = c.testResults[i].remark;
      }
    }
  }

  Future<void> _loadChecklistNumber() async {
    if (!mounted) return;
    setState(() => _isLoadingNo = true);
    try {
      final no = await ApiService.generateConcretingChecklistNumber(
          widget.projectId);
      if (mounted) setState(() => _checklistNo = no);
    } catch (_) {}
    if (mounted) setState(() => _isLoadingNo = false);
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    _partWingCtrl.dispose();
    _hflCtrl.dispose();
    _shutteringCtrl.dispose();
    _reinforcementCtrl.dispose();
    _electricalCtrl.dispose();
    _plumbingCtrl.dispose();
    _generalCtrl.dispose();
    _rccCtrl.dispose();
    _rccDrawingCtrl.dispose();
    _plumbingDrawingCtrl.dispose();
    _architectDrawingCtrl.dispose();
    _observationsCtrl.dispose();
    for (final r in _testRows) {
      r.remarkCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(bool isCasting) async {
    final initial = isCasting
        ? (_dateOfCasting ?? DateTime.now())
        : (_checklistDate ?? DateTime.now());
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
    if (picked != null && mounted) {
      setState(() {
        if (isCasting) {
          _dateOfCasting = picked;
        } else {
          _checklistDate = picked;
        }
      });
    }
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return 'Select date';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (_isSaving) return;
    if (_checklistDate == null) {
      _showError('Please select a checklist date.');
      return;
    }

  if (!_isEditing && _checklistNo.trim().isEmpty) {
  _showError('Checklist number is still generating. Please wait.');
  return;
}

    setState(() => _isSaving = true);

    final testResults = _testRows
        .map((r) => {
              'sr_no': r.srNo,
              'particulars': r.particulars,
              'check': r.check,
              'check_yes': r.check == 'yes',
              'check_no': r.check == 'no',
              'remark': r.remarkCtrl.text.trim(),
            })
        .toList();

    try {
      if (_isEditing) {
        await ApiService.updateConcretingChecklist(
          projectId: widget.projectId,
          id: widget.existing!.id,
          checklistDate: _isoDate(_checklistDate!),
          location: _locationCtrl.text.trim(),
          partWing: _partWingCtrl.text.trim(),
          dateOfCasting:
              _dateOfCasting != null ? _isoDate(_dateOfCasting!) : null,
          hflReference: _hflCtrl.text.trim(),
          shuttering: _shutteringCtrl.text.trim(),
          reinforcement: _reinforcementCtrl.text.trim(),
          electrical: _electricalCtrl.text.trim(),
          plumbing: _plumbingCtrl.text.trim(),
          general: _generalCtrl.text.trim(),
          rcc: _rccCtrl.text.trim(),
          rccDrawing: _rccDrawingCtrl.text.trim(),
          plumbingDrawing: _plumbingDrawingCtrl.text.trim(),
          architectDrawing: _architectDrawingCtrl.text.trim(),
          testResults: testResults,
          additionalObservations: _observationsCtrl.text.trim(),
        );
      } else {
        await ApiService.createConcretingChecklist(
          projectId: widget.projectId,
          checklistNo: _checklistNo,
          checklistDate: _isoDate(_checklistDate!),
          location: _locationCtrl.text.trim(),
          partWing: _partWingCtrl.text.trim(),
          dateOfCasting:
              _dateOfCasting != null ? _isoDate(_dateOfCasting!) : null,
          hflReference: _hflCtrl.text.trim(),
          shuttering: _shutteringCtrl.text.trim(),
          reinforcement: _reinforcementCtrl.text.trim(),
          electrical: _electricalCtrl.text.trim(),
          plumbing: _plumbingCtrl.text.trim(),
          general: _generalCtrl.text.trim(),
          rcc: _rccCtrl.text.trim(),
          rccDrawing: _rccDrawingCtrl.text.trim(),
          plumbingDrawing: _plumbingDrawingCtrl.text.trim(),
          architectDrawing: _architectDrawingCtrl.text.trim(),
          testResults: testResults,
          additionalObservations: _observationsCtrl.text.trim(),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEditing
            ? 'Checklist updated successfully!'
            : 'Checklist created successfully!'),
        backgroundColor: AppColors.primaryGreen,
      ));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showError(e is ApiException ? e.message : e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFEF4444)));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(
            _isEditing
                ? 'Edit Concreting Checklist'
                : 'New Concreting Checklist',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B)),
          ),
          Text(widget.projectName,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF64748B)),
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
                      _isEditing ? 'Update' : 'Save',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildBasicInfoSection()),
          SliverToBoxAdapter(child: _buildCheckPointsSection()),
          SliverToBoxAdapter(child: _buildDrawingsSection()),
          SliverToBoxAdapter(child: _buildChecklistTableSection()),
          SliverToBoxAdapter(child: _buildObservationsSection()),
          SliverToBoxAdapter(child: _buildSignatureSection()),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  // ── Sections ──────────────────────────────────────────────────────────────

  Widget _buildBasicInfoSection() => _card(
        title: 'Basic Information',
        icon: Icons.info_outline,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Checklist No & Date
          Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _label('Checklist No.'),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    border:
                        Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        _isLoadingNo
                            ? 'Generating…'
                            : (_checklistNo.isEmpty
                                ? 'WR/EXE/06/...'
                                : _checklistNo),
                        style: TextStyle(
                            fontSize: 13,
                            color: _isLoadingNo
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF1E293B)),
                      ),
                    ),
                    if (_isLoadingNo)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryGreen),
                      ),
                  ]),
                ),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _label('Date of Checking *'),
                _datePicker(
                  value: _checklistDate,
                  hint: 'Select date',
                  onTap: () => _pickDate(false),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 14),

          _label('Project Name'),
          _readOnlyField(widget.projectName),
          const SizedBox(height: 14),

          // Location, Part/Wing
          Row(children: [
            Expanded(
                child: _inputField(_locationCtrl, 'Location',
                    hint: 'Enter location')),
            const SizedBox(width: 12),
            Expanded(
                child: _inputField(_partWingCtrl, 'Part / Wing',
                    hint: 'Enter part/wing')),
          ]),
          const SizedBox(height: 14),

          // Date of casting
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('Date of Casting'),
            _datePicker(
              value: _dateOfCasting,
              hint: 'Select casting date (optional)',
              onTap: () => _pickDate(true),
            ),
          ]),
        ]),
      );

  Widget _buildCheckPointsSection() => _card(
        title: 'Check Following Points',
        icon: Icons.checklist_outlined,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          _inputField(_hflCtrl, '01) HFL. Reference point.',
              hint: 'Enter value'),
          const SizedBox(height: 10),
          _inputField(_shutteringCtrl, '03) Shuttering',
              hint: 'Enter value'),
          const SizedBox(height: 10),
          _inputField(_reinforcementCtrl, '04) Reinforcement',
              hint: 'Enter value'),
          const SizedBox(height: 10),
          _inputField(_electricalCtrl, '05) Electrical',
              hint: 'Enter value'),
          const SizedBox(height: 10),
          _inputField(_plumbingCtrl, '06) Plumbing',
              hint: 'Enter value'),
          const SizedBox(height: 10),
          _inputField(_generalCtrl, '07) General', hint: 'Enter value'),
        ]),
      );

  Widget _buildDrawingsSection() => _card(
        title: 'Drawings Available',
        icon: Icons.description_outlined,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(children: [
            Expanded(
                child: _inputField(_rccCtrl, '01) RCC',
                    hint: 'Drawing no.')),
            const SizedBox(width: 12),
            Expanded(
                child: _inputField(_rccDrawingCtrl, '02) RCC',
                    hint: 'Drawing no.')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: _inputField(
                    _plumbingDrawingCtrl, '03) Plumbing',
                    hint: 'Drawing no.')),
            const SizedBox(width: 12),
            Expanded(
                child: _inputField(
                    _architectDrawingCtrl, '04) Architect',
                    hint: 'Drawing no.')),
          ]),
        ]),
      );

  Widget _buildChecklistTableSection() => _card(
        title: 'Checklist Particulars',
        icon: Icons.list_alt_outlined,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
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
          const SizedBox(height: 6),

          // Section headers + rows
          ..._buildSectionedRows(),
        ]),
      );

  /// Groups rows by section (same 5 sections as backend blade)
  List<Widget> _buildSectionedRows() {
    final sections = <Map<String, dynamic>>[
      {'label': '01) LEVEL', 'count': 1},
      {'label': '02) SHUTTERING', 'count': 22},
      {'label': '03) REINFORCEMENT (Clean & Rust Free)', 'count': 10},
      {'label': '04) ELECTRICAL CONDUITS & BOXES. (Drawing)', 'count': 7},
      // Note: some items in section 4 continue from previous count.
      // The particulars list is flat; we use kSectionBreaks to know where to insert headers.
      {'label': '05) GENERAL', 'count': 14},
    ];

    final widgets = <Widget>[];
    int rowIdx = 0;
    for (final sec in sections) {
      // Section header
      widgets.add(Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 8),
        margin: const EdgeInsets.only(top: 6, bottom: 4),
        decoration: BoxDecoration(
          color: AppColors.primaryGreen.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          sec['label'] as String,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryGreen),
        ),
      ));

      final count = sec['count'] as int;
      for (int i = 0; i < count && rowIdx < _testRows.length; i++) {
        widgets.add(_buildTestRow(rowIdx));
        rowIdx++;
      }
    }

    return widgets;
  }

  Widget _buildTestRow(int idx) {
    final row = _testRows[idx];
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
          width: 28,
          child: Center(
            child: Text(
              row.srNo.toUpperCase(),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryGreen),
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
                height: 1.4),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: Column(children: [
            _radioCheck('Yes', 'yes', row.check,
                (v) => setState(() => row.check = v)),
            const SizedBox(height: 4),
            _radioCheck('No', 'no', row.check,
                (v) => setState(() => row.check = v)),
          ]),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: TextField(
            controller: row.remarkCtrl,
            decoration: InputDecoration(
              hintText: 'Remark',
              hintStyle: const TextStyle(
                  fontSize: 11, color: Color(0xFFCBD5E1)),
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
                      color: AppColors.primaryGreen, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 6),
              isDense: true,
            ),
            style: const TextStyle(
                fontSize: 11, color: Color(0xFF1E293B)),
            maxLines: 2,
          ),
        ),
      ]),
    );
  }

  Widget _buildObservationsSection() => _card(
        title: 'Additional Observations',
        icon: Icons.notes_outlined,
        child: TextField(
          controller: _observationsCtrl,
          maxLines: 4,
          decoration: InputDecoration(
            hintText:
                'Enter any additional observations (optional)…',
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
          style: const TextStyle(
              fontSize: 13, color: Color(0xFF1E293B)),
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
              const Text('Contractor Representative',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text('Date:',
                  style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8))),
            ]),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
              const SizedBox(height: 48),
              Divider(color: AppColors.primaryGreen),
              const Text('Project Engineer / Client',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text('Date:',
                  style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8))),
            ]),
          ),
        ]),
      );

  // ── Reusable helpers ──────────────────────────────────────────────────────

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
              color: AppColors.primaryGreen.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12)),
            ),
            child: Row(children: [
              Icon(icon, size: 15, color: AppColors.primaryGreen),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryGreen)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        ]),
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
          border: Border.all(color: const Color(0xFFE2E8F0)),
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
    TextInputType? type,
    int maxLines = 1,
  }) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label(label),
        TextField(
          controller: ctrl,
          keyboardType: type,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
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
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 11),
            isDense: true,
          ),
          style: const TextStyle(
              fontSize: 13, color: Color(0xFF1E293B)),
        ),
      ]);

  Widget _datePicker({
    required DateTime? value,
    required String hint,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Expanded(
              child: Text(
                value != null ? _fmtDate(value) : hint,
                style: TextStyle(
                    fontSize: 13,
                    color: value != null
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFCBD5E1)),
              ),
            ),
            Icon(Icons.calendar_today_outlined,
                size: 16,
                color: value != null
                    ? AppColors.primaryGreen
                    : const Color(0xFF94A3B8)),
          ]),
        ),
      );

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
        padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.12)
              : Colors.white,
          border: Border.all(
              color:
                  selected ? color : const Color(0xFFE2E8F0)),
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
            color: selected ? color : const Color(0xFF94A3B8),
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