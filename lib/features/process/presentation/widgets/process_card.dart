// lib/features/process/presentation/widgets/process_card.dart

import 'package:flutter/material.dart';

import '../../data/models/process_model.dart';

class ProcessCard extends StatelessWidget {
  final ProcessModel process;
  final int serialNo;
  final String stageKey;
  final bool isDeleting;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTeam;

  const ProcessCard({
    super.key,
    required this.process,
    required this.serialNo,
    required this.stageKey,
    required this.isDeleting,
    required this.onEdit,
    required this.onDelete,
    required this.onTeam,
  });

  // ── Stage colour palette ──────────────────────────────────────────────────

  Color get _stageColor {
    switch (stageKey) {
      case 'pmc_application':
        return const Color(0xFF5E50EE);
      case 'stage1':
        return const Color(0xFF0EA5E9);
      case 'stage2':
        return const Color(0xFF10B981);
      case 'stage3':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF5E50EE);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isDeleting ? 0.5 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            children: [
              // Coloured top accent bar
              Container(
                height: 3,
                color: _stageColor,
              ),

              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header row ──────────────────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Serial badge
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _stageColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '$serialNo',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: _stageColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Process name + heading
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                process.processName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              if (process.heading != null &&
                                  process.heading!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  process.heading!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Deadline chip
                        _DeadlineChip(day: process.day),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // ── Team row ────────────────────────────────────────────
                    _TeamRow(
                      workingTeamName: process.workingTeamName,
                      reviewTeamName: process.reviewTeamName,
                      stageKey: stageKey,
                    ),

                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 10),

                    // ── Action buttons ──────────────────────────────────────
                    Row(
                      children: [
                        _ActionBtn(
                          label: 'Edit',
                          icon: Icons.edit_rounded,
                          color: const Color(0xFF5E50EE),
                          onTap: isDeleting ? null : onEdit,
                        ),
                        const SizedBox(width: 8),
                        // Stage 1/2/3 show Team button; PMC Application doesn't
                        if (stageKey != 'pmc_application') ...[
                          _ActionBtn(
                            label: 'Team',
                            icon: Icons.group_rounded,
                            color: const Color(0xFF0EA5E9),
                            onTap: isDeleting ? null : onTeam,
                          ),
                          const SizedBox(width: 8),
                        ],
                        _ActionBtn(
                          label: 'Delete',
                          icon: Icons.delete_rounded,
                          color: const Color(0xFFEF4444),
                          loading: isDeleting,
                          onTap: isDeleting ? null : onDelete,
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
    );
  }
}

// ─── Deadline chip ────────────────────────────────────────────────────────────

class _DeadlineChip extends StatelessWidget {
  final int? day;
  const _DeadlineChip({this.day});

  @override
  Widget build(BuildContext context) {
    final hasDeadline = day != null && day! > 0;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: hasDeadline
            ? const Color(0xFFFFF7ED)
            : const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasDeadline
              ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
              : const Color(0xFFE8EAFF),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_rounded,
            size: 11,
            color: hasDeadline
                ? const Color(0xFFF59E0B)
                : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 3),
          Text(
            hasDeadline ? '$day day${day! > 1 ? 's' : ''}' : 'No deadline',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: hasDeadline
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Team row ─────────────────────────────────────────────────────────────────

class _TeamRow extends StatelessWidget {
  final String? workingTeamName;
  final String? reviewTeamName;
  final String stageKey;

  const _TeamRow({
    this.workingTeamName,
    this.reviewTeamName,
    required this.stageKey,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        if (workingTeamName != null)
          _TeamBadge(
            label: workingTeamName!,
            prefix: 'Working',
            color: const Color(0xFF5E50EE),
          ),
        if (reviewTeamName != null && stageKey != 'pmc_application')
          _TeamBadge(
            label: reviewTeamName!,
            prefix: 'Review',
            color: const Color(0xFF0EA5E9),
          ),
        if (workingTeamName == null)
          const _TeamBadge(
            label: 'No team assigned',
            prefix: null,
            color: Color(0xFF94A3B8),
          ),
      ],
    );
  }
}

class _TeamBadge extends StatelessWidget {
  final String label;
  final String? prefix;
  final Color color;
  const _TeamBadge({required this.label, this.prefix, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            prefix == 'Working'
                ? Icons.build_circle_rounded
                : prefix == 'Review'
                    ? Icons.rate_review_rounded
                    : Icons.info_outline_rounded,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 4),
          if (prefix != null)
            Text(
              '$prefix: ',
              style: TextStyle(
                  fontSize: 10,
                  color: color.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500),
            ),
          Text(
            label,
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ─── Action button ────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool loading;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: loading
          ? SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : Icon(icon, size: 13),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: color.withValues(alpha: 0.4),
        elevation: 0,
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}