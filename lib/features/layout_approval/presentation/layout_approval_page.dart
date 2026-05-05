// FILE PATH: lib/features/layout_approval/presentation/layout_approval_page.dart

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/utils/api_exception.dart';
import '../data/models/layout_approval_model.dart';
import '../../process_list/presentation/pages/file_viewer_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Stage tab definition
// ─────────────────────────────────────────────────────────────────────────────

class _StageTab {
  final String key;
  final String label;
  final IconData icon;
  const _StageTab({required this.key, required this.label, required this.icon});
}

const _stageTabs = [
  _StageTab(key: 'service', label: 'Service', icon: Icons.build_outlined),
  _StageTab(
      key: 'document', label: 'Document', icon: Icons.description_outlined),
  _StageTab(
      key: 'approval',
      label: 'Approval',
      icon: Icons.check_circle_outline),
  _StageTab(key: 'payment', label: 'Payment', icon: Icons.payment_outlined),
];

// Stage accent colours
const _stageColors = {
  'service': Color(0xFF3B82F6),
  'document': Color(0xFF0EA5E9),
  'approval': Color(0xFF22C55E),
  'payment': Color(0xFFF59E0B),
};

// ─────────────────────────────────────────────────────────────────────────────
// Main page widget
// ─────────────────────────────────────────────────────────────────────────────

class LayoutApprovalPage extends StatefulWidget {
  final int projectId;
  final String projectName;

  const LayoutApprovalPage({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<LayoutApprovalPage> createState() => _LayoutApprovalPageState();
}

class _LayoutApprovalPageState extends State<LayoutApprovalPage>
    with TickerProviderStateMixin {
  late TabController _tabController;

  List<LayoutApprovalStageModel> _stages = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _stageTabs.length, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Data loading ────────────────────────────────────────────────────────

  Future<void> _loadData({bool silent = false}) async {
    if (!mounted) return;
    if (silent) {
      setState(() => _isRefreshing = true);
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final stages =
          await ApiService.fetchLayoutApprovalProgress(widget.projectId);
      if (!mounted) return;
      setState(() {
        _stages = stages;
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (!silent) {
          _errorMessage = e is ApiException ? e.message : e.toString();
        }
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  LayoutApprovalStageModel? _stageForKey(String key) {
    try {
      return _stages.firstWhere((s) => s.stageKey == key);
    } catch (_) {
      return null;
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.projectName,
            style: const TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w700,
                fontSize: 16)),
        const Text('Layout Approval Progress',
            style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w400)),
      ]),
      actions: [
        if (_isRefreshing)
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: AppColors.primaryGreen)),
          )
        else
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
            onPressed: _isLoading ? null : () => _loadData(silent: false),
            tooltip: 'Refresh',
          ),
      ],
      bottom: _isLoading
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: _buildTabBar(),
            ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: AppColors.primaryGreen,
        unselectedLabelColor: const Color(0xFF94A3B8),
        indicatorColor: AppColors.primaryGreen,
        indicatorWeight: 2.5,
        labelStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        tabs: _stageTabs.asMap().entries.map((entry) {
          final i = entry.key;
          final tab = entry.value;
          final stage = _stageForKey(tab.key);

          return Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(tab.icon, size: 13),
              const SizedBox(width: 5),
              Text(tab.label),
              if (stage != null && stage.summary != null) ...[
                const SizedBox(width: 6),
                _tabBadge(stage.summary!, i),
              ],
            ]),
          );
        }).toList(),
      ),
    );
  }

  Widget _tabBadge(LayoutApprovalStageSummary summary, int index) {
    final remaining = summary.pending;
    final color =
        remaining == 0 ? const Color(0xFF22C55E) : const Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color:
            _tabController.index == index ? color : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$remaining',
        style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: _tabController.index == index
                ? Colors.white
                : const Color(0xFF64748B)),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: AppColors.primaryGreen),
          const SizedBox(height: 14),
          const Text('Loading layout approval data…',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
        ]),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline,
                color: Color(0xFFEF4444), size: 48),
            const SizedBox(height: 12),
            Text(_errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF1E293B))),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _loadData(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white),
            ),
          ]),
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: _stageTabs.map((tab) {
        final stage = _stageForKey(tab.key);
        final color = _stageColors[tab.key] ?? AppColors.primaryGreen;
        return _StageTabContent(
          stage: stage,
          stageTab: tab,
          accentColor: color,
          projectId: widget.projectId,
          onRefresh: () => _loadData(silent: true),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-stage tab content
// ─────────────────────────────────────────────────────────────────────────────

class _StageTabContent extends StatelessWidget {
  final LayoutApprovalStageModel? stage;
  final _StageTab stageTab;
  final Color accentColor;
  final int projectId;
  final Future<void> Function() onRefresh;

  const _StageTabContent({
    required this.stage,
    required this.stageTab,
    required this.accentColor,
    required this.projectId,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (stage == null) {
      return _emptyStageState();
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: accentColor,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildSummaryCard()),
          SliverToBoxAdapter(child: _buildProgressBar()),
          if (stage!.processes.isEmpty)
            SliverFillRemaining(child: _emptyStageState())
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _ProcessCard(
                  process: stage!.processes[i],
                  index: i,
                  accentColor: accentColor,
                  projectId: projectId,
                  stageKey: stageTab.key,
                  onRefresh: onRefresh,
                ),
                childCount: stage!.processes.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final summary = stage!.summary;
    if (summary == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(stageTab.icon, color: accentColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${stageTab.label} Processes',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: accentColor)),
                  Text(
                    '${summary.completed + summary.na} of ${summary.total} actioned',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ]),
          ),
          Text(
            '${summary.completionPercentage.toStringAsFixed(0)}%',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: accentColor),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          _summaryChip(
              label: 'Completed',
              count: summary.completed,
              color: const Color(0xFF22C55E)),
          const SizedBox(width: 8),
          _summaryChip(
              label: 'N.A',
              count: summary.na,
              color: const Color.fromARGB(255, 238, 13, 13)),
          const SizedBox(width: 8),
          _summaryChip(
              label: 'Pending',
              count: summary.pending,
              color: const Color(0xFFF59E0B)),
        ]),
      ]),
    );
  }

  Widget _summaryChip(
      {required String label, required int count, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.2))),
        child: Column(children: [
          Text('$count',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ]),
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = stage!.progress;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: const Color(0xFFE2E8F0),
          valueColor: AlwaysStoppedAnimation<Color>(accentColor),
          minHeight: 6,
        ),
      ),
    );
  }

  Widget _emptyStageState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(stageTab.icon,
                size: 52, color: accentColor.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('No ${stageTab.label} processes found',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF94A3B8), fontSize: 14)),
          ]),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual process card
// ─────────────────────────────────────────────────────────────────────────────

class _ProcessCard extends StatefulWidget {
  final LayoutApprovalProcessModel process;
  final int index;
  final Color accentColor;
  final int projectId;
  final String stageKey;
  final Future<void> Function() onRefresh;

  const _ProcessCard({
    required this.process,
    required this.index,
    required this.accentColor,
    required this.projectId,
    required this.stageKey,
    required this.onRefresh,
  });

  @override
  State<_ProcessCard> createState() => _ProcessCardState();
}

class _ProcessCardState extends State<_ProcessCard> {
  bool _isUpdating = false;

  // ── Status helpers ─────────────────────────────────────────────────────

  Future<void> _toggleStatus(String status) async {
    if (_isUpdating) return;
    final process = widget.process;

    final isCurrentlySet = (status == 'Completed' && process.isCompleted) ||
        (status == 'N.A' && process.isNa);

    final bool useDangerTheme = status == 'N.A' || isCurrentlySet;

    final confirmed = await _showConfirm(
      title: isCurrentlySet ? 'Remove Status?' : 'Mark as $status',
      processName: process.processName,
      confirmLabel: isCurrentlySet ? 'Remove' : 'Confirm',
      danger: useDangerTheme,
    );
    if (!confirmed) return;

    setState(() => _isUpdating = true);

    try {
      if (isCurrentlySet) {
        await ApiService.removeLayoutApprovalStatus(
            projectId: widget.projectId, processId: process.processId);
        _showSnack('Status removed.', success: true);
      } else {
        await ApiService.updateLayoutApprovalStatus(
            projectId: widget.projectId,
            processId: process.processId,
            status: status);
        _showSnack('Marked as $status.', success: true);
      }
      await widget.onRefresh();
    } catch (e) {
      _showSnack(
          e is ApiException ? e.message : 'Operation failed.',
          success: false);
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  // ── Upload ─────────────────────────────────────────────────────────────

  void _openUploadSheet() {
    if (widget.process.isNa) {
      _showSnack('Upload disabled — process is marked N.A.', success: false);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UploadSheet(
        processId: widget.process.processId,
        processName: widget.process.processName,
        projectId: widget.projectId,
        accentColor: widget.accentColor,
        onUploaded: widget.onRefresh,
      ),
    );
  }

  void _openFile() {
    final path = widget.process.fileInfo?.filePath;
    if (path == null || path.isEmpty) {
      _showSnack('No file available.', success: false);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FileViewerPage(url: path, title: widget.process.processName),
      ),
    );
  }

  // ── UI helpers ─────────────────────────────────────────────────────────

  void _showSnack(String msg, {required bool success}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          success ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(12),
    ));
  }

  Future<bool> _showConfirm({
    required String title,
    required String processName,
    required String confirmLabel,
    bool danger = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          barrierColor: Colors.black.withValues(alpha: 0.45),
          builder: (_) => _StatusConfirmDialog(
            title: title,
            processName: processName,
            confirmLabel: confirmLabel,
            danger: danger,
          ),
        ) ??
        false;
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final process = widget.process;
    final isNa = process.isNa;
    final isCompleted = process.isCompleted;
    final accentColor = widget.accentColor;

    Color borderColor = const Color(0xFFE2E8F0);
    if (isCompleted) borderColor = const Color(0xFF22C55E);
    if (isNa) borderColor = const Color.fromARGB(255, 221, 9, 9);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: isNa ? const Color(0xFFF8FAFC) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isCompleted
                    ? const Color(0xFF22C55E)
                    : isNa
                        ? const Color(0xFF94A3B8)
                        : accentColor.withValues(alpha: 0.25),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    bottomLeft: Radius.circular(10)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                      color: isNa
                          ? const Color(0xFFE2E8F0)
                          : accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(7)),
                  alignment: Alignment.center,
                  child: Text(
                    '${widget.index + 1}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isNa ? const Color(0xFF94A3B8) : accentColor),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    process.processName,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isNa
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF1E293B)),
                  ),
                ),
                const SizedBox(width: 6),
                _statusPill(process),
              ]),
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFEFF3F8)),
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(
                  child: _isUpdating
                      ? Center(
                          child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: accentColor)))
                      : _actionToggle(
                          label: 'Completed',
                          checked: isCompleted,
                          activeColor: const Color(0xFF22C55E),
                          icon: Icons.check_circle_outline,
                          disabled: isNa,
                          onTap: () => _toggleStatus('Completed'),
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _isUpdating
                      ? const SizedBox.shrink()
                      : _actionToggle(
                          label: 'N.A',
                          checked: isNa,
                          activeColor: const Color(0xFF94A3B8),
                          icon: Icons.remove_circle_outline,
                          disabled: isCompleted && process.hasFile,
                          onTap: () => _toggleStatus('N.A'),
                        ),
                ),
                const SizedBox(width: 8),
                _buildUploadArea(process),
              ]),
              if (process.hasFile && process.fileInfo != null) ...[
                const SizedBox(height: 8),
                _buildFileChip(process.fileInfo!),
              ],
            ]),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(LayoutApprovalProcessModel process) {
    if (process.isCompleted) {
      return _pill('Completed', const Color(0xFF22C55E));
    } else if (process.isNa) {
      return _pill('N.A', const Color.fromARGB(255, 223, 8, 8));
    } else {
      return _pill('Pending', const Color(0xFFF59E0B));
    }
  }

  Widget _pill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.4))),
        child: Text(label,
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.3)),
      );

  Widget _actionToggle({
    required String label,
    required bool checked,
    required Color activeColor,
    required IconData icon,
    required bool disabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: checked
              ? activeColor.withValues(alpha: 0.1)
              : disabled
                  ? const Color(0xFFF1F5F9)
                  : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: checked
                  ? activeColor.withValues(alpha: 0.5)
                  : const Color(0xFFE2E8F0)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(
            checked ? Icons.check_circle_rounded : icon,
            size: 14,
            color: checked
                ? activeColor
                : disabled
                    ? const Color(0xFFCBD5E1)
                    : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: checked
                      ? activeColor
                      : disabled
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFF475569))),
        ]),
      ),
    );
  }

  Widget _buildUploadArea(LayoutApprovalProcessModel process) {
    if (process.isNa) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0))),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.block, size: 12, color: Color(0xFFCBD5E1)),
          SizedBox(width: 4),
          Text('N/A',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFCBD5E1))),
        ]),
      );
    }

    if (process.hasFile) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        GestureDetector(
          onTap: _openFile,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.4))),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.open_in_new_rounded,
                  size: 12, color: Color(0xFF22C55E)),
              SizedBox(width: 4),
              Text('View',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF22C55E))),
            ]),
          ),
        ),
        const SizedBox(width: 5),
        GestureDetector(
          onTap: _openUploadSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.4))),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.upload_rounded, size: 12, color: Color(0xFFF59E0B)),
              SizedBox(width: 4),
              Text('Replace',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFF59E0B))),
            ]),
          ),
        ),
      ]);
    }

    return GestureDetector(
      onTap: _openUploadSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
            color: widget.accentColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: widget.accentColor.withValues(alpha: 0.35))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.upload_file_outlined,
              size: 12, color: widget.accentColor),
          const SizedBox(width: 4),
          Text('Upload',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: widget.accentColor)),
        ]),
      ),
    );
  }

  Widget _buildFileChip(LayoutApprovalFileInfo info) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFBBF7D0))),
      child: Row(children: [
        const Icon(Icons.attach_file_rounded,
            size: 12, color: Color(0xFF22C55E)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            info.fileName ?? 'Uploaded file',
            style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF166534),
                fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (info.fileSize != null) ...[
          const SizedBox(width: 6),
          Text(info.fileSize!,
              style:
                  const TextStyle(fontSize: 10, color: Color(0xFF4ADE80))),
        ],
        if (info.uploadedDate != null) ...[
          const SizedBox(width: 6),
          Text(info.uploadedDate!,
              style:
                  const TextStyle(fontSize: 10, color: Color(0xFF4ADE80))),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom confirmation dialog
// ─────────────────────────────────────────────────────────────────────────────

class _StatusConfirmDialog extends StatelessWidget {
  final String title;
  final String processName;
  final String confirmLabel;
  final bool danger;

  const _StatusConfirmDialog({
    required this.title,
    required this.processName,
    required this.confirmLabel,
    required this.danger,
  });

  @override
  Widget build(BuildContext context) {
    final Color headerColor =
        danger ? const Color(0xFFEF4444) : const Color(0xFF22C55E);

    final IconData headerIcon = danger
        ? Icons.delete_outline_rounded
        : Icons.check_circle_outline_rounded;

    final String hintText = danger
        ? 'The current status will be cleared from this process.'
        : 'This action can be undone later if needed.';

    final Color hintBg =
        danger ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4);
    final Color hintBorder =
        danger ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0);
    final Color hintIconColor =
        danger ? const Color(0xFFEF4444) : const Color(0xFF22C55E);
    final Color hintTextColor =
        danger ? const Color(0xFF991B1B) : const Color(0xFF166534);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Coloured header ──────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                color: headerColor,
                child: Row(children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(headerIcon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Layout approval process',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.75)),
                          ),
                        ]),
                  ),
                ]),
              ),

              // ── Body ─────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Process',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          processName,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Hint banner
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                            color: hintBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: hintBorder)),
                        child: Row(children: [
                          Icon(
                            danger
                                ? Icons.warning_amber_rounded
                                : Icons.info_outline_rounded,
                            size: 15,
                            color: hintIconColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              hintText,
                              style: TextStyle(
                                  fontSize: 11, color: hintTextColor),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 18),
                    ]),
              ),

              // ── Actions ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF475569),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8))),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: Icon(
                        danger
                            ? Icons.delete_outline_rounded
                            : Icons.check_rounded,
                        size: 15,
                      ),
                      label: Text(
                        confirmLabel,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: headerColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8))),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Upload bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _UploadSheet extends StatefulWidget {
  final int processId;
  final String processName;
  final int projectId;
  final Color accentColor;
  final Future<void> Function() onUploaded;

  const _UploadSheet({
    required this.processId,
    required this.processName,
    required this.projectId,
    required this.accentColor,
    required this.onUploaded,
  });

  @override
  State<_UploadSheet> createState() => _UploadSheetState();
}

class _UploadSheetState extends State<_UploadSheet> {
  PlatformFile? _pickedFile;
  DateTime _uploadDate = DateTime.now();
  bool _isSaving = false;
  bool _isPicking = false;

  String get _formattedDate =>
      '${_uploadDate.day.toString().padLeft(2, '0')}/${_uploadDate.month.toString().padLeft(2, '0')}/${_uploadDate.year}';

  String get _isoDate =>
      '${_uploadDate.year}-${_uploadDate.month.toString().padLeft(2, '0')}-${_uploadDate.day.toString().padLeft(2, '0')}';

  Future<void> _pickFile() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'zip'],
        withData: false,
      );
      if (result != null && result.files.isNotEmpty && mounted) {
        setState(() => _pickedFile = result.files.first);
      }
    } catch (e) {
      _showSnack('Could not open file picker: $e', success: false);
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _uploadDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme:
                ColorScheme.light(primary: widget.accentColor)),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _uploadDate = picked);
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (_pickedFile == null) {
      _showSnack('Please select a file first.', success: false);
      return;
    }

    final path = _pickedFile!.path;
    if (path == null) {
      _showSnack('Could not access file path.', success: false);
      return;
    }

    setState(() => _isSaving = true);

    try {
      await ApiService.uploadLayoutApprovalFile(
        projectId: widget.projectId,
        processId: widget.processId,
        file: File(path),
        fileName: _pickedFile!.name,
        uploadedDate: _isoDate,
      );

      if (!mounted) return;
      Navigator.pop(context);
      _showSnack('File uploaded successfully!', success: true);
      await widget.onUploaded();
    } catch (e) {
      _showSnack(
          e is ApiException ? e.message : 'Upload failed.',
          success: false);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg, {required bool success}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          success ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(12),
    ));
  }

  IconData _fileIcon(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'doc':
      case 'docx':
        return Icons.description_outlined;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image_outlined;
      case 'zip':
        return Icons.folder_zip_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // ── Header ──────────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: BoxDecoration(
              color: widget.accentColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20))),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Upload Document',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(widget.processName,
                        style: TextStyle(
                            color:
                                Colors.white.withValues(alpha: 0.75),
                            fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ]),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6)),
                child:
                    const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ]),
        ),

        // ── Body ────────────────────────────────────────────────────────
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: const Color(0xFFBFDBFE))),
                    child: const Row(children: [
                      Icon(Icons.info_outline,
                          size: 15, color: Color(0xFF2563EB)),
                      SizedBox(width: 8),
                      Expanded(
                          child: Text(
                        'Uploading a file will mark this process as Completed.',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF1D4ED8)),
                      )),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  const Text('Select File *',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151))),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _isPicking ? null : _pickFile,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: _pickedFile != null
                                ? widget.accentColor
                                : widget.accentColor
                                    .withValues(alpha: 0.35)),
                        borderRadius: BorderRadius.circular(10),
                        color: _pickedFile != null
                            ? widget.accentColor.withValues(alpha: 0.05)
                            : const Color(0xFFFAFBFF),
                      ),
                      child: _isPicking
                          ? Center(
                              child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: widget.accentColor)))
                          : _pickedFile != null
                              ? Row(children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                        color: widget.accentColor
                                            .withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(6)),
                                    child: Icon(
                                        _fileIcon(_pickedFile!.extension),
                                        color: widget.accentColor,
                                        size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(_pickedFile!.name,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF1E293B)),
                                            overflow:
                                                TextOverflow.ellipsis),
                                        const SizedBox(height: 2),
                                        Text(_formatSize(_pickedFile!.size),
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color:
                                                    Color(0xFF94A3B8))),
                                      ])),
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _pickedFile = null),
                                    child: const Icon(Icons.close,
                                        size: 18,
                                        color: Color(0xFF94A3B8)),
                                  ),
                                ])
                              : Column(children: [
                                  Icon(Icons.cloud_upload_outlined,
                                      size: 36,
                                      color: widget.accentColor),
                                  const SizedBox(height: 8),
                                  Text('Tap to select file',
                                      style: TextStyle(
                                          color: widget.accentColor,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                  const SizedBox(height: 4),
                                  const Text(
                                      'PDF, DOC, DOCX, JPG, PNG, ZIP (max 10 MB)',
                                      style: TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 11)),
                                ]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Upload Date *',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151))),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 13),
                      decoration: BoxDecoration(
                          border:
                              Border.all(color: const Color(0xFFD1D5DB)),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white),
                      child: Row(children: [
                        Expanded(
                            child: Text(_formattedDate,
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF1E293B)))),
                        const Icon(Icons.calendar_today_outlined,
                            size: 18, color: Color(0xFF6B7280)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 20),
                ]),
          ),
        ),

        // ── Footer ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF374151),
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
                child: const Text('Cancel',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _submit,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.upload_rounded, size: 16),
                label: Text(_isSaving ? 'Uploading…' : 'Upload',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: widget.accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}