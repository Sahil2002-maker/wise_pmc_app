// lib/features/re_execution/data/services/re_execution_api_service.dart
//
// Thin wrapper that delegates every call to the central ApiService.
// This keeps HTTP logic in one place — any future auth/timeout change
// made to ApiService is automatically picked up here.

import '../../../../core/services/api_service.dart';
import '../models/re_execution_model.dart';

class ReExecutionApiService {
  /// Fetch paginated list of daily progress reports for [projectId].
  ///
  /// Returns a map with keys:
  ///   `reports`      → `List<ReExecutionModel>`
  ///   `project`      → `Map<String, dynamic>`
  ///   `current_page` → `int`
  ///   `last_page`    → `int`
  ///   `total`        → `int`
  static Future<Map<String, dynamic>> fetchReports({
    required int projectId,
    int page = 1,
    int perPage = 15,
  }) =>
      ApiService.fetchReExecutionReports(
        projectId: projectId,
        page: page,
        perPage: perPage,
      );

  /// Fetch full detail of a single report.
  static Future<ReExecutionDetailModel> fetchReportDetail({
    required int projectId,
    required int reportId,
  }) =>
      ApiService.fetchReExecutionDetail(
        projectId: projectId,
        reportId: reportId,
      );

  /// Create a new daily progress report.
  static Future<ReExecutionDetailModel> createReport({
    required int projectId,
    required String reportDate,
    required List<Map<String, dynamic>> laborAgencies,
    required List<Map<String, dynamic>> previousProgress,
    required List<Map<String, dynamic>> plannedWorks,
    String? decisionsApprovals,
    String? bottleNecks,
    String? changeAuthorizations,
    String? materialDelivered,
    String? ehsIncidentReports,
  }) =>
      ApiService.createReExecutionReport(
        projectId:            projectId,
        reportDate:           reportDate,
        laborAgencies:        laborAgencies,
        previousProgress:     previousProgress,
        plannedWorks:         plannedWorks,
        decisionsApprovals:   decisionsApprovals  ?? '',
        bottleNecks:          bottleNecks         ?? '',
        changeAuthorizations: changeAuthorizations ?? '',
        materialDelivered:    materialDelivered   ?? '',
        ehsIncidentReports:   ehsIncidentReports  ?? '',
      );

  /// Update an existing daily progress report.
  static Future<ReExecutionDetailModel> updateReport({
    required int projectId,
    required int reportId,
    required String reportDate,
    required List<Map<String, dynamic>> laborAgencies,
    required List<Map<String, dynamic>> previousProgress,
    required List<Map<String, dynamic>> plannedWorks,
    String? decisionsApprovals,
    String? bottleNecks,
    String? changeAuthorizations,
    String? materialDelivered,
    String? ehsIncidentReports,
  }) =>
      ApiService.updateReExecutionReport(
        projectId:            projectId,
        reportId:             reportId,
        reportDate:           reportDate,
        laborAgencies:        laborAgencies,
        previousProgress:     previousProgress,
        plannedWorks:         plannedWorks,
        decisionsApprovals:   decisionsApprovals  ?? '',
        bottleNecks:          bottleNecks         ?? '',
        changeAuthorizations: changeAuthorizations ?? '',
        materialDelivered:    materialDelivered   ?? '',
        ehsIncidentReports:   ehsIncidentReports  ?? '',
      );

  /// Delete a report and its Google Drive files.
  static Future<void> deleteReport({
    required int projectId,
    required int reportId,
  }) =>
      ApiService.deleteReExecutionReport(
        projectId: projectId,
        reportId:  reportId,
      );
}