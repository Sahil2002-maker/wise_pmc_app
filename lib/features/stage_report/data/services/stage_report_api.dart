// lib/features/stage_report/data/services/stage_report_api.dart
 
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
 
import '../../../../core/services/auth_storage_service.dart';
import '../../../../core/utils/api_exception.dart';
import '../models/stage_report_models.dart';
 
/// Standalone API helper for Stage Report so it can be used
/// without modifying the monolithic ApiService during integration.
/// Once ready, move the two static methods into ApiService and
/// the constants into ApiConstants following the project's convention.
class StageReportApi {
  static const String _base = 'https://test.pmc.wisehome.in/api/mobile';
  static const Duration _timeout = Duration(seconds: 30);
 
  static Future<Map<String, String>> _headers() async {
    final token = await AuthStorageService.getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }
 
  static dynamic _decode(String body) {
    if (body.isEmpty) return {};
    try {
      return jsonDecode(body);
    } catch (_) {
      return {'message': body};
    }
  }
 
  // ── Project list for the dropdown ────────────────────────────────────────
 
  static Future<List<StageReportProject>> fetchProjects() async {
    final url = Uri.parse('$_base/stage-report/projects');
    developer.log('[StageReportApi] fetchProjects → GET $url',
        name: 'StageReportApi');
 
    try {
      final response = await http
          .get(url, headers: await _headers())
          .timeout(_timeout);
 
      final body = _decode(response.body);
      developer.log(
          '[StageReportApi] fetchProjects ← ${response.statusCode}',
          name: 'StageReportApi');
 
      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Accept both { data: [...] } and flat list
        List<dynamic> raw = [];
        if (body is List) {
          raw = body;
        } else if (body is Map) {
          final d = body['data'] ?? body['projects'] ?? body['items'];
          if (d is List) raw = d;
        }
        int idx = 1;
        return raw
            .whereType<Map>()
            .map((e) =>
                StageReportProject.fromJson(Map<String, dynamic>.from(e)))
            .where((p) => p.id > 0 && p.societyName.isNotEmpty)
            .toList();
      }
 
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
 
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to load projects (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Stage report projects error: $e');
    }
  }
 
  // ── Stage report data (server-side DataTables-compatible) ────────────────
 
  static Future<StageReportResponse> fetchReportData({
    int? projectId,
    int start = 0,
    int length = 25,
    String search = '',
  }) async {
    final params = {
      'draw': '1',
      'start': start.toString(),
      'length': length.toString(),
      if (search.isNotEmpty) 'search[value]': search,
      if (projectId != null) 'project_id': projectId.toString(),
    };
 
    final url = Uri.parse('$_base/stage-report/data')
        .replace(queryParameters: params);
 
    developer.log('[StageReportApi] fetchReportData → GET $url',
        name: 'StageReportApi');
 
    try {
      final response = await http
          .get(url, headers: await _headers())
          .timeout(_timeout);
 
      final body = _decode(response.body);
      developer.log(
          '[StageReportApi] fetchReportData ← ${response.statusCode}',
          name: 'StageReportApi');
 
      if (response.statusCode >= 200 && response.statusCode < 300) {
        List<dynamic> rawData = [];
        if (body is Map) {
          final d = body['data'];
          if (d is List) rawData = d;
        } else if (body is List) {
          rawData = body;
        }
 
        final int total = body is Map
            ? (int.tryParse(
                    body['recordsTotal']?.toString() ??
                        body['total']?.toString() ??
                        '0') ??
                0)
            : rawData.length;
 
        int srNo = start + 1;
        final rows = rawData
            .whereType<Map>()
            .map((e) => StageReportRow.fromJson(
                  Map<String, dynamic>.from(e),
                  srNo: srNo++,
                ))
            .toList();
 
        return StageReportResponse(
          rows: rows,
          total: total,
          currentPage: (start ~/ (length == 0 ? 1 : length)) + 1,
          lastPage: total == 0 ? 1 : ((total + length - 1) ~/ length),
        );
      }
 
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
 
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to load stage report (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Stage report data error: $e');
    }
  }
}