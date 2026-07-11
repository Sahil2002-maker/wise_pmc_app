// lib/features/development_process/data/services/development_process_api.dart
//
// FIX (Assign To list showing only Team Members, no Team Leader):
//   fetchTeamMembersForProcess() was calling ApiConstants.teamMembers(teamId)
//   → GET /api/mobile/teams/{teamId}/members
//   That's the GENERIC team-members endpoint served by a different
//   controller. It only returns plain members and has no `role` field, so
//   Team Leaders never came through — even though the backend's dedicated
//   MobileDevelopmentProcessController::getTeamMembers() logic (which DOES
//   return both leaders and members, each tagged with role: 'Team Leader' /
//   'Team Member') was already correct.
//
//   That correct endpoint is registered at:
//   GET /api/mobile/development-process/team-members/{teamId}
//   → ApiConstants.devProcessTeamMembers(teamId)
//
//   Fixed below: fetchTeamMembersForProcess() now calls
//   ApiConstants.devProcessTeamMembers(teamId) instead of
//   ApiConstants.teamMembers(teamId). No changes were needed in
//   AssignProcessSheet — its leader/member split logic was already correct,
//   it just never received leader data because of the wrong URL.
//
// FIX: getFileUrl() now logs the exact path sent and full server response so
// the root cause of "No file is attached" can be diagnosed. The method also
// surfaces the real server error message instead of a generic one, and guards
// against the path being an empty string after trimming.

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

  // ── Decode helper ────────────────────────────────────────────────────────────

  static dynamic _decode(String body) {
    if (body.isEmpty) return {};
    try {
      return jsonDecode(body);
    } catch (_) {
      return {'message': body};
    }
  }

  // ── Fetch development processes for a project ────────────────────────────────

  static Future<Map<String, dynamic>> fetchDevelopmentProcesses(
      int projectId) async {
    final url =
        '${ApiConstants.baseUrl}/api/mobile/projects/$projectId/development-processes';

    developer.log(
        '[DevelopmentProcessApi] fetchDevelopmentProcesses → GET $url',
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

  // ── Assign a development process ─────────────────────────────────────────────

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
      'project_id': projectId,
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

  // ── Upload file for a development process ─────────────────────────────────────

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
      ..fields['project_id'] = projectId.toString()
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

  // ── Get pre-signed file URL ───────────────────────────────────────────────────

  static Future<String> getFileUrl(String filePath) async {
    final cleanPath = filePath.trim();
    if (cleanPath.isEmpty) {
      developer.log(
          '[DevelopmentProcessApi] getFileUrl → filePath is empty — '
          'the assignment\'s document_path column is NULL or blank in the DB.',
          name: 'DevelopmentProcessApi');
      throw ApiException(
          'No file is attached to this process. '
          'Please upload a document first.');
    }

    final uri = Uri.parse(ApiConstants.devProcessFileUrl).replace(
      queryParameters: {
        'file_path': cleanPath,
        'path': cleanPath,
      },
    );

    developer.log(
        '[DevelopmentProcessApi] getFileUrl → GET $uri\n'
        '  file_path = "$cleanPath"',
        name: 'DevelopmentProcessApi');

    try {
      final response = await http
          .get(uri, headers: await _headers())
          .timeout(const Duration(seconds: 30));

      developer.log(
          '[DevelopmentProcessApi] getFileUrl ← HTTP ${response.statusCode}\n'
          '  body = ${response.body}',
          name: 'DevelopmentProcessApi');

      final decoded = _decode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final url = decoded is Map ? decoded['url']?.toString() : null;
        if (url != null && url.isNotEmpty) {
          developer.log(
              '[DevelopmentProcessApi] getFileUrl ✓ signed URL obtained',
              name: 'DevelopmentProcessApi');
          return url;
        }

        developer.log(
            '[DevelopmentProcessApi] getFileUrl ✗ server returned 200 but '
            'no "url" field in response.\n'
            '  success = ${decoded is Map ? decoded['success'] : 'N/A'}\n'
            '  message = ${decoded is Map ? decoded['message'] : 'N/A'}\n'
            '  Full decoded = $decoded',
            name: 'DevelopmentProcessApi');

        final serverMsg =
            decoded is Map ? decoded['message']?.toString() : null;
        throw ApiException(
          serverMsg?.isNotEmpty == true
              ? serverMsg!
              : 'The server could not generate a file URL. '
                  'The file may have been deleted from storage.',
        );
      }

      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      if (response.statusCode == 404) {
        developer.log(
            '[DevelopmentProcessApi] getFileUrl 404 — file not found on S3.\n'
            '  Searched path: "$cleanPath"\n'
            '  Server response: ${response.body}',
            name: 'DevelopmentProcessApi');
        throw ApiException(
            'The file could not be found on the server.\n'
            'Path: $cleanPath');
      }
      if (response.statusCode == 422) {
        final serverMsg =
            decoded is Map ? decoded['message']?.toString() : null;
        developer.log(
            '[DevelopmentProcessApi] getFileUrl 422 validation error: $serverMsg',
            name: 'DevelopmentProcessApi');
        throw ApiException(
            serverMsg ?? 'Validation error: invalid file path.');
      }
      if (response.statusCode == 500) {
        final serverMsg =
            decoded is Map ? decoded['message']?.toString() : null;
        developer.log(
            '[DevelopmentProcessApi] getFileUrl 500 server error: $serverMsg\n'
            '  Full response: ${response.body}',
            name: 'DevelopmentProcessApi');
        throw ApiException(
            'Server error while retrieving file URL. '
            '${serverMsg != null ? '($serverMsg)' : ''}');
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

  // ── Fetch team members (leaders + members) for the Assign sheet ───────────────

  static Future<List<TeamMemberItem>> fetchTeamMembersForProcess(
      int teamId) async {
    // ── FIX ────────────────────────────────────────────────────────────────
    // This USED to call ApiConstants.teamMembers(teamId), i.e.
    //   GET /api/mobile/teams/{teamId}/members
    // That is the GENERIC team-members endpoint, served by a different
    // controller. It only returns plain team members with no `role` field,
    // so Team Leaders never came through in the Assign To list — even
    // though TeamMemberItem.isTeamLeader and the AssignProcessSheet's
    // leader/member split were already implemented correctly.
    //
    // The endpoint that returns BOTH Team Leaders and Team Members (each
    // tagged with role: 'Team Leader' / 'Team Member') is
    // MobileDevelopmentProcessController::getTeamMembers(), registered at:
    //   GET /api/mobile/development-process/team-members/{teamId}
    // which is exactly ApiConstants.devProcessTeamMembers(teamId).
    final url = ApiConstants.devProcessTeamMembers(teamId);

    developer.log(
        '[DevelopmentProcessApi] fetchTeamMembersForProcess → GET $url teamId=$teamId',
        name: 'DevelopmentProcessApi');

    try {
      final response = await http
          .get(Uri.parse(url), headers: await _headers())
          .timeout(ApiConstants.requestTimeout);

      final body = _decode(response.body);

      developer.log(
          '[DevelopmentProcessApi] fetchTeamMembersForProcess ← ${response.statusCode}: ${response.body}',
          name: 'DevelopmentProcessApi');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw =
            body is Map ? (body['members'] as List? ?? []) : <dynamic>[];
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