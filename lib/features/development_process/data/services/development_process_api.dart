// lib/features/development_process/data/services/development_process_api.dart
//
// Add these static methods inside your existing ApiService class,
// OR use this as a standalone helper that calls the same _authHeaders() / _rawPost() etc.
//
// INTEGRATION: Copy each method into api_service.dart inside the ApiService class.
// The file path for INTEGRATION is: lib/core/services/api_service.dart
//
// This file shows the STANDALONE version for clarity.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/services/auth_storage_service.dart';
import '../../../../core/utils/api_exception.dart';
import '../models/development_process_model.dart';

class DevelopmentProcessApi {
  // ── Shared helpers (mirrors ApiService private helpers) ──────────────────

  static Future<Map<String, String>> _headers() async {
    final token = await AuthStorageService.getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
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

  // ─────────────────────────────────────────────────────────────────────────
  // FETCH DEVELOPMENT PROCESSES FOR A PROJECT
  // GET /api/mobile/projects/{projectId}/development-processes
  // ─────────────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> fetchDevelopmentProcesses(
      int projectId) async {
    final url =
        '${ApiConstants.baseUrl}/api/mobile/projects/$projectId/development-processes';

    developer.log('[DevProcessApi] fetchDevelopmentProcesses → GET $url',
        name: 'DevProcessApi');

    try {
      final response = await http
          .get(Uri.parse(url), headers: await _headers())
          .timeout(ApiConstants.requestTimeout);

      final body = _decode(response.body);

      developer.log(
          '[DevProcessApi] fetchDevelopmentProcesses ← ${response.statusCode}',
          name: 'DevProcessApi');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return body is Map<String, dynamic> ? body : {'data': body};
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to load processes (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Fetch development processes error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ASSIGN A DEVELOPMENT PROCESS
  // POST /api/mobile/projects/{projectId}/development-processes/stage{N}/assign
  // ─────────────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> assignDevelopmentProcess({
    required int projectId,
    required int stageNumber,
    required int processId,
    required int orderNo,
    required String stage,
    int? assignedTo,
    String? deadline,
    bool notApplicable = false,
  }) async {
    final url =
        '${ApiConstants.baseUrl}/api/mobile/projects/$projectId/development-processes/stage$stageNumber/assign';

    final payload = <String, dynamic>{
      'process_id': processId,
      'order_no': orderNo,
      'stage': stage,
      'not_applicable': notApplicable,
      if (!notApplicable && assignedTo != null) 'assigned_to': assignedTo,
      if (!notApplicable && deadline != null && deadline.isNotEmpty)
        'deadline': deadline,
    };

    developer.log(
        '[DevProcessApi] assignDevelopmentProcess → POST $url payload=$payload',
        name: 'DevProcessApi');

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: await _headers(),
            body: jsonEncode(payload),
          )
          .timeout(ApiConstants.requestTimeout);

      final body = _decode(response.body);

      developer.log(
          '[DevProcessApi] assignDevelopmentProcess ← ${response.statusCode}: ${response.body}',
          name: 'DevProcessApi');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return body is Map<String, dynamic> ? body : {'success': true};
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      if (response.statusCode == 422 && body is Map && body['errors'] is Map) {
        final errors = Map<String, dynamic>.from(body['errors'] as Map);
        final firstKey = errors.keys.isNotEmpty ? errors.keys.first : null;
        if (firstKey != null &&
            errors[firstKey] is List &&
            (errors[firstKey] as List).isNotEmpty) {
          throw ApiException((errors[firstKey] as List).first.toString());
        }
      }
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to assign process (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Assign development process error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UPLOAD FILE FOR A DEVELOPMENT PROCESS
  // POST /api/mobile/projects/{projectId}/development-processes/stage{N}/upload
  // ─────────────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> uploadDevelopmentProcessFile({
    required int projectId,
    required int stageNumber,
    required int processId,
    required int orderNo,
    required File file,
    required String fileName,
  }) async {
    final url =
        '${ApiConstants.baseUrl}/api/mobile/projects/$projectId/development-processes/stage$stageNumber/upload';

    developer.log(
        '[DevProcessApi] uploadDevelopmentProcessFile → POST $url '
        'processId=$processId orderNo=$orderNo file=$fileName',
        name: 'DevProcessApi');

    final token = await AuthStorageService.getToken();
    final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
    final mimeParts = mimeType.split('/');

    final request = http.MultipartRequest('POST', Uri.parse(url))
      ..headers.addAll({
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      })
      ..fields['process_id'] = processId.toString()
      ..fields['order_no'] = orderNo.toString()
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: fileName,
        contentType: MediaType(mimeParts[0], mimeParts[1]),
      ));

    late http.StreamedResponse streamed;
    try {
      streamed = await request.send().timeout(const Duration(seconds: 90));
    } on TimeoutException {
      throw ApiException('Upload timed out. Please check your connection.');
    } catch (e) {
      throw ApiException('Upload network error: $e');
    }

    final bodyStr = await streamed.stream.bytesToString();
    final decoded = _decode(bodyStr);

    developer.log(
        '[DevProcessApi] uploadDevelopmentProcessFile ← ${streamed.statusCode}: $bodyStr',
        name: 'DevProcessApi');

    if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
      return decoded is Map<String, dynamic> ? decoded : {'success': true};
    }
    if (streamed.statusCode == 401) {
      throw ApiException('Session expired. Please login again.');
    }
    if (streamed.statusCode == 422 && decoded is Map && decoded['errors'] is Map) {
      final errors = Map<String, dynamic>.from(decoded['errors'] as Map);
      final firstKey = errors.keys.isNotEmpty ? errors.keys.first : null;
      if (firstKey != null &&
          errors[firstKey] is List &&
          (errors[firstKey] as List).isNotEmpty) {
        throw ApiException((errors[firstKey] as List).first.toString());
      }
    }
    throw ApiException(
      (decoded is Map ? decoded['message']?.toString() : null) ??
          'Upload failed (${streamed.statusCode})',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GET TEAM MEMBERS FOR A TEAM (for assign modal dropdown)
  // GET /api/mobile/teams/{teamId}/members
  // ─────────────────────────────────────────────────────────────────────────
  static Future<List<TeamMemberItem>> fetchTeamMembersForProcess(
      int teamId) async {
    final url = ApiConstants.teamMembers(teamId);

    developer.log(
        '[DevProcessApi] fetchTeamMembersForProcess → GET $url teamId=$teamId',
        name: 'DevProcessApi');

    try {
      final response = await http
          .get(Uri.parse(url), headers: await _headers())
          .timeout(ApiConstants.requestTimeout);

      final body = _decode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        List<dynamic> raw = [];
        if (body is Map) {
          raw = (body['members'] as List?) ??
              (body['data'] as List?) ??
              (body['users'] as List?) ??
              [];
        } else if (body is List) {
          raw = body;
        }
        return raw
            .whereType<Map<String, dynamic>>()
            .map(TeamMemberItem.fromJson)
            .where((m) => m.id > 0 && m.name.isNotEmpty)
            .toList();
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to load team members (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Fetch team members error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GET FILE TEMPORARY URL
  // GET /api/mobile/development-process/file-url?file_path=...
  // ─────────────────────────────────────────────────────────────────────────
  static Future<String> getFileUrl(String filePath) async {
    final url =
        '${ApiConstants.baseUrl}/api/mobile/development-process/file-url'
        '?file_path=${Uri.encodeQueryComponent(filePath)}';

    try {
      final response = await http
          .get(Uri.parse(url), headers: await _headers())
          .timeout(ApiConstants.requestTimeout);

      final body = _decode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return body['url']?.toString() ?? '';
      }
      throw ApiException('Could not retrieve file URL.');
    } on TimeoutException {
      throw ApiException('Request timed out.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Get file URL error: $e');
    }
  }
}