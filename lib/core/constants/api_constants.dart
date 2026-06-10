// lib/core/constants/api_constants.dart

class ApiConstants {
  static const String _productionBase = 'http://wise.panvelcity.in';
  // ignore: unused_field
  static const String _localBase = 'http://10.0.2.2:8000';
  static String get baseUrl => _productionBase;

  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const String contentType = 'application/json';
  static const String accept = 'application/json';

  static const String _mobile = '/api/mobile';
  static const String _api = '/api';

  // ── Auth ─────────────────────────────────────────────────────────────────────
  static String get login          => '$baseUrl$_mobile/login';
  static String get logout         => '$baseUrl$_mobile/logout';
  static String get me             => '$baseUrl$_mobile/me';
  static String get forgotPassword => '$baseUrl$_mobile/forgot-password';

  // ── Profile ──────────────────────────────────────────────────────────────────
  static String get profile         => '$baseUrl$_mobile/profile';
  static String get profilePassword => '$baseUrl$_mobile/profile/password';

  // ── Theme ─────────────────────────────────────────────────────────────────────
  static String get getCurrentTheme => '$baseUrl$_mobile/get-current-theme';
  static String get updateThemeMode => '$baseUrl$_mobile/update-theme-mode';

  // ── Dashboard ─────────────────────────────────────────────────────────────────
  static String get dashboardProjects => '$baseUrl$_mobile/dashboard/projects';

  // ── Projects ──────────────────────────────────────────────────────────────────
  static String get projectList   => '$baseUrl$_mobile/projects/list';
  static String get projects      => '$baseUrl$_mobile/projects';
  static String get createProject => '$baseUrl$_mobile/projects';

  static String projectProcesses(int projectId) =>
      '$baseUrl$_mobile/projects/$projectId/processes';

  static String projectInfo(int projectId) =>
      '$baseUrl$_mobile/projects/$projectId/project-info';

  static String projectInfoRemoveDocument(
          int projectId, String type, int index) =>
      '$baseUrl$_mobile/projects/$projectId/project-info/$type/$index';

  // ── Teams ─────────────────────────────────────────────────────────────────────
  static String teamMembers(int teamId) =>
      '$baseUrl$_mobile/teams/$teamId/members';

  // ── General Tasks ─────────────────────────────────────────────────────────────
  static String get generalTasks               => '$baseUrl$_mobile/general-tasks';
  static String get generalTasksCreate         => '$baseUrl$_mobile/general-tasks';
  static String get generalTaskAssign          => '$baseUrl$_mobile/general-tasks/assign';
  static String get generalTaskAssignableUsers => '$baseUrl$_mobile/get-team-c-members';
  static String get assignableUsers            => '$baseUrl$_mobile/get-team-c-members';

  static String generalTaskUpdate(int taskId) =>
      '$baseUrl$_mobile/general-tasks/$taskId';
  static String generalTaskDelete(int taskId) =>
      '$baseUrl$_mobile/general-tasks/$taskId/delete';
  static String generalTaskUpdateStatus(int taskId) =>
      '$baseUrl$_mobile/general-tasks/$taskId/status';
  static String generalTaskUploadFile(int taskId) =>
      '$baseUrl$_mobile/general-tasks/$taskId/upload-file';

  // ── Calendar Tasks ────────────────────────────────────────────────────────────
  // FIX: All calendar endpoints now point to the dedicated mobile controller
  // at /api/mobile/calendar/* instead of the old web /api/tasks/* routes.
  static String get calendarTasks          => '$baseUrl$_mobile/calendar/tasks';
  static String get calendarTaskStatistics => '$baseUrl$_mobile/calendar/statistics';
  static String get calendarTeams          => '$baseUrl$_mobile/calendar/teams';
 
  static String calendarTeamMembers(int teamId) =>
      '$baseUrl$_mobile/calendar/teams/$teamId/members';
 
  static String calendarCompleteTask(int taskId) =>
      '$baseUrl$_mobile/calendar/tasks/$taskId/complete';
 
  // Legacy aliases kept for any other callers that reference these names
  static String get calendarRecentTasks    => '$baseUrl$_api/tasks/recent';
  static String get teamsAndMembers        => '$baseUrl$_mobile/calendar/teams';

  // ── All Tasks ─────────────────────────────────────────────────────────────────
  static String get allTasksTeams       => '$baseUrl$_mobile/all-tasks/teams';
  static String get allTasksEmployees   => '$baseUrl$_mobile/all-tasks/employees';
  static String get allTasksTeamMembers => '$baseUrl$_mobile/all-tasks/team-members';
  static String get allTasksList        => '$baseUrl$_mobile/all-tasks/list';
  static String get allTasksStatistics  => '$baseUrl$_mobile/all-tasks/statistics';
  static String get allTasksDetail      => '$baseUrl$_mobile/all-tasks/detail';
  static String get allTasksUpload      => '$baseUrl$_mobile/all-tasks/upload';

  // ── Work Reports ──────────────────────────────────────────────────────────────
  static String get workReportsCalendar => '$baseUrl$_mobile/work-reports/calendar';
  static String get workReportGet       => '$baseUrl$_mobile/work-reports/get';
  static String get workReportsStore    => '$baseUrl$_mobile/work-reports';
  static String get workReportUsers     => '$baseUrl$_mobile/work-reports/users';

  static String workReportDestroy(int id) =>
      '$baseUrl$_mobile/work-reports/$id';

  // ── Process List extras ───────────────────────────────────────────────────────
  static String drawingTasks(int projectId) =>
      '$baseUrl$_mobile/projects/$projectId/drawing-tasks';

  static String projectMeetings(int projectId) =>
      '$baseUrl$_mobile/projects/$projectId/meetings';

  static String ccProcesses(int projectId) =>
      '$baseUrl$_mobile/projects/$projectId/cc-processes';

  static String layoutProcesses(int projectId) =>
      '$baseUrl$_mobile/projects/$projectId/layout-processes';

  static String ocProcesses(int projectId) =>
      '$baseUrl$_mobile/projects/$projectId/oc-processes';

  static String get uploadProcessDocument =>
      '$baseUrl$_mobile/api/process-tasks/upload';

  // ── Re-Execution (Daily Progress Reports) ─────────────────────────────────────
  static String reExecutionList(int projectId) =>
      '$baseUrl$_mobile/re-execution/$projectId';

  static String reExecutionCreate(int projectId) =>
      '$baseUrl$_mobile/re-execution/$projectId';

  static String reExecutionDetail(int projectId, int reportId) =>
      '$baseUrl$_mobile/re-execution/$projectId/$reportId';

  static String reExecutionUpdate(int projectId, int reportId) =>
      '$baseUrl$_mobile/re-execution/$projectId/$reportId';

  static String reExecutionDelete(int projectId, int reportId) =>
      '$baseUrl$_mobile/re-execution/$projectId/$reportId';

  // ── Cement Checklist ──────────────────────────────────────────────────────────
  static String cementChecklistIndex(int projectId) =>
      '$baseUrl$_mobile/cement-checklist/$projectId';

  static String cementChecklistCreate(int projectId) =>
      '$baseUrl$_mobile/cement-checklist/$projectId/create';

  static String cementChecklistStore(int projectId) =>
      '$baseUrl$_mobile/cement-checklist/$projectId';

  static String cementChecklistShow(int projectId, int id) =>
      '$baseUrl$_mobile/cement-checklist/$projectId/$id';

  static String cementChecklistEdit(int projectId, int id) =>
      '$baseUrl$_mobile/cement-checklist/$projectId/$id/edit';

  static String cementChecklistUpdatePost(int projectId, int id) =>
      '$baseUrl$_mobile/cement-checklist/$projectId/$id/update';

  static String cementChecklistUpdate(int projectId, int id) =>
      '$baseUrl$_mobile/cement-checklist/$projectId/$id';

  static String cementChecklistDestroy(int projectId, int id) =>
      '$baseUrl$_mobile/cement-checklist/$projectId/$id';

  static String cementChecklistPrint(int projectId, int id) =>
      '$baseUrl$_mobile/cement-checklist/$projectId/$id/print';

  static String cementChecklistDownload(int projectId, int id) =>
      '$baseUrl$_mobile/cement-checklist/$projectId/$id/download';

  // ── Steel Checklist ───────────────────────────────────────────────────────────
  static String steelChecklistIndex(int projectId) =>
      '$baseUrl$_mobile/steel-checklist/$projectId';

  static String steelChecklistCreate(int projectId) =>
      '$baseUrl$_mobile/steel-checklist/$projectId/create';

  static String steelChecklistStore(int projectId) =>
      '$baseUrl$_mobile/steel-checklist/$projectId';

  static String steelChecklistShow(int projectId, int id) =>
      '$baseUrl$_mobile/steel-checklist/$projectId/$id';

  static String steelChecklistEdit(int projectId, int id) =>
      '$baseUrl$_mobile/steel-checklist/$projectId/$id/edit';

  static String steelChecklistPut(int projectId, int id) =>
      '$baseUrl$_mobile/steel-checklist/$projectId/$id/update';

  static String steelChecklistUpdate(int projectId, int id) =>
      '$baseUrl$_mobile/steel-checklist/$projectId/$id';

  static String steelChecklistDestroy(int projectId, int id) =>
      '$baseUrl$_mobile/steel-checklist/$projectId/$id';

  static String steelChecklistPrint(int projectId, int id) =>
      '$baseUrl$_mobile/steel-checklist/$projectId/$id/print';

  static String steelChecklistDownload(int projectId, int id) =>
      '$baseUrl$_mobile/steel-checklist/$projectId/$id/download';

  // ── Excavation Checklist ──────────────────────────────────────────────────────
  static String excavationChecklistIndex(int projectId) =>
      '$baseUrl$_mobile/excavation-checklist/$projectId';

  static String excavationChecklistCreate(int projectId) =>
      '$baseUrl$_mobile/excavation-checklist/$projectId/create';

  static String excavationChecklistStore(int projectId) =>
      '$baseUrl$_mobile/excavation-checklist/$projectId';

  static String excavationChecklistShow(int projectId, int id) =>
      '$baseUrl$_mobile/excavation-checklist/$projectId/$id';

  static String excavationChecklistEdit(int projectId, int id) =>
      '$baseUrl$_mobile/excavation-checklist/$projectId/$id/edit';

  static String excavationChecklistUpdatePost(int projectId, int id) =>
      '$baseUrl$_mobile/excavation-checklist/$projectId/$id/update';

  static String excavationChecklistUpdate(int projectId, int id) =>
      '$baseUrl$_mobile/excavation-checklist/$projectId/$id';

  static String excavationChecklistDestroy(int projectId, int id) =>
      '$baseUrl$_mobile/excavation-checklist/$projectId/$id';

  static String excavationChecklistPrint(int projectId, int id) =>
      '$baseUrl$_mobile/excavation-checklist/$projectId/$id/print';

  static String excavationChecklistDownload(int projectId, int id) =>
      '$baseUrl$_mobile/excavation-checklist/$projectId/$id/download';

  // ── Shuttering Checklist ──────────────────────────────────────────────────────
  static String shutteringChecklistIndex(int projectId) =>
      '$baseUrl$_mobile/shuttering-checklist/$projectId';

  static String shutteringChecklistCreate(int projectId) =>
      '$baseUrl$_mobile/shuttering-checklist/$projectId/create';

  static String shutteringChecklistStore(int projectId) =>
      '$baseUrl$_mobile/shuttering-checklist/$projectId';

  static String shutteringChecklistShow(int projectId, int id) =>
      '$baseUrl$_mobile/shuttering-checklist/$projectId/$id';

  static String shutteringChecklistEdit(int projectId, int id) =>
      '$baseUrl$_mobile/shuttering-checklist/$projectId/$id/edit';

  static String shutteringChecklistUpdate(int projectId, int id) =>
      '$baseUrl$_mobile/shuttering-checklist/$projectId/$id';

  static String shutteringChecklistUpdatePost(int projectId, int id) =>
      '$baseUrl$_mobile/shuttering-checklist/$projectId/$id/update';

  static String shutteringChecklistDestroy(int projectId, int id) =>
      '$baseUrl$_mobile/shuttering-checklist/$projectId/$id/delete';

  static String shutteringChecklistPrint(int projectId, int id) =>
      '$baseUrl$_mobile/shuttering-checklist/$projectId/$id/print';

  static String shutteringChecklistDownload(int projectId, int id) =>
      '$baseUrl$_mobile/shuttering-checklist/$projectId/$id/download';

  // ── Concreting Checklist ──────────────────────────────────────────────────────
  static String concretingChecklistIndex(int projectId) =>
      '$baseUrl$_mobile/concreting-checklist/$projectId';

  static String concretingChecklistCreate(int projectId) =>
      '$baseUrl$_mobile/concreting-checklist/$projectId/create';

  static String concretingChecklistStore(int projectId) =>
      '$baseUrl$_mobile/concreting-checklist/$projectId';

  static String concretingChecklistShow(int projectId, int id) =>
      '$baseUrl$_mobile/concreting-checklist/$projectId/$id';

  static String concretingChecklistEdit(int projectId, int id) =>
      '$baseUrl$_mobile/concreting-checklist/$projectId/$id/edit';

  static String concretingChecklistUpdate(int projectId, int id) =>
      '$baseUrl$_mobile/concreting-checklist/$projectId/$id';

  static String concretingChecklistUpdatePost(int projectId, int id) =>
      '$baseUrl$_mobile/concreting-checklist/$projectId/$id/update';

  static String concretingChecklistDestroy(int projectId, int id) =>
      '$baseUrl$_mobile/concreting-checklist/$projectId/$id';

  static String concretingChecklistDestroyPost(int projectId, int id) =>
      '$baseUrl$_mobile/concreting-checklist/$projectId/$id/delete';

  static String concretingChecklistPrint(int projectId, int id) =>
      '$baseUrl$_mobile/concreting-checklist/$projectId/$id/print';

  static String concretingChecklistDownload(int projectId, int id) =>
      '$baseUrl$_mobile/concreting-checklist/$projectId/$id/download';

  // ── Site Instruction ──────────────────────────────────────────────────────────
  static String siteInstructionIndex(int projectId) =>
      '$baseUrl$_mobile/site-instruction/$projectId';

  static String siteInstructionCreate(int projectId) =>
      '$baseUrl$_mobile/site-instruction/$projectId/create';

  static String siteInstructionStore(int projectId) =>
      '$baseUrl$_mobile/site-instruction/$projectId';

  static String siteInstructionShow(int projectId, int id) =>
      '$baseUrl$_mobile/site-instruction/$projectId/$id';

  static String siteInstructionEdit(int projectId, int id) =>
      '$baseUrl$_mobile/site-instruction/$projectId/$id/edit';

  static String siteInstructionUpdatePost(int projectId, int id) =>
      '$baseUrl$_mobile/site-instruction/$projectId/$id/update';

  static String siteInstructionUpdate(int projectId, int id) =>
      '$baseUrl$_mobile/site-instruction/$projectId/$id';

  static String siteInstructionDestroy(int projectId, int id) =>
      '$baseUrl$_mobile/site-instruction/$projectId/$id';

  static String siteInstructionDeletePost(int projectId, int id) =>
      '$baseUrl$_mobile/site-instruction/$projectId/$id/delete';

  static String siteInstructionPrint(int projectId, int id) =>
      '$baseUrl$_mobile/site-instruction/$projectId/$id/print';

  static String siteInstructionDownload(int projectId, int id) =>
      '$baseUrl$_mobile/site-instruction/$projectId/$id/download';

  // ── Reinforcement Checklist ───────────────────────────────────────────────────
  static String reinforcementChecklistIndex(int projectId) =>
      '$baseUrl$_mobile/reinforcement-checklist/$projectId';

  static String reinforcementChecklistCreate(int projectId) =>
      '$baseUrl$_mobile/reinforcement-checklist/$projectId/create';

  static String reinforcementChecklistStore(int projectId) =>
      '$baseUrl$_mobile/reinforcement-checklist/$projectId';

  static String reinforcementChecklistShow(int projectId, int id) =>
      '$baseUrl$_mobile/reinforcement-checklist/$projectId/$id';

  static String reinforcementChecklistEdit(int projectId, int id) =>
      '$baseUrl$_mobile/reinforcement-checklist/$projectId/$id/edit';

  static String reinforcementChecklistUpdate(int projectId, int id) =>
      '$baseUrl$_mobile/reinforcement-checklist/$projectId/$id';

  static String reinforcementChecklistDestroy(int projectId, int id) =>
      '$baseUrl$_mobile/reinforcement-checklist/$projectId/$id';

  static String reinforcementChecklistPrint(int projectId, int id) =>
      '$baseUrl$_mobile/reinforcement-checklist/$projectId/$id/print';

  static String reinforcementChecklistDownload(int projectId, int id) =>
      '$baseUrl$_mobile/reinforcement-checklist/$projectId/$id/download';

  // ── Concrete Cube Results ─────────────────────────────────────────────────────
  static String concreteCubeResultsIndex(int projectId) =>
      '$baseUrl$_mobile/concrete-cube-results/$projectId';

  static String concreteCubeResultsStore(int projectId) =>
      '$baseUrl$_mobile/concrete-cube-results/$projectId';

  static String concreteCubeResultsShow(int projectId, int id) =>
      '$baseUrl$_mobile/concrete-cube-results/$projectId/$id';

  static String concreteCubeResultsEdit(int projectId, int id) =>
      '$baseUrl$_mobile/concrete-cube-results/$projectId/$id/edit';

  static String concreteCubeResultsUpdate(int projectId, int id) =>
      '$baseUrl$_mobile/concrete-cube-results/$projectId/$id';

  static String concreteCubeResultsDestroy(int projectId, int id) =>
      '$baseUrl$_mobile/concrete-cube-results/$projectId/$id';

  static String concreteCubeResultsPrint(int projectId, int id) =>
      '$baseUrl$_mobile/concrete-cube-results/$projectId/$id/print';

  static String concreteCubeResultsDownload(int projectId, int id) =>
      '$baseUrl$_mobile/concrete-cube-results/$projectId/$id/download';

  // ── Approval Form ──────────────────────────────────────────────────────────
static String approvalFormIndex(int projectId) =>
    '$baseUrl$_mobile/approval-form/$projectId';
static String approvalFormCreate(int projectId) =>
    '$baseUrl$_mobile/approval-form/$projectId/create';
static String approvalFormStore(int projectId) =>
    '$baseUrl$_mobile/approval-form/$projectId';
static String approvalFormShow(int projectId, int id) =>
    '$baseUrl$_mobile/approval-form/$projectId/$id';
static String approvalFormEdit(int projectId, int id) =>
    '$baseUrl$_mobile/approval-form/$projectId/$id/edit';

// POST to /update alias — avoids LiteSpeed WAF blocking PUT verb
static String approvalFormUpdate(int projectId, int id) =>
    '$baseUrl$_mobile/approval-form/$projectId/$id/update';

// POST to /delete alias — avoids LiteSpeed WAF blocking DELETE verb  
static String approvalFormDestroy(int projectId, int id) =>
    '$baseUrl$_mobile/approval-form/$projectId/$id/delete';

static String approvalFormPrint(int projectId, int id) =>
    '$baseUrl$_mobile/approval-form/$projectId/$id/print';
static String approvalFormDownload(int projectId, int id) =>
    '$baseUrl$_mobile/approval-form/$projectId/$id/download';

  // ── Architecture Checklist ────────────────────────────────────────────────────
  static String architectureChecklistIndex(int projectId) =>
      '$baseUrl$_mobile/architecture-checklist/$projectId';

  static String architectureChecklistCreate(int projectId) =>
      '$baseUrl$_mobile/architecture-checklist/$projectId/create';

  static String architectureChecklistStore(int projectId) =>
      '$baseUrl$_mobile/architecture-checklist/$projectId';

  static String architectureChecklistShow(int projectId, int id) =>
      '$baseUrl$_mobile/architecture-checklist/$projectId/$id';

  static String architectureChecklistEdit(int projectId, int id) =>
      '$baseUrl$_mobile/architecture-checklist/$projectId/$id/edit';

  static String architectureChecklistUpdate(int projectId, int id) =>
      '$baseUrl$_mobile/architecture-checklist/$projectId/$id';

  static String architectureChecklistDestroy(int projectId, int id) =>
      '$baseUrl$_mobile/architecture-checklist/$projectId/$id';

  static String architectureChecklistPrint(int projectId, int id) =>
      '$baseUrl$_mobile/architecture-checklist/$projectId/$id/print';

  static String architectureChecklistDownload(int projectId, int id) =>
      '$baseUrl$_mobile/architecture-checklist/$projectId/$id/download';

  // ── Concrete Pour Card ────────────────────────────────────────────────────────
  static String concretePourCardIndex(int projectId) =>
      '$baseUrl$_mobile/concrete-pour-card/$projectId';

  static String concretePourCardCreate(int projectId) =>
      '$baseUrl$_mobile/concrete-pour-card/$projectId/create';

  static String concretePourCardStore(int projectId) =>
      '$baseUrl$_mobile/concrete-pour-card/$projectId';

  static String concretePourCardShow(int projectId, int id) =>
      '$baseUrl$_mobile/concrete-pour-card/$projectId/$id';

  static String concretePourCardEdit(int projectId, int id) =>
      '$baseUrl$_mobile/concrete-pour-card/$projectId/$id/edit';

  static String concretePourCardUpdate(int projectId, int id) =>
      '$baseUrl$_mobile/concrete-pour-card/$projectId/$id/update';

  static String concretePourCardDestroy(int projectId, int id) =>
      '$baseUrl$_mobile/concrete-pour-card/$projectId/$id';

  static String concretePourCardPrint(int projectId, int id) =>
      '$baseUrl$_mobile/concrete-pour-card/$projectId/$id/print';

  static String concretePourCardDownload(int projectId, int id) =>
      '$baseUrl$_mobile/concrete-pour-card/$projectId/$id/download';

  // ── Minutes of Meeting (MOM) ──────────────────────────────────────────────────
  static String calendarEvents(int projectId) =>
      '$baseUrl$_mobile/projects/$projectId/mom/calendar-events';

  static String scheduledMeetingsList(int projectId) =>
      '$baseUrl$_mobile/projects/$projectId/scheduled-meetings';

  static String scheduledMeetingDetails(int meetingId) =>
      '$baseUrl$_mobile/scheduled-meeting/$meetingId';

  static String scheduledMeetingForMom(int meetingId) =>
      '$baseUrl$_mobile/scheduled-meeting/$meetingId/for-mom';

  static String storeScheduledMeeting() =>
      '$baseUrl$_mobile/scheduled-meeting';

  static String deleteScheduledMeeting(int meetingId) =>
      '$baseUrl$_mobile/scheduled-meeting/$meetingId/delete';

  static String storeMom() =>
      '$baseUrl$_mobile/mom';

  static String momDetails(int momId) =>
      '$baseUrl$_mobile/mom/$momId';

  static String updateMom(int momId) =>
      '$baseUrl$_mobile/mom/$momId/update';

  static String deleteMom(int momId) =>
      '$baseUrl$_mobile/mom/$momId/delete';

  static String downloadMomPdf(int momId) =>
      '$baseUrl$_mobile/mom/$momId/download-pdf';

  static String meetingsDatatable(int projectId) =>
      '$baseUrl$_mobile/projects/$projectId/meetings-list';

  // ── CC Progress ───────────────────────────────────────────────────────────────
  static String ccProgressIndex(int projectId) =>
      '$baseUrl$_mobile/cc-progress/$projectId';

  static String ccProgressStage(int projectId, String stageName) =>
      '$baseUrl$_mobile/cc-progress/$projectId/stage/$stageName';

  static String ccProgressSummary(int projectId) =>
      '$baseUrl$_mobile/cc-progress/$projectId/summary';

  static String get ccProgressUpdateStatus =>
      '$baseUrl$_mobile/cc-progress/update-status';

  static String get ccProgressRemoveStatus =>
      '$baseUrl$_mobile/cc-progress/remove-status';

  static String get ccProgressUploadFile =>
      '$baseUrl$_mobile/cc-progress/upload-file';

  // ── Layout Approval Progress ──────────────────────────────────────────────────
  static String layoutApprovalIndex(int projectId) =>
      '$baseUrl$_mobile/layout-approval/$projectId';

  static String layoutApprovalStage(int projectId, String stageName) =>
      '$baseUrl$_mobile/layout-approval/$projectId/stage/$stageName';

  static String layoutApprovalSummary(int projectId) =>
      '$baseUrl$_mobile/layout-approval/$projectId/summary';

  static String get layoutApprovalUpdateStatus =>
      '$baseUrl$_mobile/layout-approval/update-status';

  static String get layoutApprovalRemoveStatus =>
      '$baseUrl$_mobile/layout-approval/remove-status';

  static String get layoutApprovalUploadFile =>
      '$baseUrl$_mobile/layout-approval/upload-file';

  static String get layoutApprovalDeleteFile =>
      '$baseUrl$_mobile/layout-approval/delete-file';

  // ── OC Progress ───────────────────────────────────────────────────────────────
  static String ocProgressIndex(int projectId) =>
      '$baseUrl$_mobile/oc-progress/$projectId';

  static String ocProgressStage(int projectId, String stageName) =>
      '$baseUrl$_mobile/oc-progress/$projectId/stage/$stageName';

  static String ocProgressSummary(int projectId) =>
      '$baseUrl$_mobile/oc-progress/$projectId/summary';

  static String get ocProgressUpdateStatus =>
      '$baseUrl$_mobile/oc-progress/update-status';

  static String get ocProgressRemoveStatus =>
      '$baseUrl$_mobile/oc-progress/remove-status';

  static String get ocProgressUploadFile =>
      '$baseUrl$_mobile/oc-progress/upload-file';

  static String get ocProgressDeleteFile =>
      '$baseUrl$_mobile/oc-progress/delete-file';

  // ── NOC Map ───────────────────────────────────────────────────────────────────
  static String nocMapIndex(int projectId) =>
      '$baseUrl$_mobile/projects/$projectId/noc-map';

  static String nocMapProcessDetail(int projectId, int processId) =>
      '$baseUrl$_mobile/projects/$projectId/noc-map/process/$processId';

  static String nocMapFilter(int projectId) =>
      '$baseUrl$_mobile/projects/$projectId/noc-map/filter';

  // ── NOC Analytics ─────────────────────────────────────────────────────────────
  static String get nocAnalyticsOverallStats =>
      '$baseUrl$_mobile/noc-analytics/overall-stats';

  static String get nocAnalyticsProjects =>
      '$baseUrl$_mobile/noc-analytics/projects';

  static String nocAnalyticsProjectDetail(int projectId) =>
      '$baseUrl$_mobile/noc-analytics/projects/$projectId';

  static String nocAnalyticsGrouped(int projectId) =>
      '$baseUrl$_mobile/noc-analytics/projects/$projectId/grouped';

      // ── Employee Report ───────────────────────────────────────────────────────────
  static String get employeeReportInit     => '$baseUrl$_mobile/employee-report/init';
  static String get employeeReportGenerate => '$baseUrl$_mobile/employee-report/generate';
  static String get employeeReportDetails  => '$baseUrl$_mobile/employee-report/task-details';

      // ── Project Report ─────────────────────────────────────────────────────────
  static String get projectReportProjects =>
    '$baseUrl$_mobile/project-report/projects';
 
  static String get projectReportGenerate =>
    '$baseUrl$_mobile/project-report/generate';


       // ── Team Report ───────────────────────────────────────────────────────────────
  static String get teamReportTeams   => '$baseUrl$_mobile/team-report/teams';
  static String get teamReportMembers => '$baseUrl$_mobile/team-report/members';
  static String get teamReportGenerate => '$baseUrl$_mobile/team-report/generate';
        
       // ── Stage Report ──────────────────────────────────────────────────────────
  static String get stageReportProjects =>
      '$baseUrl$_mobile/stage-report/projects';
 
  static String get stageReportData =>
      '$baseUrl$_mobile/stage-report/data';

    // ── Re-Development Process (mobile API) ──────────────────────────────────────
 
/// GET  /api/mobile/processes?stage={stage}
static String get processMobileList => '$baseUrl$_mobile/processes';
 
/// GET  /api/mobile/processes/teams
static String get processMobileTeams => '$baseUrl$_mobile/processes/teams';
 
/// GET  /api/mobile/processes/{orderNo}
static String processMobileShow(int orderNo) =>
    '$baseUrl$_mobile/processes/$orderNo';
 
/// POST /api/mobile/processes
static String get processMobileStore => '$baseUrl$_mobile/processes';
 
/// POST /api/mobile/processes/{orderNo}/update
static String processMobileUpdate(int orderNo) =>
    '$baseUrl$_mobile/processes/$orderNo/update';
 
/// POST /api/mobile/processes/{orderNo}/delete
static String processMobileDelete(int orderNo) =>
    '$baseUrl$_mobile/processes/$orderNo/delete';
 
/// POST /api/mobile/processes/{orderNo}/update-team
static String processMobileUpdateTeam(int orderNo) =>
    '$baseUrl$_mobile/processes/$orderNo/update-team';

// ── Development Process endpoints ─────────────────────────────────────────
  //
  // NOTE: These are `static String` (NOT `static const String`) because
  // they reference `baseUrl` via string interpolation, which is a
  // runtime expression and therefore cannot be `const` in Dart.
 
  static String get devProcessBase      => '$baseUrl$_mobile/development-process';
  static String get devProcessList      => '$devProcessBase/processes';
  static String get devProcessAllStages => '$devProcessBase/all-stages';
  static String get devProcessTeams     => '$devProcessBase/teams';
  static String get devProcessStore     => '$devProcessBase/store';
  static String get devProcessUpdate    => '$devProcessBase/update';
  static String get devProcessMaxOrder  => '$devProcessBase/max-order';
  static String get devProcessAssign    => '$devProcessBase/assign';
 
  // Parametric helpers — call like: ApiConstants.devProcessEdit(42)
  static String devProcessEdit(int processId)    => '$devProcessBase/edit/$processId';
  static String devProcessDelete(int processId)  => '$devProcessBase/delete/$processId';
  static String devProcessProject(int projectId) => '$devProcessBase/project/$projectId';
  static String devProcessTeamMembers(int teamId)=> '$devProcessBase/team-members/$teamId';  

  // ADD after devProcessTeamMembers line:
static String get devProcessFileUrl => '$devProcessBase/file-url'; 

static String devProcessUpload(int projectId) =>
    '$devProcessBase/$projectId/upload';
}