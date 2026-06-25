// lib/features/dashboard/presentation/pages/team_leader_dashboard_page.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/api_exception.dart';
import '../../data/models/dashboard_model.dart';
import '../../data/services/dashboard_api_service.dart';

class TeamLeaderDashboardPage extends StatefulWidget {
  const TeamLeaderDashboardPage({super.key});

  @override
  State<TeamLeaderDashboardPage> createState() =>
      _TeamLeaderDashboardPageState();
}

class _TeamLeaderDashboardPageState extends State<TeamLeaderDashboardPage>
    with SingleTickerProviderStateMixin {
  DashboardModel? _data;
  bool _isLoading = true;
  String? _error;

  DateTime _startDate =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate =
      DateTime(DateTime.now().year, DateTime.now().month + 1, 0);

  MemberTaskSummary? _selectedMember;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // ── Palette (mirrors web) ──────────────────────────────────────────────
  static const _green  = Color(0xFF28C76F);
  static const _orange = Color(0xFFFF9F43);
  static const _red    = Color(0xFFEA5455);
  static const _blue   = Color(0xFF4C6FFF);
  static const _cyan   = Color(0xFF00CFE8);
  static const _purple = Color(0xFF7367F0);

  static const _textDark  = Color(0xFF1A2340);
  static const _textMuted = Color(0xFF8E9BB5);
  static const _cardBg    = Colors.white;

  @override
  void initState() {
    super.initState();
    _fadeCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _load();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtDisplay(DateTime d) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month]} ${d.year}';
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await DashboardApiService.fetchDashboard(
        startDate: _fmt(_startDate),
        endDate: _fmt(_endDate),
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _isLoading = false;
        _selectedMember = null;
      });
      _fadeCtrl.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              const ColorScheme.light(primary: AppColors.primaryGreen),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
      } else {
        _endDate = picked;
        if (_startDate.isAfter(_endDate)) _startDate = _endDate;
      }
    });
  }

  Color _progressColor(int pct) {
    if (pct >= 90) return _green;
    if (pct >= 75) return _orange;
    return _red;
  }

  // ── Root ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      );
    }
    if (_error != null) return _buildError();
    return FadeTransition(opacity: _fadeAnim, child: _buildContent());
  }

  // ── Error ─────────────────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 56, color: Color(0xFFE74C3C)),
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _textMuted)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Main Content ──────────────────────────────────────────────────────────

  Widget _buildContent() {
    final d = _data!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Welcome banner
        _buildWelcomeBanner(d),
        const SizedBox(height: 14),

        // 2. Date filter
        _buildDateFilter(),
        const SizedBox(height: 18),

        // ── My Personal Analytics ────────────────────────────────────────
        _sectionTitle('My Personal Analytics',
            icon: Icons.person_outline_rounded),
        const SizedBox(height: 10),
        _buildTaskCardsColored(
          d.leaderTaskSummary,
          colors: [_blue, _green, _orange, _red],
          labels: [
            'My Total Tasks',
            'My Completed',
            'My In Progress',
            'My Pending'
          ],
        ),
        const SizedBox(height: 18),

        // ── My Attendance ────────────────────────────────────────────────
        _buildLeaderAttendanceCard(d),
        const SizedBox(height: 18),

        // ── Overall Team Analytics (leader + members) ────────────────────
        _sectionTitle('Overall Team Analytics (Including You)',
            icon: Icons.groups_outlined),
        const SizedBox(height: 10),
        _buildTaskCards(d.combinedTaskSummary),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: _buildDistributionChart(
                  d.combinedTaskSummary, 'Overall Distribution')),
          const SizedBox(width: 12),
          Expanded(
              child: _buildProgressDonut(
                  d.combinedTaskSummary.progressPercentage,
                  'Overall Progress',
                  'Overall Completion Rate')),
        ]),
        const SizedBox(height: 18),

        // ── Team Members Only ────────────────────────────────────────────
        _sectionTitle('Team Members Analytics (Excluding You)',
            icon: Icons.people_outline_rounded),
        const SizedBox(height: 10),
        _buildTaskCards(d.teamTaskSummary),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: _buildDistributionChart(
                  d.teamTaskSummary, 'Team Distribution')),
          const SizedBox(width: 12),
          Expanded(
              child: _buildProgressDonut(
                  d.teamTaskSummary.progressPercentage,
                  'Team Progress',
                  'Team Completion Rate')),
        ]),
        const SizedBox(height: 18),

        // ── Individual Member Analytics ──────────────────────────────────
        _sectionTitle('Individual Member Analytics',
            icon: Icons.manage_accounts_outlined),
        const SizedBox(height: 10),
        _buildMemberSection(d),
        const SizedBox(height: 18),

        // ── Team Attendance Analytics ────────────────────────────────────
        _buildTeamAttendanceSection(d),
        const SizedBox(height: 18),

        // ── My Attendance (date-filtered charts) ─────────────────────────
        _sectionTitle(
          'My Attendance  ${_fmtDisplay(_startDate)} → ${_fmtDisplay(_endDate)}',
          icon: Icons.calendar_today_outlined,
        ),
        const SizedBox(height: 10),
        _buildAttendanceCards(d.leaderAttendanceSummary,
            showWorkingDays: false),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: _buildAttendanceDistributionChart(
                  d.leaderAttendanceSummary)),
          const SizedBox(width: 12),
          Expanded(
              child:
                  _buildAttendanceRateChart(d.leaderAttendanceSummary)),
        ]),
        const SizedBox(height: 18),

        // ── Team Upcoming Deadline Tasks ─────────────────────────────────
        _sectionTitle('Team Upcoming Deadline Tasks',
            icon: Icons.event_busy_outlined),
        const SizedBox(height: 10),
        _buildUpcomingDeadlineTable(d.teamUpcomingTasks,
            showAssignedTo: true),
        const SizedBox(height: 24),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // WELCOME BANNER  (gradient teal-blue matching web team-card)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildWelcomeBanner(DashboardModel d) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.groups_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome ${d.userName},',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                ),
                if (d.teamName != null) ...[
                  const SizedBox(height: 2),
                  Text('Team: ${d.teamName}',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.92),
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 3),
                Text(
                  'Monitor your team\'s performance and task completion',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 12),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${d.teamMembers.length} Team Members',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DATE FILTER
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDateFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF667eea), Color(0xFF764ba2)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  color: Colors.white, size: 16),
              SizedBox(width: 6),
              Text('Attendance Date Range Filter',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _dateField(
                      'Start Date', _startDate, () => _pickDate(true))),
              const SizedBox(width: 10),
              Expanded(
                  child: _dateField(
                      'End Date', _endDate, () => _pickDate(false))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.filter_alt_outlined, size: 16),
                  label: const Text('Apply Filter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF764ba2),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _startDate = DateTime(
                          DateTime.now().year, DateTime.now().month, 1);
                      _endDate = DateTime(
                          DateTime.now().year, DateTime.now().month + 1, 0);
                    });
                    _load();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Reset'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateField(String label, DateTime value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 10, color: _textMuted)),
            const SizedBox(height: 2),
            Text(_fmt(value),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _textDark)),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LEADER PERSONAL ATTENDANCE CARD
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildLeaderAttendanceCard(DashboardModel d) {
    final att = d.leaderAttendanceSummary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04), blurRadius: 8)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('My Attendance',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _textDark)),
              const Spacer(),
              Text(
                '${_fmtDisplay(_startDate)} – ${_fmtDisplay(_endDate)}',
                style:
                    const TextStyle(fontSize: 11, color: _textMuted),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              _attItem(Icons.check_rounded,
                  '${att.presentDays}', 'Present', _green),
              _attItem(Icons.remove_rounded,
                  '${att.halfDays}', 'Half Day', _orange),
              _attItem(Icons.close_rounded,
                  '${att.absentDays}', 'Absent', _red),
              _attItem(
                  Icons.percent_rounded,
                  '${att.attendancePercentage.toStringAsFixed(1)}%',
                  'Rate',
                  _cyan),
            ],
          ),
        ],
      ),
    );
  }

  Widget _attItem(
      IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: color)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 10, color: _textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TASK STAT CARDS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildTaskCards(DashboardTaskSummary s) {
    return _buildTaskCardsColored(
      s,
      colors: [_blue, _green, _orange, _red],
      labels: [
        'Total Tasks',
        'Completed Tasks',
        'In Progress',
        'Pending Tasks'
      ],
    );
  }

  Widget _buildTaskCardsColored(
    DashboardTaskSummary s, {
    required List<Color> colors,
    required List<String> labels,
  }) {
    final values = [s.total, s.completed, s.inProgress, s.pending];
    final icons = [
      Icons.list_alt_outlined,
      Icons.check_circle_outline,
      Icons.schedule_outlined,
      Icons.error_outline_rounded,
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.65,
      children: List.generate(4, (i) {
        return _statCard(
          label: labels[i],
          value: '${values[i]}',
          icon: icons[i],
          color: colors[i],
          bgColor: colors[i].withOpacity(0.12),
        );
      }),
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: color,
                        height: 1.1)),
                const SizedBox(height: 2),
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: _textMuted,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DONUT CHARTS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDistributionChart(
      DashboardTaskSummary s, String title) {
    return _chartCard(
      title: title,
      child: Column(
        children: [
          SizedBox(
            height: 130,
            child: CustomPaint(
              painter: _DonutPainter(
                values: [
                  s.completed.toDouble(),
                  s.inProgress.toDouble(),
                  s.pending.toDouble()
                ],
                colors: const [_green, _orange, _red],
              ),
              child: Center(
                child: Text('${s.total}',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _textDark)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _legend([
            ('Completed', _green),
            ('In Progress', _orange),
            ('Pending', _red)
          ]),
        ],
      ),
    );
  }

  Widget _buildProgressDonut(int pct, String title, String subtitle) {
    return _chartCard(
      title: title,
      child: Column(
        children: [
          SizedBox(
            height: 130,
            child: CustomPaint(
              painter: _DonutPainter(
                values: [
                  pct.toDouble(),
                  math.max(0, 100 - pct).toDouble()
                ],
                colors: const [_purple, Color(0xFFE9ECEF)],
              ),
              child: Center(
                child: Text('$pct%',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _textDark)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(subtitle,
              style: const TextStyle(fontSize: 11, color: _textMuted)),
          const SizedBox(height: 6),
          _legend([
            ('Completed', _purple),
            ('Remaining', Color(0xFFE9ECEF))
          ]),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INDIVIDUAL MEMBER ANALYTICS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildMemberSection(DashboardModel d) {
    return Column(
      children: [
        // Dropdown picker (gradient card matching web member-select-card)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFFf093fb), Color(0xFFf5576c)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Team Member',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<MemberTaskSummary>(
                    isExpanded: true,
                    value: _selectedMember,
                    hint: const Text('-- Select Member --',
                        style: TextStyle(
                            fontSize: 13, color: _textMuted)),
                    items: d.memberTaskSummaries.map((m) {
                      return DropdownMenuItem(
                        value: m,
                        child: Text(
                          m.isLeader
                              ? '${m.memberName} (You - Team Leader)'
                              : m.memberName,
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: (v) =>
                        setState(() => _selectedMember = v),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Member list
        Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8)
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: Row(
                  children: [
                    const Text('Team Members',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _textDark)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _blue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                          '${d.memberTaskSummaries.length} Members',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _blue)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 20),
              if (d.memberTaskSummaries.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('No team members found',
                        style: TextStyle(color: _textMuted)),
                  ),
                )
              else
                ...d.memberTaskSummaries
                    .map(_memberListItem),
              const SizedBox(height: 8),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Analytics panel
        if (_selectedMember != null)
          _buildMemberAnalyticsPanel(_selectedMember!)
        else
          _noMemberSelected(),
      ],
    );
  }

  Widget _memberListItem(MemberTaskSummary m) {
    final isActive = _selectedMember?.memberId == m.memberId;
    return GestureDetector(
      onTap: () => setState(() => _selectedMember = m),
      child: Container(
        margin:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFF8F9FA)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border(
              left: BorderSide(
                  color: isActive ? _green : _purple, width: 4)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: _blue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8)),
              child: Center(
                child: Text(
                  m.memberName.length >= 2
                      ? m.memberName
                          .substring(0, 2)
                          .toUpperCase()
                      : m.memberName,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _blue),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.memberName,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _textDark)),
                  if (m.isLeader)
                    const Text('Team Leader',
                        style: TextStyle(
                            fontSize: 11, color: _textMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: _textMuted, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _noMemberSelected() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04), blurRadius: 8)
        ],
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_outline_rounded,
                size: 48, color: _textMuted),
            SizedBox(height: 10),
            Text('Select a Team Member',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _textMuted)),
            SizedBox(height: 4),
            Text(
                'Choose a team member to view their task analytics',
                style: TextStyle(fontSize: 12, color: _textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberAnalyticsPanel(MemberTaskSummary m) {
    final s = m.summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header bar
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8)
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: _blue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: Center(
                  child: Text(
                    m.memberName.length >= 2
                        ? m.memberName
                            .substring(0, 2)
                            .toUpperCase()
                        : m.memberName,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _blue),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  m.isLeader
                      ? '${m.memberName} (You)'
                      : m.memberName,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _textDark),
                ),
              ),
              GestureDetector(
                onTap: () =>
                    setState(() => _selectedMember = null),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded,
                      color: _textMuted, size: 20),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildTaskCards(s),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child:
                  _buildDistributionChart(s, 'Task Distribution')),
          const SizedBox(width: 12),
          Expanded(child: _buildMemberPerformanceChart(s)),
        ]),
      ],
    );
  }

  Widget _buildMemberPerformanceChart(DashboardTaskSummary s) {
    final pct = s.progressPercentage;
    return _chartCard(
      title: 'Performance',
      child: Column(
        children: [
          SizedBox(
            height: 100,
            child: CustomPaint(
              painter: _DonutPainter(
                values: [
                  pct.toDouble(),
                  math.max(0, 100 - pct).toDouble()
                ],
                colors: const [_green, Color(0xFFE9ECEF)],
              ),
              child: Center(
                child: Text('$pct%',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _textDark)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Completion Rate',
                  style: TextStyle(fontSize: 12, color: _textMuted)),
              Text('$pct%',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _green)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 8,
              backgroundColor: const Color(0xFFE9ECEF),
              valueColor:
                  const AlwaysStoppedAnimation(_green),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TEAM ATTENDANCE SECTION
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildTeamAttendanceSection(DashboardModel d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Team Attendance Analytics',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _textDark)),
            ),
            Text(
              '${_fmtDisplay(_startDate)} – ${_fmtDisplay(_endDate)}',
              style: const TextStyle(fontSize: 11, color: _textMuted),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8)
            ],
          ),
          child: d.memberAttendance.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text('No attendance data available',
                        style: TextStyle(color: _textMuted)),
                  ),
                )
              : Column(
                  children: [
                    // Table header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          14, 14, 14, 0),
                      child: Row(
                        children: const [
                          Expanded(
                              child: Text('Member',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight:
                                          FontWeight.w700,
                                      color: _textMuted))),
                          _AttHdrCell('Present'),
                          _AttHdrCell('Half'),
                          _AttHdrCell('Absent'),
                          _AttHdrCell('%'),
                        ],
                      ),
                    ),
                    const Divider(height: 16),
                    ...d.memberAttendance
                        .map(_teamAttendanceRow),
                    const SizedBox(height: 10),
                  ],
                ),
        ),
        if (d.memberAttendance.isNotEmpty) ...[
          const SizedBox(height: 14),
          _buildTeamAttendanceBarChart(d.memberAttendance),
        ],
      ],
    );
  }

  Widget _teamAttendanceRow(MemberAttendanceSummary m) {
    final pct = m.attendance.attendancePercentage;
    final color =
        pct >= 90 ? _green : pct >= 75 ? _orange : _red;
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                      color: _blue.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6)),
                  child: Center(
                    child: Text(
                      m.memberName.length >= 2
                          ? m.memberName
                              .substring(0, 2)
                              .toUpperCase()
                          : m.memberName,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _blue),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(m.memberName,
                      style: const TextStyle(
                          fontSize: 12, color: _textDark),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          _AttBadge('${m.attendance.presentDays}', _green),
          _AttBadge('${m.attendance.halfDays}', _orange),
          _AttBadge('${m.attendance.absentDays}', _red),
          SizedBox(
            width: 44,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                    '${pct.toStringAsFixed(0)}%',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color)),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    minHeight: 5,
                    backgroundColor: const Color(0xFFE9ECEF),
                    valueColor:
                        AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamAttendanceBarChart(
      List<MemberAttendanceSummary> members) {
    return _chartCard(
      title: 'Team Attendance Comparison',
      child: SizedBox(
        height: 180,
        child: CustomPaint(
          size: Size.infinite,
          painter:
              _StackedBarChartPainter(members: members),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ATTENDANCE CARDS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildAttendanceCards(DashboardAttendanceSummary s,
      {required bool showWorkingDays}) {
    final cards = [
      _statCard(
          label: 'Present Days',
          value: '${s.presentDays}',
          icon: Icons.check_box_outlined,
          color: _green,
          bgColor: _green.withOpacity(0.12)),
      _statCard(
          label: 'Half Days',
          value: '${s.halfDays}',
          icon: Icons.remove_circle_outline,
          color: _orange,
          bgColor: _orange.withOpacity(0.12)),
      _statCard(
          label: 'Absent Days',
          value: '${s.absentDays}',
          icon: Icons.cancel_outlined,
          color: _red,
          bgColor: _red.withOpacity(0.12)),
      if (showWorkingDays)
        _statCard(
            label: 'Working Days',
            value: '${s.workingDays}',
            icon: Icons.calendar_month_outlined,
            color: _cyan,
            bgColor: _cyan.withOpacity(0.12)),
    ];

    if (!showWorkingDays) {
      return GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.3,
        children: cards,
      );
    }
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.65,
      children: cards,
    );
  }

  Widget _buildAttendanceDistributionChart(
      DashboardAttendanceSummary s) {
    final maxVal = math.max(s.presentDays,
            math.max(s.halfDays, s.absentDays))
        .toDouble();
    return _chartCard(
      title: 'Attendance Distribution',
      child: SizedBox(
        height: 130,
        child: CustomPaint(
          size: Size.infinite,
          painter: _BarChartPainter(
            bars: [
              _BarData('Present', s.presentDays.toDouble(), _green),
              _BarData('Half Day', s.halfDays.toDouble(), _orange),
              _BarData('Absent', s.absentDays.toDouble(), _red),
            ],
            maxValue: maxVal,
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceRateChart(
      DashboardAttendanceSummary s) {
    final pct = s.attendancePercentage;
    return _chartCard(
      title: 'Attendance Rate',
      child: Column(
        children: [
          SizedBox(
            height: 100,
            child: CustomPaint(
              painter: _DonutPainter(
                values: [pct, math.max(0, 100 - pct)],
                colors: const [_cyan, Color(0xFFE9ECEF)],
              ),
              child: Center(
                child: Text(
                    '${pct.toStringAsFixed(1)}%',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _textDark)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Attendance Percentage',
              style: TextStyle(fontSize: 11, color: _textMuted)),
          const SizedBox(height: 6),
          _legend([
            ('Present', _cyan),
            ('Absent', Color(0xFFE9ECEF))
          ]),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UPCOMING DEADLINE TASKS TABLE
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildUpcomingDeadlineTable(
      List<UpcomingDeadlineTask> tasks,
      {required bool showAssignedTo}) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                      'Tasks with Nearest Deadlines',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _textDark)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen
                        .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${tasks.length} Tasks',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryGreen)),
                ),
              ],
            ),
          ),
          const Divider(height: 20),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 30),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.task_alt_rounded,
                        size: 48,
                        color: AppColors.primaryGreen
                            .withOpacity(0.4)),
                    const SizedBox(height: 10),
                    const Text('No upcoming deadline tasks',
                        style: TextStyle(
                            fontSize: 13, color: _textMuted)),
                  ],
                ),
              ),
            )
          else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tasks.length,
              padding:
                  const EdgeInsets.fromLTRB(14, 0, 14, 0),
              separatorBuilder: (_, __) =>
                  const Divider(height: 1),
              itemBuilder: (_, i) => _deadlineTaskRow(
                  tasks[i],
                  showAssignedTo: showAssignedTo),
            ),
            const SizedBox(height: 14),
            // Summary badges matching web
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  _summaryBadge('Overdue',
                      tasks.where((t) => t.isOverdue).length,
                      _red),
                  const SizedBox(width: 6),
                  _summaryBadge('Today',
                      tasks.where((t) => t.isToday).length,
                      _orange),
                  const SizedBox(width: 6),
                  _summaryBadge('Urgent',
                      tasks.where((t) => t.isUrgent).length,
                      _orange),
                  const SizedBox(width: 6),
                  _summaryBadge(
                      'Normal',
                      tasks
                          .where((t) =>
                              !t.isOverdue && !t.isUrgent)
                          .length,
                      _cyan),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _deadlineTaskRow(UpcomingDeadlineTask task,
      {required bool showAssignedTo}) {
    Color? rowTint;
    if (task.isOverdue) rowTint = _red.withOpacity(0.05);
    else if (task.isUrgent) rowTint = _orange.withOpacity(0.05);

    Widget daysBadge;
    if (task.isOverdue) {
      daysBadge = _badge(
          '${task.daysRemaining.abs()}d overdue', _red,
          bold: true);
    } else if (task.isToday) {
      daysBadge =
          _badge('Due Today', _orange, bold: true);
    } else {
      daysBadge = _badge('${task.daysRemaining}d', _blue);
    }

    Widget statusBadge;
    switch (task.status) {
      case 'completed':
        statusBadge = _badge('Completed', _green);
        break;
      case 'in_process':
        statusBadge = _badge('In Progress', _orange);
        break;
      default:
        statusBadge = _badge('Pending', _red);
    }

    Widget priorityBadge;
    if (task.isOverdue) {
      priorityBadge = _badge('Overdue', _red,
          icon: Icons.warning_amber_rounded);
    } else if (task.isUrgent) {
      priorityBadge = _badge('Urgent', _orange,
          icon: Icons.bolt_rounded);
    } else {
      priorityBadge = _badge('Normal', _cyan,
          icon: Icons.flag_outlined);
    }

    return Container(
      color: rowTint,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: task.taskType == 'general'
                      ? _blue.withOpacity(0.1)
                      : _cyan.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  task.taskType == 'general'
                      ? Icons.assignment_outlined
                      : Icons.layers_outlined,
                  color: task.taskType == 'general'
                      ? _blue
                      : _cyan,
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _textDark),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(
                        '${task.taskType[0].toUpperCase()}${task.taskType.substring(1)} Task',
                        style: const TextStyle(
                            fontSize: 10,
                            color: _textMuted)),
                  ],
                ),
              ),
              daysBadge,
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const SizedBox(width: 36),
              if (showAssignedTo &&
                  task.assignedToName.isNotEmpty) ...[
                const Icon(Icons.person_outline_rounded,
                    size: 12, color: _textMuted),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(task.assignedToName,
                      style: const TextStyle(
                          fontSize: 11, color: _textMuted),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1),
                ),
                const SizedBox(width: 8),
              ],
              if (task.projectName.isNotEmpty) ...[
                const Icon(Icons.domain_outlined,
                    size: 12, color: _textMuted),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(task.projectName,
                      style: const TextStyle(
                          fontSize: 11, color: _textMuted),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1),
                ),
                const SizedBox(width: 8),
              ],
              const Icon(Icons.calendar_today_outlined,
                  size: 12, color: _textMuted),
              const SizedBox(width: 3),
              Text(task.deadlineFormatted,
                  style: const TextStyle(
                      fontSize: 11, color: _textMuted)),
              const Spacer(),
              statusBadge,
              const SizedBox(width: 4),
              priorityBadge,
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color,
      {bool bold = false, IconData? icon}) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
          ],
          Text(text,
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    bold ? FontWeight.w700 : FontWeight.w600,
                color: color,
              )),
        ],
      ),
    );
  }

  Widget _summaryBadge(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text('$count',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 9, color: _textMuted),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SHARED HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _sectionTitle(String text, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: _textDark),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textDark)),
        ),
      ],
    );
  }

  Widget _chartCard(
      {required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _textDark)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _legend(List<(String, Color)> items) {
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: items.map((e) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color: e.$2,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 4),
            Text(e.$1,
                style: const TextStyle(
                    fontSize: 10, color: _textMuted)),
          ],
        );
      }).toList(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// STATIC WIDGETS
// ══════════════════════════════════════════════════════════════════════════

class _AttHdrCell extends StatelessWidget {
  final String text;
  const _AttHdrCell(this.text);
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      child: Text(text,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8E9BB5))),
    );
  }
}

class _AttBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _AttBadge(this.text, this.color);
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(text,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// BAR CHART PAINTER
// ══════════════════════════════════════════════════════════════════════════

class _BarData {
  final String label;
  final double value;
  final Color color;
  const _BarData(this.label, this.value, this.color);
}

class _BarChartPainter extends CustomPainter {
  final List<_BarData> bars;
  final double maxValue;
  const _BarChartPainter(
      {required this.bars, required this.maxValue});

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    final effectiveMax = maxValue <= 0 ? 1.0 : maxValue;
    final gridPaint = Paint()
      ..color = const Color(0xFFEEF1F8)
      ..strokeWidth = 1;
    const labelStyle =
        TextStyle(fontSize: 9, color: Color(0xFF8E9BB5));
    const gridLines = 4;
    for (int i = 0; i <= gridLines; i++) {
      final y = size.height * (1 - i / gridLines);
      canvas.drawLine(
          Offset(28, y), Offset(size.width, y), gridPaint);
      final val = (effectiveMax * i / gridLines).round();
      final tp = TextPainter(
          text: TextSpan(text: '$val', style: labelStyle),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }
    final barWidth =
        (size.width - 28) / (bars.length * 2);
    for (int i = 0; i < bars.length; i++) {
      final bar = bars[i];
      final barH = (bar.value / effectiveMax) * size.height;
      final x =
          28 + i * (barWidth * 2) + barWidth / 2;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(
              x, size.height - barH, barWidth, barH),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        ),
        Paint()..color = bar.color,
      );
      final tp = TextPainter(
          text: TextSpan(text: bar.label, style: labelStyle),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(
          canvas,
          Offset(x + barWidth / 2 - tp.width / 2,
              size.height + 4));
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.bars != bars || old.maxValue != maxValue;
}

// ══════════════════════════════════════════════════════════════════════════
// STACKED BAR CHART PAINTER
// ══════════════════════════════════════════════════════════════════════════

class _StackedBarChartPainter extends CustomPainter {
  final List<MemberAttendanceSummary> members;
  const _StackedBarChartPainter({required this.members});

  @override
  void paint(Canvas canvas, Size size) {
    if (members.isEmpty) return;
    final maxVal = members.fold<double>(0, (prev, m) {
      final total = m.attendance.presentDays +
          m.attendance.halfDays +
          m.attendance.absentDays;
      return total > prev ? total.toDouble() : prev;
    });
    if (maxVal == 0) return;

    const labelAreaH = 28.0;
    const leftPad = 8.0;
    final chartH = size.height - labelAreaH;
    final barW =
        (size.width - leftPad) / (members.length * 1.5 + 0.5);
    final gap = barW * 0.5;
    const style =
        TextStyle(fontSize: 8, color: Color(0xFF8E9BB5));

    final gridP = Paint()
      ..color = const Color(0xFFEEF1F8)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = chartH * (1 - i / 4);
      canvas.drawLine(
          Offset(leftPad, y), Offset(size.width, y), gridP);
    }

    for (int i = 0; i < members.length; i++) {
      final m = members[i].attendance;
      final x = leftPad + gap + i * (barW + gap);
      double yOff = chartH;

      void drawSeg(int val, Color color) {
        if (val <= 0) return;
        final h = (val / maxVal) * chartH;
        yOff -= h;
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x, yOff, barW, h),
            topLeft: const Radius.circular(3),
            topRight: const Radius.circular(3),
          ),
          Paint()..color = color,
        );
      }

      drawSeg(m.presentDays, const Color(0xFF28C76F));
      drawSeg(m.halfDays, const Color(0xFFFF9F43));
      drawSeg(m.absentDays, const Color(0xFFEA5455));

      final name = members[i].memberName.split(' ').first;
      final tp = TextPainter(
          text: TextSpan(text: name, style: style),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(
          canvas,
          Offset(x + barW / 2 - tp.width / 2,
              chartH + 4));
    }

    final legendItems = [
      ('Present', const Color(0xFF28C76F)),
      ('Half', const Color(0xFFFF9F43)),
      ('Absent', const Color(0xFFEA5455))
    ];
    double lx = leftPad;
    for (final item in legendItems) {
      final tp = TextPainter(
          text: TextSpan(text: item.$1, style: style),
          textDirection: TextDirection.ltr)
        ..layout();
      canvas.drawRect(
          Rect.fromLTWH(lx, size.height - 14, 8, 8),
          Paint()..color = item.$2);
      tp.paint(canvas, Offset(lx + 10, size.height - 14));
      lx += tp.width + 18;
    }
  }

  @override
  bool shouldRepaint(_StackedBarChartPainter old) =>
      old.members != members;
}

// ══════════════════════════════════════════════════════════════════════════
// DONUT PAINTER
// ══════════════════════════════════════════════════════════════════════════

class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  const _DonutPainter(
      {required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold(0.0, (a, b) => a + b);
    if (total == 0) return;
    final stroke = size.width * 0.18;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    double startAngle = -math.pi / 2;
    final rect =
        Rect.fromLTWH(0, 0, size.width, size.height)
            .deflate(stroke / 2);
    for (int i = 0; i < values.length; i++) {
      if (values[i] == 0) continue;
      final sweep = (values[i] / total) * 2 * math.pi;
      paint.color = colors[i % colors.length];
      canvas.drawArc(
          rect, startAngle, sweep - 0.04, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.values != values || old.colors != colors;
}