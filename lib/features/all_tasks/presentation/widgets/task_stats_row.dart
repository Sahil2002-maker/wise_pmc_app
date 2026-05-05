import 'package:flutter/material.dart';
import '../../data/models/all_task_models.dart';

class TaskStatsRow extends StatelessWidget {
  final TaskStatsCombined stats;
  const TaskStatsRow({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          _StatCard(label: 'Total',     value: stats.statistics.totalTasks,     color: const Color(0xFF3B82F6)),
          const SizedBox(width: 8),
          _StatCard(label: 'Completed', value: stats.statistics.completedTasks, color: const Color(0xFF22C55E)),
          const SizedBox(width: 8),
          _StatCard(label: 'Pending',   value: stats.statistics.pendingTasks,   color: const Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          _StatCard(label: 'Overdue',   value: stats.statistics.overdueTasks,   color: const Color(0xFFEF4444)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int    value;
  final Color  color;

  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}