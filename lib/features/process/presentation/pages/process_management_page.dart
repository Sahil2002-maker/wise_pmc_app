// lib/features/process/presentation/pages/process_management_page.dart

import 'package:flutter/material.dart';

import '../../../../core/services/api_service.dart';
import '../../../../core/utils/api_exception.dart';
import '../../data/models/process_model.dart';
import '../widgets/process_card.dart';
import '../widgets/process_form_sheet.dart';
import '../widgets/process_team_sheet.dart';

class ProcessManagementPage extends StatefulWidget {
  const ProcessManagementPage({super.key});

  @override
  State<ProcessManagementPage> createState() => _ProcessManagementPageState();
}

class _ProcessManagementPageState extends State<ProcessManagementPage>
    with SingleTickerProviderStateMixin {
  // ── Tabs ──────────────────────────────────────────────────────────────────
  late TabController _tabController;

  static const List<_StageTab> _tabs = [
    _StageTab(key: 'pmc_application', label: 'PMC Application'),
    _StageTab(key: 'stage1', label: 'Stage 1'),
    _StageTab(key: 'stage2', label: 'Stage 2'),
    _StageTab(key: 'stage3', label: 'Stage 3'),
  ];

  // ── State ─────────────────────────────────────────────────────────────────
  bool _loading = true;
  String? _error;
  int _currentTab = 0;

  final Map<String, List<ProcessModel>> _stageProcesses = {
    'pmc_application': [],
    'stage1': [],
    'stage2': [],
    'stage3': [],
  };

  List<ProcessTeamModel> _teams = [];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final Set<int> _deletingOrderNos = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _currentTab = _tabController.index);
      }
    });
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase().trim());
    });
    _init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await Future.wait([_loadTeams(), _loadAllProcesses()]);
  }

  Future<void> _loadTeams() async {
    try {
      final teams = await ApiService.fetchProcessTeams();
      if (mounted) setState(() => _teams = teams);
    } catch (_) {}
  }

  Future<void> _loadAllProcesses() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait(
        _tabs.map((t) => ApiService.fetchProcesses(stage: t.key)),
      );
      if (mounted) {
        setState(() {
          for (int i = 0; i < _tabs.length; i++) {
            _stageProcesses[_tabs[i].key] = results[i];
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiException ? e.message : e.toString();
          _loading = false;
        });
      }
    }
  }

  List<ProcessModel> get _currentProcesses {
    final key = _tabs[_currentTab].key;
    final list = _stageProcesses[key] ?? [];
    if (_searchQuery.isEmpty) return list;
    return list
        .where((p) =>
            p.processName.toLowerCase().contains(_searchQuery) ||
            (p.workingTeamName?.toLowerCase().contains(_searchQuery) ?? false) ||
            (p.reviewTeamName?.toLowerCase().contains(_searchQuery) ?? false))
        .toList();
  }

  Future<void> _openAddSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProcessFormSheet(
        teams: _teams,
        initialStage: _tabs[_currentTab].key,
      ),
    );
    if (result == true && mounted) {
      await _loadAllProcesses();
      _showSuccessSnackBar('Process added successfully.');
    }
  }

  Future<void> _openEditSheet(ProcessModel process) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProcessFormSheet(
        teams: _teams,
        process: process,
        initialStage: process.stage,
      ),
    );
    if (result == true && mounted) {
      await _loadAllProcesses();
      _showSuccessSnackBar('Process updated successfully.');
    }
  }

  Future<void> _confirmDelete(ProcessModel process) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeleteDialog(processName: process.processName),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingOrderNos.add(process.orderNo));
    try {
      await ApiService.deleteProcess(process.orderNo);
      await _loadAllProcesses();
      if (mounted) _showSuccessSnackBar('Process deleted successfully.');
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(e is ApiException ? e.message : e.toString());
      }
    } finally {
      if (mounted) setState(() => _deletingOrderNos.remove(process.orderNo));
    }
  }

  Future<void> _openTeamSheet(ProcessModel process) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProcessTeamSheet(
        process: process,
        teams: _teams,
      ),
    );
    if (result == true && mounted) {
      await _loadAllProcesses();
      _showSuccessSnackBar('Review team updated successfully.');
    }
  }

  void _showSuccessSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(msg,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(msg,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF5E50EE)))
          : _error != null
              ? _buildError()
              : _buildBody(),
    );
  }

  Widget _buildError() {
    return CustomScrollView(
      slivers: [
        _buildAppBar(),
        SliverFillRemaining(
          child: Center(
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
                    child: const Icon(Icons.error_outline_rounded,
                        color: Color(0xFFEF4444), size: 36),
                  ),
                  const SizedBox(height: 20),
                  const Text('Failed to load processes',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B))),
                  const SizedBox(height: 8),
                  Text(_error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Color(0xFF64748B), fontSize: 13)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _loadAllProcesses,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5E50EE),
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
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return CustomScrollView(
      slivers: [
        _buildAppBar(),
        SliverToBoxAdapter(child: _buildSearchBar()),
        SliverToBoxAdapter(child: _buildTabBar()),
        SliverToBoxAdapter(child: _buildStageStats()),
        _buildProcessList(),
      ],
    );
  }

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF5E50EE),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          tooltip: 'Refresh',
          onPressed: _loadAllProcesses,
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ElevatedButton.icon(
            onPressed: _openAddSheet,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF5E50EE),
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4338CA), Color(0xFF5E50EE)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(56, 12, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'Process Management',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Re-Development workflows across stages',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search processes, teams…',
          hintStyle:
              const TextStyle(color: Color(0xFFB0BAC9), fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded,
              color: Color(0xFF5E50EE), size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      color: Color(0xFF94A3B8), size: 18),
                  onPressed: () => _searchController.clear(),
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFF8F9FF),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE8EAFF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE8EAFF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Color(0xFF5E50EE), width: 1.5),
          ),
        ),
      ),
    );
  }

  // ── Tab bar — FIX: isScrollable + tabAlignment to prevent RenderFlex overflow
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,              // ← FIX: tabs scroll instead of squishing
        tabAlignment: TabAlignment.start, // ← keeps them left-aligned
        labelColor: const Color(0xFF5E50EE),
        unselectedLabelColor: const Color(0xFF94A3B8),
        indicatorColor: const Color(0xFF5E50EE),
        indicatorWeight: 3,
        labelStyle:
            const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
        tabs: _tabs.asMap().entries.map((entry) {
          final i = entry.key;
          final tab = entry.value;
          final count = _stageProcesses[tab.key]?.length ?? 0;
          return Tab(
            child: Row(                   // ← Row instead of Column to save vertical space
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tab.label),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _currentTab == i
                        ? const Color(0xFF5E50EE)
                        : const Color(0xFFE8EAFF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _currentTab == i
                          ? Colors.white
                          : const Color(0xFF5E50EE),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStageStats() {
    final list = _stageProcesses[_tabs[_currentTab].key] ?? [];
    final withDeadline = list.where((p) => p.day != null && p.day! > 0).length;
    final withTeam = list.where((p) => p.workingTeam != null).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5E50EE), Color(0xFF7C6FFF)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5E50EE).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _StatPill(
              icon: Icons.layers_rounded,
              label: 'Total',
              value: '${list.length}'),
          const _StatDivider(),
          _StatPill(
              icon: Icons.group_rounded,
              label: 'With Team',
              value: '$withTeam'),
          const _StatDivider(),
          _StatPill(
              icon: Icons.timer_rounded,
              label: 'With Deadline',
              value: '$withDeadline'),
        ],
      ),
    );
  }

  Widget _buildProcessList() {
    final list = _currentProcesses;

    if (list.isEmpty) {
      return SliverToBoxAdapter(
        child: _EmptyState(
          hasSearch: _searchQuery.isNotEmpty,
          onAdd: _openAddSheet,
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final process = list[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ProcessCard(
                process: process,
                serialNo: index + 1,
                stageKey: _tabs[_currentTab].key,
                isDeleting: _deletingOrderNos.contains(process.orderNo),
                onEdit: () => _openEditSheet(process),
                onDelete: () => _confirmDelete(process),
                onTeam: () => _openTeamSheet(process),
              ),
            );
          },
          childCount: list.length,
        ),
      ),
    );
  }
}

// ─── Stage tab metadata ───────────────────────────────────────────────────────

class _StageTab {
  final String key;
  final String label;
  const _StageTab({required this.key, required this.label});
}

// ─── Stat pill ────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white70, size: 13),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();
  @override
  Widget build(BuildContext context) {
    return Container(
        width: 1, height: 36, color: Colors.white.withValues(alpha: 0.25));
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  final VoidCallback onAdd;
  const _EmptyState({required this.hasSearch, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Icon(
              hasSearch ? Icons.search_off_rounded : Icons.inbox_rounded,
              color: const Color(0xFFCBD5E1),
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasSearch ? 'No results found' : 'No processes yet',
            style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 15,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            hasSearch
                ? 'Try a different search term.'
                : 'Tap "Add" to create the first process.',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            textAlign: TextAlign.center,
          ),
          if (!hasSearch) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add Process'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5E50EE),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Delete confirmation dialog ───────────────────────────────────────────────

class _DeleteDialog extends StatelessWidget {
  final String processName;
  const _DeleteDialog({required this.processName});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Color(0xFFEF4444), size: 22),
          SizedBox(width: 8),
          Text('Delete Process',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
      content: RichText(
        text: TextSpan(
          style: const TextStyle(
              color: Color(0xFF475569), fontSize: 13, height: 1.5),
          children: [
            const TextSpan(text: 'Are you sure you want to delete '),
            TextSpan(
              text: '"$processName"',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
            ),
            const TextSpan(text: '? This action cannot be undone.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel',
              style: TextStyle(color: Color(0xFF64748B))),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Delete',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}