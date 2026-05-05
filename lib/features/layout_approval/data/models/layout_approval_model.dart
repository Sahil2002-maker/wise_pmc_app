// FILE PATH: lib/features/layout_approval/data/models/layout_approval_model.dart

/// Represents one process item inside a layout approval stage.
class LayoutApprovalProcessModel {
  final int processId;
  final String processName;
  final String? currentStatus;
  final bool isCompleted;
  final bool isNa;
  final bool hasFile;
  final LayoutApprovalFileInfo? fileInfo;

  const LayoutApprovalProcessModel({
    required this.processId,
    required this.processName,
    this.currentStatus,
    required this.isCompleted,
    required this.isNa,
    required this.hasFile,
    this.fileInfo,
  });

  factory LayoutApprovalProcessModel.fromJson(Map<String, dynamic> json) {
    LayoutApprovalFileInfo? fileInfo;
    if (json['file_info'] is Map<String, dynamic>) {
      fileInfo = LayoutApprovalFileInfo.fromJson(
        Map<String, dynamic>.from(json['file_info'] as Map),
      );
    }

    return LayoutApprovalProcessModel(
      processId:     _parseInt(json['process_id']),
      processName:   json['process_name']?.toString() ?? '',
      currentStatus: json['current_status']?.toString(),
      isCompleted:   _parseBool(json['is_completed']),
      isNa:          _parseBool(json['is_na']),
      hasFile:       _parseBool(json['has_file']),
      fileInfo:      fileInfo,
    );
  }

  /// Returns a copy with updated fields.
  LayoutApprovalProcessModel copyWith({
    String? currentStatus,
    bool? isCompleted,
    bool? isNa,
    bool? hasFile,
    LayoutApprovalFileInfo? fileInfo,
  }) {
    return LayoutApprovalProcessModel(
      processId:     processId,
      processName:   processName,
      currentStatus: currentStatus ?? this.currentStatus,
      isCompleted:   isCompleted ?? this.isCompleted,
      isNa:          isNa ?? this.isNa,
      hasFile:       hasFile ?? this.hasFile,
      fileInfo:      fileInfo ?? this.fileInfo,
    );
  }

  static int _parseInt(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;
  static bool _parseBool(dynamic v) {
    if (v is bool) return v;
    if (v is int) return v == 1;
    return v?.toString().toLowerCase() == 'true' || v?.toString() == '1';
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// File metadata attached to a process status record.
class LayoutApprovalFileInfo {
  final String? fileName;
  final String? filePath;
  final String? fileSize;
  final String? uploadedDate;
  final String? uploadedBy;

  const LayoutApprovalFileInfo({
    this.fileName,
    this.filePath,
    this.fileSize,
    this.uploadedDate,
    this.uploadedBy,
  });

  factory LayoutApprovalFileInfo.fromJson(Map<String, dynamic> json) {
    return LayoutApprovalFileInfo(
      fileName:     json['file_name']?.toString(),
      filePath:     json['file_path']?.toString(),
      fileSize:     json['file_size']?.toString(),
      uploadedDate: json['uploaded_date']?.toString(),
      uploadedBy:   json['uploaded_by']?.toString(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Summary count data for one stage.
class LayoutApprovalStageSummary {
  final int total;
  final int completed;
  final int na;
  final int pending;
  final double completionPercentage;

  const LayoutApprovalStageSummary({
    required this.total,
    required this.completed,
    required this.na,
    required this.pending,
    required this.completionPercentage,
  });

  factory LayoutApprovalStageSummary.fromJson(Map<String, dynamic> json) {
    return LayoutApprovalStageSummary(
      total:                 _parseInt(json['total']),
      completed:             _parseInt(json['completed']),
      na:                    _parseInt(json['na']),
      pending:               _parseInt(json['pending']),
      completionPercentage:  double.tryParse(json['completion_percentage']?.toString() ?? '0') ?? 0,
    );
  }

  static int _parseInt(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;
}

// ─────────────────────────────────────────────────────────────────────────────

/// One full stage block returned by the API.
class LayoutApprovalStageModel {
  final String stageKey;
  final String stageLabel;
  final List<LayoutApprovalProcessModel> processes;
  final LayoutApprovalStageSummary? summary;

  const LayoutApprovalStageModel({
    required this.stageKey,
    required this.stageLabel,
    required this.processes,
    this.summary,
  });

  factory LayoutApprovalStageModel.fromJson(Map<String, dynamic> json) {
    final rawProcesses = json['processes'];
    final processes = <LayoutApprovalProcessModel>[];

    if (rawProcesses is List) {
      for (final p in rawProcesses) {
        if (p is Map) {
          processes.add(LayoutApprovalProcessModel.fromJson(
            Map<String, dynamic>.from(p),
          ));
        }
      }
    }

    LayoutApprovalStageSummary? summary;
    if (json['summary'] is Map) {
      summary = LayoutApprovalStageSummary.fromJson(
        Map<String, dynamic>.from(json['summary'] as Map),
      );
    }

    return LayoutApprovalStageModel(
      stageKey:  json['stage_key']?.toString() ?? '',
      stageLabel: json['stage_label']?.toString() ?? '',
      processes: processes,
      summary:   summary,
    );
  }

  /// Number of processes that have been actioned (Completed or N.A).
  int get actionedCount => processes.where((p) => p.isCompleted || p.isNa).length;

  double get progress {
    final total = processes.length;
    if (total == 0) return 0;
    return actionedCount / total;
  }
}