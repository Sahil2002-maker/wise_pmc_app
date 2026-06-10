// lib/features/dashboard/presentation/pages/dashboard_page.dart

import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/auth_storage_service.dart';
import '../../data/models/project_dashboard_model.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/dashboard_sidebar.dart';
import '../widgets/project_card.dart';
import '../../../project_list/presentation/pages/project_list_page.dart';
import '../../../general_tasks/presentation/pages/general_tasks_page.dart';
import '../../../general_tasks/presentation/pages/task_calendar_page.dart';
import '../../../work_reports/presentation/pages/work_reports_page.dart';
import '../../../all_tasks/presentation/pages/all_tasks_page.dart';
import '../../../employee_report/presentation/pages/employee_report_page.dart';
import '../../../project_report/presentation/pages/project_report_page.dart';
import '../../../team_report/presentation/pages/team_report_page.dart';
import '../../../stage_report/presentation/pages/stage_report_page.dart';
import '../../../process_list/presentation/pages/process_list_page.dart';
import '../../../process/presentation/pages/process_management_page.dart';
import '../../../development_process/presentation/pages/dev_process_page.dart';

// ↓ NEW: import the employee dashboard page
import 'employee_dashboard_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController searchController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  List<ProjectDashboardModel> allProjects = [];
  List<ProjectDashboardModel> filteredProjects = [];

  bool isLoading = true;
  String? errorMessage;

  String userName    = 'Admin';
  String userRole    = 'admin';
  int    userId      = 0;
  List<String> permissions = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _loadLocalUser();
    _loadDashboard();
    searchController.addListener(_filterProjects);
  }

  @override
  void dispose() {
    searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadLocalUser() async {
    final savedName        = await AuthStorageService.getUserName();
    final savedRole        = await AuthStorageService.getUserRole();
    final savedUserId      = await AuthStorageService.getUserId();
    final savedPermissions = await AuthStorageService.getPermissions();
    if (!mounted) return;
    setState(() {
      userName    = (savedName == null || savedName.isEmpty) ? 'Admin' : savedName;
      userRole    = (savedRole == null || savedRole.isEmpty) ? 'admin' : savedRole;
      userId      = savedUserId ?? 0;
      permissions = savedPermissions;
    });
  }

  Future<void> _loadDashboard() async {
    try {
      setState(() {
        isLoading    = true;
        errorMessage = null;
      });

      // Non-admin roles use EmployeeDashboardPage — no project fetch needed here
      if (!_isAdminRole) {
        if (!mounted) return;
        setState(() => isLoading = false);
        return;
      }

      final projects = await ApiService.fetchDashboardProjects();
      if (!mounted) return;
      setState(() {
        allProjects      = projects;
        filteredProjects = projects;
        isLoading        = false;
      });
      _animationController.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString();
        isLoading    = false;
      });
    }
  }

  void _filterProjects() {
    final query = searchController.text.trim().toLowerCase();
    setState(() {
      filteredProjects = query.isEmpty
          ? List<ProjectDashboardModel>.from(allProjects)
          : allProjects
              .where((item) =>
                  item.societyName.toLowerCase().contains(query))
              .toList();
    });
  }

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  bool get _isAdminRole => userRole.trim().toLowerCase() == 'admin';

  void _navigateTo(Widget page) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => page),
      );

  void _openProcessList(ProjectDashboardModel project) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProcessListPage(
          projectId:   project.id,
          projectName: project.societyName,
        ),
      ),
    );
  }

  void _openProjectList()   => _navigateTo(const ProjectListPage());
  void _openGeneralTasks()  => _navigateTo(const GeneralTasksPage());
  void _openTaskCalendar()  => _navigateTo(const TaskCalendarPage());
  void _openAllTasks()      => _navigateTo(const AllTasksPage());
  void _openWorkReports()   => _navigateTo(const WorkReportsPage());
  void _openProjectReport() => _navigateTo(const ProjectReportPage());
  void _openTeamReport()    => _navigateTo(const TeamReportPage());
  void _openStageReport()   => _navigateTo(const StageReportPage());

  void _openReDevelopmentProcess() => _navigateTo(
        const ProcessManagementPage(),
      );

  void _openDevelopmentProcess() => _navigateTo(
        const DevProcessPage(),
      );

  void _showComingSoon(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              '$title module coming soon',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sidebar builder ───────────────────────────────────────────────────────

  DashboardSidebar _buildSidebar() {
    return DashboardSidebar(
      userRole:                   userRole,
      userId:                     userId,
      permissions:                permissions,
      onDashboardTap:             () {},
      onProjectListTap:           _openProjectList,
      onAllMeetingsTap:           () => _showComingSoon('All Meetings'),
      onGeneralTasksTap:          _openGeneralTasks,
      onTaskCalendarTap:          _openTaskCalendar,
      onWorkReportsTap:           _openWorkReports,
      onAllTasksTap:              _openAllTasks,
      onReportsTap:               () => _showComingSoon('Reports'),
      onEmployeeReportTap:        () => _navigateTo(const EmployeeReportPage()),
      onProjectReportTap:         _openProjectReport,
      onTeamReportTap:            _openTeamReport,
      onStageReportTap:           _openStageReport,
      onUserManagementTap:        () => _showComingSoon('User Management'),
      onReDevelopmentProcessTap:  _openReDevelopmentProcess,
      onDevelopmentProcessTap:    _openDevelopmentProcess,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile    = screenWidth < 900;

    return Scaffold(
      key:             _scaffoldKey,
      backgroundColor: const Color(0xFFF4F6FA),
      drawer:          isMobile ? Drawer(child: _buildSidebar()) : null,
      body: SafeArea(
        child: Row(
          children: [
            if (!isMobile) _buildSidebar(),
            Expanded(
              child: Column(
                children: [
                  // ── Header ──────────────────────────────────────────────
                  DashboardHeader(
                    userName:       userName,
                    userRole:       userRole,
                    showMenuButton: isMobile,
                    onMenuTap:      isMobile ? _openDrawer : null,
                  ),

                  // ── Body ────────────────────────────────────────────────
                  Expanded(
                    child: _isAdminRole
                        ? _buildAdminBody(isMobile)
                        : _buildNonAdminBody(), // ← CHANGED: was SizedBox.expand()
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Non-admin body (employee / team leader) ───────────────────────────────
  // EmployeeDashboardPage handles both layouts via data.isTeamLeader internally.

  Widget _buildNonAdminBody() {
    return const EmployeeDashboardPage();
  }

  // ── Admin body ────────────────────────────────────────────────────────────

  Widget _buildAdminBody(bool isMobile) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 24,
        16,
        isMobile ? 16 : 24,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Stats summary row ──────────────────────────────────────────
          if (!isLoading && errorMessage == null && allProjects.isNotEmpty)
            _buildStatsSummary(isMobile),

          if (!isLoading && errorMessage == null && allProjects.isNotEmpty)
            const SizedBox(height: 20),

          // ── Section title + search ─────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Projects Overview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A2340),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${filteredProjects.length} active projects',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF8E9BB5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildSearchBar(),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(child: _buildProjectsBody(isMobile)),
        ],
      ),
    );
  }

  // ── Stats summary cards ───────────────────────────────────────────────────

  Widget _buildStatsSummary(bool isMobile) {
    final totalProjects  = allProjects.length;
    final totalCompleted = allProjects.fold<int>(0, (s, p) => s + p.completedTasks);
    final totalPending   = allProjects.fold<int>(0, (s, p) => s + p.pendingTasks);
    final avgProgress    = allProjects.isEmpty
        ? 0
        : (allProjects.fold<int>(0, (s, p) => s + p.progressPercentage) ~/
            allProjects.length);

    final stats = [
      _StatData(
        label: 'Total Projects',
        value: '$totalProjects',
        icon: Icons.domain_outlined,
        color: const Color(0xFF4C6FFF),
        bgColor: const Color(0xFFEEF1FF),
      ),
      _StatData(
        label: 'Completed Tasks',
        value: '$totalCompleted',
        icon: Icons.check_circle_outline_rounded,
        color: AppColors.primaryGreen,
        bgColor: const Color(0xFFE6F7EE),
      ),
      _StatData(
        label: 'Pending Tasks',
        value: '$totalPending',
        icon: Icons.pending_outlined,
        color: const Color(0xFFFF9F43),
        bgColor: const Color(0xFFFFF4E6),
      ),
      _StatData(
        label: 'Avg Progress',
        value: '$avgProgress%',
        icon: Icons.trending_up_rounded,
        color: const Color(0xFF9B59B6),
        bgColor: const Color(0xFFF5EEFF),
      ),
    ];

    if (isMobile) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.6,
        children: stats.map(_buildStatCard).toList(),
      );
    }

    return Row(
      children: stats
          .map((s) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: s == stats.last ? 0 : 14,
                  ),
                  child: _buildStatCard(s),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildStatCard(_StatData data) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: data.bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(data.icon, color: data.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  data.value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: data.color,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8E9BB5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Search bar ────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Container(
      width: 220,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE4E9F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: searchController,
        style: const TextStyle(fontSize: 13, color: Color(0xFF1A2340)),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
          hintText: 'Search projects...',
          hintStyle: const TextStyle(
            color: Color(0xFFB0BAC9),
            fontSize: 13,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFFB0BAC9),
            size: 18,
          ),
          suffixIcon: searchController.text.isNotEmpty
              ? GestureDetector(
                  onTap: () => searchController.clear(),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFFB0BAC9),
                    size: 16,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  // ── Projects body (admin only) ────────────────────────────────────────────

  Widget _buildProjectsBody(bool isMobile) {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: AppColors.primaryGreen,
              strokeWidth: 2.5,
            ),
            const SizedBox(height: 14),
            const Text(
              'Loading projects...',
              style: TextStyle(
                color: Color(0xFF8E9BB5),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(28),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F0),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: Color(0xFFE74C3C),
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Failed to load projects',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A2340),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF8E9BB5),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadDashboard,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (filteredProjects.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 52,
              color: Color(0xFFCDD2DD),
            ),
            const SizedBox(height: 12),
            const Text(
              'No projects found',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8E9BB5),
              ),
            ),
          ],
        ),
      );
    }

    if (isMobile) {
      return FadeTransition(
        opacity: _fadeAnimation,
        child: ListView.separated(
          itemCount:        filteredProjects.length,
          padding:          const EdgeInsets.only(bottom: 24),
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (_, i) => ProjectCard(
            project:   filteredProjects[i],
            onViewTap: () => _openProcessList(filteredProjects[i]),
          ),
        ),
      );
    }

    final crossCount = screenWidth(context) > 1400
        ? 4
        : screenWidth(context) > 1100
            ? 3
            : 2;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: GridView.builder(
        itemCount: filteredProjects.length,
        padding: const EdgeInsets.only(bottom: 24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:   crossCount,
          crossAxisSpacing: 16,
          mainAxisSpacing:  16,
          childAspectRatio: 0.95,
        ),
        itemBuilder: (_, i) => ProjectCard(
          project:   filteredProjects[i],
          onViewTap: () => _openProcessList(filteredProjects[i]),
        ),
      ),
    );
  }

  double screenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;
}

// ── Internal helper model ──────────────────────────────────────────────────

class _StatData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _StatData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
  });
}