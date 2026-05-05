// lib/features/oc_progress/data/models/oc_progress_model.dart

class OcProcessModel {
  final int processId;
  final String processName;
  final String stage;
  final String? currentStatus;
  final bool isCompleted;
  final bool isNa;
  final bool hasFile;
  final OcFileInfoModel? fileInfo;

  const OcProcessModel({
    required this.processId,
    required this.processName,
    required this.stage,
    this.currentStatus,
    required this.isCompleted,
    required this.isNa,
    required this.hasFile,
    this.fileInfo,
  });

  factory OcProcessModel.fromJson(Map<String, dynamic> json) {
    OcFileInfoModel? fileInfo;
    final rawFileInfo = json['file_info'];
    if (rawFileInfo is Map<String, dynamic>) {
      fileInfo = OcFileInfoModel.fromJson(rawFileInfo);
    }

    return OcProcessModel(
      processId: _parseInt(json['process_id']),
      processName: json['process_name']?.toString() ?? '',
      stage: json['stage']?.toString() ?? '',
      currentStatus: json['current_status']?.toString(),
      isCompleted: json['is_completed'] == true,
      isNa: json['is_na'] == true,
      hasFile: json['has_file'] == true,
      fileInfo: fileInfo,
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }
}

class OcFileInfoModel {
  final String? fileName;
  final String? filePath;
  final String? fileSize;
  final String? uploadedDate;
  final String? uploadedBy;

  const OcFileInfoModel({
    this.fileName,
    this.filePath,
    this.fileSize,
    this.uploadedDate,
    this.uploadedBy,
  });

  factory OcFileInfoModel.fromJson(Map<String, dynamic> json) {
    return OcFileInfoModel(
      fileName: json['file_name']?.toString(),
      filePath: json['file_path']?.toString(),
      fileSize: json['file_size']?.toString(),
      uploadedDate: json['uploaded_date']?.toString(),
      uploadedBy: json['uploaded_by']?.toString(),
    );
  }
}

class OcStageSummaryModel {
  final int total;
  final int completed;
  final int na;
  final int remaining;

  const OcStageSummaryModel({
    required this.total,
    required this.completed,
    required this.na,
    required this.remaining,
  });

  factory OcStageSummaryModel.fromJson(Map<String, dynamic> json) {
    final total = _parseInt(json['total']);
    final completed = _parseInt(json['completed']);
    final na = _parseInt(json['na']);
    final pending = _parseInt(json['pending'] ?? json['remaining']);
    return OcStageSummaryModel(
      total: total,
      completed: completed,
      na: na,
      remaining: pending,
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  double get completionPercentage =>
      total > 0 ? (completed + na) / total : 0.0;
}

class OcStageDataModel {
  final String stageKey;
  final String stageLabel;
  final List<OcProcessModel> processes;
  final OcStageSummaryModel? summary;

  const OcStageDataModel({
    required this.stageKey,
    required this.stageLabel,
    required this.processes,
    this.summary,
  });

  factory OcStageDataModel.fromJson(Map<String, dynamic> json) {
    final rawProcesses = json['processes'];
    final processes = <OcProcessModel>[];
    if (rawProcesses is List) {
      for (final p in rawProcesses) {
        if (p is Map) {
          processes.add(OcProcessModel.fromJson(Map<String, dynamic>.from(p)));
        }
      }
    }

    OcStageSummaryModel? summary;
    final rawSummary = json['summary'];
    if (rawSummary is Map<String, dynamic>) {
      summary = OcStageSummaryModel.fromJson(rawSummary);
    }

    return OcStageDataModel(
      stageKey: json['stage_key']?.toString() ?? '',
      stageLabel: json['stage_label']?.toString() ??
          json['stage_name']?.toString() ?? '',
      processes: processes,
      summary: summary,
    );
  }
}