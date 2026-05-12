// lib/features/process/data/models/process_model.dart

class ProcessModel {
  final int orderNo;
  final int? processId;
  final String processName;
  final String stage;
  final String? heading;
  final int? workingTeam;
  final String? workingTeamName;
  final int? reviewTeam;
  final String? reviewTeamName;
  final int? day;

  const ProcessModel({
    required this.orderNo,
    this.processId,
    required this.processName,
    required this.stage,
    this.heading,
    this.workingTeam,
    this.workingTeamName,
    this.reviewTeam,
    this.reviewTeamName,
    this.day,
  });

  factory ProcessModel.fromJson(Map<String, dynamic> json) {
    return ProcessModel(
      orderNo: _parseInt(json['order_no']),
      processId: json['process_id'] != null ? _parseInt(json['process_id']) : null,
      processName: json['process_name']?.toString() ?? '',
      stage: json['stage']?.toString() ?? '',
      heading: json['heading']?.toString(),
      workingTeam: json['working_team'] != null ? _parseInt(json['working_team']) : null,
      workingTeamName: json['working_team_name']?.toString(),
      reviewTeam: json['review_team'] != null ? _parseInt(json['review_team']) : null,
      reviewTeamName: json['review_team_name']?.toString(),
      day: json['day'] != null ? _parseInt(json['day']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'order_no': orderNo,
        'process_id': processId,
        'process_name': processName,
        'stage': stage,
        'heading': heading,
        'working_team': workingTeam,
        'working_team_name': workingTeamName,
        'review_team': reviewTeam,
        'review_team_name': reviewTeamName,
        'day': day,
      };

  ProcessModel copyWith({
    int? orderNo,
    int? processId,
    String? processName,
    String? stage,
    String? heading,
    int? workingTeam,
    String? workingTeamName,
    int? reviewTeam,
    String? reviewTeamName,
    int? day,
  }) {
    return ProcessModel(
      orderNo: orderNo ?? this.orderNo,
      processId: processId ?? this.processId,
      processName: processName ?? this.processName,
      stage: stage ?? this.stage,
      heading: heading ?? this.heading,
      workingTeam: workingTeam ?? this.workingTeam,
      workingTeamName: workingTeamName ?? this.workingTeamName,
      reviewTeam: reviewTeam ?? this.reviewTeam,
      reviewTeamName: reviewTeamName ?? this.reviewTeamName,
      day: day ?? this.day,
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  String get deadlineLabel {
    if (day == null || day == 0) return 'No deadline';
    return '$day day${day! > 1 ? 's' : ''}';
  }

  String get stageLabel {
    switch (stage) {
      case 'pmc_application':
        return 'PMC Application';
      case 'stage1':
        return 'Stage 1';
      case 'stage2':
        return 'Stage 2';
      case 'stage3':
        return 'Stage 3';
      default:
        return stage;
    }
  }
}

class ProcessTeamModel {
  final int id;
  final String teamName;

  const ProcessTeamModel({required this.id, required this.teamName});

  factory ProcessTeamModel.fromJson(Map<String, dynamic> json) {
    return ProcessTeamModel(
      id: _parseInt(json['id']),
      teamName: json['team_name']?.toString() ?? '',
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }
}

class ProcessListResult {
  final List<ProcessModel> processes;
  final int total;
  final int currentPage;
  final int lastPage;

  const ProcessListResult({
    required this.processes,
    required this.total,
    required this.currentPage,
    required this.lastPage,
  });

  factory ProcessListResult.fromJson(Map<String, dynamic> json) {
    final raw = json['data'] as List<dynamic>? ?? [];
    return ProcessListResult(
      processes: raw
          .whereType<Map<String, dynamic>>()
          .map(ProcessModel.fromJson)
          .toList(),
      total: _parseInt(json['recordsTotal'] ?? json['total'] ?? 0),
      currentPage: _parseInt(json['current_page'] ?? 1),
      lastPage: _parseInt(json['last_page'] ?? 1),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }
}