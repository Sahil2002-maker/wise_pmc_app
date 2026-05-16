// lib/features/development_process/presentation/widgets/dev_process_card.dart
//
// Card widget for a single Development Process row.
//
// FIX 1: RenderFlex overflowed by 29 pixels on the right.
//   – Team name text wrapped in Flexible to prevent overflow.
//   – Stage label text wrapped in Flexible.
//   – Actions column given a fixed-width SizedBox so the Expanded
//     content never crowds it.
//
// FIX 2 (dart errors):
//   – process.teamColor is now non-nullable (String, not String?) so the
//     null-coalescing branch is removed; _hexColor() handles bad values.
//   – _stageColor() now accepts int (process.stageNum) instead of String.
//   – process.stageLabel getter is used directly (added to model).
//   – All .withOpacity() calls replaced with .withValues(alpha: …)
//     to silence dart(deprecated_member_use) warnings.

import 'package:flutter/material.dart';
import '../../data/models/dev_process_model.dart';

class DevProcessCard extends StatelessWidget {
  final DevProcessModel process;
  final int serialNo;
  final bool isDeleting;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const DevProcessCard({
    super.key,
    required this.process,
    required this.serialNo,
    required this.isDeleting,
    required this.onEdit,
    required this.onDelete,
  });

  static const Color _accent = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    // FIX: teamColor is non-nullable String — no null check needed.
    final teamColor = _hexColor(process.teamColor);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isDeleting ? 0.5 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              // FIX: withOpacity → withValues
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Top accent bar in team color ───────────────────────────
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: teamColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Order badge ──────────────────────────────────────
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          // FIX: withOpacity → withValues
                          _accent.withValues(alpha: 0.15),
                          _accent.withValues(alpha: 0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${process.orderNo}',
                        style: const TextStyle(
                          color: _accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // ── Name + team ──────────────────────────────────────
                  // FIX: Expanded constrains this column so it never
                  //      pushes the action buttons off-screen.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // FIX: softWrap + overflow so long names wrap
                        //      instead of forcing the row wider.
                        Text(
                          process.processName,
                          softWrap: true,
                          overflow: TextOverflow.visible,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (process.teamName != null)
                          // FIX: wrap in a Row that clips its content
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: teamColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              // FIX: Flexible lets the text shrink/wrap
                              //      rather than overflow.
                              Flexible(
                                child: Text(
                                  process.teamName!,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: teamColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 6),
                        // FIX: wrap the stage chip in a Row so it is
                        //      intrinsically sized and never overflows.
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                // FIX: _stageColor now takes int (stageNum)
                                // FIX: withOpacity → withValues
                                color: _stageColor(process.stageNum)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                // FIX: use stageLabel getter from model
                                process.stageLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  // FIX: _stageColor now takes int (stageNum)
                                  color: _stageColor(process.stageNum),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── Actions ──────────────────────────────────────────
                  // FIX: give the actions a fixed width so the Expanded
                  //      column above always has a guaranteed boundary.
                  SizedBox(
                    width: 76, // 34 + 8 gap + 34
                    child: !isDeleting
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _iconBtn(
                                icon: Icons.edit_rounded,
                                color: const Color(0xFFF59E0B),
                                onTap: onEdit,
                                tooltip: 'Edit',
                              ),
                              const SizedBox(width: 8),
                              _iconBtn(
                                icon: Icons.delete_outline_rounded,
                                color: const Color(0xFFEF4444),
                                onTap: onDelete,
                                tooltip: 'Delete',
                              ),
                            ],
                          )
                        : const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFEF4444),
                              ),
                            ),
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

  Widget _iconBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            // FIX: withOpacity → withValues
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
      ),
    );
  }

  Color _hexColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF43C880);
    }
  }

  // FIX: parameter changed from String to int to match process.stageNum
  Color _stageColor(int stage) {
    const colors = [
      Color(0xFF6366F1), // Stage 0 — indigo
      Color(0xFF0EA5E9), // Stage 1 — sky
      Color(0xFF10B981), // Stage 2 — emerald
      Color(0xFFF59E0B), // Stage 3 — amber
    ];
    return colors[stage.clamp(0, 3)];
  }
}