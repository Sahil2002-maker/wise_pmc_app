// lib/features/development_process/data/services/development_process_api.dart
//
// FIX: "The project id field is required."
// assignDevelopmentProcess() now includes 'project_id' in the POST body.
// Previously the projectId was only used to build the URL path, but the
// Laravel controller also validates it from the request body — causing the
// "The project id field is required." validation error.

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
import '../models/development_process_model.dart';

class DevelopmentProcessApi {
  DevelopmentProcessApi._();

  // ── Auth headers ────────────────────────────────────────────────────────────

  static Future<Map<String, String>> _headers() async {
    final token = await AuthStorageService.getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, String>> _multipartHeaders() async {
    final token = await AuthStorageService.getToken();
    return {
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // ── Decode helper ───────────────────────────────────────────────────────────

  static dynamic _decode(String body) {
    if (body.isEmpty) return {};
    try {
      return jsonDecode(body);
    } catch (_) {
      return {'message': body};
    }
  }

  // ── Fetch development processes for a project ───────────────────────────────

  static Future<Map<String, dynamic>> fetchDevelopmentProcesses(
      int projectId) async {
    final url =
        '${ApiConstants.baseUrl}/api/mobile/projects/$projectId/development-processes';

    developer.log('[DevelopmentProcessApi] fetchDevelopmentProcesses → GET $url',
        name: 'DevelopmentProcessApi');

    try {
      final response = await http
          .get(Uri.parse(url), headers: await _headers())
          .timeout(ApiConstants.requestTimeout);

      final body = _decode(response.body);

      developer.log(
          '[DevelopmentProcessApi] fetchDevelopmentProcesses ← ${response.statusCode}',
          name: 'DevelopmentProcessApi');

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

  // ── Assign a development process ────────────────────────────────────────────

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

    // FIX: 'project_id' is now included in the POST body.
    // The Laravel controller validates request->input('project_id') in addition
    // to reading it from the route parameter. Without this field in the body
    // the server returned "The project id field is required."
    final payload = <String, dynamic>{
      'project_id': projectId,       // ← FIX: was missing from body
      'process_id': processId,
      'order_no': orderNo,
      'stage': stage,
      'not_applicable': notApplicable,
      if (!notApplicable && assignedTo != null) 'assigned_to': assignedTo,
      if (!notApplicable && deadline != null && deadline.isNotEmpty)
        'deadline': deadline,
    };

    developer.log(
        '[DevelopmentProcessApi] assignDevelopmentProcess → POST $url payload=$payload',
        name: 'DevelopmentProcessApi');

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
          '[DevelopmentProcessApi] assignDevelopmentProcess ← ${response.statusCode}: ${response.body}',
          name: 'DevelopmentProcessApi');

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

  // ── Upload file for a development process ───────────────────────────────────

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
        '[DevelopmentProcessApi] uploadDevelopmentProcessFile → POST $url '
        'processId=$processId orderNo=$orderNo file=$fileName',
        name: 'DevelopmentProcessApi');

    final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
    final mimeParts = mimeType.split('/');

    final request = http.MultipartRequest('POST', Uri.parse(url))
      ..headers.addAll(await _multipartHeaders())
      ..fields['project_id'] = projectId.toString()   // ← also include here
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
        '[DevelopmentProcessApi] uploadDevelopmentProcessFile ← ${streamed.statusCode}: $bodyStr',
        name: 'DevelopmentProcessApi');

    if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
      return decoded is Map<String, dynamic> ? decoded : {'success': true};
    }
    if (streamed.statusCode == 401) {
      throw ApiException('Session expired. Please login again.');
    }
    if (streamed.statusCode == 422 &&
        decoded is Map &&
        decoded['errors'] is Map) {
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

  // ── Get pre-signed file URL ─────────────────────────────────────────────────

  static Future<String> getFileUrl(String filePath) async {
    if (filePath.isEmpty) {
      throw ApiException('No file path provided.');
    }

    final uri = Uri.parse(ApiConstants.devProcessFileUrl).replace(
      queryParameters: {
        'file_path': filePath,
        'path': filePath,
      },
    );

    developer.log('[DevelopmentProcessApi] getFileUrl → GET $uri',
        name: 'DevelopmentProcessApi');

    try {
      final response = await http
          .get(uri, headers: await _headers())
          .timeout(const Duration(seconds: 30));

      final decoded = _decode(response.body);

      developer.log(
          '[DevelopmentProcessApi] getFileUrl ← ${response.statusCode}: ${response.body}',
          name: 'DevelopmentProcessApi');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final url = decoded is Map ? decoded['url']?.toString() : null;
        if (url != null && url.isNotEmpty) return url;
        throw ApiException('Server returned an empty file URL.');
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      if (response.statusCode == 404) {
        throw ApiException('File not found on the server.');
      }
      throw ApiException(
        (decoded is Map ? decoded['message']?.toString() : null) ??
            'Could not retrieve file URL (HTTP ${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('File URL error: $e');
    }
  }

  // ── Fetch team members for assignment picker ─────────────────────────────────

  static Future<List<TeamMemberItem>> fetchTeamMembersForProcess(
      int teamId) async {
    final url = ApiConstants.teamMembers(teamId);

    developer.log(
        '[DevelopmentProcessApi] fetchTeamMembersForProcess → GET $url teamId=$teamId',
        name: 'DevelopmentProcessApi');

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
}