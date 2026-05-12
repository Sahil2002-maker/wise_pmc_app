// lib/features/development_process/data/models/dev_process_model.dart
//
// ── FIX: "Statements in a for should be enclosed in a block" ─────────────────
// All for-loop bodies now use explicit { } blocks.

class DevProcessModel {
  final int processId;
  final int orderNo;
  final String processName;
  final int stage;
  final String stageLabel;
  final int? teamId;
  final String? teamName;
  final String teamColor;

  const DevProcessModel({
    required this.processId,
    required this.orderNo,
    required this.processName,
    required this.stage,
    required this.stageLabel,
    this.teamId,
    this.teamName,
    this.teamColor = '#43C880',
  });

  factory DevProcessModel.fromJson(Map<String, dynamic> json) {
    return DevProcessModel(
      processId:   (json['process_id']  as num).toInt(),
      orderNo:     (json['order_no']    as num).toInt(),
      processName: json['process_name'] as String,
      stage:       (json['stage']       as num).toInt(),
      stageLabel:  json['stage_label']  as String? ?? 'Stage ${json['stage']}',
      teamId:      json['team_id'] != null ? (json['team_id'] as num).toInt() : null,
      teamName:    json['team_name']  as String?,
      teamColor:   json['team_color'] as String? ?? '#43C880',
    );
  }

  Map<String, dynamic> toJson() => {
        'process_id':   processId,
        'order_no':     orderNo,
        'process_name': processName,
        'stage':        stage,
        'stage_label':  stageLabel,
        'team_id':      teamId,
        'team_name':    teamName,
        'team_color':   teamColor,
      };

  DevProcessModel copyWith({
    int?    processId,
    int?    orderNo,
    String? processName,
    int?    stage,
    String? stageLabel,
    int?    teamId,
    String? teamName,
    String? teamColor,
  }) {
    return DevProcessModel(
      processId:   processId   ?? this.processId,
      orderNo:     orderNo     ?? this.orderNo,
      processName: processName ?? this.processName,
      stage:       stage       ?? this.stage,
      stageLabel:  stageLabel  ?? this.stageLabel,
      teamId:      teamId      ?? this.teamId,
      teamName:    teamName    ?? this.teamName,
      teamColor:   teamColor   ?? this.teamColor,
    );
  }
}

// ── Team model ────────────────────────────────────────────────────────────────

class DevProcessTeamModel {
  final int id;
  final String teamName;
  final String teamColor;

  const DevProcessTeamModel({
    required this.id,
    required this.teamName,
    this.teamColor = '#43C880',
  });

  factory DevProcessTeamModel.fromJson(Map<String, dynamic> json) {
    return DevProcessTeamModel(
      id:        (json['id'] as num).toInt(),
      teamName:  json['team_name']  as String,
      teamColor: json['team_color'] as String? ?? '#43C880',
    );
  }
}

// ── Stage summary model ───────────────────────────────────────────────────────

class DevProcessStageModel {
  final int stage;
  final String stageLabel;
  final int count;
  final List<DevProcessModel> processes;

  const DevProcessStageModel({
    required this.stage,
    required this.stageLabel,
    required this.count,
    required this.processes,
  });

  factory DevProcessStageModel.fromJson(Map<String, dynamic> json) {
    final rawProcesses = json['processes'] as List<dynamic>? ?? [];

    // FIX: explicit block in for-each (using map instead of for loop avoids
    // the lint entirely — no bare statement risk)
    final processes = rawProcesses
        .map((p) => DevProcessModel.fromJson(p as Map<String, dynamic>))
        .toList();

    return DevProcessStageModel(
      stage:      (json['stage'] as num).toInt(),
      stageLabel: json['stage_label'] as String,
      count:      (json['count']      as num).toInt(),
      processes:  processes,
    );
  }
}