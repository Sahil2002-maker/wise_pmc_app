// lib/features/dashboard/presentation/pages/employee_dashboard_page.dart
//
// Shows after login for Employee and Team Leader roles.
// Matches the web UI in the screenshot: welcome banner, date filter,
// General Task Analytics cards, task distribution / progress charts,
// Project-wise dropdown section, Attendance Analytics cards.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/api_exception.dart';
import '../../data/models/dashboard_model.dart';
import '../../data/services/dashboard_api_service.dart';

class EmployeeDashboardPage extends StatefulWidget {
  const EmployeeDashboardPage({super.key});

  @override
  State<EmployeeDashboardPage> createState() => _EmployeeDashboardPageState();
}

class _EmployeeDashboardPageState extends State<EmployeeDashboardPage>
    with SingleTickerProviderStateMixin {
  DashboardModel? _data;
  bool _isLoading = true;
  String? _error;

  // Date filter
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate   = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);

  // Project picker
  DashboardProjectSummary? _selectedProject;

  // Member picker (team leader only)
  MemberTaskSummary? _selectedMember;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
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

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await DashboardApiService.fetchDashboard(
        startDate: _fmt(_startDate),
        endDate:   _fmt(_endDate),
      );
      if (!mounted) return;
      setState(() {
        _data          = data;
        _isLoading     = false;
        _selectedProject = null;
        _selectedMember  = null;
      });
      _fadeCtrl.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error     = e is ApiException ? e.message : e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart ? _startDate : _endDate;
    final picked  = await showDatePicker(
      context:      context,
      initialDate:  initial,
      firstDate:    DateTime(2020),
      lastDate:     DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primaryGreen,
          ),
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

  String _displayDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : _error != null
              ? _buildError()
              : FadeTransition(opacity: _fadeAnim, child: _buildContent()),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 56, color: Color(0xFFE74C3C)),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF8E9BB5))),
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

  Widget _buildContent() {
    final d = _data!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildWelcomeBanner(d),
        const SizedBox(height: 14),
        _buildDateFilter(),
        const SizedBox(height: 14),

        // ── General Task Analytics ─────────────────────────────────────────
        _sectionTitle('General Task Analytics'),
        const SizedBox(height: 10),
        _buildTaskCards(d.isTeamLeader ? d.combinedTaskSummary : d.taskSummary),
        const SizedBox(height: 14),

        // ── Charts row ─────────────────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildDistributionChart(
                d.isTeamLeader ? d.combinedTaskSummary : d.taskSummary)),
            const SizedBox(width: 12),
            Expanded(child: _buildProgressChart(
                d.isTeamLeader ? d.combinedTaskSummary : d.taskSummary)),
          ],
        ),
        const SizedBox(height: 14),

        // ── Team leader: own stats + team stats ────────────────────────────
        if (d.isTeamLeader) ...[
          _sectionTitle('My Personal Analytics'),
          const SizedBox(height: 10),
          _buildTaskCards(d.leaderTaskSummary, color: const Color(0xFF4C6FFF)),
          const SizedBox(height: 14),

          _sectionTitle('Team Members Analytics'),
          const SizedBox(height: 10),
          _buildTaskCards(d.teamTaskSummary, color: const Color(0xFF1ABC9C)),
          const SizedBox(height: 14),

          // Member picker
          if (d.memberTaskSummaries.isNotEmpty) ...[
            _buildMemberPicker(d),
            const SizedBox(height: 14),
          ],

          // Team attendance table
          if (d.memberAttendance.isNotEmpty) ...[
            _sectionTitle('Team Attendance'),
            const SizedBox(height: 10),
            _buildTeamAttendanceTable(d),
            const SizedBox(height: 14),
          ],
        ],

        // ── Project-wise ───────────────────────────────────────────────────
        if (d.projectSummary.isNotEmpty) ...[
          _sectionTitle('Project-wise Task Analytics'),
          const SizedBox(height: 10),
          _buildProjectPicker(d),
          const SizedBox(height: 14),
          if (_selectedProject != null) _buildProjectDetail(_selectedProject!),
          if (_selectedProject != null) const SizedBox(height: 14),
        ],

        // ── Attendance Analytics ───────────────────────────────────────────
        _sectionTitle('Attendance Analytics  '
            '${_displayDate(_startDate)} → ${_displayDate(_endDate)}'),
        const SizedBox(height: 10),
        _buildAttendanceCards(
            d.isTeamLeader ? d.leaderAttendanceSummary : d.attendanceSummary),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Welcome banner ─────────────────────────────────────────────────────────

  Widget _buildWelcomeBanner(DashboardModel d) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF4CAF50)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.work_outline_rounded,
                color: Colors.white, size: 26),
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
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  d.isTeamLeader
                      ? (d.teamName != null
                          ? 'Team: ${d.teamName} · ${d.teamMembers.length} members'
                          : 'Track your team\'s performance below')
                      : 'Track your tasks and performance metrics below',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Date filter ────────────────────────────────────────────────────────────

  Widget _buildDateFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_today_outlined, color: Colors.white, size: 16),
              SizedBox(width: 6),
              Text(
                'Attendance Date Range Filter',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _dateField('Start Date', _startDate, () => _pickDate(true))),
              const SizedBox(width: 10),
              Expanded(child: _dateField('End Date', _endDate, () => _pickDate(false))),
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
                    foregroundColor: const Color(0xFFf5576c),
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
                      _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
                      _endDate   = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 10, color: Color(0xFF8E9BB5))),
            const SizedBox(height: 2),
            Text(_displayDate(value),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: Color(0xFF1A2340))),
          ],
        ),
      ),
    );
  }

  // ── Section title ──────────────────────────────────────────────────────────

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1A2340),
      ),
    );
  }

  // ── Task summary cards ─────────────────────────────────────────────────────

  Widget _buildTaskCards(DashboardTaskSummary s,
      {Color color = AppColors.primaryGreen}) {
    final cards = [
      _TaskCardData('Total Tasks',     '${s.total}',       Icons.list_alt_outlined,         const Color(0xFF4C6FFF), const Color(0xFFEEF1FF)),
      _TaskCardData('Completed',       '${s.completed}',   Icons.check_circle_outline,      const Color(0xFF28C76F), const Color(0xFFE6F7EE)),
      _TaskCardData('In Progress',     '${s.inProgress}',  Icons.schedule_outlined,         const Color(0xFFFF9F43), const Color(0xFFFFF4E6)),
      _TaskCardData('Pending Tasks',   '${s.pending}',     Icons.error_outline_rounded,     const Color(0xFFEA5455), const Color(0xFFFEE2E2)),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.65,
      children: cards.map(_buildTaskCard).toList(),
    );
  }

  Widget _buildTaskCard(_TaskCardData d) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: d.bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(d.icon, color: d.color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(d.value,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: d.color,
                        height: 1.1)),
                const SizedBox(height: 2),
                Text(d.label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8E9BB5),
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Distribution chart (custom painter) ───────────────────────────────────

  Widget _buildDistributionChart(DashboardTaskSummary s) {
    return _chartCard(
      title: 'Task Distribution',
      child: Column(
        children: [
          SizedBox(
            height: 130,
            child: CustomPaint(
              painter: _DonutPainter(
                values: [
                  s.completed.toDouble(),
                  s.inProgress.toDouble(),
                  s.pending.toDouble(),
                ],
                colors: const [
                  Color(0xFF28C76F),
                  Color(0xFFFF9F43),
                  Color(0xFFEA5455),
                ],
              ),
              child: Center(
                child: Text(
                  '${s.total}',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A2340)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _legend([
            ('Completed',   const Color(0xFF28C76F)),
            ('In Progress', const Color(0xFFFF9F43)),
            ('Pending',     const Color(0xFFEA5455)),
          ]),
        ],
      ),
    );
  }

  Widget _buildProgressChart(DashboardTaskSummary s) {
    final pct = s.progressPercentage;
    return _chartCard(
      title: 'Task Progress',
      child: Column(
        children: [
          SizedBox(
            height: 130,
            child: CustomPaint(
              painter: _DonutPainter(
                values: [pct.toDouble(), (100 - pct).toDouble()],
                colors: const [Color(0xFF7367F0), Color(0xFFE9ECEF)],
              ),
              child: Center(
                child: Text(
                  '$pct%',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A2340)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text('Overall Completion Rate',
              style: TextStyle(fontSize: 11, color: Color(0xFF8E9BB5))),
          _legend([
            ('Completed',  const Color(0xFF7367F0)),
            ('Remaining',  const Color(0xFFE9ECEF)),
          ]),
        ],
      ),
    );
  }

  Widget _chartCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A2340))),
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
            Container(width: 10, height: 10,
                decoration: BoxDecoration(
                    color: e.$2, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 4),
            Text(e.$1,
                style: const TextStyle(fontSize: 10, color: Color(0xFF8E9BB5))),
          ],
        );
      }).toList(),
    );
  }

  // ── Project picker ─────────────────────────────────────────────────────────

  Widget _buildProjectPicker(DashboardModel d) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select Project to View Details',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<DashboardProjectSummary>(
                isExpanded: true,
                value: _selectedProject,
                hint: const Text('-- Select Project --',
                    style: TextStyle(fontSize: 13)),
                items: d.projectSummary.map((p) {
                  return DropdownMenuItem(
                    value: p,
                    child: Text(p.projectName,
                        style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedProject = v),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectDetail(DashboardProjectSummary p) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.projectName,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A2340))),
          const SizedBox(height: 12),
          Row(
            children: [
              _miniStat('Total',     '${p.total}',     const Color(0xFF4C6FFF)),
              _miniStat('Done',      '${p.completed}', const Color(0xFF28C76F)),
              _miniStat('Assigned',  '${p.assigned}',  const Color(0xFF00CFE8)),
              _miniStat('Pending',   '${p.pending}',   const Color(0xFFFF9F43)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Progress', style: TextStyle(fontSize: 12)),
              const Spacer(),
              Text('${p.progressPercentage}%',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: p.progressPercentage / 100,
              minHeight: 8,
              backgroundColor: const Color(0xFFE9ECEF),
              valueColor: const AlwaysStoppedAnimation(AppColors.primaryGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: Color(0xFF8E9BB5))),
        ],
      ),
    );
  }

  // ── Member picker (team leader) ────────────────────────────────────────────

  Widget _buildMemberPicker(DashboardModel d) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select Team Member to View Analytics',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<MemberTaskSummary>(
                isExpanded: true,
                value: _selectedMember,
                hint: const Text('-- Select Member --',
                    style: TextStyle(fontSize: 13)),
                items: d.memberTaskSummaries.map((m) {
                  return DropdownMenuItem(
                    value: m,
                    child: Text(
                      m.isLeader ? '${m.memberName} (You)' : m.memberName,
                      style: const TextStyle(fontSize: 13),
                    ),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedMember = v),
              ),
            ),
          ),
          if (_selectedMember != null) ...[
            const SizedBox(height: 12),
            _buildTaskCards(_selectedMember!.summary,
                color: const Color(0xFF7367F0)),
          ],
        ],
      ),
    );
  }

  // ── Team attendance table ──────────────────────────────────────────────────

  Widget _buildTeamAttendanceTable(DashboardModel d) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Text('Team Attendance',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2340))),
          ),
          const Divider(height: 20),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: const [
                Expanded(child: Text('Member', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF8E9BB5)))),
                _AttendanceHeaderCell('Present'),
                _AttendanceHeaderCell('Half'),
                _AttendanceHeaderCell('Absent'),
                _AttendanceHeaderCell('%'),
              ],
            ),
          ),
          const SizedBox(height: 6),
          ...d.memberAttendance.map((m) => _attendanceRow(m)),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _attendanceRow(MemberAttendanceSummary m) {
    final pct = m.attendance.attendancePercentage;
    final color = pct >= 90
        ? const Color(0xFF28C76F)
        : pct >= 75
            ? const Color(0xFFFF9F43)
            : const Color(0xFFEA5455);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(m.memberName,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis),
          ),
          _AttendanceBadge('${m.attendance.presentDays}', const Color(0xFF28C76F)),
          _AttendanceBadge('${m.attendance.halfDays}',    const Color(0xFFFF9F43)),
          _AttendanceBadge('${m.attendance.absentDays}',  const Color(0xFFEA5455)),
          SizedBox(
            width: 44,
            child: Text('${pct.toStringAsFixed(0)}%',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ),
        ],
      ),
    );
  }

  // ── Attendance cards ───────────────────────────────────────────────────────

  Widget _buildAttendanceCards(DashboardAttendanceSummary s) {
    final cards = [
      _TaskCardData('Present Days',  '${s.presentDays}',
          Icons.check_box_outlined,          const Color(0xFF28C76F), const Color(0xFFE6F7EE)),
      _TaskCardData('Half Days',     '${s.halfDays}',
          Icons.remove_circle_outline,       const Color(0xFFFF9F43), const Color(0xFFFFF4E6)),
      _TaskCardData('Absent Days',   '${s.absentDays}',
          Icons.cancel_outlined,             const Color(0xFFEA5455), const Color(0xFFFEE2E2)),
      _TaskCardData('Attendance %',  '${s.attendancePercentage.toStringAsFixed(0)}%',
          Icons.calendar_month_outlined,     const Color(0xFF00CFE8), const Color(0xFFE0F7FA)),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.65,
      children: cards.map(_buildTaskCard).toList(),
    );
  }
}

// ── Static helpers ─────────────────────────────────────────────────────────

class _TaskCardData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;
  const _TaskCardData(this.label, this.value, this.icon, this.color, this.bgColor);
}

class _AttendanceHeaderCell extends StatelessWidget {
  final String text;
  const _AttendanceHeaderCell(this.text);
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

class _AttendanceBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _AttendanceBadge(this.text, this.color);
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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

// ── Custom donut painter ───────────────────────────────────────────────────

class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;

  const _DonutPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold(0.0, (a, b) => a + b);
    if (total == 0) return;

    final rect   = Rect.fromLTWH(0, 0, size.width, size.height);
    final stroke = size.width * 0.18;
    final paint  = Paint()
      ..style       = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap   = StrokeCap.butt;

    double startAngle = -math.pi / 2;

    for (int i = 0; i < values.length; i++) {
      if (values[i] == 0) continue;
      final sweep = (values[i] / total) * 2 * math.pi;
      paint.color = colors[i % colors.length];
      canvas.drawArc(
        rect.deflate(stroke / 2),
        startAngle,
        sweep - 0.04,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.values != values || old.colors != colors;
}