// lib/features/development_process/presentation/widgets/assign_process_sheet.dart

import 'package:flutter/material.dart';

import '../../../../core/utils/api_exception.dart';
import '../../data/models/development_process_model.dart';
import '../../data/services/development_process_api.dart';

class AssignProcessSheet extends StatefulWidget {
  final DevelopmentProcessItem process;
  final int stageNumber;
  final int projectId;

  const AssignProcessSheet({
    super.key,
    required this.process,
    required this.stageNumber,
    required this.projectId,
  });

  @override
  State<AssignProcessSheet> createState() => _AssignProcessSheetState();
}

class _AssignProcessSheetState extends State<AssignProcessSheet> {
  bool _loadingMembers = true;
  bool _assigning = false;
  String? _loadError;

  List<TeamMemberItem> _members = [];
  int? _selectedMemberId;
  String? _selectedMemberName;

  bool _notApplicable = false;
  String? _deadline;

  final _deadlineController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  @override
  void dispose() {
    _deadlineController.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _fetchMembers() async {
    final teamId = widget.process.teamId;
    if (teamId == null || teamId <= 0) {
      setState(() {
        _loadingMembers = false;
        _loadError = 'No team assigned to this process.';
      });
      return;
    }

    setState(() {
      _loadingMembers = true;
      _loadError = null;
    });

    try {
      final members =
          await DevelopmentProcessApi.fetchTeamMembersForProcess(teamId);
      if (!mounted) return;
      setState(() {
        _members = members;
        _loadingMembers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e is ApiException ? e.message : e.toString();
        _loadingMembers = false;
      });
    }
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_notApplicable && _selectedMemberId == null) return;
    setState(() => _assigning = true);

    try {
      final result = await DevelopmentProcessApi.assignDevelopmentProcess(
        projectId: widget.projectId,
        stageNumber: widget.stageNumber,
        processId: widget.process.processId ?? 0,
        orderNo: widget.process.orderNo ?? 0,
        stage: widget.process.stage ?? 'stage${widget.stageNumber}',
        assignedTo: _notApplicable ? null : _selectedMemberId,
        deadline:
            (_deadline != null && _deadline!.isNotEmpty) ? _deadline : null,
        notApplicable: _notApplicable,
      );

      if (!mounted) return;
      Navigator.pop(context, result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _assigning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : e.toString()),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  // ── Date picker ───────────────────────────────────────────────────────────

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF7C3AED),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      final formatted =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() {
        _deadline = formatted;
        _deadlineController.text = formatted;
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      height: mq.size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          _buildHeader(),

          // Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Process info
                  _buildProcessInfo(),
                  const SizedBox(height: 20),

                  // Not Applicable toggle
                  _buildNAToggle(),
                  const SizedBox(height: 20),

                  // Members list
                  if (!_notApplicable) ...[
                    _buildMembersSection(),
                    const SizedBox(height: 20),
                    _buildDeadlineField(),
                  ],
                ],
              ),
            ),
          ),

          // Footer
          _buildFooter(mq),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF5B21B6), Color(0xFF7C3AED)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person_add_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Assign Process',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                Text('Select team member and optional deadline',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w400)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessInfo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PROCESS',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 1)),
          const SizedBox(height: 6),
          Text(
            widget.process.processName,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B)),
          ),
          if (widget.process.teamName != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.group_rounded,
                    size: 13, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Text(
                  widget.process.teamName!,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNAToggle() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _notApplicable
            ? const Color(0xFFF1F5F9)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _notApplicable
              ? const Color(0xFF94A3B8)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mark as Not Applicable',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF1E293B))),
                const SizedBox(height: 2),
                Text(
                  'This process will be skipped',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _notApplicable,
            onChanged: (v) => setState(() => _notApplicable = v),
            activeColor: const Color(0xFF7C3AED),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersSection() {
    if (_loadingMembers) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
        ),
      );
    }

    if (_loadError != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(_loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFFEF4444), fontSize: 13)),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _fetchMembers,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF7C3AED)),
            ),
          ],
        ),
      );
    }

    if (_members.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text('No team members found.',
              style: TextStyle(color: Color(0xFF94A3B8))),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ASSIGN TO',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF94A3B8),
                letterSpacing: 1)),
        const SizedBox(height: 10),
        ...List.generate(_members.length, (i) {
          final m = _members[i];
          final selected = _selectedMemberId == m.id;
          return Padding(
            padding: EdgeInsets.only(bottom: i < _members.length - 1 ? 8 : 0),
            child: GestureDetector(
              onTap: () => setState(() {
                _selectedMemberId = m.id;
                _selectedMemberName = m.name;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFEDE9FE)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF7C3AED)
                        : const Color(0xFFE2E8F0),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: selected
                              ? const [
                                  Color(0xFF7C3AED),
                                  Color(0xFF5B21B6)
                                ]
                              : const [
                                  Color(0xFFCBD5E1),
                                  Color(0xFF94A3B8)
                                ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          m.name.isNotEmpty
                              ? m.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.name,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: selected
                                    ? const Color(0xFF4C1D95)
                                    : const Color(0xFF1E293B)),
                          ),
                          if (m.email != null && m.email!.isNotEmpty)
                            Text(
                              m.email!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF94A3B8)),
                            ),
                        ],
                      ),
                    ),
                    if (selected)
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(Icons.check_rounded,
                            color: Colors.white, size: 13),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDeadlineField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('DEADLINE (OPTIONAL)',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF94A3B8),
                letterSpacing: 1)),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _pickDeadline,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _deadline != null
                    ? const Color(0xFF7C3AED)
                    : const Color(0xFFE2E8F0),
                width: _deadline != null ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: _deadline != null
                      ? const Color(0xFF7C3AED)
                      : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 10),
                Text(
                  _deadline ?? 'Select deadline date',
                  style: TextStyle(
                    fontSize: 14,
                    color: _deadline != null
                        ? const Color(0xFF1E293B)
                        : const Color(0xFF94A3B8),
                    fontWeight: _deadline != null
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
                if (_deadline != null) ...[
                  const Spacer(),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _deadline = null),
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: Color(0xFF94A3B8)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(MediaQueryData mq) {
    final canSubmit = _notApplicable ||
        (_selectedMemberId != null && !_loadingMembers);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, mq.padding.bottom + 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: canSubmit && !_assigning ? _submit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFE2E8F0),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: _assigning
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  _notApplicable
                      ? 'Mark as Not Applicable'
                      : _selectedMemberId == null
                          ? 'Select a member first'
                          : 'Assign to $_selectedMemberName',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
        ),
      ),
    );
  }
}