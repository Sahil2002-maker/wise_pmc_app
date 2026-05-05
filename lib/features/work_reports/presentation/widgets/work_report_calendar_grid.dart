import 'package:flutter/material.dart';
import '../../data/models/work_report_calendar_event.dart';

class WorkReportCalendarGrid extends StatelessWidget {
  final List<WorkReportCalendarEvent> events;
  final DateTime currentMonth;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<WorkReportCalendarEvent> onEventTapped;

  const WorkReportCalendarGrid({
    super.key,
    required this.events,
    required this.currentMonth,
    required this.onMonthChanged,
    required this.onEventTapped,
  });

  Map<String, WorkReportCalendarEvent> _buildEventMap() {
    final map = <String, WorkReportCalendarEvent>{};
    for (final e in events) {
      map[e.date] = e;
    }
    return map;
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final eventMap = _buildEventMap();
    final firstDay = DateTime(currentMonth.year, currentMonth.month, 1);
    final daysInMonth =
        DateTime(currentMonth.year, currentMonth.month + 1, 0).day;

    final startWeekday = firstDay.weekday % 7;

    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    const dayHeaders = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    final totalCells = startWeekday + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return LayoutBuilder(
      builder: (context, constraints) {
        const headerH = 44.0;
        const dayRowH = 20.0;
        const spacerH = 4.0;

        final availableHeight = constraints.maxHeight;
        final rawGridH = availableHeight - headerH - dayRowH - spacerH;
        final gridH = rawGridH > 0 ? rawGridH : 0.0;
        final rowH = (gridH / rows).clamp(24.0, 64.0);

        return Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            SizedBox(
              height: headerH,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.chevron_left_rounded,
                      color: Color(0xFF2D6A4F),
                    ),
                    onPressed: () => onMonthChanged(
                      DateTime(currentMonth.year, currentMonth.month - 1),
                    ),
                  ),
                  Text(
                    '${monthNames[currentMonth.month - 1]} ${currentMonth.year}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF2D6A4F),
                    ),
                    onPressed: () => onMonthChanged(
                      DateTime(currentMonth.year, currentMonth.month + 1),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: dayRowH,
              child: Row(
                children: dayHeaders
                    .map(
                      (d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF888888),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: spacerH),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: List.generate(rows, (row) {
                    return SizedBox(
                      height: rowH,
                      child: Row(
                        children: List.generate(7, (col) {
                          final cellIndex = row * 7 + col;
                          final dayNum = cellIndex - startWeekday + 1;

                          if (dayNum < 1 || dayNum > daysInMonth) {
                            return const Expanded(child: SizedBox());
                          }

                          final date = DateTime(
                            currentMonth.year,
                            currentMonth.month,
                            dayNum,
                          );
                          final key = _fmt(date);
                          final event = eventMap[key];
                          final today = DateTime.now();

                          final isToday = date.year == today.year &&
                              date.month == today.month &&
                              date.day == today.day;

                          return Expanded(
                            child: _DayCell(
                              day: dayNum,
                              event: event,
                              isToday: isToday,
                              onTap:
                                  event != null ? () => onEventTapped(event) : null,
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final WorkReportCalendarEvent? event;
  final bool isToday;
  final VoidCallback? onTap;

  const _DayCell({
    required this.day,
    required this.event,
    required this.isToday,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasEvent = event != null;
    final props = event?.extendedProps;
    final bgColor = hasEvent ? event!.backgroundColor : Colors.transparent;

    IconData? statusIcon;
    if (props != null) {
      if (props.hasWorkReport) {
        statusIcon = Icons.check_circle_rounded;
      } else if (props.canAddReport) {
        statusIcon = Icons.edit_note_rounded;
      } else if (props.isAbsentNoCheckin) {
        statusIcon = Icons.cancel_rounded;
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(1),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: hasEvent ? bgColor.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: isToday
                ? const Color(0xFF2D6A4F)
                : hasEvent
                    ? bgColor.withOpacity(0.35)
                    : const Color(0xFFEEEEEE),
            width: isToday ? 1.4 : 1,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final h = constraints.maxHeight;
            final ultraCompact = h <= 26;
            final compact = h <= 32;
            final medium = h <= 40;

            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: ultraCompact ? 14 : compact ? 16 : 18,
                    height: ultraCompact ? 14 : compact ? 16 : 18,
                    decoration: isToday
                        ? const BoxDecoration(
                            color: Color(0xFF2D6A4F),
                            shape: BoxShape.circle,
                          )
                        : null,
                    child: Center(
                      child: Text(
                        '$day',
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          fontSize: ultraCompact ? 8 : compact ? 9 : 10,
                          fontWeight:
                              isToday ? FontWeight.w800 : FontWeight.w600,
                          color: isToday
                              ? Colors.white
                              : hasEvent
                                  ? bgColor
                                  : const Color(0xFFBBBBBB),
                        ),
                      ),
                    ),
                  ),

                  if (!compact && statusIcon != null) ...[
                    const SizedBox(height: 1),
                    Icon(
                      statusIcon,
                      size: medium ? 7 : 8,
                      color: bgColor,
                    ),
                  ],

                  if (!medium &&
                      props != null &&
                      props.workingHours > 0) ...[
                    const SizedBox(height: 1),
                    Text(
                      '${props.workingHours.toStringAsFixed(0)}h',
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.w600,
                        color: bgColor,
                        height: 1,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}