// lib/features/stage21/data/services/dpr_api_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/services/auth_storage_service.dart';
import '../../../../core/utils/api_exception.dart';
import '../models/daily_project_report_model.dart';

class DprApiService {
  DprApiService._();

  static const String _tag = 'DprApiService';

  // ── Auth headers ───────────────────────────────────────────────────────────

  static Future<Map<String, String>> _headers() async {
    final token = await AuthStorageService.getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, String>> _multipartHeaders() async {
    final token = await AuthStorageService.getToken();
    return {
      'Accept': 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // ── URL helpers ────────────────────────────────────────────────────────────

  static String _base(int projectId) =>
      '${ApiConstants.baseUrl}/api/mobile/projects/$projectId/dpr';

  static String _item(int projectId, int id) => '${_base(projectId)}/$id';

  // ── Decode ────────────────────────────────────────────────────────────────

  static dynamic _decode(String body) {
    if (body.isEmpty) return {};
    try {
      return jsonDecode(body);
    } catch (_) {
      return {'message': body};
    }
  }

  // ── Error extraction ──────────────────────────────────────────────────────

  static String _extractError(dynamic body, int statusCode, String fallback) {
    if (body is Map) {
      if (body['errors'] is Map) {
        final errs = body['errors'] as Map;
        if (errs.isNotEmpty) {
          final first = errs.values.first;
          if (first is List && first.isNotEmpty) return first.first.toString();
        }
      }
      if (body['message'] != null) return body['message'].toString();
    }
    return '$fallback (HTTP $statusCode)';
  }

  // ── List ──────────────────────────────────────────────────────────────────

  static Future<List<DailyProjectReportSummary>> fetchReports(
      int projectId) async {
    final url = _base(projectId);
    developer.log('fetchReports → GET $url', name: _tag);

    try {
      final response = await http
          .get(Uri.parse(url), headers: await _headers())
          .timeout(ApiConstants.requestTimeout);

      final body = _decode(response.body);
      developer.log('fetchReports ← ${response.statusCode}', name: _tag);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = body['reports'];
        if (raw is! List) return [];
        return raw
            .whereType<Map<String, dynamic>>()
            .map(DailyProjectReportSummary.fromJson)
            .toList();
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(_extractError(body, response.statusCode, 'Failed to load reports'));
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Fetch reports error: $e');
    }
  }

  // ── Next Report Number ────────────────────────────────────────────────────

  static Future<String> fetchNextReportNo(int projectId) async {
    final url = '${_base(projectId)}/next-report-no';
    developer.log('fetchNextReportNo → GET $url', name: _tag);

    try {
      final response = await http
          .get(Uri.parse(url), headers: await _headers())
          .timeout(ApiConstants.requestTimeout);

      final body = _decode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return body['report_no']?.toString() ?? '';
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(_extractError(body, response.statusCode, 'Failed to generate report number'));
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Next report no error: $e');
    }
  }

  // ── Show ──────────────────────────────────────────────────────────────────

  static Future<DailyProjectReportDetail> fetchReport(
      int projectId, int id) async {
    final url = _item(projectId, id);
    developer.log('fetchReport → GET $url', name: _tag);

    try {
      final response = await http
          .get(Uri.parse(url), headers: await _headers())
          .timeout(ApiConstants.requestTimeout);

      final body = _decode(response.body);
      developer.log('fetchReport ← ${response.statusCode}', name: _tag);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = body['report'];
        if (raw is! Map<String, dynamic>) {
          throw ApiException('Invalid report data format.');
        }
        return DailyProjectReportDetail.fromJson(raw);
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      if (response.statusCode == 404) {
        throw ApiException('Report not found.');
      }
      throw ApiException(_extractError(body, response.statusCode, 'Failed to load report'));
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Fetch report error: $e');
    }
  }

  // ── Store ─────────────────────────────────────────────────────────────────

  static Future<DailyProjectReportSummary> createReport({
    required int projectId,
    required String reportDate,
    String? weather,
    required List<Map<String, dynamic>> laborReport,
    required List<Map<String, dynamic>> progressPrevious,
    required List<Map<String, dynamic>> worksPlanned,
    String? decisionsApprovals,
    String? bottleNecks,
    String? changeAuthorizations,
    String? materialDelivered,
    String? ehsIncidentReports,
    List<File> progressPhotos = const [],
  }) async {
    final url = _base(projectId);
    developer.log('createReport → POST $url', name: _tag);

    try {
      final request = http.MultipartRequest('POST', Uri.parse(url))
        ..headers.addAll(await _multipartHeaders())
        ..fields['report_date'] = reportDate
        ..fields['labor_report'] = jsonEncode(laborReport)
        ..fields['progress_previous'] = jsonEncode(progressPrevious)
        ..fields['works_planned'] = jsonEncode(worksPlanned);

      if (weather != null && weather.isNotEmpty) {
        request.fields['weather'] = weather;
      }
      if (decisionsApprovals != null && decisionsApprovals.isNotEmpty) {
        request.fields['decisions_approvals'] = decisionsApprovals;
      }
      if (bottleNecks != null && bottleNecks.isNotEmpty) {
        request.fields['bottle_necks'] = bottleNecks;
      }
      if (changeAuthorizations != null && changeAuthorizations.isNotEmpty) {
        request.fields['change_authorizations'] = changeAuthorizations;
      }
      if (materialDelivered != null && materialDelivered.isNotEmpty) {
        request.fields['material_delivered'] = materialDelivered;
      }
      if (ehsIncidentReports != null && ehsIncidentReports.isNotEmpty) {
        request.fields['ehs_incident_reports'] = ehsIncidentReports;
      }

      for (final photo in progressPhotos) {
        final mime = lookupMimeType(photo.path) ?? 'application/octet-stream';
        final parts = mime.split('/');
        request.files.add(await http.MultipartFile.fromPath(
          'progress_photos[]',
          photo.path,
          contentType: MediaType(parts[0], parts[1]),
        ));
      }

      final streamed = await request.send().timeout(const Duration(seconds: 120));
      final bodyStr  = await streamed.stream.bytesToString();
      final decoded  = _decode(bodyStr);

      developer.log('createReport ← ${streamed.statusCode}', name: _tag);

      if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
        final raw = decoded['report'];
        if (raw is Map<String, dynamic>) {
          return DailyProjectReportSummary.fromJson(raw);
        }
        throw ApiException('Unexpected response format.');
      }
      if (streamed.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(_extractError(decoded, streamed.statusCode, 'Failed to create report'));
    } on TimeoutException {
      throw ApiException('Upload timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Create report error: $e');
    }
  }

  // ── Update ────────────────────────────────────────────────────────────────

  static Future<DailyProjectReportSummary> updateReport({
    required int projectId,
    required int id,
    required String reportDate,
    String? weather,
    required List<Map<String, dynamic>> laborReport,
    required List<Map<String, dynamic>> progressPrevious,
    required List<Map<String, dynamic>> worksPlanned,
    String? decisionsApprovals,
    String? bottleNecks,
    String? changeAuthorizations,
    String? materialDelivered,
    String? ehsIncidentReports,
    List<File> newProgressPhotos = const [],
    List<String> deletedPhotos = const [],
  }) async {
    // Use POST alias for LiteSpeed WAF compatibility
    final url = '${_item(projectId, id)}/update';
    developer.log('updateReport → POST $url', name: _tag);

    try {
      final request = http.MultipartRequest('POST', Uri.parse(url))
        ..headers.addAll(await _multipartHeaders())
        ..fields['report_date']       = reportDate
        ..fields['labor_report']      = jsonEncode(laborReport)
        ..fields['progress_previous'] = jsonEncode(progressPrevious)
        ..fields['works_planned']     = jsonEncode(worksPlanned);

      if (weather != null && weather.isNotEmpty) {
        request.fields['weather'] = weather;
      }
      if (decisionsApprovals != null) {
        request.fields['decisions_approvals'] = decisionsApprovals;
      }
      if (bottleNecks != null) {
        request.fields['bottle_necks'] = bottleNecks;
      }
      if (changeAuthorizations != null) {
        request.fields['change_authorizations'] = changeAuthorizations;
      }
      if (materialDelivered != null) {
        request.fields['material_delivered'] = materialDelivered;
      }
      if (ehsIncidentReports != null) {
        request.fields['ehs_incident_reports'] = ehsIncidentReports;
      }

      // Deleted photo paths
      for (int i = 0; i < deletedPhotos.length; i++) {
        request.fields['deleted_photos[$i]'] = deletedPhotos[i];
      }

      // New photos
      for (final photo in newProgressPhotos) {
        final mime  = lookupMimeType(photo.path) ?? 'application/octet-stream';
        final parts = mime.split('/');
        request.files.add(await http.MultipartFile.fromPath(
          'new_progress_photos[]',
          photo.path,
          contentType: MediaType(parts[0], parts[1]),
        ));
      }

      final streamed = await request.send().timeout(const Duration(seconds: 120));
      final bodyStr  = await streamed.stream.bytesToString();
      final decoded  = _decode(bodyStr);

      developer.log('updateReport ← ${streamed.statusCode}', name: _tag);

      if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
        final raw = decoded['report'];
        if (raw is Map<String, dynamic>) {
          return DailyProjectReportSummary.fromJson(raw);
        }
        // Fallback: re-fetch summary if body doesn't include it
        final list = await fetchReports(projectId);
        return list.firstWhere(
          (r) => r.id == id,
          orElse: () => DailyProjectReportSummary(id: id, reportNo: ''),
        );
      }
      if (streamed.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(_extractError(decoded, streamed.statusCode, 'Failed to update report'));
    } on TimeoutException {
      throw ApiException('Upload timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Update report error: $e');
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  static Future<void> deleteReport(int projectId, int id) async {
    // Use POST alias for LiteSpeed WAF compatibility
    final url = '${_item(projectId, id)}/delete';
    developer.log('deleteReport → POST $url', name: _tag);

    try {
      final response = await http
          .post(Uri.parse(url), headers: await _headers())
          .timeout(ApiConstants.requestTimeout);

      final body = _decode(response.body);
      developer.log('deleteReport ← ${response.statusCode}', name: _tag);

      if (response.statusCode >= 200 && response.statusCode < 300) return;
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      if (response.statusCode == 404) {
        throw ApiException('Report not found.');
      }
      throw ApiException(_extractError(body, response.statusCode, 'Failed to delete report'));
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Delete report error: $e');
    }
  }
}