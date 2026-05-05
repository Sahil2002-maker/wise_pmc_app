class WorkReportModel {
  final int? id;
  final int userId;
  final int attendanceId;
  final String date;
  final String workDescription;
  final String? tasksCompleted;
  final double hoursWorked;
  final String? challengesFaced;
  final String? nextDayPlan;
  final String status; // 'draft' or 'submitted'
  final AttendanceInfo? attendance;
  final UserInfo? user;
  final bool canEdit;

  WorkReportModel({
    this.id,
    required this.userId,
    required this.attendanceId,
    required this.date,
    required this.workDescription,
    this.tasksCompleted,
    required this.hoursWorked,
    this.challengesFaced,
    this.nextDayPlan,
    required this.status,
    this.attendance,
    this.user,
    this.canEdit = true,
  });

  factory WorkReportModel.fromJson(Map<String, dynamic> json) {
    return WorkReportModel(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      userId: int.tryParse(json['user_id']?.toString() ?? '0') ?? 0,
      attendanceId: int.tryParse(json['attendance_id']?.toString() ?? '0') ?? 0,
      date: json['date']?.toString() ?? '',
      workDescription: json['work_description']?.toString() ?? '',
      tasksCompleted: json['tasks_completed']?.toString(),
      hoursWorked: double.tryParse(json['hours_worked']?.toString() ?? '0') ?? 0,
      challengesFaced: json['challenges_faced']?.toString(),
      nextDayPlan: json['next_day_plan']?.toString(),
      status: json['status']?.toString() ?? 'draft',
      canEdit: json['can_edit'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'attendance_id': attendanceId,
        'date': date,
        'work_description': workDescription,
        'tasks_completed': tasksCompleted,
        'hours_worked': hoursWorked,
        'challenges_faced': challengesFaced,
        'next_day_plan': nextDayPlan,
        'status': status,
      };
}

class AttendanceInfo {
  final int id;
  final String date;
  final String status;
  final String? checkIn;
  final String? checkOut;
  final double workingHours;
  final bool isIncompleteShift;
  final bool isAbsentWithCheckin;
  final String? leaveTypeName;

  AttendanceInfo({
    required this.id,
    required this.date,
    required this.status,
    this.checkIn,
    this.checkOut,
    required this.workingHours,
    this.isIncompleteShift = false,
    this.isAbsentWithCheckin = false,
    this.leaveTypeName,
  });

  factory AttendanceInfo.fromJson(Map<String, dynamic> json) {
    return AttendanceInfo(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      date: json['date']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      checkIn: json['check_in']?.toString(),
      checkOut: json['check_out']?.toString(),
      workingHours: double.tryParse(json['working_hours']?.toString() ?? '0') ?? 0,
      isIncompleteShift: json['is_incomplete_shift'] == true,
      isAbsentWithCheckin: json['is_absent_with_checkin'] == true,
      leaveTypeName: json['leave_type_name']?.toString(),
    );
  }
}

class UserInfo {
  final int id;
  final String name;
  final String email;

  UserInfo({required this.id, required this.name, required this.email});

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
    );
  }
}