// lib/features/noc_analytics/presentation/pages/noc_analytics_detail_page.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/utils/api_exception.dart';
import '../../data/models/noc_analytics_model.dart';

// Re-use design tokens
class _AC {
  static const primary    = Color(0xFF7367F0);
  static const secondary  = Color(0xFF764BA2);
  static const completed  = Color(0xFF28C76F);
  static const assigned   = Color(0xFF00CFE8);
  static const pending    = Color(0xFFFF9F43);
  static const bgLight    = Color(0xFFF8F7FA);
  static const surface    = Colors.white;
  static const textDark   = Color(0xFF5E5873);
  static const textMuted  = Color(0xFF6E6B7B);
  static const border     = Color(0xFFEBE9F1);
}

class NocAnalyticsDetailPage extends StatefulWidget {
  final int    projectId;
  final String projectName;

  const NocAnalyticsDetailPage({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<NocAnalyticsDetailPage> createState() =>
      _NocAnalyticsDetailPageState();
}

class _NocAnalyticsDetailPageState
    extends State<NocAnalyticsDetailPage> {
  // ── State ──────────────────────────────────────────────────────────────────
  NocAnalyticsDetailModel?       _detail;
  List<NocGroupedSectionModel>   _sections  = [];
  bool   _isLoading   = true;
  String? _error;

  // Section collapse state
  final Map<String, bool> _sectionExpanded = {};

  // Active status filter
  String _activeFilter = 'all'; // all | completed | assigned | pending

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final results = await Future.wait([
        ApiService.fetchNocAnalyticsDetail(widget.projectId),
        ApiService.fetchNocGroupedByHeading(widget.projectId),
      ]);
      if (!mounted) return;
      final detail   = results[0] as NocAnalyticsDetailModel;
      final sections = results[1] as List<NocGroupedSectionModel>;

      // Default all sections expanded
      final expanded = <String, bool>{};
      for (final s in sections) {
        expanded[s.heading] = true;
      }

      setState(() {
        _detail   = detail;
        _sections = sections;
        _sectionExpanded.addAll(expanded);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error     = e is ApiException ? e.message : e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AC.bgLight,
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
            color: _AC.textDark, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('NOC Analytics',
              style: TextStyle(
                  color: _AC.textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          Text(widget.projectName,
              style: const TextStyle(
                  color: _AC.textMuted, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: _AC.primary),
          onPressed: _loadData,
        ),
      ],
    );
  }

  Widget _buildLoader() => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _AC.primary),
            SizedBox(height: 12),
            Text('Loading Analytics…',
                style: TextStyle(color: _AC.textMuted, fontSize: 14)),
          ],
        ),
      );

  Widget _buildError() => Center(
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
                  style: const TextStyle(color: _AC.textDark, fontSize: 15)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _AC.primary,
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

  Widget _buildBody() {
    return RefreshIndicator(
      color: _AC.primary,
      onRefresh: _loadData,
      child: CustomScrollView(
        slivers: [
          // Project header
          SliverToBoxAdapter(child: _buildProjectHeader()),
          // Stat cards
          SliverToBoxAdapter(child: _buildStatCards()),
          // Charts row
          SliverToBoxAdapter(child: _buildChartsRow()),
          // Status breakdown
          SliverToBoxAdapter(child: _buildBreakdownCard()),
          // NOC List section header + filter
          SliverToBoxAdapter(child: _buildListHeader()),
          // Sections
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _buildSection(_visibleSections[i]),
              childCount: _visibleSections.length,
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }

  // ── Project header card ────────────────────────────────────────────────────
  Widget _buildProjectHeader() {
    final proj = _detail!.project;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_AC.primary, _AC.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: _AC.primary.withValues(alpha: 0.3),
              blurRadius: 14,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.apartment_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(proj.societyName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                if (proj.address != null && proj.address!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 12, color: Colors.white70),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(proj.address!,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Stat cards row ─────────────────────────────────────────────────────────
  Widget _buildStatCards() {
    final a = _detail!.analytics;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          _miniStatCard('Total', a.totalNocs, _AC.primary,
              Icons.file_copy_rounded),
          const SizedBox(width: 8),
          _miniStatCard('Done', a.completedNocs, _AC.completed,
              Icons.check_circle_rounded),
          const SizedBox(width: 8),
          _miniStatCard('Active', a.assignedNocs, _AC.assigned,
              Icons.pending_actions_rounded),
          const SizedBox(width: 8),
          _miniStatCard('Pending', a.pendingNocs, _AC.pending,
              Icons.hourglass_empty_rounded),
        ],
      ),
    );
  }

  Widget _miniStatCard(
      String label, int value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 5),
            Text('$value',
                style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
            Text(label,
                style: const TextStyle(
                    color: _AC.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // ── Charts row ─────────────────────────────────────────────────────────────
  Widget _buildChartsRow() {
    final a   = _detail!.analytics;
    final pct = a.completionPercentage;
    Color barColor = _AC.pending;
    String statusLabel = 'Not Started';
    if (pct >= 75)       { barColor = _AC.completed; statusLabel = 'On Track'; }
    else if (pct >= 50)  { barColor = Colors.orange;  statusLabel = 'In Progress'; }
    else if (pct > 0)    { barColor = _AC.assigned;   statusLabel = 'Started'; }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          // Circular progress
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _AC.border),
              ),
              child: Column(
                children: [
                  const Text('Progress',
                      style: TextStyle(
                          color: _AC.textDark,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: 100, height: 100,
                    child: CustomPaint(
                      painter: _CircularProgressPainter(
                          percentage: pct, color: barColor),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${pct.toStringAsFixed(1)}%',
                                style: TextStyle(
                                    color: barColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800)),
                            Text('done',
                                style: const TextStyle(
                                    color: _AC.textMuted,
                                    fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: barColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(statusLabel,
                        style: TextStyle(
                            color: barColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Donut chart
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _AC.border),
              ),
              child: Column(
                children: [
                  const Text('Distribution',
                      style: TextStyle(
                          color: _AC.textDark,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 90, height: 90,
                    child: CustomPaint(
                      painter: _DonutChartPainter(
                        completed: a.completedNocs,
                        assigned:  a.assignedNocs,
                        pending:   a.pendingNocs,
                        total:     a.totalNocs,
                      ),
                      child: Center(
                        child: Text('${a.totalNocs}',
                            style: const TextStyle(
                                color: _AC.textDark,
                                fontSize: 14,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Mini legend
                  Column(
                    children: [
                      _legendRow(_AC.completed, 'Completed', a.completedNocs),
                      const SizedBox(height: 3),
                      _legendRow(_AC.assigned,  'Assigned',  a.assignedNocs),
                      const SizedBox(height: 3),
                      _legendRow(_AC.pending,   'Pending',   a.pendingNocs),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendRow(Color color, String label, int count) {
    return Row(
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  color: _AC.textMuted, fontSize: 10)),
        ),
        Text('$count',
            style: const TextStyle(
                color: _AC.textDark,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      ],
    );
  }

  // ── Breakdown card ─────────────────────────────────────────────────────────
  Widget _buildBreakdownCard() {
    final a = _detail!.analytics;
    final total = a.totalNocs;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _AC.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Status Breakdown',
                style: TextStyle(
                    color: _AC.textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            _breakdownRow(_AC.completed, 'Completed',
                a.completedNocs, total),
            const SizedBox(height: 10),
            _breakdownRow(_AC.assigned, 'Assigned (In Progress)',
                a.assignedNocs, total),
            const SizedBox(height: 10),
            _breakdownRow(_AC.pending, 'Pending (Not Started)',
                a.pendingNocs, total),
            const SizedBox(height: 14),
            const Divider(height: 1, color: _AC.border),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Completion Rate',
                    style: TextStyle(
                        color: _AC.textMuted, fontSize: 12)),
                Text('${a.completionPercentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                        color: _AC.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _breakdownRow(Color color, String label, int count, int total) {
    final pct = total > 0 ? count / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 14, height: 14,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: _AC.textDark, fontSize: 12)),
            ),
            Text('$count',
                style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Text('(${(pct * 100).toStringAsFixed(1)}%)',
                style: const TextStyle(
                    color: _AC.textMuted, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: _AC.border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ── NOC list header + filter ───────────────────────────────────────────────
  Widget _buildListHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Detailed NOC List',
              style: TextStyle(
                  color: _AC.textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          const Text('Grouped by category  ·  Order No. 128–189',
              style: TextStyle(color: _AC.textMuted, fontSize: 11)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterBtn('all',       'All'),
                const SizedBox(width: 8),
                _filterBtn('completed', 'Completed'),
                const SizedBox(width: 8),
                _filterBtn('assigned',  'Assigned'),
                const SizedBox(width: 8),
                _filterBtn('pending',   'Pending'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterBtn(String key, String label) {
    final isActive = _activeFilter == key;
    final color    = _filterColor(key);
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isActive ? color : color.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: TextStyle(
                color: isActive ? Colors.white : color,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  Color _filterColor(String key) {
    switch (key) {
      case 'completed': return _AC.completed;
      case 'assigned':  return _AC.assigned;
      case 'pending':   return _AC.pending;
      default:          return _AC.primary;
    }
  }

  List<NocGroupedSectionModel> get _visibleSections {
    if (_activeFilter == 'all') return _sections;
    return _sections.map((s) {
      final filtered = s.processes.where((p) {
        switch (_activeFilter) {
          case 'completed': return p.statusCode == 2;
          case 'assigned':  return p.statusCode == 1;
          case 'pending':   return p.statusCode == 0;
          default:          return true;
        }
      }).toList();
      return NocGroupedSectionModel(
          heading: s.heading, count: filtered.length, processes: filtered);
    }).where((s) => s.processes.isNotEmpty).toList();
  }

  // ── Section widget ─────────────────────────────────────────────────────────
  Widget _buildSection(NocGroupedSectionModel section) {
    final isExpanded = _sectionExpanded[section.heading] ?? true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _AC.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header (collapsible)
            GestureDetector(
              onTap: () => setState(() =>
                  _sectionExpanded[section.heading] = !isExpanded),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _AC.bgLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    AnimatedRotation(
                      turns: isExpanded ? 0 : -0.25,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.expand_more_rounded,
                          color: _AC.textMuted, size: 20),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(section.heading,
                          style: const TextStyle(
                              color: _AC.textDark,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_AC.primary, _AC.secondary],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text('${section.count} NOCs',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
            // Process items
            AnimatedCrossFade(
              firstChild: Column(
                children: section.processes
                    .map(_buildProcessRow)
                    .toList(),
              ),
              secondChild: const SizedBox.shrink(),
              crossFadeState: isExpanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessRow(NocGroupedProcessModel p) {
    final color  = _statusColor(p.statusCode);
    final icon   = _statusIcon(p.statusCode);
    final isLast = _sections
        .expand((s) => s.processes)
        .last.processId == p.processId;

    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: _AC.border, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order badge
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: _AC.bgLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('#${p.orderNo}',
                style: const TextStyle(
                    color: _AC.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          // Name + details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.processName,
                    style: const TextStyle(
                        color: _AC.textDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                if (p.assignedUser != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded,
                          size: 11, color: _AC.textMuted),
                      const SizedBox(width: 4),
                      Text(p.assignedUser!,
                          style: const TextStyle(
                              color: _AC.textMuted, fontSize: 11)),
                      if (p.assignDate != null) ...[
                        const SizedBox(width: 10),
                        const Icon(Icons.calendar_today_rounded,
                            size: 11, color: _AC.textMuted),
                        const SizedBox(width: 4),
                        Text(p.assignDate!,
                            style: const TextStyle(
                                color: _AC.textMuted, fontSize: 11)),
                      ],
                    ],
                  ),
                ],
                if (p.completionDate != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded,
                          size: 11, color: _AC.completed),
                      const SizedBox(width: 4),
                      Text(p.completionDate!,
                          style: const TextStyle(
                              color: _AC.completed, fontSize: 11)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 10, color: color),
                const SizedBox(width: 4),
                Text(p.status,
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(int code) {
    switch (code) {
      case 2:  return _AC.completed;
      case 1:  return _AC.assigned;
      default: return _AC.pending;
    }
  }

  IconData _statusIcon(int code) {
    switch (code) {
      case 2:  return Icons.check_circle_rounded;
      case 1:  return Icons.pending_actions_rounded;
      default: return Icons.hourglass_empty_rounded;
    }
  }
}

// ─── Circular progress painter ────────────────────────────────────────────────
class _CircularProgressPainter extends CustomPainter {
  final double percentage;
  final Color  color;

  const _CircularProgressPainter({
    required this.percentage,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx    = size.width / 2;
    final cy    = size.height / 2;
    final r     = math.min(cx, cy) - 8;
    final rect  = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    const stroke = 10.0;

    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi,
      false,
      Paint()
        ..style      = PaintingStyle.stroke
        ..strokeWidth= stroke
        ..color      = const Color(0xFFEBE9F1),
    );

    final sweep = 2 * math.pi * (percentage / 100).clamp(0.0, 1.0);
    if (sweep > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style      = PaintingStyle.stroke
          ..strokeWidth= stroke
          ..strokeCap  = StrokeCap.round
          ..color      = color,
      );
    }
  }

  @override
  bool shouldRepaint(_CircularProgressPainter old) =>
      old.percentage != percentage || old.color != color;
}

// ─── Donut chart painter ──────────────────────────────────────────────────────
class _DonutChartPainter extends CustomPainter {
  final int completed;
  final int assigned;
  final int pending;
  final int total;

  const _DonutChartPainter({
    required this.completed,
    required this.assigned,
    required this.pending,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx     = size.width / 2;
    final cy     = size.height / 2;
    final r      = math.min(cx, cy);
    final stroke = r * 0.38;
    final rect   = Rect.fromCircle(
        center: Offset(cx, cy), radius: r - stroke / 2);

    final bg = Paint()
      ..style      = PaintingStyle.stroke
      ..strokeWidth= stroke
      ..color      = const Color(0xFFEBE9F1);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi, false, bg);

    if (total == 0) return;

    final paint = Paint()
      ..style      = PaintingStyle.stroke
      ..strokeWidth= stroke
      ..strokeCap  = StrokeCap.butt;

    double startAngle = -math.pi / 2;
    final data = [
      (completed, const Color(0xFF28C76F)),
      (assigned,  const Color(0xFF00CFE8)),
      (pending,   const Color(0xFFFF9F43)),
    ];
    for (final (count, color) in data) {
      if (count == 0) continue;
      final sweep = 2 * math.pi * count / total;
      paint.color = color;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutChartPainter old) =>
      old.completed != completed ||
      old.assigned  != assigned  ||
      old.pending   != pending;
}