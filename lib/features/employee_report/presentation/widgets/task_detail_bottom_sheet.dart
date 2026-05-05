// lib/features/employee_report/presentation/widgets/task_detail_bottom_sheet.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/utils/api_exception.dart';
import '../../data/models/employee_report_models.dart';

/// Bottom sheet that shows process tasks + general tasks for one employee/date.
class TaskDetailBottomSheet extends StatefulWidget {
  final int employeeId;
  final String employeeName;
  final String date;

  const TaskDetailBottomSheet({
    super.key,
    required this.employeeId,
    required this.employeeName,
    required this.date,
  });

  @override
  State<TaskDetailBottomSheet> createState() =>
      _TaskDetailBottomSheetState();
}

class _TaskDetailBottomSheetState extends State<TaskDetailBottomSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  TaskDetailResult? _result;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error   = null;
    });
    try {
      final result = await ApiService.fetchEmployeeTaskDetails(
        employeeId: widget.employeeId,
        date:       widget.date,
      );
      if (mounted) setState(() {
        _result  = result;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() {
        _error   = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final dt = DateTime.tryParse(widget.date);
    final dateLabel = dt != null
        ? DateFormat('EEEE, dd MMM yyyy').format(dt)
        : widget.date;

    return Container(
      height: mq.size.height * 0.82,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          _buildSheetHeader(dateLabel),
          if (!_loading && _result != null) _buildTabBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2)),
        ),
      ),
    );
  }

  Widget _buildSheetHeader(String dateLabel) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AppColors.sidebarActiveStart,
                  AppColors.sidebarActiveEnd
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.person_outline_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.employeeName,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B)),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 11, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(dateLabel,
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded,
                color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final pCount = _result!.processTasks.length;
    final gCount = _result!.generalTasks.length;

    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabCtrl,
        labelColor: AppColors.primaryGreen,
        unselectedLabelColor: const Color(0xFF94A3B8),
        indicatorColor: AppColors.primaryGreen,
        indicatorWeight: 2.5,
        labelStyle: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w500),
        tabs: [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Process Tasks'),
                const SizedBox(width: 6),
                _badge(pCount, AppColors.primaryGreen),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('General Tasks'),
                const SizedBox(width: 6),
                _badge(gCount, const Color(0xFF3B82F6)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('$count',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child:
              CircularProgressIndicator(color: AppColors.primaryGreen));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 44, color: Color(0xFFEF4444)),
              const SizedBox(height: 10),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
              ),
            ],
          ),
        ),
      );
    }

    return TabBarView(
      controller: _tabCtrl,
      children: [
        _ProcessTaskTab(tasks: _result!.processTasks),
        _GeneralTaskTab(tasks: _result!.generalTasks),
      ],
    );
  }
}

// ── Process Tasks Tab ──────────────────────────────────────────────────────────

class _ProcessTaskTab extends StatelessWidget {
  final List<ReportProcessTask> tasks;
  const _ProcessTaskTab({required this.tasks});

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return _emptyState('No process tasks for this date.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final t = tasks[i];
        return _TaskCard(
          title:    t.processName,
          subtitle: t.projectName,
          status:   t.status,
          deadline: t.deadline,
          icon:     Icons.account_tree_outlined,
        );
      },
    );
  }
}

// ── General Tasks Tab ──────────────────────────────────────────────────────────

class _GeneralTaskTab extends StatelessWidget {
  final List<ReportGeneralTask> tasks;
  const _GeneralTaskTab({required this.tasks});

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return _emptyState('No general tasks for this date.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final t = tasks[i];
        return _TaskCard(
          title:    t.taskName,
          subtitle: t.taskDescription,
          status:   t.status,
          deadline: t.taskDeadline,
          icon:     Icons.check_box_outlined,
        );
      },
    );
  }
}

// ── Shared task card ──────────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String status;
  final String? deadline;
  final IconData icon;

  const _TaskCard({
    required this.title,
    this.subtitle,
    required this.status,
    this.deadline,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusLabel, statusBg) = switch (status) {
      'completed' => (
          const Color(0xFF22C55E),
          'Completed',
          const Color(0xFFF0FDF4)
        ),
      'overdue' => (
          const Color(0xFFEF4444),
          'Overdue',
          const Color(0xFFFEF2F2)
        ),
      _ => (
          const Color(0xFFF59E0B),
          'Pending',
          const Color(0xFFFFFBEB)
        ),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: statusBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B))),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!,
                      style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w400),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2),
                ],
                if (deadline != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.schedule_outlined,
                          size: 11,
                          color: statusColor.withValues(alpha: 0.8)),
                      const SizedBox(width: 4),
                      Text('Due: $deadline',
                          style: TextStyle(
                              fontSize: 11,
                              color: statusColor,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(statusLabel,
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: statusColor)),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

Widget _emptyState(String msg) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.inbox_outlined, size: 44, color: Colors.grey.shade400),
        const SizedBox(height: 10),
        Text(msg,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
      ],
    ),
  );
}