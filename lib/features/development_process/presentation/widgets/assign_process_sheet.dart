// lib/features/development_process/presentation/widgets/assign_process_sheet.dart
//
// KEY CHANGES vs previous version
// ─────────────────────────────────────────────────────────────────────────────
//
//  The backend's getTeamMembers() (MobileDevelopmentProcessController) now
//  returns a `role` field for each member:
//    { "id": 5, "name": "Shubham Patil", "email": "...", "role": "Team Leader" }
//    { "id": 9, "name": "Sheetal Sase",  "email": "...", "role": "Team Member" }
//
//  TeamMemberItem.isTeamLeader already checks `role.contains('leader')`.
//  So the sheet already splits into _leaders / _members correctly.
//
//  Previous issue: the OLD backend was stripping leaders from the response
//  entirely (array_diff without re-adding them). That is now fixed in
//  MobileDevelopmentProcessController::getTeamMembers(). This sheet needs no
//  logic change — it just needed the backend to send leaders too.
//
//  Visible change: leaders now appear at the top of the list with a purple
//  star badge, and members appear below with a blue person badge.
//  This matches the web portal's "Assign to" dropdown exactly.

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
  bool _assigning      = false;
  String? _loadError;

  // Separated into leaders + members so we can render section headers
  List<TeamMemberItem> _leaders = [];
  List<TeamMemberItem> _members = [];

  int?    _selectedMemberId;
  String? _selectedMemberName;
  bool    _selectedIsLeader = false;

  bool    _notApplicable = false;
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

  // ── Data fetch ────────────────────────────────────────────────────────────

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
      _loadError      = null;
    });

    try {
      // Backend getTeamMembers() returns leaders first (role='Team Leader'),
      // then members (role='Team Member'). TeamMemberItem.isTeamLeader uses
      // the role field, so splitting here is safe and correct.
      final all =
          await DevelopmentProcessApi.fetchTeamMembersForProcess(teamId);
      if (!mounted) return;
      setState(() {
        _leaders        = all.where((m) => m.isTeamLeader).toList();
        _members        = all.where((m) => !m.isTeamLeader).toList();
        _loadingMembers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError      = e is ApiException ? e.message : e.toString();
        _loadingMembers = false;
      });
    }
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_notApplicable && _selectedMemberId == null) return;
    setState(() => _assigning = true);

    try {
      final result = await DevelopmentProcessApi.assignDevelopmentProcess(
        projectId:     widget.projectId,
        stageNumber:   widget.stageNumber,
        processId:     widget.process.processId ?? 0,
        orderNo:       widget.process.orderNo   ?? 0,
        stage:         widget.process.stage     ?? 'stage${widget.stageNumber}',
        assignedTo:    _notApplicable ? null : _selectedMemberId,
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
          behavior:        SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  // ── Date picker ───────────────────────────────────────────────────────────

  Future<void> _pickDeadline() async {
    final now    = DateTime.now();
    final picked = await showDatePicker(
      context:     context,
      initialDate: now,
      firstDate:   now,
      lastDate:    DateTime(now.year + 5),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              const ColorScheme.light(primary: Color(0xFF7C3AED)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      final fmt =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() {
        _deadline               = fmt;
        _deadlineController.text = fmt;
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      height: mq.size.height * 0.85,
      decoration: const BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color:        const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProcessInfo(),
                  const SizedBox(height: 20),
                  _buildNAToggle(),
                  if (!_notApplicable) ...[
                    const SizedBox(height: 20),
                    _buildMembersSection(),
                    const SizedBox(height: 20),
                    _buildDeadlineField(),
                  ],
                ],
              ),
            ),
          ),
          _buildFooter(mq),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF5B21B6), Color(0xFF7C3AED)],
          begin:  Alignment.centerLeft,
          end:    Alignment.centerRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color:        Colors.white.withValues(alpha: 0.2),
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
                        color:      Colors.white,
                        fontSize:   16,
                        fontWeight: FontWeight.w700)),
                Text('Select team leader / member and optional deadline',
                    style: TextStyle(
                        color:      Colors.white70,
                        fontSize:   11,
                        fontWeight: FontWeight.w400)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color:        Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  // ── Process info card ─────────────────────────────────────────────────────

  Widget _buildProcessInfo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PROCESS',
              style: TextStyle(
                  fontSize:      10,
                  fontWeight:    FontWeight.w700,
                  color:         Color(0xFF94A3B8),
                  letterSpacing: 1)),
          const SizedBox(height: 6),
          Text(widget.process.processName,
              style: const TextStyle(
                  fontSize:   15,
                  fontWeight: FontWeight.w700,
                  color:      Color(0xFF1E293B))),
          if (widget.process.teamName != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.group_rounded,
                  size: 13, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(widget.process.teamName!,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF64748B))),
            ]),
          ],
        ],
      ),
    );
  }

  // ── N/A toggle ────────────────────────────────────────────────────────────

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
                        fontSize:   14,
                        color:      Color(0xFF1E293B))),
                const SizedBox(height: 2),
                Text('This process will be skipped',
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Switch.adaptive(
            value:       _notApplicable,
            onChanged:   (v) => setState(() => _notApplicable = v),
            activeColor: const Color(0xFF7C3AED),
          ),
        ],
      ),
    );
  }

  // ── Members section ───────────────────────────────────────────────────────
  //
  // Renders Team Leaders first (purple star badge) then Team Members (blue
  // person badge), exactly mirroring the web portal's assign dropdown.

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
          color:        const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Text(_loadError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFFEF4444), fontSize: 13)),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _fetchMembers,
            icon:  const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF7C3AED)),
          ),
        ]),
      );
    }

    if (_leaders.isEmpty && _members.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: const Color(0xFFE2E8F0)),
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
                fontSize:      10,
                fontWeight:    FontWeight.w700,
                color:         Color(0xFF94A3B8),
                letterSpacing: 1)),
        const SizedBox(height: 12),

        // ── Team Leaders ──────────────────────────────────────────────────
        if (_leaders.isNotEmpty) ...[
          const _SectionHeader(
            icon:  Icons.star_rounded,
            label: 'Team Leaders',
            color: Color(0xFF7C3AED),
          ),
          const SizedBox(height: 8),
          ..._leaders.asMap().entries.map((e) => Padding(
                padding: EdgeInsets.only(
                    bottom: (e.key < _leaders.length - 1 ||
                            _members.isNotEmpty)
                        ? 8
                        : 0),
                child: _MemberCard(
                  member:   e.value,
                  selected: _selectedMemberId == e.value.id,
                  onSelect: () => setState(() {
                    _selectedMemberId   = e.value.id;
                    _selectedMemberName = e.value.name;
                    _selectedIsLeader   = true;
                  }),
                ),
              )),
          if (_members.isNotEmpty) const SizedBox(height: 16),
        ],

        // ── Team Members ──────────────────────────────────────────────────
        if (_members.isNotEmpty) ...[
          const _SectionHeader(
            icon:  Icons.people_rounded,
            label: 'Team Members',
            color: Color(0xFF3B82F6),
          ),
          const SizedBox(height: 8),
          ..._members.asMap().entries.map((e) => Padding(
                padding: EdgeInsets.only(
                    bottom: e.key < _members.length - 1 ? 8 : 0),
                child: _MemberCard(
                  member:   e.value,
                  selected: _selectedMemberId == e.value.id,
                  onSelect: () => setState(() {
                    _selectedMemberId   = e.value.id;
                    _selectedMemberName = e.value.name;
                    _selectedIsLeader   = false;
                  }),
                ),
              )),
        ],
      ],
    );
  }

  // ── Deadline field ────────────────────────────────────────────────────────

  Widget _buildDeadlineField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('DEADLINE (OPTIONAL)',
            style: TextStyle(
                fontSize:      10,
                fontWeight:    FontWeight.w700,
                color:         Color(0xFF94A3B8),
                letterSpacing: 1)),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _pickDeadline,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
            child: Row(children: [
              Icon(Icons.calendar_today_rounded,
                  size: 16,
                  color: _deadline != null
                      ? const Color(0xFF7C3AED)
                      : const Color(0xFF94A3B8)),
              const SizedBox(width: 10),
              Text(
                _deadline ?? 'Select deadline date',
                style: TextStyle(
                    fontSize:   14,
                    color: _deadline != null
                        ? const Color(0xFF1E293B)
                        : const Color(0xFF94A3B8),
                    fontWeight: _deadline != null
                        ? FontWeight.w600
                        : FontWeight.w400),
              ),
              if (_deadline != null) ...[
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() {
                    _deadline = null;
                    _deadlineController.clear();
                  }),
                  child: const Icon(Icons.close_rounded,
                      size: 16, color: Color(0xFF94A3B8)),
                ),
              ],
            ]),
          ),
        ),
      ],
    );
  }

  // ── Footer / submit button ────────────────────────────────────────────────

  Widget _buildFooter(MediaQueryData mq) {
    final canSubmit =
        _notApplicable || (_selectedMemberId != null && !_loadingMembers);

    final String buttonLabel;
    if (_notApplicable) {
      buttonLabel = 'Mark as Not Applicable';
    } else if (_selectedMemberId == null) {
      buttonLabel = 'Select a member first';
    } else {
      final roleTag = _selectedIsLeader ? ' (Team Leader)' : '';
      buttonLabel = 'Assign to $_selectedMemberName$roleTag';
    }

    return Padding(
      padding:
          EdgeInsets.fromLTRB(20, 12, 20, mq.padding.bottom + 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: canSubmit && !_assigning ? _submit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor:         const Color(0xFF7C3AED),
            foregroundColor:         Colors.white,
            disabledBackgroundColor: const Color(0xFFE2E8F0),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: _assigning
              ? const SizedBox(
                  width:  20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(buttonLabel,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

// ─── Section header divider ───────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 22, height: 22,
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 13, color: color),
      ),
      const SizedBox(width: 8),
      Text(label,
          style: TextStyle(
              fontSize:      11,
              fontWeight:    FontWeight.w700,
              color:         color,
              letterSpacing: 0.3)),
      const SizedBox(width: 8),
      Expanded(
          child: Container(
              height: 1, color: color.withValues(alpha: 0.15))),
    ]);
  }
}

// ─── Individual member / leader card ─────────────────────────────────────────

class _MemberCard extends StatelessWidget {
  final TeamMemberItem member;
  final bool           selected;
  final VoidCallback   onSelect;

  const _MemberCard({
    required this.member,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isLeader    = member.isTeamLeader;
    final accentColor = isLeader
        ? const Color(0xFF7C3AED)  // purple for leaders
        : const Color(0xFF3B82F6); // blue for members
    final selectedBg  = isLeader
        ? const Color(0xFFEDE9FE)
        : const Color(0xFFEFF6FF);

    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? selectedBg : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accentColor : const Color(0xFFE2E8F0),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(children: [
          // Avatar initial
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: selected
                    ? [accentColor, accentColor.withValues(alpha: 0.7)]
                    : const [Color(0xFFCBD5E1), Color(0xFF94A3B8)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                member.name.isNotEmpty
                    ? member.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color:      Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize:   14),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name + role badge + email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(
                      member.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize:   13,
                          color: selected
                              ? accentColor.withValues(alpha: 0.85)
                              : const Color(0xFF1E293B)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Role badge — always visible, matches web dropdown labels
                  _RoleBadge(
                    label:  isLeader ? 'Team Leader' : 'Member',
                    color:  accentColor,
                    filled: selected,
                  ),
                ]),
                if (member.email != null && member.email!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(member.email!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF94A3B8))),
                ],
              ],
            ),
          ),

          // Check mark when selected
          if (selected)
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                  color:        accentColor,
                  borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.check_rounded,
                  color: Colors.white, size: 13),
            ),
        ]),
      ),
    );
  }
}

// ─── Role badge chip ──────────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  final String label;
  final Color  color;
  final bool   filled;

  const _RoleBadge({
    required this.label,
    required this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: filled
            ? color.withValues(alpha: 0.18)
            : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: filled ? 0.4 : 0.2),
          width: 0.8,
        ),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize:   9,
              fontWeight: FontWeight.w700,
              color:      color)),
    );
  }
}