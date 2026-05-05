// lib/features/minutes_of_meeting/data/models/minutes_of_meeting_model.dart

class MomAttendeeModel {
  final int? id;
  final String fullName;
  final String? organisation;
  final String email;
  final bool isOriginal;

  MomAttendeeModel({
    this.id,
    required this.fullName,
    this.organisation,
    required this.email,
    this.isOriginal = false,
  });

  factory MomAttendeeModel.fromJson(Map<String, dynamic> json) {
    return MomAttendeeModel(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      fullName: json['full_name']?.toString() ?? '',
      organisation: json['organisation']?.toString(),
      email: json['email']?.toString() ?? '',
      isOriginal: json['is_original'] == true || json['is_original'] == 1,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'full_name': fullName,
        if (organisation != null && organisation!.isNotEmpty)
          'organisation': organisation,
        'email': email,
        'is_original': isOriginal,
      };
}

class MinutesOfMeetingModel {
  final int id;
  final int? projectId;
  final int? scheduledMeetingId;
  final String title;
  final String meetingDate;
  final String? meetingDateFormatted;
  final String? meetingTime;
  final String? meetingTimeFormatted;
  final String? venue;
  final String description;
  final String? pdfPath;
  final List<MomAttendeeModel> attendees;
  final Map<String, dynamic>? creator;
  final String? createdAt;

  MinutesOfMeetingModel({
    required this.id,
    this.projectId,
    this.scheduledMeetingId,
    required this.title,
    required this.meetingDate,
    this.meetingDateFormatted,
    this.meetingTime,
    this.meetingTimeFormatted,
    this.venue,
    required this.description,
    this.pdfPath,
    this.attendees = const [],
    this.creator,
    this.createdAt,
  });

  factory MinutesOfMeetingModel.fromJson(Map<String, dynamic> json) {
    final attendeeList = <MomAttendeeModel>[];
    if (json['attendees'] is List) {
      for (final a in json['attendees'] as List) {
        if (a is Map<String, dynamic>) {
          attendeeList.add(MomAttendeeModel.fromJson(a));
        }
      }
    }
    return MinutesOfMeetingModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      projectId: json['project_id'] != null
          ? int.tryParse(json['project_id'].toString())
          : null,
      scheduledMeetingId: json['scheduled_meeting_id'] != null
          ? int.tryParse(json['scheduled_meeting_id'].toString())
          : null,
      title: json['title']?.toString() ?? '',
      meetingDate: json['meeting_date']?.toString() ?? '',
      meetingDateFormatted: json['meeting_date_formatted']?.toString(),
      meetingTime: json['meeting_time']?.toString(),
      meetingTimeFormatted: json['meeting_time_formatted']?.toString(),
      venue: json['venue']?.toString(),
      description: json['description']?.toString() ?? '',
      pdfPath: json['pdf_path']?.toString(),
      attendees: attendeeList,
      creator: json['creator'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['creator'])
          : null,
      createdAt: json['created_at']?.toString(),
    );
  }
}

class ScheduledMeetingModel {
  final int id;
  final String meetingTitle;
  final String meetingDate;
  final String? meetingDateFormatted;
  final String? meetingTime;
  final String? meetingTimeFormatted;
  final String? venue;
  final String? meetingAgenda;
  final String? status;
  final bool hasMom;
  final int? momId;
  final List<MomAttendeeModel> attendees;
  final int? attendeesCount;

  ScheduledMeetingModel({
    required this.id,
    required this.meetingTitle,
    required this.meetingDate,
    this.meetingDateFormatted,
    this.meetingTime,
    this.meetingTimeFormatted,
    this.venue,
    this.meetingAgenda,
    this.status,
    this.hasMom = false,
    this.momId,
    this.attendees = const [],
    this.attendeesCount,
  });

  factory ScheduledMeetingModel.fromJson(Map<String, dynamic> json) {
    final attendeeList = <MomAttendeeModel>[];
    if (json['attendees'] is List) {
      for (final a in json['attendees'] as List) {
        if (a is Map<String, dynamic>) {
          attendeeList.add(MomAttendeeModel.fromJson(a));
        }
      }
    }
    return ScheduledMeetingModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      meetingTitle:
          json['meeting_title']?.toString() ?? json['title']?.toString() ?? '',
      meetingDate: json['meeting_date']?.toString() ?? '',
      meetingDateFormatted: json['meeting_date_formatted']?.toString(),
      meetingTime: json['meeting_time']?.toString(),
      meetingTimeFormatted: json['meeting_time_formatted']?.toString(),
      venue: json['venue']?.toString(),
      meetingAgenda: json['meeting_agenda']?.toString(),
      status: json['status']?.toString(),
      hasMom: json['has_mom'] == true || json['has_mom'] == 1,
      momId: json['mom_id'] != null
          ? int.tryParse(json['mom_id'].toString())
          : null,
      attendees: attendeeList,
      attendeesCount: json['attendees_count'] != null
          ? int.tryParse(json['attendees_count'].toString())
          : null,
    );
  }
}

class CalendarMeetingEvent {
  final String date;
  final String title;
  final String type; // 'mom' or 'scheduled'
  final int id;
  final String? time;
  final bool hasMom;

  CalendarMeetingEvent({
    required this.date,
    required this.title,
    required this.type,
    required this.id,
    this.time,
    required this.hasMom,
  });

  factory CalendarMeetingEvent.fromJson(Map<String, dynamic> json) {
    return CalendarMeetingEvent(
      date: json['date']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      type: json['type']?.toString() ?? 'scheduled',
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      time: json['time']?.toString(),
      hasMom: json['has_mom'] == true || json['has_mom'] == 1,
    );
  }
}