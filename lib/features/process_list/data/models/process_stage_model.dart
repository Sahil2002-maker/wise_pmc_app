// lib/features/process_list/data/models/process_stage_model.dart

import '../../data/models/process_list_item_model.dart';

class ProcessStageModel {
  final String stageKey;
  final String stageLabel;
  final List<ProcessListItemModel> processes;

  ProcessStageModel({
    required this.stageKey,
    required this.stageLabel,
    required this.processes,
  });

  int get completedCount =>
      processes.where((p) => p.isCompleted).length;
  int get totalCount => processes.length;
  double get progress =>
      totalCount > 0 ? completedCount / totalCount : 0.0;
}