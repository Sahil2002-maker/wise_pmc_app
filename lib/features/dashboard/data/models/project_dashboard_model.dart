class ProjectDashboardModel {
  final int id;
  final String societyName;
  final String status;
  final int totalProcesses;
  final int completedTasks;
  final int assignedTasks;
  final int pendingTasks;
  final int progressPercentage;

  const ProjectDashboardModel({
    required this.id,
    required this.societyName,
    required this.status,
    required this.totalProcesses,
    required this.completedTasks,
    required this.assignedTasks,
    required this.pendingTasks,
    required this.progressPercentage,
  });

  factory ProjectDashboardModel.fromJson(Map<String, dynamic> json) {
    return ProjectDashboardModel(
      id: _toInt(json['id']),
      societyName: json['society_name']?.toString() ??
          json['name']?.toString() ??
          '',
      status: json['status']?.toString() ?? 'pending',
      totalProcesses: _toInt(json['total_processes']),
      completedTasks: _toInt(json['completed_tasks']),
      assignedTasks: _toInt(json['assigned_tasks']),
      pendingTasks: _toInt(json['pending_tasks']),
      progressPercentage: _toInt(json['progress_percentage']),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }
}