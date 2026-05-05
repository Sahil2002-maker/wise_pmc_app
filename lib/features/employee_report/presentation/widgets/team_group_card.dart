// lib/features/employee_report/presentation/widgets/team_group_card.dart

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/employee_report_models.dart';

typedef CellTapCallback = void Function(
    int employeeId, String employeeName, String date);

/// Displays one team as a card with a scrollable date-column matrix.
class TeamGroupCard extends StatelessWidget {
  final ReportTeamGroup group;
  final List<String> dates;
  final CellTapCallback onCellTap;

  const TeamGroupCard({
    super.key,
    required this.group,
    required this.dates,
    required this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TeamHeader(group: group),
            if (group.members.isEmpty)
              const Padding(
                padding: EdgeInsets.all(14),
                child: Text('No members found.',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              )
            else
              _MemberMatrix(
                  group: group, dates: dates, onCellTap: onCellTap),
          ],
        ),
      ),
    );
  }
}

// ── Team header ───────────────────────────────────────────────────────────────

class _TeamHeader extends StatelessWidget {
  final ReportTeamGroup group;
  const _TeamHeader({required this.group});

  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(group.teamColor);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, _darken(color, 0.1)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.group_outlined,
                  color: Colors.white, size: 17),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.teamName.toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5)),
                if (group.teamLeaderName.isNotEmpty &&
                    group.teamLeaderName != 'No Leader')
                  Text(
                    '⭐ ${group.teamLeaderName}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500),
                  ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('${group.members.length} member(s)',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Matrix with fixed employee column + scrollable date columns ───────────────

class _MemberMatrix extends StatelessWidget {
  final ReportTeamGroup group;
  final List<String> dates;
  final CellTapCallback onCellTap;

  const _MemberMatrix({
    required this.group,
    required this.dates,
    required this.onCellTap,
  });

  static const double _empColW  = 130.0;
  static const double _dateColW = 56.0;
  static const double _rowH     = 44.0;
  static const double _headerH  = 38.0;

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Padding(
      padding: const EdgeInsets.all(0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed left column
          SizedBox(
            width: _empColW,
            child: Column(
              children: [
                // Header spacer
                Container(
                  height: _headerH,
                  color: const Color(0xFFF8F9FB),
                  alignment: Alignment.center,
                  child: const Text('Employee',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B))),
                ),
                ...group.members.map((m) => _EmployeeCell(
                    member: m, height: _rowH)),
              ],
            ),
          ),
          Container(width: 1, color: const Color(0xFFE2E8F0)),
          // Scrollable date columns
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: dates.length * _dateColW,
                child: Column(
                  children: [
                    // Date headers
                    SizedBox(
                      height: _headerH,
                      child: Row(
                        children: dates.map((d) {
                          final isToday = d == today;
                          final dt = DateTime.tryParse(d);
                          final isWeekend = dt != null &&
                              (dt.weekday == 6 || dt.weekday == 7);
                          return _DateHeader(
                            date:      d,
                            isToday:   isToday,
                            isWeekend: isWeekend,
                            width:     _dateColW,
                          );
                        }).toList(),
                      ),
                    ),
                    // Data rows
                    ...group.members.map((m) => SizedBox(
                          height: _rowH,
                          child: Row(
                            children: dates.map((d) {
                              final count = m.taskCounts[d] ?? 0;
                              final isToday = d == today;
                              return _CountCell(
                                count:      count,
                                isToday:    isToday,
                                width:      _dateColW,
                                onTap: count > 0
                                    ? () => onCellTap(m.id, m.name, d)
                                    : null,
                              );
                            }).toList(),
                          ),
                        )),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  final String date;
  final bool isToday;
  final bool isWeekend;
  final double width;

  const _DateHeader({
    required this.date,
    required this.isToday,
    required this.isWeekend,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(date);
    final day  = dt != null ? DateFormat('dd').format(dt) : '';
    final mon  = dt != null ? DateFormat('MMM').format(dt) : '';

    Color bg   = const Color(0xFFF8F9FB);
    Color text = const Color(0xFF64748B);
    if (isToday) {
      bg   = const Color(0xFF28C76F);
      text = Colors.white;
    } else if (isWeekend) {
      bg   = const Color(0xFFF1F5F9);
      text = const Color(0xFF94A3B8);
    }

    return Container(
      width: width,
      color: bg,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(day,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: text)),
          Text(mon,
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: text.withValues(alpha: 0.8))),
        ],
      ),
    );
  }
}

class _EmployeeCell extends StatelessWidget {
  final ReportMember member;
  final double height;

  const _EmployeeCell({required this.member, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
            bottom: BorderSide(color: const Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          if (member.isLeader) ...[
            const Icon(Icons.star_rounded,
                size: 12, color: Color(0xFFF59E0B)),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              member.name,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: member.isLeader
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: const Color(0xFF1E293B)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountCell extends StatelessWidget {
  final int count;
  final bool isToday;
  final double width;
  final VoidCallback? onTap;

  const _CountCell({
    required this.count,
    required this.isToday,
    required this.width,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color textColor;
    Color bgColor;

    if (count == 0) {
      textColor = const Color(0xFFEF4444);
      bgColor   = const Color(0xFFFEF2F2);
    } else if (count <= 2) {
      textColor = const Color(0xFFF59E0B);
      bgColor   = const Color(0xFFFFFBEB);
    } else if (count <= 5) {
      textColor = const Color(0xFF3B82F6);
      bgColor   = const Color(0xFFEFF6FF);
    } else {
      textColor = const Color(0xFF22C55E);
      bgColor   = const Color(0xFFF0FDF4);
    }

    if (isToday) {
      bgColor = const Color(0xFFDCFCE7);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: double.infinity,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            bottom: BorderSide(color: const Color(0xFFF1F5F9)),
            left:   BorderSide(color: const Color(0xFFE2E8F0)),
          ),
        ),
        alignment: Alignment.center,
        child: count > 0
            ? Container(
                width: 28,
                height: 24,
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text('$count',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: textColor)),
              )
            : Text('0',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textColor.withValues(alpha: 0.6))),
      ),
    );
  }
}

// ── Color utilities ───────────────────────────────────────────────────────────

Color _hexToColor(String hex) {
  final cleaned = hex.replaceAll('#', '');
  if (cleaned.length == 6) {
    return Color(int.parse('FF$cleaned', radix: 16));
  }
  return const Color(0xFF77DD77);
}

Color _darken(Color color, double amount) {
  final hsl    = HSLColor.fromColor(color);
  final darker = hsl.withLightness(
      (hsl.lightness - amount).clamp(0.0, 1.0));
  return darker.toColor();
}