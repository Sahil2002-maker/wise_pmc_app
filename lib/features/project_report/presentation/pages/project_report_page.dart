// lib/features/project_report/presentation/pages/project_report_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/utils/api_exception.dart';
import '../../data/models/project_report_models.dart';

class ProjectReportPage extends StatefulWidget {
  const ProjectReportPage({super.key});

  @override
  State<ProjectReportPage> createState() => _ProjectReportPageState();
}

class _ProjectReportPageState extends State<ProjectReportPage>
    with SingleTickerProviderStateMixin {
  // ── Projects list ──────────────────────────────────────────────────────────
  List<ReportProject> _projects = [];
  bool _projectsLoading = true;
  String? _projectsError;

  // ── Selection ──────────────────────────────────────────────────────────────
  ReportProject? _selected;

  // ── Report state ───────────────────────────────────────────────────────────
  ProjectReportData? _reportData;
  bool _reportLoading = false;
  String? _reportError;

  // ── Search within report ───────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // ── Fade animation ─────────────────────────────────────────────────────────
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadProjects();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _loadProjects() async {
    setState(() {
      _projectsLoading = true;
      _projectsError = null;
    });
    try {
      final list = await ApiService.fetchProjectReportProjects();
      if (mounted) {
        setState(() {
          _projects = list;
          _projectsLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _projectsError = e.toString();
          _projectsLoading = false;
        });
      }
    }
  }

  Future<void> _loadReport() async {
    if (_selected == null) return;
    setState(() {
      _reportLoading = true;
      _reportError = null;
      _reportData = null;
    });
    try {
      final data =
          await ApiService.generateProjectReport(projectId: _selected!.id);
      if (mounted) {
        setState(() {
          _reportData = data;
          _reportLoading = false;
        });
        _fadeCtrl
          ..reset()
          ..forward();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _reportError = e.toString();
          _reportLoading = false;
        });
      }
    }
  }

  // ── Filtered teams ─────────────────────────────────────────────────────────

  List<ProjectReportTeamRow> get _filteredTeams {
    if (_reportData == null) return [];
    if (_searchQuery.isEmpty) return _reportData!.teams;
    final q = _searchQuery.toLowerCase();
    return _reportData!.teams
        .where((t) => t.teamName.toLowerCase().contains(q))
        .toList();
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.sidebarActiveStart, AppColors.sidebarActiveEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Project Report',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  // Refresh button
                  if (_selected != null)
                    GestureDetector(
                      onTap: _reportLoading ? null : _loadReport,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _reportLoading
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(
                                          Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.refresh_rounded,
                                    color: Colors.white, size: 16),
                            const SizedBox(width: 5),
                            const Text('Refresh',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              // Project selector
              _buildProjectSelector(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProjectSelector() {
    if (_projectsLoading) {
      return Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white70)),
            ),
            SizedBox(width: 10),
            Text('Loading projects…',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
      );
    }

    if (_projectsError != null) {
      return GestureDetector(
        onTap: _loadProjects,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const Text('Failed to load projects — tap to retry',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
        ),
      );
    }

    return GestureDetector(
      onTap: _showProjectPicker,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.business_outlined,
                size: 18,
                color: _selected != null
                    ? AppColors.sidebarActiveStart
                    : Colors.grey),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _selected?.societyName ?? 'Select a project…',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: _selected != null
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: _selected != null
                      ? const Color(0xFF1E293B)
                      : Colors.grey,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: _selected != null
                    ? AppColors.sidebarActiveStart
                    : Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showProjectPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProjectPickerSheet(
        projects: _projects,
        selected: _selected,
        onSelected: (p) {
          setState(() => _selected = p);
          _loadReport();
        },
      ),
    );
  }

  // ── Body ───────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_selected == null) return _buildInitialState();
    if (_reportLoading) return _buildShimmer();
    if (_reportError != null) return _buildError();
    if (_reportData == null || _reportData!.teams.isEmpty) {
      return _buildEmptyState();
    }
    return _buildReport();
  }

  Widget _buildInitialState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bar_chart_outlined,
                  size: 40, color: AppColors.primaryGreen),
            ),
            const SizedBox(height: 18),
            const Text(
              'Project Report',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a project above to view\nthe team-wise task breakdown.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                  height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: 5,
      itemBuilder: (_, __) => _ShimmerCard(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            Text(_reportError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadReport,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 52, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No report data for\n"${_selected!.societyName}"',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildReport() {
    final summary = _reportData!.summary;
    final teams = _filteredTeams;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Column(
        children: [
          _buildSummaryBar(summary),
          _buildSearchBar(),
          Expanded(
            child: teams.isEmpty
                ? Center(
                    child: Text(
                      'No teams match "$_searchQuery"',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                    itemCount: teams.length,
                    itemBuilder: (_, i) => _TeamCard(row: teams[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar(ProjectReportSummary s) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          _statChip(Icons.group_outlined, '${s.totalTeams}', 'Teams',
              AppColors.primaryGreen),
          const SizedBox(width: 6),
          _statChip(Icons.task_alt_outlined, '${s.totalCompleted}',
              'Done', const Color(0xFF22C55E)),
          const SizedBox(width: 6),
          _statChip(Icons.hourglass_top_rounded, '${s.totalPending}',
              'Pending', const Color(0xFFF59E0B)),
          const SizedBox(width: 6),
          _statChip(Icons.warning_amber_rounded, '${s.totalOverdue}',
              'Overdue', const Color(0xFFEF4444)),
        ],
      ),
    );
  }

  Widget _statChip(
      IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color)),
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    color: color.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _searchQuery = v.trim()),
        decoration: InputDecoration(
          hintText: 'Search team…',
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
          prefixIcon:
              const Icon(Icons.search_rounded, color: Colors.grey, size: 18),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.grey, size: 16),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
                color: AppColors.primaryGreen, width: 1.5),
          ),
        ),
      ),
    );
  }
}

// ── Team card ──────────────────────────────────────────────────────────────

class _TeamCard extends StatelessWidget {
  final ProjectReportTeamRow row;
  const _TeamCard({required this.row});

  Color _hexColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    if (cleaned.length == 6) {
      return Color(int.parse('FF$cleaned', radix: 16));
    }
    return AppColors.primaryGreen;
  }

  @override
  Widget build(BuildContext context) {
    final teamColor = _hexColor(row.teamColor);
    final total = row.totalTasks;
    final completedFrac =
        total > 0 ? row.completedTasks / total : 0.0;
    final pendingFrac =
        total > 0 ? row.pendingTasks / total : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Colored team header ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [teamColor, _darken(teamColor, 0.1)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.group_outlined,
                          color: Colors.white, size: 17),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.teamName.toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4),
                        ),
                        if (row.teamLeader.isNotEmpty &&
                            row.teamLeader != 'N/A')
                          Text(
                            '⭐ ${row.teamLeader}',
                            style: TextStyle(
                                color:
                                    Colors.white.withValues(alpha: 0.85),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500),
                          ),
                      ],
                    ),
                  ),
                  // Total badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${row.totalTasks} tasks',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress bar
                  _buildProgressBar(completedFrac, pendingFrac),
                  const SizedBox(height: 12),

                  // Task counts row
                  Row(
                    children: [
                      _taskPill(
                        label: 'Completed',
                        value: row.completedTasks,
                        color: const Color(0xFF22C55E),
                        bg: const Color(0xFFF0FDF4),
                        icon: Icons.check_circle_outline_rounded,
                      ),
                      const SizedBox(width: 8),
                      _taskPill(
                        label: 'Pending',
                        value: row.pendingTasks,
                        color: const Color(0xFFF59E0B),
                        bg: const Color(0xFFFFFBEB),
                        icon: Icons.hourglass_top_rounded,
                      ),
                      const SizedBox(width: 8),
                      _taskPill(
                        label: 'Not Assigned',
                        value: row.notAssignedTasks,
                        color: const Color(0xFF3B82F6),
                        bg: const Color(0xFFEFF6FF),
                        icon: Icons.assignment_late_outlined,
                      ),
                    ],
                  ),

                  // Divider
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Divider(
                        height: 1, color: Colors.grey.shade100),
                  ),

                  // Deadline row
                  Row(
                    children: [
                      _deadlinePill(
                        label: 'Overdue',
                        value: row.overdueTasks,
                        color: const Color(0xFFEF4444),
                        icon: Icons.warning_amber_rounded,
                      ),
                      const SizedBox(width: 10),
                      _deadlinePill(
                        label: 'Next 3 days',
                        value: row.upcomingDeadlineTasks,
                        color: const Color(0xFFF97316),
                        icon: Icons.schedule_rounded,
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

  Widget _buildProgressBar(double completedFrac, double pendingFrac) {
    final notAssignedFrac = 1.0 - completedFrac - pendingFrac;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Task distribution',
            style: TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                if (completedFrac > 0)
                  Expanded(
                    flex: (completedFrac * 1000).round(),
                    child: const ColoredBox(color: Color(0xFF22C55E)),
                  ),
                if (pendingFrac > 0)
                  Expanded(
                    flex: (pendingFrac * 1000).round(),
                    child: const ColoredBox(color: Color(0xFFF59E0B)),
                  ),
                if (notAssignedFrac > 0.001)
                  Expanded(
                    flex: (notAssignedFrac * 1000).round(),
                    child: const ColoredBox(color: Color(0xFF3B82F6)),
                  ),
                if (row.totalTasks == 0)
                  const Expanded(
                    child: ColoredBox(color: Color(0xFFE2E8F0)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _taskPill({
    required String label,
    required int value,
    required Color color,
    required Color bg,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(height: 4),
            Text(
              '$value',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color),
            ),
            Text(
              label,
              style: TextStyle(
                  fontSize: 9.5,
                  color: color.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deadlinePill({
    required String label,
    required int value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: color),
                ),
                Text(
                  label,
                  style: TextStyle(
                      fontSize: 9.5,
                      color: color.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }
}

// ── Project picker sheet ────────────────────────────────────────────────────

class _ProjectPickerSheet extends StatefulWidget {
  final List<ReportProject> projects;
  final ReportProject? selected;
  final ValueChanged<ReportProject> onSelected;

  const _ProjectPickerSheet({
    required this.projects,
    required this.selected,
    required this.onSelected,
  });

  @override
  State<_ProjectPickerSheet> createState() => _ProjectPickerSheetState();
}

class _ProjectPickerSheetState extends State<_ProjectPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _q = '';

  List<ReportProject> get _filtered {
    if (_q.isEmpty) return widget.projects;
    final q = _q.toLowerCase();
    return widget.projects
        .where((p) => p.societyName.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFFF4F6FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2))),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Row(
              children: [
                const Text('Select Project',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B))),
                const Spacer(),
                Text('${widget.projects.length} projects',
                    style: const TextStyle(
                        color: Color(0xFF64748B), fontSize: 12)),
              ],
            ),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _q = v.trim()),
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search project…',
                hintStyle:
                    const TextStyle(color: Colors.grey, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: Colors.grey, size: 18),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.grey.shade200)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: AppColors.primaryGreen, width: 1.5),
                ),
              ),
            ),
          ),
          // List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final p = _filtered[i];
                final isSelected = widget.selected?.id == p.id;
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    widget.onSelected(p);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryGreen.withValues(alpha: 0.1)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isSelected
                              ? AppColors.primaryGreen
                              : Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.business_outlined,
                            size: 18,
                            color: isSelected
                                ? AppColors.primaryGreen
                                : Colors.grey),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(p.societyName,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? AppColors.primaryGreen
                                      : const Color(0xFF1E293B))),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.primaryGreen, size: 18),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shimmer placeholder card ────────────────────────────────────────────────

class _ShimmerCard extends StatefulWidget {
  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final shade = Color.lerp(
            const Color(0xFFE2E8F0), const Color(0xFFF1F5F9), _anim.value)!;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 180,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  height: 52,
                  decoration: BoxDecoration(
                      color: shade,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16)))),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        height: 10,
                        width: 120,
                        color: shade,
                        margin: const EdgeInsets.only(bottom: 10)),
                    Row(
                      children: List.generate(
                          3,
                          (_) => Expanded(
                                child: Container(
                                  height: 52,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                      color: shade,
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                ),
                              )),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}