// lib/features/all_tasks/data/models/all_task_models.dart

// ─────────────────────────────────────────────────────────────────────────────
// Team Model
// ─────────────────────────────────────────────────────────────────────────────

class TeamModel {
  final int    id;
  final String teamName;
  final String displayText;
  final int    memberCount;
  final String? teamColor;

  TeamModel({
    required this.id,
    required this.teamName,
    required this.displayText,
    required this.memberCount,
    this.teamColor,
  });

  factory TeamModel.fromJson(Map<String, dynamic> json) {
    return TeamModel(
      id:          (json['id'] as num?)?.toInt() ?? 0,
      teamName:    json['team_name']?.toString()    ?? '',
      displayText: json['display_text']?.toString() ?? json['team_name']?.toString() ?? '',
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      teamColor:   json['team_color']?.toString(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Employee Model
// ─────────────────────────────────────────────────────────────────────────────

class EmployeeModel {
  final int     id;
  final String  name;
  final String  email;
  final String? team;
  final String? roleDisplay;
  final bool    isLeader;
  final bool    isEmployee;

  EmployeeModel({
    required this.id,
    required this.name,
    required this.email,
    this.team,
    this.roleDisplay,
    required this.isLeader,
    required this.isEmployee,
  });

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    return EmployeeModel(
      id:          (json['id'] as num?)?.toInt() ?? 0,
      name:        json['name']?.toString()         ?? '',
      email:       json['email']?.toString()        ?? '',
      team:        json['team']?.toString(),
      roleDisplay: json['role_display']?.toString(),
      isLeader:    json['is_leader']   == true,
      isEmployee:  json['is_employee'] == true,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Task Item
// ─────────────────────────────────────────────────────────────────────────────

class TaskItem {
  final int     id;
  final String  taskType;
  final String  taskName;
  final String? processName;
  final String? createdBy;
  final String  assignedDate;
  final String  completedDate;
  final bool    isCompleted;
  final bool    canUpload;

  TaskItem({
    required this.id,
    required this.taskType,
    required this.taskName,
    this.processName,
    this.createdBy,
    required this.assignedDate,
    required this.completedDate,
    required this.isCompleted,
    required this.canUpload,
  });

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    final status = json['status']?.toString() ?? '';
    return TaskItem(
      id:            (json['id'] as num?)?.toInt() ?? 0,
      taskType:      json['task_type']?.toString()      ?? 'general',
      taskName:      json['task_name']?.toString()      ?? '',
      processName:   json['process_name']?.toString(),
      createdBy:     json['created_by']?.toString(),
      assignedDate:  json['assigned_date']?.toString()  ?? '-',
      completedDate: json['completed_date']?.toString() ?? '-',
      isCompleted:   status == 'completed',
      canUpload:     json['can_upload'] == true,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Task List Result  (paginated response wrapper)
// ─────────────────────────────────────────────────────────────────────────────

class TaskListResult {
  final List<TaskItem> data;
  final int            total;
  final int            page;
  final int            perPage;
  final int            totalPages;

  TaskListResult({
    required this.data,
    required this.total,
    required this.page,
    required this.perPage,
    required this.totalPages,
  });

  factory TaskListResult.fromJson(Map<String, dynamic> json) {
    final list = json['data'] as List<dynamic>? ?? [];
    return TaskListResult(
      data:       list
          .whereType<Map>()
          .map((e) => TaskItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      total:      (json['total']       as num?)?.toInt() ?? 0,
      page:       (json['page']        as num?)?.toInt() ?? 1,
      perPage:    (json['per_page']    as num?)?.toInt() ?? 15,
      // ← KEY FIX: backend sends "total_pages" (snake_case)
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 1,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Task Statistics
// ─────────────────────────────────────────────────────────────────────────────

class TaskStatistics {
  final int totalTasks;
  final int completedTasks;
  final int pendingTasks;
  final int overdueTasks;

  TaskStatistics({
    required this.totalTasks,
    required this.completedTasks,
    required this.pendingTasks,
    required this.overdueTasks,
  });

  factory TaskStatistics.fromJson(Map<String, dynamic> json) {
    return TaskStatistics(
      totalTasks:     (json['total']     as num?)?.toInt() ?? 0,
      completedTasks: (json['completed'] as num?)?.toInt() ?? 0,
      pendingTasks:   (json['pending']   as num?)?.toInt() ?? 0,
      overdueTasks:   (json['overdue']   as num?)?.toInt() ?? 0,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Task Performance Metrics
// ─────────────────────────────────────────────────────────────────────────────

class TaskPerformanceMetrics {
  final double completionRate;
  final double onTimeRate;
  final double avgCompletionDays;

  TaskPerformanceMetrics({
    required this.completionRate,
    required this.onTimeRate,
    required this.avgCompletionDays,
  });

  factory TaskPerformanceMetrics.fromJson(Map<String, dynamic> json) {
    return TaskPerformanceMetrics(
      completionRate:    (json['completion_rate']     as num?)?.toDouble() ?? 0.0,
      // backend doesn't send these two yet, default to 0
      onTimeRate:        (json['on_time_rate']        as num?)?.toDouble() ?? 0.0,
      avgCompletionDays: (json['avg_completion_days'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Task Stats Combined  (wraps both statistics + performance)
// ─────────────────────────────────────────────────────────────────────────────

class TaskStatsCombined {
  final TaskStatistics         statistics;
  final TaskPerformanceMetrics performance;

  TaskStatsCombined({
    required this.statistics,
    required this.performance,
  });

  factory TaskStatsCombined.fromJson(Map<String, dynamic> json) {
    // Backend body['data'] = {
    //   "statistics": {
    //     "general_tasks": {...},
    //     "process_tasks": {...},
    //     "combined": { "total": 71, "completed": 48, "pending": 23, "overdue": 0 }
    //   },
    //   "performance": { "completion_rate": 67.61, ... }
    // }
    
    final statisticsRaw = json['statistics'] as Map<String, dynamic>? ?? {};
    
    // ← KEY FIX: drill into the "combined" sub-object for the flat counts
    final combined = statisticsRaw['combined'] as Map<String, dynamic>? ?? {};

    return TaskStatsCombined(
      statistics:  TaskStatistics.fromJson(combined),
      performance: TaskPerformanceMetrics.fromJson(
        json['performance'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}