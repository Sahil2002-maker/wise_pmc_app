// lib/features/project_list/presentation/pages/project_list_page.dart

import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/utils/api_exception.dart';
import '../../data/models/project_list_item_model.dart';
import 'add_project_page.dart';
import '../../../process_list/presentation/pages/process_list_page.dart';
import '../../../noc_map/presentation/pages/noc_map_page.dart';
import '../../../noc_analytics/presentation/pages/noc_analytics_dashboard_page.dart';

class ProjectListPage extends StatefulWidget {
  const ProjectListPage({super.key});

  @override
  State<ProjectListPage> createState() => _ProjectListPageState();
}

class _ProjectListPageState extends State<ProjectListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final searchController = TextEditingController();

  List<ProjectListItemModel> allProjects = [];
  bool isLoading = true;
  String? errorMessage;
  bool canAddProject = false;
  int currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() => currentTabIndex = _tabController.index);
    });
    loadProjects();
  }

  @override
  void dispose() {
    _tabController.dispose();
    searchController.dispose();
    super.dispose();
  }

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

  void _openProcessList(ProjectListItemModel item) {
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

  void _openNocMap(ProjectListItemModel item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NocMapPage(
          projectId: item.id,
          projectName: item.societyName,
        ),
      ),
    );
  }

  void _openNocAnalytics(ProjectListItemModel item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NocAnalyticsDashboardPage(),
      ),
    );
  }

  Future<void> _openProjectTypeSelector() async {
    final selectedType = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _ProjectTypeSelectorDialog(),
    );

    if (!mounted || selectedType == null) return;

    final created = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddProjectPage(initialProjectType: selectedType),
      ),
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

  List<ProjectListItemModel> _filteredProjects(String type) {
    final query = searchController.text.trim().toLowerCase();
    Iterable<ProjectListItemModel> list = allProjects;
    if (type == 'development') {
      list = list.where((p) => p.isDevelopment);
    } else if (type == 'redevelopment') {
      list = list.where((p) => p.isRedevelopment);
    }
    if (query.isNotEmpty) {
      list = list.where((p) => p.societyName.toLowerCase().contains(query));
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

  String _formatDate(String value) {
    if (value.isEmpty) return '-';
    try {
      final dt = DateTime.parse(value).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}-'
          '${dt.month.toString().padLeft(2, '0')}-'
          '${dt.year}';
    } catch (_) {
      return value;
    }
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  String _statusLabel(ProjectListItemModel item) =>
      item.status.isEmpty ? 'Pending' : _capitalize(item.status);

  Color _statusColor(ProjectListItemModel item) =>
      item.status.toLowerCase() == 'started'
          ? const Color(0xFF22C55E)
          : const Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : errorMessage != null
              ? _buildError()
              : _buildBody(),
    );
  }

  Widget _buildError() {
    return Center(
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
  }

  Widget _buildBody() {
    return CustomScrollView(
      slivers: [
        // ── Sliver App Bar ──────────────────────────────────────────────────
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
                                const Text(
                                  'Projects',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${allProjects.length} total projects',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.75),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                  ),
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
                                      color: Colors.black.withOpacity(0.15),
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
                                    const Text(
                                      'Add New',
                                      style: TextStyle(
                                        color: Color(0xFF166534),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
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

        // ── Stats Row ───────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Row(
              children: [
                _StatCard(
                  label: 'All',
                  count: allProjects.length,
                  color: const Color(0xFF3B82F6),
                  icon: Icons.folder_rounded,
                ),
                const SizedBox(width: 10),
                _StatCard(
                  label: 'Development',
                  count: allProjects.where((p) => p.isDevelopment).length,
                  color: const Color(0xFF8B5CF6),
                  icon: Icons.business_rounded,
                ),
                const SizedBox(width: 10),
                _StatCard(
                  label: 'Redevelop',
                  count: allProjects.where((p) => p.isRedevelopment).length,
                  color: const Color(0xFFF59E0B),
                  icon: Icons.construction_rounded,
                ),
              ],
            ),
          ),
        ),

        // ── Search + Tabs Card ──────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
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
                      controller: searchController,
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

        // ── Project List ────────────────────────────────────────────────────
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
                          onViewProcesses: () => _openProcessList(item),
                          onNocMap: () => _openNocMap(item),
                          onNocAnalytics: () => _openNocAnalytics(item),
                          onEdit: () => _editProject(item),
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

// ── Stat Card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
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
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              '$count',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -0.5),
            ),
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

// ── Project Card ──────────────────────────────────────────────────────────────

class _ProjectCard extends StatelessWidget {
  final ProjectListItemModel item;
  final int index;
  final String formattedDate;
  final String statusLabel;
  final Color statusColor;
  final bool canEdit;
  final VoidCallback onViewProcesses;
  final VoidCallback onNocMap;
  final VoidCallback onNocAnalytics;
  final VoidCallback onEdit;

  const _ProjectCard({
    required this.item,
    required this.index,
    required this.formattedDate,
    required this.statusLabel,
    required this.statusColor,
    required this.canEdit,
    required this.onViewProcesses,
    required this.onNocMap,
    required this.onNocAnalytics,
    required this.onEdit,
  });

  Color get _typeColor =>
      item.isRedevelopment ? const Color(0xFFF59E0B) : const Color(0xFF8B5CF6);

  String get _typeLabel =>
      item.isRedevelopment ? 'Redevelopment' : 'Development';

  IconData get _typeIcon =>
      item.isRedevelopment ? Icons.construction_rounded : Icons.business_rounded;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
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
            // Colored top accent bar
            Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _typeColor,
                    _typeColor.withOpacity(0.4),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
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
                              _typeColor.withOpacity(0.7),
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
                              fontSize: 18,
                            ),
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
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded,
                                    size: 11, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 4),
                                Text(
                                  formattedDate,
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: statusColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              statusLabel,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Type chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _typeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_typeIcon, size: 12, color: _typeColor),
                        const SizedBox(width: 5),
                        Text(
                          _typeLabel,
                          style: TextStyle(
                            color: _typeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 14),

                  // Action buttons
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
                      if (canEdit)
                        _ActionBtn(
                          label: 'Edit',
                          icon: Icons.edit_rounded,
                          color: const Color(0xFF6366F1),
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
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 13),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 13),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ── Project Type Selector Dialog ──────────────────────────────────────────────

class _ProjectTypeSelectorDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  colors: [Color(0xFF166534), Color(0xFF16A34A)],
                ),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Select Project Type',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
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
                    onTap: () => Navigator.pop(context, 'development'),
                  ),
                  const SizedBox(height: 14),
                  _TypeOptionCard(
                    title: 'Redevelopment',
                    subtitle:
                        'Register a redevelopment project for existing society',
                    icon: Icons.construction_rounded,
                    color: const Color(0xFFF59E0B),
                    onTap: () => Navigator.pop(context, 'redevelopment'),
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
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
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
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25), width: 1.5),
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
                  colors: [color, color.withOpacity(0.7)],
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
                color: color.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }
}