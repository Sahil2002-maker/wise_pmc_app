// lib/features/development_process/presentation/pages/dev_process_page.dart
//
// Main page for the Development Process module.
// Design: clean professional card layout matching the existing Re-Development
// Process page, with a blue accent (0xFF2563EB) distinguishing it.
//
// FIX (dart errors):
//   – _openEdit() passed p.stage (String) to initialStage (int) parameter.
//     Changed to p.stageNum (int).
//   – All .withOpacity() calls replaced with .withValues(alpha: …)
//     to silence dart(deprecated_member_use) warnings.

import 'package:flutter/material.dart';

import '../../../../core/services/api_service.dart';
import '../../../../core/utils/api_exception.dart';
import '../../data/models/dev_process_model.dart';
import '../widgets/dev_process_card.dart';
import '../widgets/dev_process_form_sheet.dart';

class DevProcessPage extends StatefulWidget {
  const DevProcessPage({super.key});

  @override
  State<DevProcessPage> createState() => _DevProcessPageState();
}

class _DevProcessPageState extends State<DevProcessPage>
    with SingleTickerProviderStateMixin {
  // ── Constants ─────────────────────────────────────────────────────────────
  static const Color _accent    = Color(0xFF2563EB);
  static const Color _accentEnd = Color(0xFF1D4ED8);

  static const List<_StageTab> _tabs = [
    _StageTab(stage: 0, label: 'Stage 0'),
    _StageTab(stage: 1, label: 'Stage 1'),
    _StageTab(stage: 2, label: 'Stage 2'),
    _StageTab(stage: 3, label: 'Stage 3'),
  ];

  // ── State ─────────────────────────────────────────────────────────────────
  late TabController _tabController;
  bool    _loading    = true;
  String? _error;
  int     _currentTab = 0;

  final Map<int, List<DevProcessModel>> _stageProcesses = {
    0: [], 1: [], 2: [], 3: [],
  };

  List<DevProcessTeamModel> _teams = [];

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  final Set<int> _deletingIds = {};

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging) {
          setState(() => _currentTab = _tabController.index);
        }
      });
    _searchCtrl.addListener(() {
      setState(() =>
          _searchQuery = _searchCtrl.text.toLowerCase().trim());
    });
    _init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await Future.wait([_loadTeams(), _loadAllStages()]);
  }

  Future<void> _loadTeams() async {
    try {
      final teams = await ApiService.fetchDevProcessTeams();
      if (mounted) setState(() => _teams = teams);
    } catch (_) {}
  }

  Future<void> _loadAllStages() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait(
        _tabs.map((t) => ApiService.fetchDevProcesses(stage: t.stage)),
      );
      if (mounted) {
        setState(() {
          for (int i = 0; i < _tabs.length; i++) {
            _stageProcesses[_tabs[i].stage] = results[i];
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error   = e is ApiException ? e.message : e.toString();
          _loading = false;
        });
      }
    }
  }

  // ── Derived data ──────────────────────────────────────────────────────────

  List<DevProcessModel> get _currentProcesses {
    final stage = _tabs[_currentTab].stage;
    final list  = _stageProcesses[stage] ?? [];
    if (_searchQuery.isEmpty) return list;
    return list
        .where((p) =>
            p.processName.toLowerCase().contains(_searchQuery) ||
            (p.teamName?.toLowerCase().contains(_searchQuery) ?? false))
        .toList();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _openAdd() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DevProcessFormSheet(
        teams:        _teams,
        initialStage: _tabs[_currentTab].stage,
      ),
    );
    if (ok == true && mounted) {
      await _loadAllStages();
      _toast('Process added successfully.', success: true);
    }
  }

  Future<void> _openEdit(DevProcessModel p) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DevProcessFormSheet(
        teams:        _teams,
        process:      p,
        // FIX: p.stage was String — use p.stageNum (int) instead.
        initialStage: p.stageNum,
      ),
    );
    if (ok == true && mounted) {
      await _loadAllStages();
      _toast('Process updated successfully.', success: true);
    }
  }

  Future<void> _confirmDelete(DevProcessModel p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteDialog(processName: p.processName),
    );
    if (ok != true || !mounted) return;

    setState(() => _deletingIds.add(p.processId));
    try {
      await ApiService.deleteDevProcess(p.processId);
      await _loadAllStages();
      if (mounted) _toast('Process deleted.', success: true);
    } catch (e) {
      if (mounted) {
        _toast(e is ApiException ? e.message : e.toString(), success: false);
      }
    } finally {
      if (mounted) setState(() => _deletingIds.remove(p.processId));
    }
  }

  void _toast(String msg, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            success
                ? Icons.check_circle_rounded
                : Icons.error_outline_rounded,
            color: Colors.white, size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ]),
        backgroundColor:
            success ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _accent))
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
                    width: 72, height: 72,
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
                    onPressed: _loadAllStages,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
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
        _buildList(),
      ],
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: _accent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          tooltip: 'Refresh',
          onPressed: _loadAllStages,
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ElevatedButton.icon(
            onPressed: _openAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _accent,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
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
              colors: [_accent, _accentEnd],
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
                    'Development Process',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage development workflows across stages',
                    style: TextStyle(
                      // FIX: withOpacity → withValues
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12,
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

  // ── Search bar ────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: 'Search processes or teams…',
          hintStyle:
              const TextStyle(color: Color(0xFFB0BAC9), fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded,
              color: _accent, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      color: Color(0xFF94A3B8), size: 18),
                  onPressed: () => _searchCtrl.clear(),
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFF8FAFF),
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
            borderSide: const BorderSide(color: _accent, width: 1.5),
          ),
        ),
      ),
    );
  }

  // ── Tab bar ───────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: _accent,
        unselectedLabelColor: const Color(0xFF94A3B8),
        indicatorColor: _accent,
        indicatorWeight: 3,
        labelStyle: const TextStyle(
            fontWeight: FontWeight.w700, fontSize: 11),
        unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500, fontSize: 11),
        tabs: _tabs.asMap().entries.map((entry) {
          final i     = entry.key;
          final tab   = entry.value;
          final count = _stageProcesses[tab.stage]?.length ?? 0;
          return Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tab.label),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _currentTab == i
                        ? _accent
                        : const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _currentTab == i
                          ? Colors.white
                          : _accent,
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

  // ── Stage stats banner ────────────────────────────────────────────────────

  Widget _buildStageStats() {
    final list     = _stageProcesses[_tabs[_currentTab].stage] ?? [];
    final withTeam = list.where((p) => p.teamName != null).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_accent, _accentEnd],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            // FIX: withOpacity → withValues
            color: _accent.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _Stat(icon: Icons.layers_rounded,
              label: 'Total', value: '${list.length}'),
          _StatDivider(),
          _Stat(icon: Icons.group_rounded,
              label: 'With Team', value: '$withTeam'),
          _StatDivider(),
          _Stat(
            icon: Icons.format_list_numbered_rounded,
            label: 'Stage',
            value: 'Stage ${_tabs[_currentTab].stage}',
          ),
        ],
      ),
    );
  }

  // ── Process list ──────────────────────────────────────────────────────────

  Widget _buildList() {
    final list = _currentProcesses;

    if (list.isEmpty) {
      return SliverToBoxAdapter(
        child: _EmptyState(
          hasSearch: _searchQuery.isNotEmpty,
          onAdd: _openAdd,
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DevProcessCard(
              process:    list[i],
              serialNo:   i + 1,
              isDeleting: _deletingIds.contains(list[i].processId),
              onEdit:     () => _openEdit(list[i]),
              onDelete:   () => _confirmDelete(list[i]),
            ),
          ),
          childCount: list.length,
        ),
      ),
    );
  }
}

// ─── Stage tab metadata ───────────────────────────────────────────────────────

class _StageTab {
  final int stage;
  final String label;
  const _StageTab({required this.stage, required this.label});
}

// ─── Stat pill ────────────────────────────────────────────────────────────────

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Stat({required this.icon, required this.label, required this.value});

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
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        width: 1, height: 36,
        // FIX: withOpacity → withValues
        color: Colors.white.withValues(alpha: 0.25));
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
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Icon(
              hasSearch
                  ? Icons.search_off_rounded
                  : Icons.account_tree_outlined,
              color: const Color(0xFFCBD5E1), size: 40,
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
            style: const TextStyle(
                color: Color(0xFF94A3B8), fontSize: 12),
            textAlign: TextAlign.center,
          ),
          if (!hasSearch) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add Process'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
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

// ─── Delete dialog ────────────────────────────────────────────────────────────

class _DeleteDialog extends StatelessWidget {
  final String processName;
  const _DeleteDialog({required this.processName});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Color(0xFFEF4444), size: 22),
          SizedBox(width: 8),
          Text('Delete Process',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700)),
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
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B)),
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