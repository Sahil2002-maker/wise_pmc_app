// lib/features/dashboard/presentation/widgets/project_card.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/models/project_dashboard_model.dart';
import '../../../../core/constants/app_colors.dart';

class ProjectCard extends StatefulWidget {
  final ProjectDashboardModel project;
  final VoidCallback? onViewTap;

  const ProjectCard({
    super.key,
    required this.project,
    this.onViewTap,
  });

  @override
  State<ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<ProjectCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.025).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _statusColor() {
    final pct = widget.project.progressPercentage;
    if (pct >= 80) return AppColors.primaryGreen;
    if (pct >= 40) return const Color(0xFFFF9F43);
    return const Color(0xFFE74C3C);
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _hovered = true);
        _controller.forward();
      },
      onExit: (_) {
        setState(() => _hovered = false);
        _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _hovered
                    ? AppColors.primaryGreen.withOpacity(0.12)
                    : Colors.black.withOpacity(0.05),
                blurRadius: _hovered ? 20 : 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: _hovered
                  ? AppColors.primaryGreen.withOpacity(0.15)
                  : const Color(0xFFEEF1F8),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title row ──────────────────────────────────────────
              Row(
                children: [
                  // Project icon
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primaryGreen.withOpacity(0.15),
                          AppColors.primaryGreen.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.domain_rounded,
                      color: AppColors.primaryGreen,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.societyName.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A2340),
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _statusColor(),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              project.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                color: _statusColor(),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // View button
                  GestureDetector(
                    onTap: widget.onViewTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF43C880), Color(0xFF2DA765)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryGreen.withOpacity(0.30),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Text(
                        'View',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Donut chart ────────────────────────────────────────
              Center(
                child: SizedBox(
                  width: 130,
                  height: 130,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(130, 130),
                        painter: _DonutPainter(
                          completed: project.completedTasks,
                          assigned:  project.assignedTasks,
                          pending:   project.pendingTasks,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${project.progressPercentage}%',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: _statusColor(),
                              height: 1.1,
                            ),
                          ),
                          const Text(
                            'complete',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF8E9BB5),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ── Progress bar ───────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: (project.progressPercentage / 100).clamp(0.0, 1.0),
                  backgroundColor: const Color(0xFFEEF1F8),
                  valueColor: AlwaysStoppedAnimation<Color>(_statusColor()),
                ),
              ),

              const SizedBox(height: 14),

              // ── Stats row ──────────────────────────────────────────
              Row(
                children: [
                  _statChip(
                    color: AppColors.completed,
                    label: 'Done',
                    value: '${project.completedTasks}',
                  ),
                  const SizedBox(width: 8),
                  _statChip(
                    color: AppColors.assigned,
                    label: 'Active',
                    value: '${project.assignedTasks}',
                  ),
                  const SizedBox(width: 8),
                  _statChip(
                    color: AppColors.pending,
                    label: 'Pending',
                    value: '${project.pendingTasks}',
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ── Total tasks ────────────────────────────────────────
              Center(
                child: Text(
                  '${project.completedTasks} / ${project.totalProcesses} tasks completed',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8E9BB5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statChip({
    required Color color,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                color: Color(0xFF8E9BB5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Donut painter ─────────────────────────────────────────────────────────

class _DonutPainter extends CustomPainter {
  final int completed;
  final int assigned;
  final int pending;

  const _DonutPainter({
    required this.completed,
    required this.assigned,
    required this.pending,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total       = completed + assigned + pending;
    const strokeWidth = 16.0;
    const gap         = 0.03; // radians gap between segments

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth / 2;
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    // Background track
    final bgPaint = Paint()
      ..color = const Color(0xFFEEF1F8)
      ..style  = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap   = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    if (total <= 0) return;

    final values = [completed, assigned, pending];
    final colors = [AppColors.completed, AppColors.assigned, AppColors.pending];
    double startAngle = -math.pi / 2;

    for (int i = 0; i < values.length; i++) {
      if (values[i] == 0) continue;
      final sweepAngle =
          (values[i] / total) * math.pi * 2 - gap;
      final paint = Paint()
        ..color      = colors[i]
        ..style      = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap  = StrokeCap.round;

      canvas.drawArc(arcRect, startAngle + gap / 2, sweepAngle, false, paint);
      startAngle += sweepAngle + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      completed != old.completed ||
      assigned  != old.assigned  ||
      pending   != old.pending;
}