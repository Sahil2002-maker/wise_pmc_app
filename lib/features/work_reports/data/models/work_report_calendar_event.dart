import 'package:flutter/material.dart';

class WorkReportCalendarEvent {
  final String id;
  final String title;
  final String date;
  final Color backgroundColor;
  final CalendarEventProps extendedProps;

  WorkReportCalendarEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.backgroundColor,
    required this.extendedProps,
  });

  factory WorkReportCalendarEvent.fromJson(Map<String, dynamic> json) {
    final props = json['extendedProps'] as Map<String, dynamic>? ?? {};
    final colorStr = json['backgroundColor']?.toString() ?? '#6c757d';
    return WorkReportCalendarEvent(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      date: json['start']?.toString() ?? '',
      backgroundColor: _hexToColor(colorStr),
      extendedProps: CalendarEventProps.fromJson(props),
    );
  }

  static Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    try {
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }
}

class CalendarEventProps {
  final int attendanceId;
  final String status;
  final String? checkIn;
  final String? checkOut;
  final double workingHours;
  final bool hasWorkReport;
  final int? workReportId;
  final String? workReportStatus;
  final bool canAddReport;
  final bool isIncompleteShift;
  final bool isAbsentWithCheckin;
  final String? leaveTypeName;
  final int userId;
  final String userName;
  final String date;

  CalendarEventProps({
    required this.attendanceId,
    required this.status,
    this.checkIn,
    this.checkOut,
    required this.workingHours,
    required this.hasWorkReport,
    this.workReportId,
    this.workReportStatus,
    required this.canAddReport,
    required this.isIncompleteShift,
    required this.isAbsentWithCheckin,
    this.leaveTypeName,
    required this.userId,
    required this.userName,
    required this.date,
  });

  factory CalendarEventProps.fromJson(Map<String, dynamic> json) {
    return CalendarEventProps(
      attendanceId: int.tryParse(json['attendance_id']?.toString() ?? '0') ?? 0,
      status: json['status']?.toString() ?? '',
      checkIn: json['check_in']?.toString(),
      checkOut: json['check_out']?.toString(),
      workingHours: double.tryParse(json['working_hours']?.toString() ?? '0') ?? 0,
      hasWorkReport: json['has_work_report'] == true,
      workReportId: json['work_report_id'] != null
          ? int.tryParse(json['work_report_id'].toString())
          : null,
      workReportStatus: json['work_report_status']?.toString(),
      canAddReport: json['can_add_report'] == true,
      isIncompleteShift: json['is_incomplete_shift'] == true,
      isAbsentWithCheckin: json['is_absent_with_checkin'] == true,
      leaveTypeName: json['leave_type_name']?.toString(),
      userId: int.tryParse(json['user_id']?.toString() ?? '0') ?? 0,
      userName: json['user_name']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
    );
  }

  bool get isAbsentNoCheckin =>
      status.toLowerCase() == 'absent' && !isAbsentWithCheckin;
}

class WorkReportUser {
  final int id;
  final String name;
  final String email;
  final String teamName;
  final String companyName;
  final String role;
  final String displayName;

  WorkReportUser({
    required this.id,
    required this.name,
    required this.email,
    required this.teamName,
    required this.companyName,
    required this.role,
    required this.displayName,
  });

  factory WorkReportUser.fromJson(Map<String, dynamic> json) {
    return WorkReportUser(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      teamName: json['team_name']?.toString() ?? 'No Team',
      companyName: json['company_name']?.toString() ?? 'No Company',
      role: json['role']?.toString() ?? 'employee',
      displayName: json['display_name']?.toString() ?? json['name']?.toString() ?? '',
    );
  }
}