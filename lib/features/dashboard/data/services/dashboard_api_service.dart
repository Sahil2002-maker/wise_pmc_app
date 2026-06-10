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
  static Future<Map<String, String>> _headers() async {
    final token = await AuthStorageService.getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// GET /api/mobile/dashboard
  /// Optionally pass [startDate] and [endDate] as 'yyyy-MM-dd'.
  static Future<DashboardModel> fetchDashboard({
    String? startDate,
    String? endDate,
  }) async {
    final params = <String, String>{};
    if (startDate != null && startDate.isNotEmpty) params['start_date'] = startDate;
    if (endDate   != null && endDate.isNotEmpty)   params['end_date']   = endDate;

    final uri = Uri.parse('${ApiConstants.baseUrl}/api/mobile/dashboard')
        .replace(queryParameters: params.isNotEmpty ? params : null);

    developer.log('[DashboardApiService] fetchDashboard → GET $uri',
        name: 'DashboardApiService');

    try {
      final response = await http
          .get(uri, headers: await _headers())
          .timeout(ApiConstants.requestTimeout);

      final body = _decode(response.body);

      developer.log(
        '[DashboardApiService] fetchDashboard ← ${response.statusCode}',
        name: 'DashboardApiService',
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (body is Map<String, dynamic>) {
          return DashboardModel.fromJson(body);
        }
        throw ApiException('Unexpected response format from dashboard API.');
      }

      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }

      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to load dashboard (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Dashboard fetch error: $e');
    }
  }

  static dynamic _decode(String body) {
    if (body.isEmpty) return {};
    try {
      return jsonDecode(body);
    } catch (_) {
      return {'message': body};
    }
  }
}