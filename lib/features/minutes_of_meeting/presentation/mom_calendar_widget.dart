// lib/features/minutes_of_meeting/presentation/mom_calendar_widget.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/models/minutes_of_meeting_model.dart';

class MomCalendarWidget extends StatelessWidget {
  final List<CalendarMeetingEvent> events;
  final DateTime currentMonth;
  final Function(DateTime) onMonthChanged;
  final Function(String date, List<CalendarMeetingEvent> events) onDayTapped;

  const MomCalendarWidget({
    super.key,
    required this.events,
    required this.currentMonth,
    required this.onMonthChanged,
    required this.onDayTapped,
  });

  Map<String, List<CalendarMeetingEvent>> get _eventsByDate {
    final map = <String, List<CalendarMeetingEvent>>{};
    for (final e in events) {
      map.putIfAbsent(e.date, () => []).add(e);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final eventMap = _eventsByDate;
    final firstDay =
        DateTime(currentMonth.year, currentMonth.month, 1);
    final daysInMonth =
        DateTime(currentMonth.year, currentMonth.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7; // Sunday = 0
    final today = DateTime.now();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(children: [
        _buildHeader(),
        _buildDayLabels(),
        _buildGrid(
            eventMap, daysInMonth, startWeekday, today),
        const SizedBox(height: 12),
      ]),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => onMonthChanged(
              DateTime(currentMonth.year, currentMonth.month - 1),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.chevron_left, color: Colors.white, size: 16),
                SizedBox(width: 2),
                Text('Prev',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
          Text(
            DateFormat('MMMM yyyy').format(currentMonth),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700),
          ),
          GestureDetector(
            onTap: () => onMonthChanged(
              DateTime(currentMonth.year, currentMonth.month + 1),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Next',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                SizedBox(width: 2),
                Icon(Icons.chevron_right, color: Colors.white, size: 16),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayLabels() {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: days
            .map((d) => Expanded(
                  child: Center(
                    child: Text(d,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B))),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildGrid(
    Map<String, List<CalendarMeetingEvent>> eventMap,
    int daysInMonth,
    int startWeekday,
    DateTime today,
  ) {
    final cells = <Widget>[];

    // Empty cells before first day
    for (int i = 0; i < startWeekday; i++) {
      cells.add(const _CalendarCell(
          dayNumber: 0, isOtherMonth: true, events: []));
    }

    // Days of current month
    for (int day = 1; day <= daysInMonth; day++) {
      final dateStr =
          '${currentMonth.year}-${currentMonth.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      final dayEvents = eventMap[dateStr] ?? [];
      final isToday = today.year == currentMonth.year &&
          today.month == currentMonth.month &&
          today.day == day;

      cells.add(_CalendarCell(
        dayNumber: day,
        isOtherMonth: false,
        isToday: isToday,
        events: dayEvents,
        onTap: () => onDayTapped(dateStr, dayEvents),
      ));
    }

    // Fill remaining cells
    final remaining = (7 - cells.length % 7) % 7;
    for (int i = 0; i < remaining; i++) {
      cells.add(const _CalendarCell(
          dayNumber: 0, isOtherMonth: true, events: []));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 0.9,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        children: cells,
      ),
    );
  }
}

class _CalendarCell extends StatelessWidget {
  final int dayNumber;
  final bool isOtherMonth;
  final bool isToday;
  final List<CalendarMeetingEvent> events;
  final VoidCallback? onTap;

  const _CalendarCell({
    required this.dayNumber,
    required this.isOtherMonth,
    this.isToday = false,
    required this.events,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isOtherMonth || dayNumber == 0) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: const Color(0xFFF8FAFC).withValues(alpha: 0.4),
        ),
      );
    }

    final hasMultiple = events.length > 1;
    final hasMeeting = events.isNotEmpty;

    Color bgColor = Colors.white;
    Color borderColor = const Color(0xFFE9ECEF);

    if (isToday) {
      bgColor = const Color(0xFFE7F3FF);
      borderColor = const Color(0xFF0D6EFD);
    } else if (hasMultiple) {
      bgColor = const Color(0xFFFFE6E6);
      borderColor = const Color(0xFFDC3545);
    } else if (hasMeeting) {
      bgColor = const Color(0xFFD1F4DD);
      borderColor = const Color(0xFF198754);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Stack(children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$dayNumber',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isToday || hasMeeting
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                if (hasMeeting) ...[
                  const SizedBox(height: 2),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: hasMultiple
                          ? const Color(0xFFDC3545)
                          : const Color(0xFF198754),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (hasMultiple)
            Positioned(
              top: 3,
              right: 3,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFFDC3545),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${events.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}