// lib/features/stage_report/presentation/pages/stage_report_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/stage_report_models.dart';
import '../../data/services/stage_report_api.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
const _kPrimaryDark = Color(0xFF0D5C37);
const _kPrimary = Color(0xFF1A7A4A);
const _kPrimaryMid = Color(0xFF2E9D64);
const _kPrimaryGlow = Color(0xFFD0F0E0);

const _kBg = Color(0xFFF0F4F2);
const _kSurface = Colors.white;
const _kBorder = Color(0xFFDDE6E1);

const _kText = Color(0xFF0F1F17);
const _kTextSub = Color(0xFF4A6358);
const _kMuted = Color(0xFF8FA89E);

const _kDone = Color(0xFF059669);
const _kDoneBg = Color(0xFFD1FAE5);
const _kPend = Color(0xFFD97706);
const _kPendBg = Color(0xFFFEF3C7);
const _kAsgn = Color(0xFF2563EB);
const _kAsgnBg = Color(0xFFDBEAFE);
const _kTot = Color(0xFF374151);
const _kTotBg = Color(0xFFF3F4F6);

class StageReportPage extends StatefulWidget {
  const StageReportPage({super.key});

  @override
  State<StageReportPage> createState() => _StageReportPageState();
}

class _StageReportPageState extends State<StageReportPage>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  List<StageReportProject> _projects = [];
  StageReportProject? _selectedProject;
  bool _projectsLoading = true;

  List<StageReportRow> _rows = [];
  List<StageReportRow> _filtered = [];
  bool _dataLoading = false;
  String? _error;

  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadProjects();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────
  Future<void> _loadProjects() async {
    setState(() => _projectsLoading = true);
    try {
      final list = await StageReportApi.fetchProjects();
      if (!mounted) return;
      setState(() {
        _projects = list;
        _projectsLoading = false;
      });
      _loadReport();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _projectsLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadReport() async {
    _fadeCtrl.reset();
    setState(() {
      _dataLoading = true;
      _error = null;
    });
    try {
      final resp = await StageReportApi.fetchReportData(
        projectId: _selectedProject?.id,
        length: 200,
      );
      if (!mounted) return;
      setState(() {
        _rows = resp.rows;
        _dataLoading = false;
      });
      _applySearch();
      _fadeCtrl.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dataLoading = false;
        _error = e.toString();
      });
    }
  }

  void _onSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), _applySearch);
  }

  void _applySearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.from(_rows)
          : _rows
              .where((r) => r.projectName.toLowerCase().contains(q))
              .toList();
    });
  }

  void _onProjectChanged(StageReportProject? p) {
    HapticFeedback.selectionClick();
    setState(() => _selectedProject = p);
    _loadReport();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _kBg,
        body: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            Expanded(child: _buildBody()),
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kPrimaryDark, _kPrimary, _kPrimaryMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 20),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Stage Report',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  _buildRefreshButton(),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildProjectDropdown(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
    return Material(
      color: Colors.white.withAlpha(30),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          HapticFeedback.lightImpact();
          _loadReport();
        },
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  // ── Project Dropdown ───────────────────────────────────────────────────────
  Widget _buildProjectDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withAlpha(60), width: 1),
        ),
        child: _projectsLoading
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
              )
            : DropdownButtonHideUnderline(
                child: DropdownButton<StageReportProject?>(
                  value: _selectedProject,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1C5E3A),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Colors.white70, size: 22),
                  style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w500),
                  hint: const Text('All Projects',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  items: [
                    const DropdownMenuItem<StageReportProject?>(
                      value: null,
                      child: Text('All Projects',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 14)),
                    ),
                    ..._projects.map(
                      (p) => DropdownMenuItem<StageReportProject?>(
                        value: p,
                        child: Text(
                          p.societyName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                  onChanged: _onProjectChanged,
                ),
              ),
      ),
    );
  }

  // ── Search Bar ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      color: _kBg,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(fontSize: 14, color: _kText),
        decoration: InputDecoration(
          hintText: 'Search projects…',
          hintStyle: const TextStyle(color: _kMuted, fontSize: 14),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 14, right: 8),
            child: Icon(Icons.search_rounded, color: _kMuted, size: 20),
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 0, minHeight: 0),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.cancel_rounded,
                      color: _kMuted, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    _applySearch();
                  },
                )
              : null,
          filled: true,
          fillColor: _kSurface,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _kPrimary, width: 1.8),
          ),
        ),
      ),
    );
  }

  // ── Body ───────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_dataLoading) return _buildLoader();
    if (_error != null) return _buildError();
    if (_filtered.isEmpty) return _buildEmpty();

    return FadeTransition(
      opacity: _fadeAnim,
      child: Column(
        children: [
          _buildTableHeader(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: _filtered.length,
              itemBuilder: (ctx, i) => _buildRow(_filtered[i], i),
            ),
          ),
          _buildCountBar(),
        ],
      ),
    );
  }

  Widget _buildLoader() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _kPrimaryGlow,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                  color: _kPrimary, strokeWidth: 2.5),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Loading report…',
              style: TextStyle(
                  color: _kTextSub,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE4E4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  color: Color(0xFFE53E3E), size: 34),
            ),
            const SizedBox(height: 16),
            const Text('Something went wrong',
                style: TextStyle(
                    color: _kText,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kMuted, fontSize: 13),
            ),
            const SizedBox(height: 22),
            TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _loadReport,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _kPrimaryGlow,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.bar_chart_rounded,
                color: _kPrimaryMid, size: 34),
          ),
          const SizedBox(height: 16),
          Text(
            _searchCtrl.text.isNotEmpty
                ? 'No results found'
                : 'No data available',
            style: const TextStyle(
                color: _kText,
                fontSize: 16,
                fontWeight: FontWeight.w700),
          ),
          if (_searchCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text(
              'Try a different search term',
              style: TextStyle(color: _kMuted, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  // ── Table Header ───────────────────────────────────────────────────────────
  Widget _buildTableHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B3A2D), Color(0xFF1E4535)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _hCell('SR', flex: 1, center: true),
              _hCell('PROJECT NAME', flex: 5),
              _hGroup('STAGE 1', flex: 4),
              _hGroup('STAGE 2', flex: 4),
            ],
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.white.withAlpha(0),
                Colors.white.withAlpha(40),
                Colors.white.withAlpha(0),
              ]),
            ),
          ),
          Row(
            children: [
              _hSub('', flex: 1),
              _hSub('', flex: 5),
              _hSub('DONE', flex: 1, color: _kDone),
              _hSub('PEND', flex: 1, color: _kPend),
              _hSub('ASGN', flex: 1, color: _kAsgn),
              _hSub('TOT', flex: 1, color: _kMuted),
              _hSub('DONE', flex: 1, color: _kDone),
              _hSub('PEND', flex: 1, color: _kPend),
              _hSub('ASGN', flex: 1, color: _kAsgn),
              _hSub('TOT', flex: 1, color: _kMuted),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hCell(String text, {required int flex, bool center = false}) =>
      Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
          child: Text(
            text,
            textAlign: center ? TextAlign.center : TextAlign.left,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8),
          ),
        ),
      );

  Widget _hGroup(String text, {required int flex}) => Expanded(
        flex: flex,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8),
          ),
        ),
      );

  Widget _hSub(String text, {required int flex, Color? color}) => Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: color ?? Colors.white.withAlpha(120),
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5),
          ),
        ),
      );

  // ── Data Row ───────────────────────────────────────────────────────────────
  Widget _buildRow(StageReportRow row, int index) {
    final isEven = index % 2 == 0;
    return Container(
      decoration: BoxDecoration(
        color: isEven ? Colors.white : const Color(0xFFF6FAF8),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFEDF2EF), width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Sr No
          Expanded(
            flex: 1,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  color: _kPrimaryGlow,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${row.srNo}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11,
                      color: _kPrimaryDark,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          // Project Name
          Expanded(
            flex: 5,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 11, horizontal: 7),
              child: Text(
                row.projectName,
                style: const TextStyle(
                  fontSize: 12,
                  color: _kText,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ),
          ),
          // Stage 1
          _statCell(row.stage1.completed, _kDone, _kDoneBg),
          _statCell(row.stage1.pending, _kPend, _kPendBg),
          _statCell(row.stage1.assigned, _kAsgn, _kAsgnBg),
          _statCell(row.stage1.total, _kTot, _kTotBg),
          // Stage 2
          _statCell(row.stage2.completed, _kDone, _kDoneBg),
          _statCell(row.stage2.pending, _kPend, _kPendBg),
          _statCell(row.stage2.assigned, _kAsgn, _kAsgnBg),
          _statCell(row.stage2.total, _kTot, _kTotBg),
        ],
      ),
    );
  }

  Widget _statCell(int value, Color textColor, Color bgColor) {
    final hasValue = value > 0;
    return Expanded(
      flex: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: hasValue ? bgColor : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: hasValue ? textColor : const Color(0xFFD1D5DB),
            ),
          ),
        ),
      ),
    );
  }

  // ── Count Bar ──────────────────────────────────────────────────────────────
  Widget _buildCountBar() {
    return Container(
      color: _kSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
                color: _kPrimaryMid, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            'Showing ${_filtered.length} of ${_rows.length} project${_rows.length == 1 ? '' : 's'}',
            style: const TextStyle(
                fontSize: 12,
                color: _kTextSub,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ── Legend ─────────────────────────────────────────────────────────────────
  Widget _buildLegend() {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border(top: BorderSide(color: _kBorder.withAlpha(180))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          iconColor: _kPrimary,
          collapsedIconColor: _kMuted,
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _kPrimaryGlow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.info_outline_rounded,
                color: _kPrimary, size: 18),
          ),
          title: const Text(
            'Status & Stage Guide',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _kText),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _legendSection('STATUS', [
                      _LegendEntry(
                          'Done', 'Upload date set', _kDone, _kDoneBg),
                      _LegendEntry(
                          'Pending', 'Not yet uploaded', _kPend, _kPendBg),
                      _LegendEntry(
                          'Assigned', 'Has assign date', _kAsgn, _kAsgnBg),
                      _LegendEntry(
                          'Total', 'All processes', _kTot, _kTotBg),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _legendSection('STAGES', [
                      _LegendEntry('Stage 1', 'Pretender Phase', _kPrimary,
                          _kPrimaryGlow),
                      _LegendEntry('Stage 2', 'Pre-Construction',
                          _kPrimaryMid, const Color(0xFFCCF0DF)),
                      _LegendEntry(
                          'Stage 3', 'Construction', _kAsgn, _kAsgnBg),
                    ]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendSection(String title, List<_LegendEntry> entries) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: _kMuted,
                letterSpacing: 1.2)),
        const SizedBox(height: 8),
        ...entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 20,
                    decoration: BoxDecoration(
                      color: e.bg,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Center(
                      child: Text(
                        e.label.length > 1
                            ? e.label.substring(0, 2)
                            : e.label,
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: e.color),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.label,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _kText)),
                        Text(e.desc,
                            style: const TextStyle(
                                fontSize: 10, color: _kMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

class _LegendEntry {
  final String label;
  final String desc;
  final Color color;
  final Color bg;
  const _LegendEntry(this.label, this.desc, this.color, this.bg);
}