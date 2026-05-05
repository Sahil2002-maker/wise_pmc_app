// lib/features/oc_progress/presentation/oc_progress_page.dart

import 'dart:developer' as developer;
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'dart:convert';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_storage_service.dart';
import '../../../core/utils/api_exception.dart';
import '../data/models/oc_progress_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OcProgressPage — Main entry point
// ─────────────────────────────────────────────────────────────────────────────

class OcProgressPage extends StatefulWidget {
  final int projectId;
  final String projectName;

  const OcProgressPage({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<OcProgressPage> createState() => _OcProgressPageState();
}

class _OcProgressPageState extends State<OcProgressPage>
    with TickerProviderStateMixin {
  TabController? _tabController;

  static const _stageOrder = ['service', 'document', 'approval', 'payment'];
  static const _stageLabels = {
    'service': 'Service',
    'document': 'Document',
    'approval': 'Approval',
    'payment': 'Payment',
  };
  static const _stageIcons = {
    'service': Icons.settings_outlined,
    'document': Icons.description_outlined,
    'approval': Icons.check_circle_outline,
    'payment': Icons.credit_card_outlined,
  };
  static const _stageColors = {
    'service': Color(0xFF3B82F6),
    'document': Color(0xFF06B6D4),
    'approval': Color(0xFF22C55E),
    'payment': Color(0xFFF59E0B),
  };

  List<OcStageDataModel> _stages = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _rebuildTabController(int count) {
    final len = count < 1 ? 1 : count;
    if (_tabController != null && _tabController!.length == len) return;
    final old = _tabController;
    final nc = TabController(
      length: len,
      vsync: this,
      initialIndex: _currentTabIndex.clamp(0, len - 1),
    );
    nc.addListener(() {
      if (!nc.indexIsChanging && mounted) {
        setState(() => _currentTabIndex = nc.index);
      }
    });
    _tabController = nc;
    old?.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final token = await AuthStorageService.getToken();
      if (token == null || token.isEmpty) {
        throw ApiException('Session expired.');
      }

      final url = Uri.parse(
        '${ApiConstants.baseUrl}/api/mobile/oc-progress/${widget.projectId}',
      );

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;

      final body = _decode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = (body is Map ? body['data'] : null);
        List<OcStageDataModel> stages = [];

        if (raw is List) {
          stages = raw
              .whereType<Map>()
              .map(
                (e) => OcStageDataModel.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList();
        }

        stages.sort((a, b) {
          final ai = _stageOrder.indexOf(a.stageKey);
          final bi = _stageOrder.indexOf(b.stageKey);
          return ai.compareTo(bi);
        });

        _rebuildTabController(stages.length);

        setState(() {
          _stages = stages;
          _isLoading = false;
          _errorMessage = null;
        });
      } else if (response.statusCode == 401) {
        throw ApiException('Session expired.');
      } else {
        throw ApiException(
          (body is Map ? body['message']?.toString() : null) ??
              'Failed to load OC Progress (${response.statusCode})',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is ApiException ? e.message : e.toString();
        _isLoading = false;
      });
    }
  }

  dynamic _decode(String body) {
    if (body.isEmpty) return {};
    try {
      return jsonDecode(body);
    } catch (_) {
      return {'message': body};
    }
  }

  Future<void> _updateStatus({
    required int processId,
    required String status,
    required String stageKey,
  }) async {
    final token = await AuthStorageService.getToken();
    if (token == null) return;

    final url = Uri.parse(
      '${ApiConstants.baseUrl}/api/mobile/oc-progress/update-status',
    );

    final response = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'project_id': widget.projectId,
        'process_id': processId,
        'status': status,
      }),
    ).timeout(const Duration(seconds: 30));

    final decoded = _decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      await _loadData(silent: true);
    } else {
      throw ApiException(
        (decoded is Map ? decoded['message']?.toString() : null) ??
            'Failed to update status',
      );
    }
  }

  Future<void> _removeStatus({
    required int processId,
  }) async {
    final token = await AuthStorageService.getToken();
    if (token == null) return;

    final url = Uri.parse(
      '${ApiConstants.baseUrl}/api/mobile/oc-progress/remove-status',
    );

    final response = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'project_id': widget.projectId,
        'process_id': processId,
      }),
    ).timeout(const Duration(seconds: 30));

    final decoded = _decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      await _loadData(silent: true);
    } else {
      throw ApiException(
        (decoded is Map ? decoded['message']?.toString() : null) ??
            'Failed to remove status',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildLoading();
    if (_errorMessage != null) return _buildError();
    if (_stages.isEmpty) return _buildEmpty();

    final ctrl = _tabController;
    if (ctrl == null || ctrl.length != _stages.length) {
      return _buildLoading();
    }

    return Column(
      children: [
        _buildHeader(),
        _buildTabBar(ctrl),
        Expanded(
          child: TabBarView(
            controller: ctrl,
            children: _stages
                .map(
                  (s) => _OcStageTab(
                    stage: s,
                    projectId: widget.projectId,
                    stageColor:
                        _stageColors[s.stageKey] ?? AppColors.primaryGreen,
                    stageIcon: _stageIcons[s.stageKey] ?? Icons.layers_outlined,
                    stageLabel: _stageLabels[s.stageKey] ?? s.stageLabel,
                    onUpdateStatus: (processId, status) => _updateStatus(
                      processId: processId,
                      status: status,
                      stageKey: s.stageKey,
                    ),
                    onRemoveStatus: (processId) =>
                        _removeStatus(processId: processId),
                    onRefresh: () => _loadData(silent: true),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    int totalCompleted = 0;
    int totalNa = 0;
    int totalRemaining = 0;
    int grandTotal = 0;

    for (final s in _stages) {
      if (s.summary != null) {
        totalCompleted += s.summary!.completed;
        totalNa += s.summary!.na;
        totalRemaining += s.summary!.remaining;
        grandTotal += s.summary!.total;
      }
    }

    final progress =
        grandTotal > 0 ? (totalCompleted + totalNa) / grandTotal : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'OC Progress Overview',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryGreen,
                ),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor:
                  AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _overviewChip(
                'Completed',
                totalCompleted,
                const Color(0xFF22C55E),
              ),
              const SizedBox(width: 8),
              _overviewChip('N.A', totalNa, const Color(0xFF94A3B8)),
              const SizedBox(width: 8),
              _overviewChip(
                'Remaining',
                totalRemaining,
                const Color(0xFFF59E0B),
              ),
              const Spacer(),
              Text(
                'of $grandTotal total',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _overviewChip(String label, int count, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '$count $label',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      );

  Widget _buildTabBar(TabController ctrl) => Container(
        color: Colors.white,
        child: TabBar(
          controller: ctrl,
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
          tabs: _stages.map((s) {
            final icon = _stageIcons[s.stageKey] ?? Icons.layers_outlined;
            final summary = s.summary;
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 13),
                  const SizedBox(width: 5),
                  Text(_stageLabels[s.stageKey] ?? s.stageLabel),
                  if (summary != null) ...[
                    const SizedBox(width: 6),
                    _tabBadge(summary.completed, const Color(0xFF22C55E)),
                    const SizedBox(width: 2),
                    _tabBadge(summary.na, const Color(0xFF94A3B8)),
                    const SizedBox(width: 2),
                    _tabBadge(summary.remaining, const Color(0xFFF59E0B)),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      );

  Widget _tabBadge(int count, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$count',
          style: const TextStyle(
            fontSize: 9,
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _buildLoading() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primaryGreen),
            const SizedBox(height: 16),
            const Text(
              'Loading OC Progress…',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      );

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Color(0xFFEF4444),
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 56,
                color: AppColors.primaryGreen.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 12),
              const Text(
                'No OC Progress data found',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// _OcStageTab — renders a single stage's process list
// ─────────────────────────────────────────────────────────────────────────────

class _OcStageTab extends StatelessWidget {
  final OcStageDataModel stage;
  final int projectId;
  final Color stageColor;
  final IconData stageIcon;
  final String stageLabel;
  final Future<void> Function(int processId, String status) onUpdateStatus;
  final Future<void> Function(int processId) onRemoveStatus;
  final Future<void> Function() onRefresh;

  const _OcStageTab({
    required this.stage,
    required this.projectId,
    required this.stageColor,
    required this.stageIcon,
    required this.stageLabel,
    required this.onUpdateStatus,
    required this.onRemoveStatus,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primaryGreen,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildSummaryCard()),
          if (stage.processes.isEmpty)
            SliverFillRemaining(child: _buildEmpty())
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _OcProcessCard(
                  process: stage.processes[i],
                  index: i,
                  projectId: projectId,
                  stageColor: stageColor,
                  onUpdateStatus: onUpdateStatus,
                  onRemoveStatus: onRemoveStatus,
                  onRefresh: onRefresh,
                ),
                childCount: stage.processes.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final s = stage.summary;
    if (s == null) return const SizedBox.shrink();

    final completionPct = s.total > 0
        ? (s.completed + s.na) / s.total
        : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: stageColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: stageColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(stageIcon, color: stageColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$stageLabel Processes',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: stageColor,
                      ),
                    ),
                    Text(
                      '${s.completed + s.na} of ${s.total} actioned',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(completionPct * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: stageColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ── Progress bar ─────────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: completionPct,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(stageColor),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 14),
          // ── Three equal stat chips (matching Layout Approval style) ──────
          Row(
            children: [
              _summaryChip(
                label: 'Completed',
                count: s.completed,
                color: const Color(0xFF22C55E),
              ),
              const SizedBox(width: 8),
              _summaryChip(
                label: 'N.A',
                count: s.na,
                color: const Color(0xFFEF4444),
              ),
              const SizedBox(width: 8),
              _summaryChip(
                label: 'Remaining',
                count: s.remaining,
                color: const Color(0xFFF59E0B),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryChip({
    required String label,
    required int count,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.list_alt_outlined,
                size: 48,
                color: stageColor.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 12),
              Text(
                'No processes found for ${stage.stageLabel}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// _OcProcessCard — individual process row card
// ─────────────────────────────────────────────────────────────────────────────

class _OcProcessCard extends StatefulWidget {
  final OcProcessModel process;
  final int index;
  final int projectId;
  final Color stageColor;
  final Future<void> Function(int processId, String status) onUpdateStatus;
  final Future<void> Function(int processId) onRemoveStatus;
  final Future<void> Function() onRefresh;

  const _OcProcessCard({
    required this.process,
    required this.index,
    required this.projectId,
    required this.stageColor,
    required this.onUpdateStatus,
    required this.onRemoveStatus,
    required this.onRefresh,
  });

  @override
  State<_OcProcessCard> createState() => _OcProcessCardState();
}

class _OcProcessCardState extends State<_OcProcessCard> {
  bool _isUpdating = false;

  Color get _cardBorderColor {
    if (widget.process.isCompleted) return const Color(0xFF22C55E);
    if (widget.process.isNa) return const Color(0xFF94A3B8);
    return const Color(0xFFE2E8F0);
  }

  Color get _cardBgColor {
    if (widget.process.isCompleted) return const Color(0xFFF0FDF4);
    if (widget.process.isNa) return const Color(0xFFF8FAFC);
    return Colors.white;
  }

  Future<void> _onCompletedToggle(bool checked) async {
    if (_isUpdating) return;

    final confirmed = await _confirmStatusDialog(
      context: context,
      processName: widget.process.processName,
      isCompletedAction: checked,
      isNaAction: false,
      isRemoving: !checked,
    );

    if (!confirmed) return;

    setState(() => _isUpdating = true);
    try {
      if (checked) {
        await widget.onUpdateStatus(widget.process.processId, 'Completed');
      } else {
        await widget.onRemoveStatus(widget.process.processId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _onNaToggle(bool checked) async {
    if (_isUpdating) return;

    final confirmed = await _confirmStatusDialog(
      context: context,
      processName: widget.process.processName,
      isCompletedAction: false,
      isNaAction: checked,
      isRemoving: !checked,
    );

    if (!confirmed) return;

    setState(() => _isUpdating = true);
    try {
      if (checked) {
        await widget.onUpdateStatus(widget.process.processId, 'N.A');
      } else {
        await widget.onRemoveStatus(widget.process.processId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<bool> _confirmStatusDialog({
    required BuildContext context,
    required String processName,
    required bool isCompletedAction,
    required bool isNaAction,
    required bool isRemoving,
  }) async {
    final bool isCompleted = isCompletedAction && !isRemoving;
    final bool isNa = isNaAction && !isRemoving;

    final Color headerColor = isCompleted
        ? const Color(0xFF22C55E)
        : isNa
            ? const Color(0xFFEF4444)
            : const Color(0xFF6B7280);

    final Color lightBg = isCompleted
        ? const Color(0xFFF0FDF4)
        : isNa
            ? const Color(0xFFFEF2F2)
            : const Color(0xFFF8FAFC);

    final Color borderColor = isCompleted
        ? const Color(0xFFBBF7D0)
        : isNa
            ? const Color(0xFFFECACA)
            : const Color(0xFFE2E8F0);

    final IconData topIcon = isCompleted
        ? Icons.check_circle_outline_rounded
        : isNa
            ? Icons.delete_outline_rounded
            : Icons.info_outline_rounded;

    final String title = isCompleted
        ? 'Mark as Completed'
        : isNa
            ? 'Mark as N.A'
            : 'Remove Status';

    final String subtitle = 'OC progress process';

    final String note = isCompleted
        ? 'This action can be undone later if needed.'
        : isNa
            ? 'The current status will be cleared from this process.'
            : 'The selected status will be removed from this process.';

    final String confirmLabel = isCompleted
        ? 'Confirm'
        : isNa
            ? 'Confirm'
            : 'Remove';

    final IconData confirmIcon = isCompleted
        ? Icons.check_rounded
        : isNa
            ? Icons.delete_outline_rounded
            : Icons.close_rounded;

    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'status_confirm',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) {
        return SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 380),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 32,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                        decoration: BoxDecoration(
                          color: headerColor,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(22),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                topIcon,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.86),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Process',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 13,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Text(
                                processName.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                color: lightBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: borderColor),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    isCompleted
                                        ? Icons.info_outline_rounded
                                        : isNa
                                            ? Icons.warning_amber_rounded
                                            : Icons.remove_circle_outline_rounded,
                                    size: 16,
                                    color: headerColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      note,
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1.35,
                                        fontWeight: FontWeight.w500,
                                        color: headerColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF475569),
                                      side: const BorderSide(
                                        color: Color(0xFFE2E8F0),
                                      ),
                                      backgroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    icon: Icon(confirmIcon, size: 16),
                                    label: Text(
                                      confirmLabel,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: headerColor,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );

    return result ?? false;
  }

  void _showUploadDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OcUploadDialog(
        process: widget.process,
        projectId: widget.projectId,
        onUploaded: widget.onRefresh,
      ),
    );
  }

  void _viewFile() {
    final url = widget.process.fileInfo?.filePath;
    if (url == null || url.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'View Document',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.insert_drive_file_outlined,
              size: 40,
              color: Color(0xFF3B82F6),
            ),
            const SizedBox(height: 8),
            Text(
              widget.process.fileInfo?.fileName ?? 'Document',
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.process.fileInfo?.fileSize ?? ''} • ${widget.process.fileInfo?.uploadedDate ?? ''}',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF94A3B8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: _cardBgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _cardBorderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: widget.stageColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${widget.index + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: widget.stageColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.process.processName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      if (widget.process.isCompleted)
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Text(
                            'Completed',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF22C55E),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else if (widget.process.isNa)
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Text(
                            'Not Applicable',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_isUpdating)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: widget.stageColor,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFEFF3F8)),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _ActionCheckbox(
                    label: 'Completed',
                    icon: Icons.check_circle_outline,
                    activeColor: const Color(0xFF22C55E),
                    value: widget.process.isCompleted,
                    enabled: !_isUpdating && !widget.process.isNa,
                    onChanged: _onCompletedToggle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionCheckbox(
                    label: 'N.A',
                    icon: Icons.remove_circle_outline,
                    activeColor: const Color(0xFF94A3B8),
                    value: widget.process.isNa,
                    enabled: !_isUpdating && !widget.process.isCompleted,
                    onChanged: _onNaToggle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (widget.process.hasFile) ...[
                  _smallBtn(
                    label: 'View',
                    icon: Icons.visibility_outlined,
                    color: const Color(0xFF22C55E),
                    onTap: _viewFile,
                  ),
                  const SizedBox(width: 6),
                  _smallBtn(
                    label: 'Replace',
                    icon: Icons.upload_rounded,
                    color: const Color(0xFF3B82F6),
                    onTap: widget.process.isNa ? null : _showUploadDialog,
                    disabled: widget.process.isNa,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.process.fileInfo?.fileName ?? '',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF94A3B8),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else ...[
                  _smallBtn(
                    label: widget.process.isNa ? 'Disabled (N.A)' : 'Upload',
                    icon: Icons.upload_file_outlined,
                    color: widget.process.isNa
                        ? const Color(0xFF94A3B8)
                        : widget.stageColor,
                    onTap: widget.process.isNa ? null : _showUploadDialog,
                    disabled: widget.process.isNa,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallBtn({
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
    bool disabled = false,
  }) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: disabled
              ? const Color(0xFFF1F5F9)
              : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: disabled
                ? const Color(0xFFE2E8F0)
                : color.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: disabled ? const Color(0xFFCBD5E1) : color,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: disabled ? const Color(0xFFCBD5E1) : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ActionCheckbox — styled checkbox for Completed / N.A
// ─────────────────────────────────────────────────────────────────────────────

class _ActionCheckbox extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color activeColor;
  final bool value;
  final bool enabled;
  final void Function(bool) onChanged;

  const _ActionCheckbox({
    required this.label,
    required this.icon,
    required this.activeColor,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled ? activeColor : const Color(0xFFCBD5E1);
    final bgColor =
        value ? effectiveColor.withValues(alpha: 0.1) : const Color(0xFFF8FAFC);

    return GestureDetector(
      onTap: enabled ? () => onChanged(!value) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: value ? effectiveColor : const Color(0xFFE2E8F0),
            width: value ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: value ? effectiveColor : Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: value ? effectiveColor : const Color(0xFFD1D5DB),
                ),
              ),
              child: value
                  ? const Icon(Icons.check, size: 11, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 6),
            Icon(icon, size: 13, color: effectiveColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: effectiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _OcUploadDialog — file upload bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _OcUploadDialog extends StatefulWidget {
  final OcProcessModel process;
  final int projectId;
  final Future<void> Function() onUploaded;

  const _OcUploadDialog({
    required this.process,
    required this.projectId,
    required this.onUploaded,
  });

  @override
  State<_OcUploadDialog> createState() => _OcUploadDialogState();
}

class _OcUploadDialogState extends State<_OcUploadDialog> {
  PlatformFile? _pickedFile;
  DateTime _uploadDate = DateTime.now();
  bool _isUploading = false;
  bool _isPicking = false;

  String get _isoDate =>
      '${_uploadDate.year}-${_uploadDate.month.toString().padLeft(2, '0')}-${_uploadDate.day.toString().padLeft(2, '0')}';

  String get _fmtDate =>
      '${_uploadDate.day.toString().padLeft(2, '0')}/${_uploadDate.month.toString().padLeft(2, '0')}/${_uploadDate.year}';

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open file picker: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
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
          colorScheme: ColorScheme.light(primary: AppColors.primaryGreen),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _uploadDate = picked);
    }
  }

  Future<void> _submit() async {
    if (_isUploading) return;
    if (_pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a file'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    final filePath = _pickedFile!.path;
    if (filePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File path unavailable. Please pick again.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final token = await AuthStorageService.getToken();
      if (token == null || token.isEmpty) throw Exception('Session expired.');

      final mimeType = lookupMimeType(filePath) ?? 'application/octet-stream';
      final mimeParts = mimeType.split('/');
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${_pickedFile!.name}';

      final url = Uri.parse(
        '${ApiConstants.baseUrl}/api/mobile/oc-progress/upload-file',
      );

      final request = http.MultipartRequest('POST', url)
        ..headers.addAll({
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        })
        ..fields['project_id'] = widget.projectId.toString()
        ..fields['process_id'] = widget.process.processId.toString()
        ..fields['upload_date'] = _isoDate
        ..files.add(
          await http.MultipartFile.fromPath(
            'document',
            filePath,
            filename: fileName,
            contentType: MediaType(mimeParts[0], mimeParts[1]),
          ),
        );

      final streamed =
          await request.send().timeout(const Duration(seconds: 90));
      final body = await streamed.stream.bytesToString();

      dynamic decoded;
      try {
        decoded = jsonDecode(body);
      } catch (_) {
        decoded = {};
      }

      if (!mounted) return;

      if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (decoded is Map ? decoded['message']?.toString() : null) ??
                  'File uploaded successfully',
            ),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
        await widget.onUploaded();
      } else {
        String msg =
            (decoded is Map ? decoded['message']?.toString() : null) ??
                'Upload failed (${streamed.statusCode})';

        if (decoded is Map && decoded['errors'] is Map) {
          final errors = decoded['errors'] as Map;
          if (errors.isNotEmpty && errors.values.first is List) {
            msg = (errors.values.first as List).first.toString();
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
        return Icons.archive_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.upload_file_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Upload OC Document',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        widget.process.processName,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: Color(0xFF2563EB),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Supported: JPG, PNG, ZIP, PDF, DOC, DOCX (Max 10MB)',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Document *',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _isPicking ? null : _pickFile,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: _pickedFile != null
                            ? AppColors.primaryGreen.withValues(alpha: 0.05)
                            : const Color(0xFFF8FAFC),
                        border: Border.all(
                          color: _pickedFile != null
                              ? AppColors.primaryGreen
                              : const Color(0xFFD1D5DB),
                          width: _pickedFile != null ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _isPicking
                          ? Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                            )
                          : _pickedFile != null
                              ? Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryGreen
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        _fileIcon(_pickedFile!.extension),
                                        color: AppColors.primaryGreen,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _pickedFile!.name,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1E293B),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _formatSize(_pickedFile!.size),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () =>
                                          setState(() => _pickedFile = null),
                                      child: const Icon(
                                        Icons.close,
                                        size: 18,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    Icon(
                                      Icons.cloud_upload_outlined,
                                      size: 34,
                                      color: AppColors.primaryGreen,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Tap to select file',
                                      style: TextStyle(
                                        color: AppColors.primaryGreen,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'PDF, DOC, DOCX, JPG, PNG, ZIP',
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Upload Date *',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFD1D5DB)),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _fmtDate,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                            color: Color(0xFF6B7280),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isUploading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isUploading ? null : _submit,
                    icon: _isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.upload_rounded, size: 16),
                    label: Text(
                      _isUploading ? 'Uploading…' : 'Upload Document',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}