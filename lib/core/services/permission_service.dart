class PermissionService {
  static bool hasPermission(List<String> permissions, String permission) {
    return permissions.contains(permission);
  }

  static bool hasAny(List<String> permissions, List<String> required) {
    for (final permission in required) {
      if (permissions.contains(permission)) return true;
    }
    return false;
  }

  static bool canViewProjectList(List<String> permissions) {
    return hasAny(permissions, [
      'view_process',
      'executive_acess',
    ]);
  }

  static bool canManageProject(List<String> permissions) {
    return hasPermission(permissions, 'master_manage');
  }

  static bool canViewReports(List<String> permissions) {
    return hasAny(permissions, [
      'view_reports',
      'team_project_report',
      'employee_report',
    ]);
  }

  static bool canViewGeneralTasks(List<String> permissions) {
    return hasAny(permissions, [
      'view_general_task',
      'general_task_access',
      'general_tasks',
    ]);
  }

  // UPDATED: made meeting check broader so All Meetings shows properly
  static bool canViewMeetings(List<String> permissions) {
    return hasAny(permissions, [
      'view_meeting',
      'meeting_access',
      'meetings_access',
      'all_meetings',
      'scheduled_meeting',
      'schedule_meeting',
      'meeting_list',
    ]);
  }

  static bool canViewTaskCalendar(List<String> permissions) {
    return hasAny(permissions, [
      'task_calendar',
      'calendar_task_access',
      'view_general_task',
    ]);
  }

  static bool canManageUsers(List<String> permissions) {
    return hasAny(permissions, [
      'role_access',
      'role_create',
      'role_update',
      'permission_access',
      'permission_create',
      'permission_update',
      'user_access',
    ]);
  }

  static bool canAddTeam(List<String> permissions) {
    return hasPermission(permissions, 'add_team');
  }

  static bool canViewWorkReports(List<String> permissions) {
    return hasAny(permissions, [
      'work_report_access',
      'daily_work_report',
      'employee_report',
    ]);
  }

  static bool canSeeMasterSection(List<String> permissions) {
    return canViewProjectList(permissions) ||
        canViewMeetings(permissions) ||
        canViewGeneralTasks(permissions) ||
        canViewTaskCalendar(permissions) ||
        canManageProject(permissions) ||
        canAddTeam(permissions);
  }

  static bool shouldUseEmployeeSidebar({
    required String role,
    required List<String> permissions,
  }) {
    if (role.toLowerCase() != 'employee') return false;

    return canSeeMasterSection(permissions) ||
        canViewWorkReports(permissions);
  }
}