// lib/features/noc_analytics/presentation/pages/noc_analytics_dashboard_page.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/utils/api_exception.dart';
import '../../data/models/noc_analytics_model.dart';
import 'noc_analytics_detail_page.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
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

class NocAnalyticsDashboardPage extends StatefulWidget {
  const NocAnalyticsDashboardPage({super.key});

  @override
  State<NocAnalyticsDashboardPage> createState() =>
      _NocAnalyticsDashboardPageState();
}

class _NocAnalyticsDashboardPageState
    extends State<NocAnalyticsDashboardPage> {
  // ── State ──────────────────────────────────────────────────────────────────
  NocOverallStatsModel?        _overallStats;
  List<NocProjectSummaryModel> _projects     = [];
  List<NocProjectSummaryModel> _filtered     = [];
  bool   _isLoading  = true;
  String? _error;
  final _searchCtrl  = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final results = await Future.wait([
        ApiService.fetchNocOverallStats(),
        ApiService.fetchNocAnalyticsProjects(),
      ]);
      if (!mounted) return;
      final stats    = results[0] as NocOverallStatsModel;
      final projects = results[1] as List<NocProjectSummaryModel>;
      setState(() {
        _overallStats = stats;
        _projects     = projects;
        _filtered     = projects;
        _isLoading    = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error     = e is ApiException ? e.message : e.toString();
        _isLoading = false;
      });
    }
  }

  void _onSearch(String q) {
    setState(() {
      _searchQuery = q;
      _filtered    = _projects
          .where((p) => p.societyName.toLowerCase().contains(q.toLowerCase()))
          .toList();
    });
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
      title: const Text('NOC Analytics',
          style: TextStyle(
              color: _AC.textDark,
              fontSize: 17,
              fontWeight: FontWeight.w700)),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: _AC.primary),
          onPressed: _loadAll,
          tooltip: 'Refresh All',
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
            Text('Loading NOC Analytics…',
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
                onPressed: _loadAll,
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
      onRefresh: _loadAll,
      child: CustomScrollView(
        slivers: [
          // Hero header
          SliverToBoxAdapter(child: _buildHeroHeader()),
          // Overall stat cards
          SliverToBoxAdapter(child: _buildOverallStats()),
          // Search bar
          SliverToBoxAdapter(child: _buildSearchBar()),
          // Project grid label
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Text(
                '${_filtered.length} Projects',
                style: const TextStyle(
                    color: _AC.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ),
          // Project cards
          _filtered.isEmpty
              ? SliverFillRemaining(child: _buildEmptySearch())
              : SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _buildProjectCard(_filtered[i]),
                      childCount: _filtered.length,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  // ── Hero header ────────────────────────────────────────────────────────────
  Widget _buildHeroHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_AC.primary, _AC.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: _AC.primary.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bar_chart_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NOC Analytics Dashboard',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 3),
                Text('Project-wise NOC Progress Tracking',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Overall stats ──────────────────────────────────────────────────────────
  Widget _buildOverallStats() {
    final s = _overallStats;
    if (s == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              _statCard('Total Projects', s.totalProjects.toString(),
                  _AC.primary, Icons.business_rounded),
              const SizedBox(width: 10),
              _statCard('Total NOCs', s.totalNocs.toString(),
                  Colors.blueGrey, Icons.description_rounded),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statCard('Completed', s.completedNocs.toString(),
                  _AC.completed, Icons.check_circle_rounded),
              const SizedBox(width: 10),
              _statCard('Pending', s.pendingNocs.toString(),
                  _AC.pending, Icons.hourglass_empty_rounded),
            ],
          ),
          const SizedBox(height: 10),
          _buildOverallProgress(s),
        ],
      ),
    );
  }

  Widget _statCard(
      String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _AC.border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        color: color,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
                Text(label,
                    style: const TextStyle(
                        color: _AC.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallProgress(NocOverallStatsModel s) {
    final pct = s.completionPercentage;
    Color barColor = _AC.pending;
    String statusLabel = 'Getting Started';
    if (pct >= 75) { barColor = _AC.completed;  statusLabel = 'On Track'; }
    else if (pct >= 50) { barColor = Colors.orange; statusLabel = 'In Progress'; }
    else if (pct > 0)   { barColor = _AC.assigned;  statusLabel = 'Started'; }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _AC.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Overall Completion Rate',
                  style: TextStyle(
                      color: _AC.textDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: barColor),
                    const SizedBox(width: 5),
                    Text(statusLabel,
                        style: TextStyle(
                            color: barColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('${pct.toStringAsFixed(1)}%',
                  style: TextStyle(
                      color: barColor,
                      fontSize: 28,
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('${s.completedNocs} / ${s.totalNocs}',
                  style: const TextStyle(
                      color: _AC.textMuted, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 10,
              backgroundColor: _AC.border,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ),
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearch,
        decoration: InputDecoration(
          hintText: 'Search projects by society name…',
          hintStyle:
              const TextStyle(color: _AC.textMuted, fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded,
              color: _AC.textMuted, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      color: _AC.textMuted, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    _onSearch('');
                  })
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _AC.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _AC.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: _AC.primary, width: 1.5)),
        ),
      ),
    );
  }

  // ── Project card ───────────────────────────────────────────────────────────
  Widget _buildProjectCard(NocProjectSummaryModel p) {
    final pct       = p.completionPercentage;
    Color barColor  = _AC.pending;
    if (pct >= 75)       barColor = _AC.completed;
    else if (pct >= 50)  barColor = Colors.orange;
    else if (pct >= 25)  barColor = _AC.assigned;

    return GestureDetector(
      onTap: () => _openDetail(p),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _AC.border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Donut mini-chart
                  _buildMiniDonut(p),
                  const SizedBox(width: 16),
                  // Project info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.societyName,
                            style: const TextStyle(
                                color: _AC.textDark,
                                fontSize: 15,
                                fontWeight: FontWeight.w700),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        // Stat pills
                        Wrap(
                          spacing: 6, runSpacing: 6,
                          children: [
                            _statPill('${p.completedNocs}',
                                'Done', _AC.completed),
                            _statPill('${p.assignedNocs}',
                                'Active', _AC.assigned),
                            _statPill('${p.pendingNocs}',
                                'Pending', _AC.pending),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: _AC.textMuted),
                ],
              ),
            ),
            // Progress footer
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${p.completedNocs} / ${p.totalNocs} NOCs',
                        style: const TextStyle(
                            color: _AC.textMuted, fontSize: 11),
                      ),
                      Text(
                        '${pct.toStringAsFixed(1)}%',
                        style: TextStyle(
                            color: barColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      minHeight: 6,
                      backgroundColor: _AC.border,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(barColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniDonut(NocProjectSummaryModel p) {
    return SizedBox(
      width: 64,
      height: 64,
      child: CustomPaint(
        painter: _DonutPainter(
          completed: p.completedNocs,
          assigned:  p.assignedNocs,
          pending:   p.pendingNocs,
          total:     p.totalNocs,
        ),
        child: Center(
          child: Text(
            '${p.completionPercentage.toStringAsFixed(0)}%',
            style: const TextStyle(
                color: _AC.textDark,
                fontSize: 11,
                fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  Widget _statPill(String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _openDetail(NocProjectSummaryModel p) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NocAnalyticsDetailPage(
          projectId:   p.id,
          projectName: p.societyName,
        ),
      ),
    );
  }

  Widget _buildEmptySearch() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded,
                size: 48, color: _AC.textMuted),
            const SizedBox(height: 12),
            Text('No projects found for "$_searchQuery"',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _AC.textMuted, fontSize: 14)),
          ],
        ),
      );
}

// ─── Custom donut painter ─────────────────────────────────────────────────────
class _DonutPainter extends CustomPainter {
  final int completed;
  final int assigned;
  final int pending;
  final int total;

  const _DonutPainter({
    required this.completed,
    required this.assigned,
    required this.pending,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx    = size.width / 2;
    final cy    = size.height / 2;
    final r     = math.min(cx, cy);
    final stroke= r * 0.38;
    final rect  = Rect.fromCircle(center: Offset(cx, cy), radius: r - stroke / 2);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = const Color(0xFFEBE9F1);

    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi, false, bg);

    if (total == 0) return;

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
  bool shouldRepaint(_DonutPainter old) =>
      old.completed != completed ||
      old.assigned  != assigned  ||
      old.pending   != pending;
}