import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/all_task_models.dart';

class TaskListView extends StatelessWidget {
  final List<TaskItem>  tasks;
  final ScrollController scrollController;
  final bool            isLoadingMore;

  const TaskListView({
    super.key,
    required this.tasks,
    required this.scrollController,
    required this.isLoadingMore,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      itemCount: tasks.length + (isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == tasks.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                  color: AppColors.primaryGreen, strokeWidth: 2),
            ),
          );
        }
        return _TaskCard(task: tasks[index]);
      },
    );
  }
}

class _TaskCard extends StatelessWidget {
  final TaskItem task;
  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final isProject   = task.taskType == 'project';
    final isCompleted = task.isCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isProject
                        ? const Color(0xFF3B82F6).withValues(alpha: 0.1)
                        : AppColors.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    isProject ? Icons.folder_outlined : Icons.assignment_outlined,
                    color: isProject ? const Color(0xFF3B82F6) : AppColors.primaryGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.taskName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      if (isProject && task.processName != null) ...[
                        const SizedBox(height: 2),
                        Text(task.processName!,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textMutedDark)),
                      ],
                      if (!isProject && task.createdBy != null) ...[
                        const SizedBox(height: 2),
                        Text('By ${task.createdBy}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textMutedDark)),
                      ],
                    ],
                  ),
                ),
                _StatusChip(isCompleted: isCompleted),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.borderColor),
            const SizedBox(height: 10),

            // ── Date row ─────────────────────────────────────────────────
            Row(
              children: [
                _DateBadge(
                    icon: Icons.calendar_today_outlined,
                    label: 'Assigned',
                    value: task.assignedDate),
                const SizedBox(width: 12),
                _DateBadge(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Completed',
                    value: task.completedDate),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isProject
                        ? const Color(0xFF3B82F6).withValues(alpha: 0.1)
                        : AppColors.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isProject ? 'Project' : 'General',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isProject
                          ? const Color(0xFF3B82F6)
                          : AppColors.primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
            // Upload button REMOVED
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isCompleted;
  const _StatusChip({required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isCompleted
            ? const Color(0xFF22C55E).withValues(alpha: 0.12)
            : const Color(0xFFF59E0B).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCompleted ? Icons.check_circle_rounded : Icons.access_time_rounded,
            size: 12,
            color: isCompleted ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 4),
          Text(
            isCompleted ? 'Completed' : 'Pending',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isCompleted ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;

  const _DateBadge({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppColors.textMutedDark),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 10, color: AppColors.textMutedDark)),
            Text(value,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark)),
          ],
        ),
      ],
    );
  }
}