// lib/features/noc_map/presentation/pages/noc_map_page.dart

import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/utils/api_exception.dart';
import '../../data/models/noc_map_model.dart';
import 'noc_file_viewer_page.dart';   // ← new import (remove url_launcher import)

// ─── Palette ──────────────────────────────────────────────────────────────────
class _NocColors {
  static const primary    = Color(0xFF7367F0);
  static const completed  = Color(0xFF28C76F);
  static const inProgress = Color(0xFF00CFE8);
  static const pending    = Color(0xFFFF9F43);
  static const bgLight    = Color(0xFFF8F7FA);
  static const surface    = Colors.white;
  static const textDark   = Color(0xFF5E5873);
  static const textMuted  = Color(0xFF6E6B7B);
  static const border     = Color(0xFFEBE9F1);
}

class NocMapPage extends StatefulWidget {
  final int    projectId;
  final String projectName;

  const NocMapPage({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<NocMapPage> createState() => _NocMapPageState();
}

class _NocMapPageState extends State<NocMapPage>
    with SingleTickerProviderStateMixin {
  NocMapDataModel? _data;
  bool    _isLoading  = true;
  String? _error;

  String _activeFilter = 'all';
  final _searchCtrl    = TextEditingController();
  String _searchQuery  = '';

  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await ApiService.fetchNocMapData(widget.projectId);
      if (!mounted) return;
      setState(() { _data = data; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error     = e is ApiException ? e.message : e.toString();
        _isLoading = false;
      });
    }
  }

  List<NocProcessModel> get _filteredProcesses {
    if (_data == null) return [];
    Iterable<NocProcessModel> list = _data!.processes;
    if (_activeFilter != 'all') {
      const codeMap = {'completed': 2, 'in_progress': 1, 'not_started': 0};
      final code = codeMap[_activeFilter];
      if (code != null) list = list.where((p) => p.statusCode == code);
    }
    if (_searchQuery.isNotEmpty) {
      list = list.where((p) =>
          p.processName.toLowerCase().contains(_searchQuery.toLowerCase()));
    }
    return list.toList();
  }

  // ── Open file in-app ───────────────────────────────────────────────────────
  void _openFile(String rawUrl, String processName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NocFileViewerPage(
          url:   rawUrl,
          title: processName,
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _NocColors.bgLight,
      appBar: _buildAppBar(),
      body: _isLoading
          ? _buildLoader()
          : _error != null
              ? _buildError()
              : _buildBody(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: _NocColors.textDark, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('NOC Map',
              style: TextStyle(
                  color: _NocColors.textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          Text(widget.projectName,
              style: const TextStyle(
                  color: _NocColors.textMuted, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: _NocColors.primary),
          onPressed: _loadData,
          tooltip: 'Refresh',
        ),
      ],
      bottom: TabBar(
        controller: _tabCtrl,
        labelColor: _NocColors.primary,
        unselectedLabelColor: _NocColors.textMuted,
        indicatorColor: _NocColors.primary,
        indicatorWeight: 3,
        tabs: const [
          Tab(icon: Icon(Icons.list_rounded, size: 20), text: 'Process List'),
          Tab(icon: Icon(Icons.bar_chart_rounded, size: 20), text: 'Timeline'),
        ],
      ),
    );
  }

  Widget _buildLoader() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _NocColors.primary),
          SizedBox(height: 12),
          Text('Loading NOC Map…',
              style: TextStyle(color: _NocColors.textMuted, fontSize: 14)),
        ],
      ),
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
              width: 72, height: 72,
              decoration: BoxDecoration(
                  color: Colors.red.shade50, shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded,
                  color: Colors.red, size: 36),
            ),
            const SizedBox(height: 16),
            Text(_error ?? 'Something went wrong',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _NocColors.textDark, fontSize: 15)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _NocColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return TabBarView(
      controller: _tabCtrl,
      children: [_buildListTab(), _buildTimelineTab()],
    );
  }

  // ── List Tab ───────────────────────────────────────────────────────────────
  Widget _buildListTab() {
    return Column(
      children: [
        _buildSummaryCards(),
        _buildSearchAndFilter(),
        Expanded(child: _buildProcessList()),
      ],
    );
  }

  Widget _buildSummaryCards() {
    final s = _data!.summary;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _NocColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'NOC Order: ${s.orderRange}',
                  style: const TextStyle(
                      color: _NocColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _summaryCard('Total',   s.totalNocProcesses.toString(),
                  _NocColors.primary,    Icons.file_copy_rounded),
              const SizedBox(width: 8),
              _summaryCard('Done',    s.completedTasks.toString(),
                  _NocColors.completed,  Icons.check_circle_rounded),
              const SizedBox(width: 8),
              _summaryCard('Active',  s.assignedTasks.toString(),
                  _NocColors.inProgress, Icons.pending_actions_rounded),
              const SizedBox(width: 8),
              _summaryCard('Pending', s.pendingTasks.toString(),
                  _NocColors.pending,    Icons.hourglass_empty_rounded),
            ],
          ),
          const SizedBox(height: 12),
          _buildProgressBar(s.completionPercentage),
        ],
      ),
    );
  }

  Widget _summaryCard(
      String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
            Text(label,
                style: const TextStyle(
                    color: _NocColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(double pct) {
    Color barColor = _NocColors.pending;
    if (pct >= 75)      barColor = _NocColors.completed;
    else if (pct >= 50) barColor = Colors.orange;
    else if (pct >= 25) barColor = _NocColors.inProgress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Completion',
                style: TextStyle(
                    color: _NocColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
            Text('${pct.toStringAsFixed(1)}%',
                style: TextStyle(
                    color: barColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct / 100,
            backgroundColor: _NocColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          const Divider(height: 1, color: _NocColors.border),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search NOC processes…',
              hintStyle: const TextStyle(
                  color: _NocColors.textMuted, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: _NocColors.textMuted, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded,
                          color: _NocColors.textMuted, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      })
                  : null,
              filled: true,
              fillColor: _NocColors.bgLight,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('all',         'All',
                    Icons.grid_view_rounded),
                const SizedBox(width: 8),
                _filterChip('completed',   'Completed',
                    Icons.check_circle_rounded),
                const SizedBox(width: 8),
                _filterChip('in_progress', 'In Progress',
                    Icons.pending_actions_rounded),
                const SizedBox(width: 8),
                _filterChip('not_started', 'Not Started',
                    Icons.radio_button_unchecked_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String key, String label, IconData icon) {
    final isActive = _activeFilter == key;
    final color    = _statusColor(key);
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isActive ? color : color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14,
                color: isActive ? Colors.white : color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: isActive ? Colors.white : color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String filter) {
    switch (filter) {
      case 'completed':   return _NocColors.completed;
      case 'in_progress': return _NocColors.inProgress;
      case 'not_started': return _NocColors.pending;
      default:            return _NocColors.primary;
    }
  }

  Widget _buildProcessList() {
    final list = _filteredProcesses;
    if (list.isEmpty) {
      return _buildEmptyState(
        icon: Icons.search_off_rounded,
        title: 'No processes found',
        subtitle: _searchQuery.isNotEmpty
            ? 'Try a different search term'
            : 'No processes match the selected filter',
      );
    }
    return RefreshIndicator(
      color: _NocColors.primary,
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: list.length,
        itemBuilder: (ctx, i) => _buildProcessCard(list[i]),
      ),
    );
  }

  Widget _buildProcessCard(NocProcessModel p) {
    final statusColor = _processStatusColor(p.statusCode);
    final statusBg    = statusColor.withValues(alpha: 0.1);
    final statusIcon  = _processStatusIcon(p.statusCode);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _NocColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _NocColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _NocColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('#${p.orderNo}',
                      style: const TextStyle(
                          color: _NocColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(p.processName,
                      style: const TextStyle(
                          color: _NocColors.textDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(p.status,
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
            if (p.heading != null) ...[
              const SizedBox(height: 8),
              Text(p.heading!,
                  style: const TextStyle(
                      color: _NocColors.textMuted, fontSize: 11)),
            ],
            if (p.assignedUser != null ||
                p.assignDate != null ||
                p.uploadDate != null) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: _NocColors.border),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  if (p.assignedUser != null)
                    _infoChip(Icons.person_rounded,
                        p.assignedUser!.name, _NocColors.inProgress),
                  if (p.assignDate != null)
                    _infoChip(Icons.calendar_today_rounded,
                        p.assignDate!, _NocColors.textMuted),
                  if (p.uploadDate != null)
                    _infoChip(Icons.check_circle_outline_rounded,
                        p.uploadDate!, _NocColors.completed),
                ],
              ),
            ],
            // ── File button ──────────────────────────────────────────
            if (p.fileUrl != null) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _openFile(p.fileUrl!, p.processName), // ← updated
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _NocColors.completed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _NocColors.completed
                            .withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility_rounded,
                          size: 14, color: _NocColors.completed),
                      SizedBox(width: 6),
                      Text('View File',
                          style: TextStyle(
                              color: _NocColors.completed,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 11)),
      ],
    );
  }

  Color _processStatusColor(int code) {
    switch (code) {
      case 2:  return _NocColors.completed;
      case 1:  return _NocColors.inProgress;
      default: return _NocColors.pending;
    }
  }

  IconData _processStatusIcon(int code) {
    switch (code) {
      case 2:  return Icons.check_circle_rounded;
      case 1:  return Icons.pending_actions_rounded;
      default: return Icons.hourglass_empty_rounded;
    }
  }

  // ── Timeline Tab ───────────────────────────────────────────────────────────
  Widget _buildTimelineTab() {
    final assigned = _data?.processes
            .where((p) => p.statusCode > 0 && p.assignDate != null)
            .toList() ??
        [];

    if (assigned.isEmpty) {
      return _buildEmptyState(
        icon: Icons.bar_chart_rounded,
        title: 'No Timeline Data',
        subtitle: 'Assign NOC processes to see the timeline view. '
            'Processes with assign dates will appear here.',
      );
    }

    return RefreshIndicator(
      color: _NocColors.primary,
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _buildTimelineHeader(),
          const SizedBox(height: 16),
          ...assigned.asMap().entries.map((e) =>
              _buildTimelineItem(e.value, e.key, assigned.length)),
        ],
      ),
    );
  }

  Widget _buildTimelineHeader() {
    final s = _data!.summary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _NocColors.primary,
            _NocColors.primary.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('NOC Timeline',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  '${s.completedTasks} of ${s.totalNocProcesses} completed',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${s.completionPercentage.toStringAsFixed(1)}%',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(NocProcessModel p, int index, int total) {
    final isLast      = index == total - 1;
    final statusColor = _processStatusColor(p.statusCode);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: statusColor.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Icon(_processStatusIcon(p.statusCode),
                      size: 12, color: Colors.white),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: _NocColors.border,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _NocColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(p.processName,
                            style: const TextStyle(
                                color: _NocColors.textDark,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(p.status,
                            style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  if (p.assignedUser != null) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.person_outline_rounded,
                          size: 13, color: _NocColors.textMuted),
                      const SizedBox(width: 4),
                      Text(p.assignedUser!.name,
                          style: const TextStyle(
                              color: _NocColors.textMuted,
                              fontSize: 12)),
                    ]),
                  ],
                  if (p.assignDate != null || p.uploadDate != null) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      if (p.assignDate != null) ...[
                        const Icon(Icons.start_rounded,
                            size: 13, color: _NocColors.inProgress),
                        const SizedBox(width: 4),
                        Text(p.assignDate!,
                            style: const TextStyle(
                                color: _NocColors.inProgress,
                                fontSize: 11)),
                      ],
                      if (p.assignDate != null && p.uploadDate != null)
                        const SizedBox(width: 12),
                      if (p.uploadDate != null) ...[
                        const Icon(Icons.flag_rounded,
                            size: 13, color: _NocColors.completed),
                        const SizedBox(width: 4),
                        Text(p.uploadDate!,
                            style: const TextStyle(
                                color: _NocColors.completed,
                                fontSize: 11)),
                      ],
                    ]),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                  color: _NocColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: _NocColors.primary),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(
                    color: _NocColors.textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _NocColors.textMuted, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}