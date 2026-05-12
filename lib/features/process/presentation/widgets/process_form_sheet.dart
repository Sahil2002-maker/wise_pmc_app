// lib/features/process/presentation/widgets/process_form_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/services/api_service.dart';
import '../../../../core/utils/api_exception.dart';
import '../../data/models/process_model.dart';

/// Bottom sheet for both creating and editing a process.
///
/// Pass [process] for edit mode; omit it for create mode.
class ProcessFormSheet extends StatefulWidget {
  final ProcessModel? process;
  final List<ProcessTeamModel> teams;
  final String initialStage;

  const ProcessFormSheet({
    super.key,
    this.process,
    required this.teams,
    required this.initialStage,
  });

  @override
  State<ProcessFormSheet> createState() => _ProcessFormSheetState();
}

class _ProcessFormSheetState extends State<ProcessFormSheet> {
  // ── Controllers ───────────────────────────────────────────────────────────

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _dayCtrl;

  int? _selectedTeamId;
  String? _selectedStage;
  bool _submitting = false;

  bool get _isEdit => widget.process != null;

  // ── Stage options ─────────────────────────────────────────────────────────

  static const List<_StageOption> _stageOptions = [
    _StageOption(key: 'pmc_application', label: 'PMC Application'),
    _StageOption(key: 'stage1', label: 'Stage 1'),
    _StageOption(key: 'stage2', label: 'Stage 2'),
    _StageOption(key: 'stage3', label: 'Stage 3'),
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
        text: widget.process?.processName ?? '');
    _dayCtrl = TextEditingController(
        text: widget.process?.day?.toString() ?? '');
    _selectedTeamId = widget.process?.workingTeam;
    _selectedStage = _isEdit ? widget.process!.stage : widget.initialStage;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dayCtrl.dispose();
    super.dispose();
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTeamId == null) {
      _showError('Please select a working team.');
      return;
    }
    if (_selectedStage == null) {
      _showError('Please select a stage.');
      return;
    }

    setState(() => _submitting = true);

    try {
      final day = int.tryParse(_dayCtrl.text.trim());

      if (_isEdit) {
        await ApiService.updateProcess(
          orderNo: widget.process!.orderNo,
          processName: _nameCtrl.text.trim(),
          workingTeam: _selectedTeamId!,
          stage: _selectedStage!,
          day: day,
        );
      } else {
        await ApiService.createProcess(
          processName: _nameCtrl.text.trim(),
          workingTeam: _selectedTeamId!,
          stage: _selectedStage!,
          day: day,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        _showError(e is ApiException ? e.message : e.toString());
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(msg,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5E50EE).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.layers_rounded,
                        color: Color(0xFF5E50EE), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEdit ? 'Edit Process' : 'Add Process',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B)),
                        ),
                        Text(
                          _isEdit
                              ? 'Update the process details below.'
                              : 'Fill in the details to create a new process.',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded,
                        color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),

            const Divider(height: 24),

            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Process name
                      _FormLabel(label: 'Process Name'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: _inputDecoration(
                          hint: 'Enter process name',
                          icon: Icons.label_rounded,
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Process name is required.'
                            : null,
                      ),

                      const SizedBox(height: 16),

                      // Working team
                      _FormLabel(label: 'Working Team'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        value: _selectedTeamId,
                        decoration: _inputDecoration(
                          hint: 'Select working team',
                          icon: Icons.group_rounded,
                        ),
                        items: widget.teams
                            .map((t) => DropdownMenuItem(
                                  value: t.id,
                                  child: Text(t.teamName,
                                      style: const TextStyle(fontSize: 13)),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedTeamId = v),
                        validator: (v) =>
                            v == null ? 'Please select a working team.' : null,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded,
                            color: Color(0xFF94A3B8)),
                        isExpanded: true,
                      ),

                      const SizedBox(height: 16),

                      // Stage
                      _FormLabel(label: 'Stage'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedStage,
                        decoration: _inputDecoration(
                          hint: 'Select stage',
                          icon: Icons.stacked_line_chart_rounded,
                        ),
                        items: _stageOptions
                            .map((s) => DropdownMenuItem(
                                  value: s.key,
                                  child: Text(s.label,
                                      style: const TextStyle(fontSize: 13)),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedStage = v),
                        validator: (v) =>
                            v == null ? 'Please select a stage.' : null,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded,
                            color: Color(0xFF94A3B8)),
                        isExpanded: true,
                      ),

                      const SizedBox(height: 16),

                      // Deadline (days)
                      _FormLabel(label: 'Deadline (Days)'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _dayCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        decoration: _inputDecoration(
                          hint: 'e.g. 7  (optional)',
                          icon: Icons.timer_rounded,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final n = int.tryParse(v.trim());
                          if (n == null || n < 0) {
                            return 'Enter a valid number of days.';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 28),

                      // Submit button
                      ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5E50EE),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              const Color(0xFF5E50EE).withValues(alpha: 0.5),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white),
                              )
                            : Text(_isEdit ? 'Update Process' : 'Add Process'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          const TextStyle(color: Color(0xFFB0BAC9), fontSize: 13),
      prefixIcon: Icon(icon, color: const Color(0xFF5E50EE), size: 18),
      filled: true,
      fillColor: const Color(0xFFF8F9FF),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE8EAFF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE8EAFF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: Color(0xFF5E50EE), width: 1.5),
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
}

// ─── Form label ───────────────────────────────────────────────────────────────

class _FormLabel extends StatelessWidget {
  final String label;
  const _FormLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF475569),
        letterSpacing: 0.2,
      ),
    );
  }
}

// ─── Stage option ─────────────────────────────────────────────────────────────

class _StageOption {
  final String key;
  final String label;
  const _StageOption({required this.key, required this.label});
}