// lib/features/project_list/presentation/pages/project_list_page.dart

import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/auth_storage_service.dart';
import '../../../../core/utils/api_exception.dart';
import '../../data/models/project_list_item_model.dart';
import 'add_project_page.dart';
import '../../../process_list/presentation/pages/process_list_page.dart';
import '../../../noc_map/presentation/pages/noc_map_page.dart';
import '../../../noc_analytics/presentation/pages/noc_analytics_dashboard_page.dart';
import '../../../development_process/presentation/pages/development_process_page.dart';

// ─── Role helper ─────────────────────────────────────────────────────────────

Future<bool> _isTeamLeader() async {
  final role =
      (await AuthStorageService.getUserRole() ?? '').trim().toLowerCase();
  return role == 'teamleader' || role == 'team leader' || role == 'leader';
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class ProjectListPage extends StatefulWidget {
  const ProjectListPage({super.key});

  @override
  State<ProjectListPage> createState() => _ProjectListPageState();
}

class _ProjectListPageState extends State<ProjectListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();

  List<ProjectListItemModel> allProjects = [];
  bool isLoading = true;
  String? errorMessage;
  bool canAddProject = false;
  bool isTeamLeader = false;
  int currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() => currentTabIndex = _tabController.index);
    });
    _init();
  }

  Future<void> _init() async {
    final leaderFlag = await _isTeamLeader();
    setState(() => isTeamLeader = leaderFlag);
    await loadProjects();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> loadProjects() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
      final result = await ApiService.fetchProjectList();
      if (!mounted) return;
      setState(() {
        allProjects = result['projects'] as List<ProjectListItemModel>;
        canAddProject = result['canAddProject'] as bool;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e is ApiException ? e.message : e.toString();
        isLoading = false;
      });
    }
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _openProcessList(ProjectListItemModel item) {
    if (item.isDevelopment) {
      // Development projects → Development Process Page (stage-based)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DevelopmentProcessPage(
            projectId: item.id,
            projectName: item.societyName,
            projectStatus: item.status,
          ),
        ),
      );
    } else {
      // Redevelopment (NOC) projects → existing NOC process list
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProcessListPage(
            projectId: item.id,
            projectName: item.societyName,
          ),
        ),
      );
    }
  }

  void _openNocMap(ProjectListItemModel item) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              NocMapPage(projectId: item.id, projectName: item.societyName),
        ),
      );

  void _openNocAnalytics(ProjectListItemModel item) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NocAnalyticsDashboardPage()),
      );

  Future<void> _openProjectTypeSelector() async {
    final selectedType = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _ProjectTypeSelectorDialog(),
    );
    if (!mounted || selectedType == null) return;
    final created = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => AddProjectPage(initialProjectType: selectedType)),
    );
    if (created == true) await loadProjects();
  }

  Future<void> _editProject(ProjectListItemModel item) async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddProjectPage(
          initialProjectType: item.projectType,
          projectId: item.id,
          isEditMode: true,
        ),
      ),
    );
    if (updated == true) await loadProjects();
  }

  /// Opens the Assign Member bottom sheet (team leader only).
  /// FIX: awaits the sheet result so we can reload if an assignment was made.
  void _openAssignMember(ProjectListItemModel item) async {
    // showModalBottomSheet returns the value passed to Navigator.pop().
    // _AssignMemberSheet now pops with `true` on success so we know to reload.
    final assigned = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AssignMemberSheet(
        projectId: item.id,
        projectName: item.societyName,
      ),
    );

    // If assignment was successful, reload the list so the UI reflects
    // any changes (e.g. assignment badge or count updates).
    if (assigned == true && mounted) {
      await loadProjects();
    }
  }

  // ── Filter helpers ────────────────────────────────────────────────────────

  List<ProjectListItemModel> _filteredProjects(String type) {
    final q = _searchCtrl.text.trim().toLowerCase();
    Iterable<ProjectListItemModel> list = allProjects;
    if (type == 'development') list = list.where((p) => p.isDevelopment);
    if (type == 'redevelopment') list = list.where((p) => p.isRedevelopment);
    if (q.isNotEmpty) {
      list = list.where((p) => p.societyName.toLowerCase().contains(q));
    }
    return list.toList();
  }

  List<ProjectListItemModel> get _currentProjects {
    switch (currentTabIndex) {
      case 1:
        return _filteredProjects('development');
      case 2:
        return _filteredProjects('redevelopment');
      default:
        return _filteredProjects('all');
    }
  }

  // ── Formatting helpers ────────────────────────────────────────────────────

  String _formatDate(String v) {
    if (v.isEmpty) return '—';
    try {
      final dt = DateTime.parse(v).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}-'
          '${dt.month.toString().padLeft(2, '0')}-'
          '${dt.year}';
    } catch (_) {
      return v;
    }
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  String _statusLabel(ProjectListItemModel p) =>
      p.status.isEmpty ? 'Pending' : _capitalize(p.status);

  Color _statusColor(ProjectListItemModel p) =>
      p.status.toLowerCase() == 'started'
          ? const Color(0xFF22C55E)
          : const Color(0xFFF59E0B);

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(color: AppColors.primaryGreen))
          : errorMessage != null
              ? _buildError()
              : _buildBody(),
    );
  }

  // ── Error state ───────────────────────────────────────────────────────────

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(36),
                ),
                child: const Icon(Icons.wifi_off_rounded,
                    color: Color(0xFFEF4444), size: 36),
              ),
              const SizedBox(height: 20),
              const Text('Something went wrong',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B))),
              const SizedBox(height: 8),
              Text(errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFF64748B), fontSize: 14)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: loadProjects,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );

  // ── Main body ─────────────────────────────────────────────────────────────

  Widget _buildBody() {
    return CustomScrollView(
      slivers: [
        // ── App bar ──────────────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 140,
          floating: false,
          pinned: true,
          elevation: 0,
          backgroundColor: AppColors.primaryGreen,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF166534), Color(0xFF16A34A)],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Projects',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.5)),
                                const SizedBox(height: 4),
                                Text(
                                  '${allProjects.length} total projects',
                                  style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.75),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400),
                                ),
                              ],
                            ),
                          ),
                          if (canAddProject)
                            GestureDetector(
                              onTap: _openProjectTypeSelector,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryGreen,
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: const Icon(Icons.add,
                                          color: Colors.white, size: 16),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('Add New',
                                        style: TextStyle(
                                            color: Color(0xFF166534),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── Stats row ─────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Row(
              children: [
                _StatCard(
                    label: 'All',
                    count: allProjects.length,
                    color: const Color(0xFF3B82F6),
                    icon: Icons.folder_rounded),
                const SizedBox(width: 10),
                _StatCard(
                    label: 'Development',
                    count: allProjects
                        .where((p) => p.isDevelopment)
                        .length,
                    color: const Color(0xFF8B5CF6),
                    icon: Icons.business_rounded),
                const SizedBox(width: 10),
                _StatCard(
                    label: 'Redevelop',
                    count: allProjects
                        .where((p) => p.isRedevelopment)
                        .length,
                    color: const Color(0xFFF59E0B),
                    icon: Icons.construction_rounded),
              ],
            ),
          ),
        ),

        // ── Search + Tabs card ────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Tabs
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: AppColors.primaryGreen,
                      unselectedLabelColor: const Color(0xFF94A3B8),
                      indicatorColor: AppColors.primaryGreen,
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13),
                      unselectedLabelStyle: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 13),
                      tabs: const [
                        Tab(text: 'All'),
                        Tab(text: 'Development'),
                        Tab(text: 'Redevelopment'),
                      ],
                    ),
                  ),
                  // Search
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF1E293B)),
                      decoration: InputDecoration(
                        hintText: 'Search projects...',
                        hintStyle: const TextStyle(
                            color: Color(0xFF94A3B8), fontSize: 14),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: Color(0xFF94A3B8), size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0), width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.primaryGreen, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Team-leader badge ─────────────────────────────────────────────
        if (isTeamLeader)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF93C5FD), width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.verified_user_rounded,
                          color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Team Leader — tap "Assign" on any project to delegate it to a team member.',
                        style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1E40AF),
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── Project list ──────────────────────────────────────────────────
        _currentProjects.isEmpty
            ? SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(48),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: const Icon(Icons.folder_open_rounded,
                            color: Color(0xFFCBD5E1), size: 40),
                      ),
                      const SizedBox(height: 16),
                      const Text('No projects found',
                          style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 16,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              )
            : SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = _currentProjects[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _ProjectCard(
                          item: item,
                          index: index,
                          formattedDate: _formatDate(item.createdAt),
                          statusLabel: _statusLabel(item),
                          statusColor: _statusColor(item),
                          canEdit: canAddProject,
                          isTeamLeader: isTeamLeader,
                          onViewProcesses: () => _openProcessList(item),
                          onNocMap: () => _openNocMap(item),
                          onNocAnalytics: () => _openNocAnalytics(item),
                          onEdit: () => _editProject(item),
                          onAssignMember: () => _openAssignMember(item),
                        ),
                      );
                    },
                    childCount: _currentProjects.length,
                  ),
                ),
              ),
      ],
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _StatCard(
      {required this.label,
      required this.count,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 10),
            Text('$count',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: -0.5)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ─── Project Card ─────────────────────────────────────────────────────────────

class _ProjectCard extends StatelessWidget {
  final ProjectListItemModel item;
  final int index;
  final String formattedDate;
  final String statusLabel;
  final Color statusColor;
  final bool canEdit;
  final bool isTeamLeader;
  final VoidCallback onViewProcesses;
  final VoidCallback onNocMap;
  final VoidCallback onNocAnalytics;
  final VoidCallback onEdit;
  final VoidCallback onAssignMember;

  const _ProjectCard({
    required this.item,
    required this.index,
    required this.formattedDate,
    required this.statusLabel,
    required this.statusColor,
    required this.canEdit,
    required this.isTeamLeader,
    required this.onViewProcesses,
    required this.onNocMap,
    required this.onNocAnalytics,
    required this.onEdit,
    required this.onAssignMember,
  });

  Color get _typeColor =>
      item.isRedevelopment
          ? const Color(0xFFF59E0B)
          : const Color(0xFF8B5CF6);

  String get _typeLabel =>
      item.isRedevelopment ? 'Redevelopment' : 'Development';

  IconData get _typeIcon =>
      item.isRedevelopment
          ? Icons.construction_rounded
          : Icons.business_rounded;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colored accent bar
            Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_typeColor, _typeColor.withValues(alpha: 0.4)],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header row ──────────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              _typeColor,
                              _typeColor.withValues(alpha: 0.7)
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            item.societyName.isNotEmpty
                                ? item.societyName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Name + date
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.societyName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: Color(0xFF1E293B),
                                  letterSpacing: -0.2),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded,
                                    size: 11,
                                    color: Color(0xFF94A3B8)),
                                const SizedBox(width: 4),
                                Text(formattedDate,
                                    style: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Status badge
                      _StatusBadge(
                          label: statusLabel, color: statusColor),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── Type chip ────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _typeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_typeIcon, size: 12, color: _typeColor),
                        const SizedBox(width: 5),
                        Text(_typeLabel,
                            style: TextStyle(
                                color: _typeColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 14),

                  // ── Action buttons ───────────────────────────────────
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ActionBtn(
                        label: 'Processes',
                        icon: Icons.account_tree_rounded,
                        color: const Color(0xFF3B82F6),
                        onTap: onViewProcesses,
                      ),
                      _ActionBtn(
                        label: 'NOC Map',
                        icon: Icons.map_rounded,
                        color: const Color(0xFFF59E0B),
                        onTap: onNocMap,
                      ),
                      _ActionBtn(
                        label: 'Analytics',
                        icon: Icons.bar_chart_rounded,
                        color: const Color(0xFF10B981),
                        onTap: onNocAnalytics,
                      ),
                      // ── Assign Member (team leader only) ────────────
                      if (isTeamLeader)
                        _ActionBtn(
                          label: 'Assign',
                          icon: Icons.person_add_rounded,
                          color: const Color(0xFF6366F1),
                          onTap: onAssignMember,
                        ),
                      // ── Edit (admin only) ────────────────────────────
                      if (canEdit)
                        _ActionBtn(
                          label: 'Edit',
                          icon: Icons.edit_rounded,
                          color: const Color(0xFF64748B),
                          onTap: onEdit,
                          outlined: true,
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
}

// ─── Status Badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
                color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ─── Action Button ────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool outlined;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = outlined
        ? OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color.withValues(alpha: 0.5)),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          )
        : ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            elevation: 0,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          );

    final iconWidget = Icon(icon, size: 13);
    final labelWidget = Text(label);

    return outlined
        ? OutlinedButton.icon(
            onPressed: onTap,
            icon: iconWidget,
            label: labelWidget,
            style: style,
          )
        : ElevatedButton.icon(
            onPressed: onTap,
            icon: iconWidget,
            label: labelWidget,
            style: style,
          );
  }
}

// ─── Assign Member Bottom Sheet ───────────────────────────────────────────────

class _AssignMemberSheet extends StatefulWidget {
  final int projectId;
  final String projectName;

  const _AssignMemberSheet(
      {required this.projectId, required this.projectName});

  @override
  State<_AssignMemberSheet> createState() => _AssignMemberSheetState();
}

class _AssignMemberSheetState extends State<_AssignMemberSheet> {
  bool _loadingMembers = true;
  bool _assigning = false;
  String? _loadError;
  List<Map<String, dynamic>> _members = [];
  int? _selectedMemberId;
  String? _selectedMemberName;

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    setState(() {
      _loadingMembers = true;
      _loadError = null;
    });
    try {
      final body = await ApiService.getTeamMembersForAssignment();
      if (!mounted) return;
      setState(() {
        _members =
            (body['members'] as List<dynamic>? ?? [])
                .whereType<Map<String, dynamic>>()
                .toList();
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

  Future<void> _assign() async {
    if (_selectedMemberId == null) return;
    setState(() => _assigning = true);
    try {
      await ApiService.assignProjectToTeamMember(
        projectId: widget.projectId,
        memberId: _selectedMemberId!,
      );
      if (!mounted) return;

      // FIX: pop with `true` so the parent page knows to reload its list
      Navigator.pop(context, true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Project assigned to $_selectedMemberName successfully.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _assigning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : e.toString()),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      height: mq.size.height * 0.65,
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
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20)),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Assign Project',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        widget.projectName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context, false),
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),

          // Body
          Expanded(
            child: _loadingMembers
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF6366F1)))
                : _loadError != null
                    ? _buildError()
                    : _members.isEmpty
                        ? _buildEmpty()
                        : _buildMemberList(),
          ),

          // Footer button
          if (!_loadingMembers &&
              _loadError == null &&
              _members.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 12, 20, mq.padding.bottom + 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _selectedMemberId == null || _assigning
                          ? null
                          : _assign,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        const Color(0xFFE2E8F0),
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
                              strokeWidth: 2,
                              color: Colors.white),
                        )
                      : Text(
                          _selectedMemberId == null
                              ? 'Select a member first'
                              : 'Assign to $_selectedMemberName',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildError() => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(30)),
              child: const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFEF4444), size: 30),
            ),
            const SizedBox(height: 16),
            Text(_loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF64748B), fontSize: 13)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _fetchMembers,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6366F1)),
            ),
          ],
        ),
      );

  Widget _buildEmpty() => const Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_off_rounded,
                size: 48, color: Color(0xFFCBD5E1)),
            SizedBox(height: 12),
            Text('No team members found',
                style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: 6),
            Text(
              'No members are assigned to your team yet.\nContact your administrator.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Color(0xFFCBD5E1), fontSize: 13),
            ),
          ],
        ),
      );

  Widget _buildMemberList() => ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        itemCount: _members.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final m = _members[i];
          final id = (m['id'] as num?)?.toInt() ?? 0;
          final name = m['name']?.toString() ?? 'Member';
          final email = m['email']?.toString() ?? '';
          final isSelected = _selectedMemberId == id;

          return GestureDetector(
            onTap: () => setState(() {
              _selectedMemberId = id;
              _selectedMemberName = name;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFEEF2FF)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF6366F1)
                      : const Color(0xFFE2E8F0),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isSelected
                            ? const [
                                Color(0xFF6366F1),
                                Color(0xFF8B5CF6)
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
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: isSelected
                                    ? const Color(0xFF4338CA)
                                    : const Color(0xFF1E293B))),
                        if (email.isNotEmpty)
                          Text(email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w400)),
                      ],
                    ),
                  ),
                  // Check
                  if (isSelected)
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 14),
                    )
                  else
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: const Color(0xFFE2E8F0), width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
}

// ─── Project Type Selector Dialog ─────────────────────────────────────────────

class _ProjectTypeSelectorDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(22, 20, 16, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFF166534), Color(0xFF16A34A)]),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Select Project Type',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _TypeOptionCard(
                    title: 'Development',
                    subtitle:
                        'Register a brand new development project from scratch',
                    icon: Icons.business_rounded,
                    color: const Color(0xFF8B5CF6),
                    onTap: () =>
                        Navigator.pop(context, 'development'),
                  ),
                  const SizedBox(height: 14),
                  _TypeOptionCard(
                    title: 'Redevelopment',
                    subtitle:
                        'Register a redevelopment project for existing society',
                    icon: Icons.construction_rounded,
                    color: const Color(0xFFF59E0B),
                    onTap: () =>
                        Navigator.pop(context, 'redevelopment'),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(
                          color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TypeOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: color.withValues(alpha: 0.25), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, color.withValues(alpha: 0.7)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: color)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: color.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}