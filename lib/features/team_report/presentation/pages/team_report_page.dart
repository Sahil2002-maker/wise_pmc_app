// lib/features/team_report/presentation/pages/team_report_page.dart

import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/utils/api_exception.dart';
import '../../data/models/team_report_models.dart';

class TeamReportPage extends StatefulWidget {
  const TeamReportPage({super.key});

  @override
  State<TeamReportPage> createState() => _TeamReportPageState();
}

class _TeamReportPageState extends State<TeamReportPage>
    with SingleTickerProviderStateMixin {
  // ── Filter state ──────────────────────────────────────────────────────────
  List<TeamReportTeamItem> _teams = [];
  List<TeamReportMemberItem> _members = [];
  TeamReportTeamItem? _selectedTeam;
  TeamReportMemberItem? _selectedMember;

  // ── Report state ──────────────────────────────────────────────────────────
  TeamReportResult? _result;
  TeamReportSummary _summary = TeamReportSummary.empty;

  // ── UI state ──────────────────────────────────────────────────────────────
  bool _teamsLoading = true;
  bool _membersLoading = false;
  bool _reportLoading = false;
  String? _errorMessage;
  final TextEditingController _searchCtrl = TextEditingController();
  late AnimationController _fadeCtrl;

  // ── Pagination ────────────────────────────────────────────────────────────
  int _currentPage = 1;
  static const int _perPage = 20;
  bool _hasMore = false;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadTeams();
    _scrollCtrl.addListener(_onScroll);
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadTeams() async {
    setState(() => _teamsLoading = true);
    try {
      final teams = await ApiService.fetchTeamReportTeams();
      if (!mounted) return;
      setState(() {
        _teams = teams;
        _teamsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _teamsLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _onTeamSelected(TeamReportTeamItem? team) async {
    setState(() {
      _selectedTeam = team;
      _selectedMember = null;
      _members = [];
      _result = null;
      _summary = TeamReportSummary.empty;
      _currentPage = 1;
    });

    if (team == null) return;

    // Load members
    setState(() => _membersLoading = true);
    try {
      final members = await ApiService.fetchTeamReportMembers(team.id);
      if (!mounted) return;
      setState(() {
        _members = members;
        _membersLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _membersLoading = false);
    }

    // Load report immediately with all members
    await _loadReport(reset: true);
  }

  Future<void> _onMemberSelected(TeamReportMemberItem? member) async {
    setState(() {
      _selectedMember = member;
      _currentPage = 1;
    });
    await _loadReport(reset: true);
  }

  Future<void> _loadReport({bool reset = false}) async {
    if (_selectedTeam == null) return;

    if (reset) {
      setState(() {
        _currentPage = 1;
        _reportLoading = true;
        _errorMessage = null;
      });
    } else {
      setState(() => _reportLoading = true);
    }

    try {
      final result = await ApiService.generateTeamReport(
        teamId: _selectedTeam!.id,
        memberId: _selectedMember?.id,
        page: _currentPage,
        perPage: _perPage,
        search: _searchCtrl.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        if (reset || _currentPage == 1) {
          _result = result;
        } else {
          // Append for infinite scroll
          _result = TeamReportResult(
            rows: [...(_result?.rows ?? []), ...result.rows],
            summary: result.summary,
            total: result.total,
            currentPage: result.currentPage,
            lastPage: result.lastPage,
            perPage: result.perPage,
          );
        }
        _summary = result.summary;
        _hasMore = result.currentPage < result.lastPage;
        _reportLoading = false;
      });

      _fadeCtrl.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _reportLoading = false;
        _errorMessage =
            e is ApiException ? e.toString() : 'Failed to load report';
      });
    }
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 200 &&
        !_reportLoading &&
        _hasMore) {
      _currentPage++;
      _loadReport();
    }
  }

  void _onSearchChanged() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _loadReport(reset: true);
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            _buildFilterSection(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B6B3A), Color(0xFF2ECC71)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.bar_chart_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Team Report',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                'Project-wise task breakdown',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          if (_selectedTeam != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded,
                  color: Colors.white, size: 22),
              onPressed: () => _loadReport(reset: true),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        children: [
          // Team Dropdown
          _DropdownCard(
            label: 'Select Team',
            icon: Icons.group_outlined,
            isLoading: _teamsLoading,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<TeamReportTeamItem?>(
                value: _selectedTeam,
                isExpanded: true,
                hint: const Text('All Teams',
                    style:
                        TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
                items: [
                  const DropdownMenuItem<TeamReportTeamItem?>(
                    value: null,
                    child:
                        Text('All Teams', style: TextStyle(fontSize: 14)),
                  ),
                  ..._teams.map((t) => DropdownMenuItem<TeamReportTeamItem?>(
                        value: t,
                        child: Text(t.teamName,
                            style: const TextStyle(fontSize: 14)),
                      )),
                ],
                onChanged: _onTeamSelected,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Member Dropdown
          _DropdownCard(
            label: 'Team Member',
            icon: Icons.person_outline,
            isLoading: _membersLoading,
            isDisabled: _selectedTeam == null,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<TeamReportMemberItem?>(
                value: _selectedMember,
                isExpanded: true,
                hint: Text(
                  _selectedTeam == null
                      ? 'Select a team first'
                      : 'All Team Members',
                  style: const TextStyle(
                      color: Color(0xFF94A3B8), fontSize: 14),
                ),
                items: _selectedTeam == null
                    ? []
                    : [
                        const DropdownMenuItem<TeamReportMemberItem?>(
                          value: null,
                          child: Text('All Team Members',
                              style: TextStyle(fontSize: 14)),
                        ),
                        ..._members.map(
                          (m) => DropdownMenuItem<TeamReportMemberItem?>(
                            value: m,
                            child: Row(
                              children: [
                                if (m.isLeader)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 6),
                                    child: Icon(Icons.star_rounded,
                                        size: 14,
                                        color: Color(0xFFF59E0B)),
                                  ),
                                Expanded(
                                  child: Text(m.label,
                                      style:
                                          const TextStyle(fontSize: 14)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                onChanged:
                    _selectedTeam == null ? null : _onMemberSelected,
              ),
            ),
          ),
          // Search bar (only when team is selected)
          if (_selectedTeam != null) ...[
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Search projects...',
                  hintStyle:
                      TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  prefixIcon: Icon(Icons.search,
                      color: Color(0xFF94A3B8), size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_selectedTeam == null) {
      return _buildInitialState();
    }

    if (_reportLoading && (_result == null || _result!.rows.isEmpty)) {
      return _buildShimmer();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_result == null || _result!.rows.isEmpty) {
      return _buildEmptyState();
    }

    return FadeTransition(
      opacity: _fadeCtrl,
      child: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          SliverToBoxAdapter(child: _buildSummaryBanner()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index == _result!.rows.length) {
                    return _hasMore
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primaryGreen,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : const SizedBox(height: 16);
                  }
                  return _TeamProjectCard(
                    row: _result!.rows[index],
                    index: index,
                  );
                },
                childCount: _result!.rows.length + 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B6B3A), Color(0xFF27AE60)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B6B3A).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined,
                  color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(
                '${_summary.totalProjects} Projects · ${_selectedTeam?.teamName ?? ''}',
                style: const TextStyle(
                    color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _SummaryChip(
                label: 'Done',
                value: _summary.totalCompleted,
                color: const Color(0xFF86EFAC),
              ),
              const SizedBox(width: 8),
              _SummaryChip(
                label: 'Pending',
                value: _summary.totalPending,
                color: const Color(0xFFFCD34D),
              ),
              const SizedBox(width: 8),
              _SummaryChip(
                label: 'Unassigned',
                value: _summary.totalNotAssigned,
                color: const Color(0xFF67E8F9),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _SummaryChip(
                label: 'Overdue',
                value: _summary.totalOverdue,
                color: const Color(0xFFFCA5A5),
              ),
              const SizedBox(width: 8),
              _SummaryChip(
                label: 'Due Soon',
                value: _summary.totalUpcomingDeadline,
                color: const Color(0xFFFDBA74),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.group_outlined,
                size: 40, color: AppColors.primaryGreen),
          ),
          const SizedBox(height: 16),
          const Text(
            'Select a Team to View Report',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose a team from the dropdown above\nto see the project-wise task breakdown.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inbox_outlined,
                size: 36, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 14),
          const Text(
            'No Projects Found',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'No task data available for this filter.',
            style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            const Text(
              'Failed to Load Report',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              onPressed: () => _loadReport(reset: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, _) => const _ShimmerCard(),
    );
  }
}

// ── Dropdown Card ──────────────────────────────────────────────────────────────

class _DropdownCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Widget child;
  final bool isLoading;
  final bool isDisabled;

  const _DropdownCard({
    required this.label,
    required this.icon,
    required this.child,
    this.isLoading = false,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDisabled ? const Color(0xFFF8FAFC) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDisabled
              ? const Color(0xFFE2E8F0)
              : const Color(0xFFCBD5E1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Icon(icon, size: 14, color: AppColors.primaryGreen),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryGreen,
                    letterSpacing: 0.5,
                  ),
                ),
                if (isLoading) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ── Summary Chip ───────────────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Project Card ───────────────────────────────────────────────────────────────

class _TeamProjectCard extends StatelessWidget {
  final TeamReportRow row;
  final int index;

  const _TeamProjectCard({required this.row, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: const BoxDecoration(
              border: Border(
                bottom:
                    BorderSide(color: Color(0xFFF1F5F9), width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    row.projectName.isNotEmpty
                        ? row.projectName[0].toUpperCase()
                        : 'P',
                    style: const TextStyle(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.projectName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        '${row.totalTasks} total tasks',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                // Total badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    row.totalTasks.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Segmented progress bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TASK DISTRIBUTION',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                _SegmentedBar(row: row),
                const SizedBox(height: 10),
                // Legend row
                Row(
                  children: [
                    _TaskLegend(
                      color: const Color(0xFF22C55E),
                      label: 'Completed',
                      count: row.completedTasks,
                    ),
                    const SizedBox(width: 12),
                    _TaskLegend(
                      color: const Color(0xFFF59E0B),
                      label: 'Pending',
                      count: row.pendingTasks,
                    ),
                    const SizedBox(width: 12),
                    _TaskLegend(
                      color: const Color(0xFF06B6D4),
                      label: 'Unassigned',
                      count: row.notAssignedTasks,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Deadline badges
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: [
                _DeadlineBadge(
                  icon: Icons.warning_amber_rounded,
                  label: 'Overdue',
                  count: row.overdueTasks,
                  color: const Color(0xFFEF4444),
                  bgColor: const Color(0xFFFEF2F2),
                ),
                const SizedBox(width: 10),
                _DeadlineBadge(
                  icon: Icons.schedule_rounded,
                  label: 'Due in 3 Days',
                  count: row.upcomingDeadlineTasks,
                  color: const Color(0xFFF59E0B),
                  bgColor: const Color(0xFFFFFBEB),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Segmented Bar ─────────────────────────────────────────────────────────────

class _SegmentedBar extends StatelessWidget {
  final TeamReportRow row;

  const _SegmentedBar({required this.row});

  @override
  Widget build(BuildContext context) {
    if (row.totalTasks == 0) {
      return Container(
        height: 10,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 10,
        child: Row(
          children: [
            if (row.completedTasks > 0)
              Flexible(
                flex: row.completedTasks,
                child: Container(color: const Color(0xFF22C55E)),
              ),
            if (row.pendingTasks > 0)
              Flexible(
                flex: row.pendingTasks,
                child: Container(color: const Color(0xFFF59E0B)),
              ),
            if (row.notAssignedTasks > 0)
              Flexible(
                flex: row.notAssignedTasks,
                child: Container(color: const Color(0xFF06B6D4)),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Task Legend Item ──────────────────────────────────────────────────────────

class _TaskLegend extends StatelessWidget {
  final Color color;
  final String label;
  final int count;

  const _TaskLegend({
    required this.color,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$count $label',
          style: const TextStyle(
              fontSize: 11, color: Color(0xFF64748B)),
        ),
      ],
    );
  }
}

// ── Deadline Badge ────────────────────────────────────────────────────────────

class _DeadlineBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final Color bgColor;

  const _DeadlineBadge({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count.toString(),
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.8),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shimmer Card ──────────────────────────────────────────────────────────────

class _ShimmerCard extends StatefulWidget {
  const _ShimmerCard();

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 0.7).animate(_ctrl);
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
      builder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _shimmerBox(36, 36, radius: 10),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _shimmerBox(140, 14),
                    const SizedBox(height: 6),
                    _shimmerBox(80, 10),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            _shimmerBox(double.infinity, 10, radius: 6),
            const SizedBox(height: 12),
            Row(
              children: [
                _shimmerBox(100, 36, radius: 10),
                const SizedBox(width: 10),
                _shimmerBox(100, 36, radius: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _shimmerBox(double w, double h, {double radius = 6}) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Color.lerp(
          const Color(0xFFF1F5F9),
          const Color(0xFFE2E8F0),
          _anim.value,
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}