// lib/features/stage21/presentation/pages/material_weight_measurement_form_page.dart
//
// Create & Edit form for Material Weight Measurement.
//
// FIX 1 (cursor/text order bug): TextEditingControllers for Vehicle Number,
//   Challan Number, Gross Weight, and Tare Weight are now owned by a dedicated
//   _EntryCardState.  Previously they were created inside the parent build()
//   method, so every notifyListeners() call recreated them and reset the cursor
//   to position 0 — making characters appear out of order.
//
// FIX 2 (spurious validation error): ctrl.clearFormError() is now called
//   whenever any field in an entry changes, so a stale "Please enter valid
//   Loaded and Empty weights" message from a prior submit attempt is dismissed
//   the moment the user starts correcting the form.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../controllers/material_weight_measurement_controller.dart';
import '../../data/models/material_weight_measurement_model.dart';

class MaterialWeightMeasurementFormPage extends StatefulWidget {
  final MaterialWeightMeasurementController controller;
  final bool isEdit;
  final int? recordId;

  const MaterialWeightMeasurementFormPage({
    super.key,
    required this.controller,
    required this.isEdit,
    this.recordId,
  });

  @override
  State<MaterialWeightMeasurementFormPage> createState() =>
      _MaterialWeightMeasurementFormPageState();
}

class _MaterialWeightMeasurementFormPageState
    extends State<MaterialWeightMeasurementFormPage> {
  static const Color _accent = Color(0xFF059669);

  final _remarksCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  // Tracks which entry/slot is currently uploading so the slot can show a
  // small spinner instead of blocking the whole screen.
  String? _busySlotKey;

  @override
  void initState() {
    super.initState();
    _remarksCtrl.text = widget.controller.formRemarks ?? '';
  }

  @override
  void dispose() {
    _remarksCtrl.dispose();
    super.dispose();
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    widget.controller.formRemarks =
        _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim();

    final ok = widget.isEdit
        ? await widget.controller.saveUpdate(widget.recordId!)
        : await widget.controller.saveCreate();

    if (!mounted) return;
    if (ok) {
      _showSnack(
        widget.isEdit
            ? 'Measurement updated successfully.'
            : 'Measurement saved successfully.',
        color: const Color(0xFF16A34A),
      );
      Navigator.pop(context);
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

  // ── File picking (delegated here so _busySlotKey lives in parent state) ──

  Future<void> pickFile(
    int entryIndex,
    MwmFileSlotKey slotKey,
    String busyKey,
  ) async {
    final source = await _showSourceSheet();
    if (source == null) return;

    setState(() => _busySlotKey = busyKey);
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2000,
      );
      if (picked == null) return;
      await widget.controller
          .setEntryFile(entryIndex, slotKey, File(picked.path));
    } catch (e) {
      if (mounted) {
        _showSnack('Could not capture/select photo.',
            color: const Color(0xFFEF4444));
      }
    } finally {
      if (mounted) setState(() => _busySlotKey = null);
    }
  }

  String? get busySlotKey => _busySlotKey;

  Future<ImageSource?> _showSourceSheet() =>
      showModalBottomSheet<ImageSource>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading:
                    const Icon(Icons.camera_alt_outlined, color: _accent),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: _accent),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.isEdit ? 'Edit Measurement' : 'New Measurement',
          style:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      body: AnimatedBuilder(
        animation: ctrl,
        builder: (_, __) {
          if (ctrl.formLoading) {
            return const Center(
                child: CircularProgressIndicator(color: _accent));
          }
          if (ctrl.formError != null && ctrl.formEntries.isEmpty) {
            return _buildInitError(ctrl);
          }
          return _buildForm(ctrl);
        },
      ),
    );
  }

  Widget _buildInitError(MaterialWeightMeasurementController ctrl) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFEF4444), size: 48),
              const SizedBox(height: 12),
              Text(ctrl.formError ?? 'Failed to load form.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF64748B))),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  ctrl.clearFormError();
                  if (widget.isEdit && widget.recordId != null) {
                    ctrl.initEditForm(widget.recordId!);
                  } else {
                    ctrl.initCreateForm();
                  }
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      );

  Widget _buildForm(MaterialWeightMeasurementController ctrl) {
    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(ctrl),
              const SizedBox(height: 16),

              // ── Error banner ─────────────────────────────────────────
              if (ctrl.formError != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline,
                        color: Color(0xFFEF4444), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(ctrl.formError!,
                          style: const TextStyle(
                              color: Color(0xFFB91C1C),
                              fontSize: 13)),
                    ),
                    IconButton(
                      onPressed: ctrl.clearFormError,
                      icon: const Icon(Icons.close,
                          color: Color(0xFFEF4444), size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
              ],

              // ── Remarks ──────────────────────────────────────────────
              _buildSection(
                label: 'Remarks (Optional)',
                child: TextField(
                  controller: _remarksCtrl,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 13),
                  decoration: _inputDeco('Add any overall remarks…'),
                ),
              ),
              const SizedBox(height: 16),

              // ── Entries ──────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Measurement Entries',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B))),
                  TextButton.icon(
                    onPressed: ctrl.addEntry,
                    icon: const Icon(Icons.add_circle_outline,
                        color: _accent, size: 18),
                    label: const Text('Add Entry',
                        style:
                            TextStyle(color: _accent, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // ── FIX 1: Each entry is now its own StatefulWidget ──────
              // This ensures TextEditingControllers are created once per
              // entry and are NOT recreated on every parent rebuild.
              ...ctrl.formEntries.asMap().entries.map(
                    (e) => _EntryCard(
                      key: ValueKey(
                          '${e.key}-${e.value.originalIndex ?? 'new'}'),
                      formPageState: this,
                      controller: ctrl,
                      index: e.key,
                      entry: e.value,
                      isEdit: widget.isEdit,
                    ),
                  ),

              const SizedBox(height: 8),

              _buildTotalSummary(ctrl),
            ],
          ),
        ),
      ),
      _buildSaveBar(ctrl),
    ]);
  }

  // ── Header card ───────────────────────────────────────────────────────────

  Widget _buildHeaderCard(MaterialWeightMeasurementController ctrl) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _accent.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('WR/MWM',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B))),
              Expanded(
                child: Text(
                  'WISE REALTY — Material Weight Measurement',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                ctrl.formMwmNo != null
                    ? 'No. ${ctrl.formMwmNo}'
                    : 'Generating…',
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(children: [
            Expanded(
                child: _readOnlyField(
                    'Project', widget.controller.projectName)),
            const SizedBox(width: 10),
            Expanded(
              child: _readOnlyField(
                'Date (Auto)',
                ctrl.formDate ?? '',
                suffix: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B7280),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Today',
                      style: TextStyle(
                          color: Colors.white, fontSize: 9)),
                ),
              ),
            ),
          ]),
        ]),
      );

  Widget _readOnlyField(String label, String value,
          {Widget? suffix}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B))),
          const SizedBox(height: 4),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(children: [
              Expanded(
                child: Text(value,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B))),
              ),
              if (suffix != null) suffix,
            ]),
          ),
        ],
      );

  // ── Total net summary ─────────────────────────────────────────────────────

  Widget _buildTotalSummary(MaterialWeightMeasurementController ctrl) =>
      AnimatedBuilder(
        animation: ctrl,
        builder: (_, __) => Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF059669).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color:
                    const Color(0xFF059669).withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Net Weight (All Entries)',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF059669))),
                  const SizedBox(height: 2),
                  Text(
                    '${ctrl.formEntries.length} entr${ctrl.formEntries.length == 1 ? 'y' : 'ies'}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              Text(
                '${ctrl.formTotalNet.toStringAsFixed(3)} kg',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF059669)),
              ),
            ],
          ),
        ),
      );

  // ── Save bar ──────────────────────────────────────────────────────────────

  Widget _buildSaveBar(MaterialWeightMeasurementController ctrl) =>
      AnimatedBuilder(
        animation: ctrl,
        builder: (_, __) => Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border:
                Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: ctrl.formSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: ctrl.formSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : Text(
                        widget.isEdit
                            ? 'Update Measurement'
                            : 'Save Measurement',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ),
        ),
      );

  // ── Shared helpers (used by _EntryCard) ──────────────────────────────────

  Widget buildSection({required String label, required Widget child}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151))),
          const SizedBox(height: 6),
          child,
        ],
      );

  static InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: Color(0xFFB0BAC9), fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
          borderSide:
              const BorderSide(color: _accent, width: 1.5),
        ),
      );

  Widget _buildSection(
          {required String label, required Widget child}) =>
      buildSection(label: label, child: child);

  static InputDecoration inputDeco(String hint) => _inputDeco(hint);
}

// ═══════════════════════════════════════════════════════════════════════════
// _EntryCard — isolated StatefulWidget for one measurement entry row.
//
// ROOT-CAUSE FIX:
//   The original code built TextEditingControllers inside _buildEntryCard(),
//   which ran on every AnimatedBuilder rebuild (i.e. every keystroke).
//   Each rebuild replaced the controller with a new one whose cursor was
//   at position 0, causing later characters to appear before earlier ones.
//
//   By moving the controllers into _EntryCardState.initState() they are
//   created exactly once and survive parent rebuilds intact.
// ═══════════════════════════════════════════════════════════════════════════

class _EntryCard extends StatefulWidget {
  final _MaterialWeightMeasurementFormPageState formPageState;
  final MaterialWeightMeasurementController controller;
  final int index;
  final MwmEntryForm entry;
  final bool isEdit;

  const _EntryCard({
    super.key,
    required this.formPageState,
    required this.controller,
    required this.index,
    required this.entry,
    required this.isEdit,
  });

  @override
  State<_EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends State<_EntryCard> {
  static const Color _accent = Color(0xFF059669);

  // ── Controllers created ONCE in initState ────────────────────────────────
  late final TextEditingController _vehicleCtrl;
  late final TextEditingController _challanCtrl;
  late final TextEditingController _grossCtrl;
  late final TextEditingController _tareCtrl;

  // Prevent feedback loops: when we push an external value into a controller
  // we set this flag so the listener ignores that one change.
  bool _suppressListener = false;

  @override
  void initState() {
    super.initState();

    final e = widget.entry;
    _vehicleCtrl = TextEditingController(text: e.vehicleNumber);
    _challanCtrl = TextEditingController(text: e.challanNumber);
    _grossCtrl = TextEditingController(
        text: e.grossWeight > 0 ? e.grossWeight.toString() : '');
    _tareCtrl = TextEditingController(
        text: e.tareWeight > 0 ? e.tareWeight.toString() : '');

    _vehicleCtrl.addListener(_onFieldChanged);
    _challanCtrl.addListener(_onFieldChanged);
    _grossCtrl.addListener(_onFieldChanged);
    _tareCtrl.addListener(_onFieldChanged);
  }

  @override
  void didUpdateWidget(_EntryCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // When the parent pushes an updated entry (e.g. material type changed),
    // sync controllers only if the values differ — and suppress our own
    // listener during the sync to avoid an update loop.
    final e = widget.entry;
    _syncController(_vehicleCtrl, e.vehicleNumber);
    _syncController(_challanCtrl, e.challanNumber);
    _syncController(
        _grossCtrl, e.grossWeight > 0 ? e.grossWeight.toString() : '');
    _syncController(
        _tareCtrl, e.tareWeight > 0 ? e.tareWeight.toString() : '');
  }

  void _syncController(TextEditingController ctrl, String newValue) {
    if (ctrl.text != newValue) {
      _suppressListener = true;
      // Preserve cursor position as much as possible
      final offset =
          ctrl.selection.baseOffset.clamp(0, newValue.length);
      ctrl.value = ctrl.value.copyWith(
        text: newValue,
        selection: TextSelection.collapsed(offset: offset),
      );
      _suppressListener = false;
    }
  }

  @override
  void dispose() {
    _vehicleCtrl.dispose();
    _challanCtrl.dispose();
    _grossCtrl.dispose();
    _tareCtrl.dispose();
    super.dispose();
  }

  // ── Field change handler ─────────────────────────────────────────────────

  void _onFieldChanged() {
    if (_suppressListener) return;

    final ctrl = widget.controller;

    // FIX 2: Clear any stale validation error the moment the user edits
    // any field.  This prevents "Please enter valid Loaded and Empty
    // weights" from lingering while the user is still filling in Vehicle
    // Number or Challan Number.
    if (ctrl.formError != null) {
      ctrl.clearFormError();
    }

    final updated = widget.entry.copyWith(
      vehicleNumber: _vehicleCtrl.text,
      challanNumber: _challanCtrl.text,
      grossWeight: double.tryParse(_grossCtrl.text) ?? 0.0,
      tareWeight: double.tryParse(_tareCtrl.text) ?? 0.0,
    );
    ctrl.updateEntry(widget.index, updated);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final entry = widget.entry;
    final net = entry.netWeight;
    final isNew = entry.originalIndex == null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withValues(alpha: 0.25)),
      ),
      child: Column(children: [
        // ── Entry header ────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.06),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(6)),
              alignment: Alignment.center,
              child: Text('${widget.index + 1}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            Text('Entry #${widget.index + 1}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B))),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isNew
                    ? const Color(0xFF16A34A).withValues(alpha: 0.1)
                    : const Color(0xFF64748B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isNew
                    ? 'New'
                    : 'Original #${entry.originalIndex! + 1}',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: isNew
                      ? const Color(0xFF16A34A)
                      : const Color(0xFF64748B),
                ),
              ),
            ),
            const Spacer(),
            // Net badge — rebuilt only when net weight changes
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF16A34A)
                        .withValues(alpha: 0.3)),
              ),
              child: Text(
                'Net: ${net.toStringAsFixed(3)} kg',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF16A34A)),
              ),
            ),
            const SizedBox(width: 6),
            // Remove button
            if (ctrl.formEntries.length > 1)
              IconButton(
                onPressed: () {
                  if (ctrl.formEntries.length <= 1) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(
                      content:
                          Text('At least one entry is required.'),
                    ));
                    return;
                  }
                  if (widget.isEdit && entry.originalIndex != null) {
                    _showRemoveAuditDialog(
                        ctrl, widget.index, entry.originalIndex!);
                  } else {
                    ctrl.removeEntry(widget.index);
                  }
                },
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFEF4444), size: 18),
                tooltip: 'Remove Entry',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ]),
        ),

        // ── Entry fields ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Vehicle / Challan
              Row(children: [
                Expanded(
                  child: _formField(
                    label: 'Vehicle Number *',
                    controller: _vehicleCtrl,
                    hint: 'e.g. MH04 AB 1234',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _formField(
                    label: 'Challan Number *',
                    controller: _challanCtrl,
                    hint: 'Challan / Invoice No.',
                  ),
                ),
              ]),
              const SizedBox(height: 10),

              _buildMaterialTypeField(ctrl, widget.index, entry),
              const SizedBox(height: 10),

              // Row 2: Loaded Weight + slip, Vehicle Photo
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _formField(
                      label: 'Loaded Weight (kg) *',
                      controller: _grossCtrl,
                      hint: '0.000',
                      isNumber: true,
                      sublabel: 'Vehicle + Material',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildFileSlot(
                      ctrl: ctrl,
                      entryIndex: widget.index,
                      slotKey: MwmFileSlotKey.grossWeightSlip,
                      slot: entry.grossWeightSlip,
                      label: 'Loaded Weight Slip',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildFileSlot(
                      ctrl: ctrl,
                      entryIndex: widget.index,
                      slotKey:
                          MwmFileSlotKey.vehicleWithMaterialImage,
                      slot: entry.vehicleWithMaterialImage,
                      label: 'Vehicle Photo (With Material)',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Row 3: Empty Weight + slip
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _formField(
                      label: 'Empty Weight (kg) *',
                      controller: _tareCtrl,
                      hint: '0.000',
                      isNumber: true,
                      sublabel: 'Vehicle Only',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildFileSlot(
                      ctrl: ctrl,
                      entryIndex: widget.index,
                      slotKey: MwmFileSlotKey.tareWeightSlip,
                      slot: entry.tareWeightSlip,
                      label: 'Empty Weight Slip',
                    ),
                  ),
                  const Expanded(child: SizedBox()),
                ],
              ),
              const SizedBox(height: 12),

              // Net weight display
              _buildNetDisplay(net),
            ],
          ),
        ),
      ]),
    );
  }

  // ── Net weight display ────────────────────────────────────────────────────

  Widget _buildNetDisplay(double net) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: const Color(0xFF16A34A).withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(children: [
              const Text('Loaded Wt.',
                  style: TextStyle(
                      fontSize: 10, color: Color(0xFF64748B))),
              Text(
                '${(double.tryParse(_grossCtrl.text) ?? 0.0).toStringAsFixed(3)} kg',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B)),
              ),
            ]),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('−',
                  style: TextStyle(
                      fontSize: 20, color: Color(0xFF94A3B8))),
            ),
            Column(children: [
              const Text('Empty Wt.',
                  style: TextStyle(
                      fontSize: 10, color: Color(0xFF64748B))),
              Text(
                '${(double.tryParse(_tareCtrl.text) ?? 0.0).toStringAsFixed(3)} kg',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B)),
              ),
            ]),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('=',
                  style: TextStyle(
                      fontSize: 20, color: Color(0xFF94A3B8))),
            ),
            Column(children: [
              const Text('Net Material Wt.',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF16A34A))),
              Text(
                '${net.toStringAsFixed(3)} kg',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF16A34A)),
              ),
            ]),
          ],
        ),
      );

  // ── File slot widget ──────────────────────────────────────────────────────

  Widget _buildFileSlot({
    required MaterialWeightMeasurementController ctrl,
    required int entryIndex,
    required MwmFileSlotKey slotKey,
    required MwmFileSlot slot,
    required String label,
  }) {
    final busyKey = '$entryIndex-$slotKey';
    final isBusy = widget.formPageState.busySlotKey == busyKey;
    final hasPreview = slot.hasNew || slot.hasExisting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: isBusy
              ? null
              : () => widget.formPageState
                  .pickFile(entryIndex, slotKey, busyKey),
          child: Container(
            height: 64,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasPreview
                    ? _accent.withValues(alpha: 0.4)
                    : const Color(0xFFCBD5E1),
              ),
            ),
            child: isBusy
                ? const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _accent),
                    ),
                  )
                : slot.hasNew
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(slot.newFile!,
                            fit: BoxFit.cover),
                      )
                    : slot.hasExisting
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              slot.existingUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Center(
                                child: Icon(
                                    Icons.picture_as_pdf_outlined,
                                    color: Color(0xFF94A3B8),
                                    size: 22),
                              ),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.add_a_photo_outlined,
                                color: Color(0xFF94A3B8), size: 20),
                          ),
          ),
        ),
        if (hasPreview)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () =>
                  ctrl.clearEntryFile(entryIndex, slotKey),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(0, 24),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Remove',
                  style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFFEF4444))),
            ),
          ),
        if (slot.geo != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(children: [
              const Icon(Icons.location_on_outlined,
                  size: 10, color: Color(0xFF1565C0)),
              const SizedBox(width: 2),
              const Flexible(
                child: Text(
                  'Location captured',
                  style: TextStyle(
                      fontSize: 9, color: Color(0xFF1565C0)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          )
        else if (!hasPreview)
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text(
              'Camera photos save your location automatically',
              style: TextStyle(fontSize: 8, color: Color(0xFF94A3B8)),
              maxLines: 2,
            ),
          ),
      ],
    );
  }

  // ── Material type dropdown ────────────────────────────────────────────────

  Widget _buildMaterialTypeField(
    MaterialWeightMeasurementController ctrl,
    int index,
    MwmEntryForm entry,
  ) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Material Type *',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151))),
          const SizedBox(height: 4),
          DropdownButtonFormField<MwmMaterialTypeModel>(
            value: entry.materialType,
            isExpanded: true,
            decoration:
                _MaterialWeightMeasurementFormPageState.inputDeco(
                        '-- Select Material Type --')
                    .copyWith(
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
            ),
            items: ctrl.materialTypes
                .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t.name,
                          style: const TextStyle(fontSize: 13)),
                    ))
                .toList(),
            onChanged: (val) {
              // FIX 2: clear error on material type change too
              if (ctrl.formError != null) ctrl.clearFormError();
              final updated =
                  entry.copyWith(materialType: val);
              ctrl.updateEntry(index, updated);
            },
          ),
        ],
      );

  // ── Form field helper ─────────────────────────────────────────────────────

  Widget _formField({
    required String label,
    required TextEditingController controller,
    String? hint,
    String? sublabel,
    bool isNumber = false,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Flexible(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151)),
                  overflow: TextOverflow.ellipsis),
            ),
            if (sublabel != null) ...[
              const SizedBox(width: 4),
              Flexible(
                child: Text('($sublabel)',
                    style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF94A3B8)),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ]),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            keyboardType: isNumber
                ? const TextInputType.numberWithOptions(
                    decimal: true)
                : TextInputType.text,
            inputFormatters: isNumber
                ? [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d*'))
                  ]
                : null,
            style: const TextStyle(fontSize: 13),
            decoration: _MaterialWeightMeasurementFormPageState
                .inputDeco(hint ?? ''),
          ),
        ],
      );

  // ── Remove-entry audit dialog ─────────────────────────────────────────────

  Future<void> _showRemoveAuditDialog(
    MaterialWeightMeasurementController ctrl,
    int index,
    int originalIndex,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Entry',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
            'Original Entry #${originalIndex + 1} will be moved to the Audit Trail on save. Files are retained on S3.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
            ),
            child: const Text('Move to Audit Trail'),
          ),
        ],
      ),
    );
    if (ok == true) ctrl.removeEntry(index);
  }
}