// lib/features/employee_report/presentation/pages/employee_report_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/utils/api_exception.dart';
import '../../data/models/employee_report_models.dart';
import '../widgets/report_filter_sheet.dart';
import '../widgets/team_group_card.dart';
import '../widgets/task_detail_bottom_sheet.dart';

/// Main Employee Report page – accessible from the Reports section of the sidebar.
class EmployeeReportPage extends StatefulWidget {
  const EmployeeReportPage({super.key});

  @override
  State<EmployeeReportPage> createState() => _EmployeeReportPageState();
}

class _EmployeeReportPageState extends State<EmployeeReportPage>
    with TickerProviderStateMixin {
  // ── Init data (dropdown options) ──────────────────────────────────────────
  List<ReportUser> _allUsers = [];
  List<ReportTeam> _allTeams = [];
  bool _initLoading = true;
  String? _initError;

  // ── Filter state ──────────────────────────────────────────────────────────
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 6));
  DateTime _endDate   = DateTime.now();
  String _selectedTeamId       = 'all';
  List<String> _selectedEmpIds = ['all'];

  // ── Report state ──────────────────────────────────────────────────────────
  EmployeeReportData? _reportData;
  bool _reportLoading = false;
  String? _reportError;
  bool _hasGenerated  = false;

  // ── Search ────────────────────────────────────────────────────────────────
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // ── Animation ─────────────────────────────────────────────────────────────
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadInit();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadInit() async {
    setState(() {
      _initLoading = true;
      _initError   = null;
    });
    try {
      final result = await ApiService.fetchEmployeeReportInit();
      if (mounted) {
        setState(() {
          _allUsers    = result['users'] as List<ReportUser>;
          _allTeams    = result['teams'] as List<ReportTeam>;
          _initLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _initError   = e.toString();
          _initLoading = false;
        });
      }
    }
  }

  Future<void> _generateReport() async {
    setState(() {
      _reportLoading = true;
      _reportError   = null;
    });

    final fmt = DateFormat('yyyy-MM-dd');
    try {
      final data = await ApiService.generateEmployeeReport(
        startDate:   fmt.format(_startDate),
        endDate:     fmt.format(_endDate),
        employeeIds: _selectedEmpIds,
        teamId:      _selectedTeamId,
      );
      if (mounted) {
        setState(() {
          _reportData    = data;
          _reportLoading = false;
          _hasGenerated  = true;
        });
        _fadeCtrl
          ..reset()
          ..forward();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _reportError   = e.toString();
          _reportLoading = false;
        });
      }
    }
  }

  // ── Filter helpers ────────────────────────────────────────────────────────

  void _openFilterSheet() async {
    final result = await showModalBottomSheet<_FilterResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportFilterSheet(
        allUsers:      _allUsers,
        allTeams:      _allTeams,
        initialStart:  _startDate,
        initialEnd:    _endDate,
        initialTeamId: _selectedTeamId,
        initialEmpIds: _selectedEmpIds,
      ),
    );

    if (result != null) {
      setState(() {
        _startDate      = result.startDate;
        _endDate        = result.endDate;
        _selectedTeamId = result.teamId;
        _selectedEmpIds = result.empIds;
      });
      _generateReport();
    }
  }

  // ── Filtered display data ─────────────────────────────────────────────────

  List<ReportTeamGroup> get _filteredTeams {
    if (_reportData == null) return [];
    if (_searchQuery.isEmpty) return _reportData!.teams;

    final q = _searchQuery.toLowerCase();
    return _reportData!.teams.map((team) {
      final filteredMembers = team.members
          .where((m) => m.name.toLowerCase().contains(q))
          .toList();
      return ReportTeamGroup(
        teamId:         team.teamId,
        teamName:       team.teamName,
        teamColor:      team.teamColor,
        teamLeaderName: team.teamLeaderName,
        members:        filteredMembers,
      );
    }).where((t) => t.members.isNotEmpty).toList();
  }

  // ── Summary stats ─────────────────────────────────────────────────────────

  _SummaryStats get _summaryStats {
    if (_reportData == null) return const _SummaryStats(0, 0, 0, 0);
    int totalEmps  = 0;
    int totalTasks = 0;
    int zeroDay    = 0;
    int maxCount   = 0;

    for (final team in _reportData!.teams) {
      for (final m in team.members) {
        totalEmps++;
        totalTasks += m.totalTasks;
        zeroDay    += m.zeroDays;
        if (m.maxTasks > maxCount) maxCount = m.maxTasks;
      }
    }
    return _SummaryStats(totalEmps, totalTasks, zeroDay, maxCount);
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _initLoading
                ? _buildInitLoader()
                : _initError != null
                    ? _buildInitError()
                    : _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final fmt   = DateFormat('dd MMM');
    final range = '${fmt.format(_startDate)} – ${fmt.format(_endDate)}';

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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                      'Employee Report',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  // Filter button
                  GestureDetector(
                    onTap: _initLoading ? null : _openFilterSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tune_rounded,
                              color: Colors.white, size: 16),
                          SizedBox(width: 5),
                          Text('Filter',
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
              // Date range pill + generate button
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            color: Colors.white70, size: 13),
                        const SizedBox(width: 5),
                        Text(range,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_selectedTeamId != 'all') ...[
                    _buildPill(
                        Icons.group_outlined,
                        _allTeams
                            .firstWhere(
                              (t) => t.id.toString() == _selectedTeamId,
                              orElse: () => const ReportTeam(
                                  id: 0,
                                  teamName: 'Team',
                                  teamColor: '#999'),
                            )
                            .teamName),
                    const SizedBox(width: 6),
                  ],
                  const Spacer(),
                  // Generate button
                  GestureDetector(
                    onTap: _reportLoading ? null : _generateReport,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _reportLoading
                            ? Colors.white38
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: _reportLoading
                            ? []
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ],
                      ),
                      child: _reportLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                    AppColors.primaryGreen),
                              ),
                            )
                          : Text(
                              _hasGenerated ? 'Refresh' : 'Generate',
                              style: TextStyle(
                                color: AppColors.sidebarActiveStart,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 11),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildInitLoader() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.primaryGreen),
          SizedBox(height: 14),
          Text('Loading filters…',
              style: TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildInitError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 52, color: Colors.grey),
            const SizedBox(height: 12),
            Text(_initError ?? 'Failed to load filters.',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadInit,
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

  Widget _buildBody() {
    return Column(
      children: [
        if (_hasGenerated && _reportData != null) _buildSummaryBar(),
        if (_hasGenerated) _buildSearchBar(),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildSummaryBar() {
    final stats = _summaryStats;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          _statChip(Icons.people_outline, '${stats.totalEmps}', 'Employees',
              AppColors.primaryGreen),
          const SizedBox(width: 8),
          _statChip(Icons.task_alt_outlined, '${stats.totalTasks}', 'Tasks',
              const Color(0xFF3B82F6)),
          const SizedBox(width: 8),
          _statChip(Icons.warning_amber_outlined, '${stats.zeroDays}',
              'Zero Days', const Color(0xFFEF4444)),
          const SizedBox(width: 8),
          _statChip(Icons.trending_up_rounded, '${stats.maxInDay}',
              'Max/Day', const Color(0xFFF59E0B)),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String value, String label, Color color) {
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
            Icon(icon, size: 16, color: color),
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v.trim()),
        decoration: InputDecoration(
          hintText: 'Search employee…',
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded,
              color: Colors.grey, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.grey, size: 18),
                  onPressed: () {
                    _searchController.clear();
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
            borderSide:
                const BorderSide(color: AppColors.primaryGreen, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_reportLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primaryGreen),
            SizedBox(height: 14),
            Text('Generating report…',
                style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
      );
    }

    if (_reportError != null) {
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
                onPressed: _generateReport,
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

    if (!_hasGenerated) {
      return _buildEmptyPrompt();
    }

    final teams = _filteredTeams;
    if (teams.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No employees match "$_searchQuery"'
                  : 'No records found for the selected criteria.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnim,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
        itemCount: teams.length,
        itemBuilder: (_, i) => TeamGroupCard(
          group:  teams[i],
          dates:  _reportData!.dates,
          onCellTap: _onCellTap,
        ),
      ),
    );
  }

  Widget _buildEmptyPrompt() {
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
              child: const Icon(Icons.assessment_outlined,
                  size: 40, color: AppColors.primaryGreen),
            ),
            const SizedBox(height: 18),
            const Text(
              'Employee Work Analysis',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Generate" to view the task report\nfor the selected date range and employees.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Colors.grey.shade500, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _reportLoading ? null : _generateReport,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Generate Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onCellTap(int employeeId, String employeeName, String date) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskDetailBottomSheet(
        employeeId:   employeeId,
        employeeName: employeeName,
        date:         date,
      ),
    );
  }
}

// ── Internal helpers ──────────────────────────────────────────────────────────

class _FilterResult {
  final DateTime startDate;
  final DateTime endDate;
  final String teamId;
  final List<String> empIds;

  const _FilterResult({
    required this.startDate,
    required this.endDate,
    required this.teamId,
    required this.empIds,
  });
}

class _SummaryStats {
  final int totalEmps;
  final int totalTasks;
  final int zeroDays;
  final int maxInDay;

  const _SummaryStats(
      this.totalEmps, this.totalTasks, this.zeroDays, this.maxInDay);
}