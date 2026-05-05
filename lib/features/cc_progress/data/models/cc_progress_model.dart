// lib/features/cc_progress/data/models/cc_progress_model.dart

class CcProcessModel {
  final int processId;
  final String processName;
  final String stage;
  final String? headStage;
  final String? currentStatus;
  final bool isCompleted;
  final bool isNa;
  final bool hasFile;
  final CcFileInfoModel? fileInfo;

  CcProcessModel({
    required this.processId,
    required this.processName,
    required this.stage,
    this.headStage,
    this.currentStatus,
    required this.isCompleted,
    required this.isNa,
    required this.hasFile,
    this.fileInfo,
  });

  factory CcProcessModel.fromJson(Map<String, dynamic> json) {
    CcFileInfoModel? fileInfo;
    final rawFileInfo = json['file_info'];
    if (rawFileInfo is Map<String, dynamic>) {
      fileInfo = CcFileInfoModel.fromJson(rawFileInfo);
    }

    return CcProcessModel(
      processId: _parseInt(json['process_id']),
      processName: json['process_name']?.toString() ?? '',
      stage: json['stage']?.toString() ?? '',
      headStage: json['head_stage']?.toString(),
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

class CcFileInfoModel {
  final String? fileName;
  final String? filePath;
  final String? fileSize;
  final String? uploadedDate;
  final String? uploadedBy;

  CcFileInfoModel({
    this.fileName,
    this.filePath,
    this.fileSize,
    this.uploadedDate,
    this.uploadedBy,
  });

  factory CcFileInfoModel.fromJson(Map<String, dynamic> json) {
    return CcFileInfoModel(
      fileName: json['file_name']?.toString(),
      filePath: json['file_path']?.toString(),
      fileSize: json['file_size']?.toString(),
      uploadedDate: json['uploaded_date']?.toString(),
      uploadedBy: json['uploaded_by']?.toString(),
    );
  }
}

class CcStageSummaryModel {
  final int total;
  final int completed;
  final int na;
  final int remaining;
  final double completionPercentage;

  CcStageSummaryModel({
    required this.total,
    required this.completed,
    required this.na,
    required this.remaining,
    required this.completionPercentage,
  });

  factory CcStageSummaryModel.fromJson(Map<String, dynamic> json) {
    return CcStageSummaryModel(
      total: _parseInt(json['total']),
      completed: _parseInt(json['completed']),
      na: _parseInt(json['na']),
      remaining: _parseInt(json['remaining'] ?? json['pending']),
      completionPercentage:
          double.tryParse(json['completion_percentage']?.toString() ?? '0') ?? 0,
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }
}

class CcStageDataModel {
  final String stageKey;
  final String stageLabel;
  final List<CcProcessModel> processes;
  final CcStageSummaryModel? summary;

  CcStageDataModel({
    required this.stageKey,
    required this.stageLabel,
    required this.processes,
    this.summary,
  });
}