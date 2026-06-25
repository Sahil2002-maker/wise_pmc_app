// lib/features/dashboard/data/services/dashboard_api_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;

import '../../../../core/constants/api_constants.dart';
import '../../../../core/services/auth_storage_service.dart';
import '../../../../core/utils/api_exception.dart';
import '../models/dashboard_model.dart';

class DashboardApiService {
  // ── Headers ───────────────────────────────────────────────────────────────

  static Future<Map<String, String>> _headers() async {
    final token = await AuthStorageService.getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty)
        'Authorization': 'Bearer $token',
    };
  }

  // ── Base URL helper ───────────────────────────────────────────────────────
  // FIX: Strip any trailing slash from baseUrl before appending the path,
  // so "https://example.com/" + "/api/mobile/dashboard" never produces
  // "https://example.com//api/mobile/dashboard" which some servers reject.

  static String get _base =>
      ApiConstants.baseUrl.endsWith('/')
          ? ApiConstants.baseUrl.substring(
              0, ApiConstants.baseUrl.length - 1)
          : ApiConstants.baseUrl;

  // ── fetchDashboard ─────────────────────────────────────────────────────────
  /// GET /api/mobile/dashboard
  /// Optionally pass [startDate] and [endDate] as 'yyyy-MM-dd'.

  static Future<DashboardModel> fetchDashboard({
    String? startDate,
    String? endDate,
  }) async {
    final params = <String, String>{};
    if (startDate != null && startDate.isNotEmpty) {
      params['start_date'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) {
      params['end_date'] = endDate;
    }

    // FIX: use replace() properly — only add queryParameters when non-empty
    final uri = Uri.parse('$_base/api/mobile/dashboard')
        .replace(queryParameters: params.isNotEmpty ? params : null);

    developer.log(
      '[DashboardApiService] fetchDashboard → GET $uri',
      name: 'DashboardApiService',
    );

    try {
      final headers = await _headers();

      // FIX: increased timeout from default (was likely very short) to 30s
      // Complex team-leader queries touch many DB tables and need more time.
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));

      developer.log(
        '[DashboardApiService] fetchDashboard ← ${response.statusCode}'
        ' | body length: ${response.body.length}',
        name: 'DashboardApiService',
      );

      // FIX: log the raw body in debug so you can see exactly what the
      // server returns without needing a proxy.
      developer.log(
        '[DashboardApiService] raw body: ${response.body}',
        name: 'DashboardApiService',
      );

      // FIX: handle empty body explicitly — an empty 200 means the server
      // returned nothing (misconfigured route or middleware swallowed it).
      if (response.body.isEmpty) {
        throw ApiException(
          'Server returned an empty response (${response.statusCode}). '
          'Check that the /api/mobile/dashboard route is registered and '
          'the auth middleware is not blocking it.',
        );
      }

      final body = _safeDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (body is Map<String, dynamic>) {
          // FIX: check the API's own status flag before parsing
          if (body['status'] == false) {
            throw ApiException(
              body['message']?.toString() ??
                  'API returned status:false',
            );
          }
          try {
            return DashboardModel.fromJson(body);
          } catch (parseError, stack) {
            developer.log(
              '[DashboardApiService] JSON parse error: $parseError\n$stack',
              name: 'DashboardApiService',
              error: parseError,
            );
            throw ApiException(
              'Failed to parse dashboard response: $parseError',
            );
          }
        }
        throw ApiException(
          'Unexpected response format (expected JSON object).',
        );
      }

      if (response.statusCode == 401) {
        throw ApiException(
          'Session expired. Please log in again.',
        );
      }

      if (response.statusCode == 403) {
        throw ApiException(
          'Access denied. You do not have permission to view this page.',
        );
      }

      if (response.statusCode == 404) {
        throw ApiException(
          'Dashboard endpoint not found (404). '
          'Verify the API route /api/mobile/dashboard exists.',
        );
      }

      if (response.statusCode == 500) {
        // FIX: surface the Laravel error message if present
        final serverMsg = (body is Map)
            ? body['message']?.toString()
            : null;
        throw ApiException(
          serverMsg != null && serverMsg.isNotEmpty
              ? 'Server error: $serverMsg'
              : 'Internal server error (500). Check the Laravel logs.',
        );
      }

      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to load dashboard (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException(
        'Request timed out after 30 seconds. '
        'Check your network connection or server performance.',
      );
    } on ApiException {
      rethrow;
    } catch (e, stack) {
      developer.log(
        '[DashboardApiService] unexpected error: $e',
        name: 'DashboardApiService',
        error: e,
        stackTrace: stack,
      );
      throw ApiException('Dashboard fetch error: $e');
    }
  }

  // ── Safe JSON decode ───────────────────────────────────────────────────────
  // FIX: original returned {} on decode failure, silently masking server
  // errors (e.g. a Laravel HTML exception page).  Now surfaces the raw
  // text so the developer can see what the server actually returned.

  static dynamic _safeDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      // Body is not JSON — could be an HTML error page or plain text.
      // Return a map so callers that do `body is Map` still work, but
      // include the raw text as the message so it surfaces in the UI.
      final preview = body.length > 300
          ? '${body.substring(0, 300)}…'
          : body;
      return <String, dynamic>{
        'status': false,
        'message': 'Non-JSON response from server: $preview',
      };
    }
  }
}