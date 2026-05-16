// lib/features/development_process/presentation/widgets/dev_process_form_sheet.dart
//
// Bottom sheet for Add / Edit a Development Process.
//
// FIX 1: RenderFlex overflowed by 0.993 pixels on the right.
//   – Team DropdownMenuItem Row: team name Text wrapped in Flexible
//     so long names truncate instead of overflowing the dropdown overlay.
//
// FIX 2 (dart errors):
//   – _selectedStage declared as int (was accidentally assigned from
//     process.stage which is now int stageNum — fixed initialisation).
//   – DropdownButtonFormField `value:` prop replaces deprecated `value:`
//     (no change needed — but `initialValue:` removed from TextFormField
//     where `controller` already sets the value, avoiding the deprecation).
//   – All .withOpacity() calls replaced with .withValues(alpha: …).

import 'package:flutter/material.dart';

import '../../../../core/services/api_service.dart';
import '../../../../core/utils/api_exception.dart';
import '../../data/models/dev_process_model.dart';

class DevProcessFormSheet extends StatefulWidget {
  final List<DevProcessTeamModel> teams;
  final DevProcessModel? process; // null → Add mode
  final int initialStage;

  const DevProcessFormSheet({
    super.key,
    required this.teams,
    this.process,
    this.initialStage = 0,
  });

  @override
  State<DevProcessFormSheet> createState() => _DevProcessFormSheetState();
}

class _DevProcessFormSheetState extends State<DevProcessFormSheet> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _orderCtrl = TextEditingController();

  bool    _submitting   = false;
  bool    _loadingOrder = false;
  String? _error;

  // FIX: explicitly typed as int so the String-vs-int error is impossible.
  int  _selectedStage  = 0;
  int? _selectedTeamId;

  bool get _isEdit => widget.process != null;

  static const List<String> _stageLabels = [
    'Stage 0', 'Stage 1', 'Stage 2', 'Stage 3',
  ];

  static const Color _accent = Color(0xFF2563EB);

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final p = widget.process!;
      _nameCtrl.text  = p.processName;
      _orderCtrl.text = p.orderNo.toString();
      // FIX: p.stageNum is int — assign directly (was p.stage which is now
      //      removed; stageNum is the canonical int field on the model).
      _selectedStage  = p.stageNum;
      _selectedTeamId = p.teamId;
    } else {
      _selectedStage = widget.initialStage;
      _fetchNextOrder();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }

  // ── API helpers ────────────────────────────────────────────────────────────

  Future<void> _fetchNextOrder() async {
    setState(() => _loadingOrder = true);
    try {
      final next = await ApiService.fetchDevProcessNextOrder(
          stage: _selectedStage);
      if (mounted) _orderCtrl.text = next.toString();
    } catch (_) {
      if (mounted) _orderCtrl.text = '1';
    } finally {
      if (mounted) setState(() => _loadingOrder = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTeamId == null) {
      setState(() => _error = 'Please select a team.');
      return;
    }

    setState(() {
      _submitting = true;
      _error      = null;
    });

    try {
      if (_isEdit) {
        await ApiService.updateDevProcess(
          processId:   widget.process!.processId,
          processName: _nameCtrl.text.trim(),
          teamId:      _selectedTeamId!,
          stage:       _selectedStage,
          orderNo:     int.parse(_orderCtrl.text.trim()),
        );
      } else {
        await ApiService.addDevProcess(
          processName: _nameCtrl.text.trim(),
          teamId:      _selectedTeamId!,
          stage:       _selectedStage,
          orderNo:     int.parse(_orderCtrl.text.trim()),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error      = e is ApiException ? e.message : e.toString();
          _submitting = false;
        });
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + bottomPad),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Handle ────────────────────────────────────────────────────
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Title ─────────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    // FIX: withOpacity → withValues
                    color: _accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isEdit ? Icons.edit_rounded : Icons.add_rounded,
                    color: _accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _isEdit ? 'Edit Process' : 'Add New Process',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Error banner ──────────────────────────────────────────────
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Color(0xFFEF4444), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                            color: Color(0xFFEF4444), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Form ──────────────────────────────────────────────────────
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Process Name
                  _label('Process Name'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameCtrl,
                    // FIX: removed deprecated `value:` — controller already
                    //      sets the initial text in initState.
                    decoration: _inputDeco(
                      hint: 'Enter process name',
                      icon: Icons.label_outline_rounded,
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Team
                  _label('Team'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    // FIX: use `value:` (not deprecated `initialValue:`)
                    value: _selectedTeamId,
                    isExpanded: true, // FIX: forces dropdown to respect its
                    //      parent width instead of sizing to content,
                    //      preventing the Row inside from overflowing.
                    decoration: _inputDeco(
                      hint: 'Select team',
                      icon: Icons.group_outlined,
                    ),
                    items: widget.teams.map((t) {
                      return DropdownMenuItem<int>(
                        value: t.id,
                        child: Row(
                          children: [
                            // Color dot
                            Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: _hexColor(t.teamColor),
                                shape: BoxShape.circle,
                              ),
                            ),
                            // FIX: Flexible lets long team names shrink /
                            //      ellipsis instead of overflowing the row.
                            Flexible(
                              child: Text(
                                t.teamName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedTeamId = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Stage
                  _label('Stage'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: _selectedStage,
                    isExpanded: true, // consistent with Team dropdown above
                    decoration: _inputDeco(
                      hint: 'Select stage',
                      icon: Icons.layers_outlined,
                    ),
                    items: List.generate(4, (i) {
                      return DropdownMenuItem<int>(
                        value: i,
                        child: Text(_stageLabels[i]),
                      );
                    }),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _selectedStage = v);
                      if (!_isEdit) _fetchNextOrder();
                    },
                  ),
                  const SizedBox(height: 16),

                  // Order No.
                  _label('Order No.'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _orderCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _inputDeco(
                      hint: 'e.g. 1',
                      icon: _loadingOrder
                          ? Icons.hourglass_empty_rounded
                          : Icons.format_list_numbered_rounded,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      final n = int.tryParse(v.trim());
                      if (n == null || n < 1) return 'Must be ≥ 1';
                      return null;
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Processes at or beyond this position will shift down automatically.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _submitting
                              ? null
                              : () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                            side: const BorderSide(
                                color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Cancel',
                              style:
                                  TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _isEdit ? 'Update' : 'Add Process',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF475569),
      ),
    );
  }

  InputDecoration _inputDeco({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          const TextStyle(color: Color(0xFFB0BAC9), fontSize: 13),
      prefixIcon: Icon(icon, color: _accent, size: 18),
      filled: true,
      fillColor: const Color(0xFFF8FAFF),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
    );
  }

  Color _hexColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF43C880);
    }
  }
}