// lib/core/services/api_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'dart:io'; 

import '../../features/dashboard/data/models/project_dashboard_model.dart';
import '../../features/general_tasks/data/models/assignable_user_model.dart';
import '../../features/general_tasks/data/models/general_task_model.dart';
import '../../features/general_tasks/data/models/task_calendar_event_model.dart';
import '../../features/project_list/data/models/project_list_item_model.dart';
import '../../features/process_list/data/models/team_member_model.dart';
import '../../features/re_execution/data/models/re_execution_model.dart';
import '../../features/cement_checklist/data/models/cement_checklist_model.dart';
import '../../features/steel_checklist/data/models/steel_checklist_model.dart';
import '../../features/excavation_checklist/data/models/excavation_checklist_model.dart';
import '../../features/shuttering_checklist/data/models/shuttering_checklist_model.dart';
import '../../features/concreting_checklist/data/models/concreting_checklist_model.dart';
import '../../features/site_instruction/data/models/site_instruction_model.dart';
import '../../features/reinforcement_checklist/data/models/reinforcement_checklist_model.dart';
import '../../features/concrete_cube_results/data/models/concrete_cube_result_model.dart';
import '../../features/approval_form/data/models/approval_form_model.dart';
import '../../features/architecture_checklist/data/models/architecture_checklist_model.dart';
import '../../features/concrete_pour_card/data/models/concrete_pour_card_model.dart';
import '../../features/work_reports/data/models/work_report_calendar_event.dart';
import '../../features/minutes_of_meeting/data/models/minutes_of_meeting_model.dart';
import '../../features/cc_progress/data/models/cc_progress_model.dart';
import '../../features/layout_approval/data/models/layout_approval_model.dart';
import '../../features/noc_map/data/models/noc_map_model.dart';
import '../../features/noc_analytics/data/models/noc_analytics_model.dart';
import '../../features/all_tasks/data/models/all_task_models.dart';
import '../../features/employee_report/data/models/employee_report_models.dart';
import '../../features/project_report/data/models/project_report_models.dart';
import '../../features/team_report/data/models/team_report_models.dart';
import '../../features/development_process/data/models/development_process_model.dart';
import '../../features/process/data/models/process_model.dart';
import '../../features/development_process/data/models/dev_process_model.dart';
import '../constants/api_constants.dart';
import '../utils/api_exception.dart';
import 'auth_storage_service.dart';

class ApiService {
  static String? _cachedToken;
  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  static String authToken = '';
  static String? get currentAuthToken => _cachedToken;

  static Future<void> syncAuthToken() async {
    final token = await AuthStorageService.getToken();
    authToken = token ?? '';
  }

  static Future<Map<String, String>> _authHeaders() async {
  final token = await AuthStorageService.getToken();
  authToken = token ?? '';
  _cachedToken = token;

  return {
    'Accept': ApiConstants.accept,
    'Content-Type': ApiConstants.contentType,
    if (authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
  };
}

static Future<http.Response> _rawPostWithMethod({
  required String fullUrl,
  required Map<String, dynamic> body,
  required String method, // 'PUT' or 'DELETE'
}) async {
  final token = await AuthStorageService.getToken();
  final headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
    'X-HTTP-Method-Override': method, // Laravel honours this header
  };
 
  // Also inject _method into body as a fallback (some proxies strip headers)
  final bodyWithMethod = {...body, '_method': method};
 
  return http.post(
    Uri.parse(fullUrl),
    headers: headers,
    body: jsonEncode(bodyWithMethod),
  ).timeout(const Duration(seconds: 30));
}

  static Future<Map<String, String>> _pdfHeaders() async {
    if (authToken.isEmpty) {
      await syncAuthToken();
    }

    return {
      'Accept': 'application/pdf',
      if (authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
    };
  }

  static Future<Uint8List> downloadBytes(String url) async {
    final uri = Uri.parse(url);

    try {
      final response = await http
          .get(uri, headers: await _pdfHeaders())
          .timeout(ApiConstants.requestTimeout);

      developer.log(
        '[ApiService] downloadBytes → GET $url → ${response.statusCode}',
        name: 'ApiService',
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }

      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }

      throw ApiException(
        'Download failed (HTTP ${response.statusCode})',
        
      );
    } on TimeoutException {
      throw ApiException('Download timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Download error: $e');
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

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  static List<dynamic> _extractList(
    dynamic body, [
    List<String> keys = const [
      'data',
      'tasks',
      'items',
      'results',
      'general_tasks',
      'list',
    ],
  ]) {
    if (body is List) return body;
    if (body is Map<String, dynamic>) {
      for (final key in keys) {
        if (body[key] is List) return body[key] as List;
      }
      for (final val in body.values) {
        if (val is List) return val;
      }
    }
    return [];
  }

  static int? _deepExtractId(dynamic node, {int depth = 0}) {
    if (depth > 6) return null;
    if (node is Map) {
      for (final key in ['id', 'task_id', 'project_id', 'projectId']) {
        final raw = node[key];
        if (raw != null) {
          final id = int.tryParse(raw.toString());
          if (id != null && id > 0) return id;
        }
      }
      for (final key in node.keys) {
        final val = node[key];
        if (val is Map || val is List) {
          final found = _deepExtractId(val, depth: depth + 1);
          if (found != null) return found;
        }
      }
    }
    if (node is List) {
      for (final item in node) {
        final found = _deepExtractId(item, depth: depth + 1);
        if (found != null) return found;
      }
    }
    return null;
  }

  static Uri _buildCalendarUri(
    List<int> teamIds,
    List<int> memberIds, {
    String? startDate,
    String? endDate,
  }) {
    final baseUri = Uri.parse(ApiConstants.calendarTasks);
    final parts   = <String>[];
 
    for (final id in teamIds)   parts.add('team_id[]=$id');
    for (final id in memberIds) parts.add('member_ids[]=$id');
    if (startDate != null && startDate.isNotEmpty) parts.add('start_date=$startDate');
    if (endDate   != null && endDate.isNotEmpty)   parts.add('end_date=$endDate');
 
    if (parts.isEmpty) return baseUri;
    return Uri.parse('${baseUri.toString()}?${parts.join('&')}');
  }

  static Future<Map<String, dynamic>> _getRequest(String fullUrl) async {
    final url = Uri.parse(fullUrl);
    try {
      final response = await http
          .get(url, headers: await _authHeaders())
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      developer.log('[ApiService] GET $fullUrl → ${response.statusCode}',
          name: 'ApiService');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return body is Map<String, dynamic> ? body : {'data': body};
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Request failed (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('GET request error: $e');
    }
  }

  static Future<http.Response> _rawPost({
    required String fullUrl,
    required Map<String, dynamic> body,
  }) async {
    final url = Uri.parse(fullUrl);
    return http
        .post(url, headers: await _authHeaders(), body: jsonEncode(body))
        .timeout(ApiConstants.requestTimeout);
  }

  static Future<Map<String, dynamic>> _postRequest({
    required String fullUrl,
    required Map<String, dynamic> body,
  }) async {
    try {
      final response = await _rawPost(fullUrl: fullUrl, body: body);
      final decoded = _decode(response.body);
      developer.log(
          '[ApiService] POST $fullUrl → ${response.statusCode}: ${response.body}',
          name: 'ApiService');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(
        (decoded is Map ? decoded['message']?.toString() : null) ??
            'Request failed (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('POST request error: $e');
    }
  }

  static Future<Map<String, dynamic>> _putRequest({
    required String fullUrl,
    Map<String, dynamic>? body,
  }) async {
    final url = Uri.parse(fullUrl);
    try {
      final response = await http
          .put(url,
              headers: await _authHeaders(),
              body: jsonEncode(body ?? <String, dynamic>{}))
          .timeout(ApiConstants.requestTimeout);
      final decoded = _decode(response.body);
      developer.log(
          '[ApiService] PUT $fullUrl → ${response.statusCode}: ${response.body}',
          name: 'ApiService');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(
        (decoded is Map ? decoded['message']?.toString() : null) ??
            'Request failed (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('PUT request error: $e');
    }
  }

  static Future<Map<String, dynamic>> _patchRequest({
    required String fullUrl,
    required Map<String, dynamic> body,
  }) async {
    final url = Uri.parse(fullUrl);
    try {
      final response = await http
          .patch(url, headers: await _authHeaders(), body: jsonEncode(body))
          .timeout(ApiConstants.requestTimeout);
      final decoded = _decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(
        (decoded is Map ? decoded['message']?.toString() : null) ??
            'Request failed (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('PATCH request error: $e');
    }
  }

  static Future<Map<String, dynamic>> _deleteRequest(String fullUrl) async {
    final url = Uri.parse(fullUrl);
    try {
      final response = await http
          .delete(url, headers: await _authHeaders())
          .timeout(ApiConstants.requestTimeout);
      final decoded = _decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(
        (decoded is Map ? decoded['message']?.toString() : null) ??
            'Request failed (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('DELETE request error: $e');
    }
  }

  Future<void> sendFcmToken(String token) async {
  try {
    await _postRequest(
      fullUrl: "${ApiConstants.baseUrl}/api/save-fcm-token",
      body: {"token": token},
    );
  } catch (e) {
    print("FCM Token send failed: $e");
  }
}

  // ═══════════════════════════════════════════════════════════════════════════
  // AUTH
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> login({
  required String usernameOrEmail,
  required String password,
}) async {
  final url = Uri.parse(ApiConstants.login);
  try {
    final response = await http
        .post(
          url,
          headers: {
            'Content-Type': ApiConstants.contentType,
            'Accept': ApiConstants.accept,
          },
          body: jsonEncode({
            'login': usernameOrEmail.trim(),
            'password': password,
          }),
        )
        .timeout(ApiConstants.requestTimeout);

    final body = _decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final token = body['token']?.toString() ?? '';
      final user = body['user'] is Map<String, dynamic>
          ? body['user'] as Map<String, dynamic>
          : Map<String, dynamic>.from(body['user'] ?? {});

      if (token.isEmpty) {
        throw ApiException('Login succeeded but token was not returned.');
      }

      authToken = token;

      final permissions = (user['permissions'] is List)
          ? (user['permissions'] as List).map((e) => e.toString()).toList()
          : <String>[];

      final userId = int.tryParse(user['id']?.toString() ?? '');

      await AuthStorageService.saveAuth(
        token: token,
        userName: user['name']?.toString(),
        userRole: user['role']?.toString(),
        userId: userId,
        permissions: permissions,
      );

      return {
        'status': true,
        'message': body['message']?.toString() ?? 'Login successful',
        'token': token,
        'user': user,
      };
    }

    throw ApiException(
      body['message']?.toString() ?? 'Login failed (${response.statusCode})',
    );
  } on TimeoutException {
    throw ApiException('Request timed out. Please try again.');
  } catch (e) {
    if (e is ApiException) rethrow;
    throw ApiException('Login error: $e');
  }
}

static Future<void> logout() async {
  final token = await AuthStorageService.getToken();
  if (token == null || token.isEmpty) {
    authToken = '';
    await AuthStorageService.clear();
    return;
  }
  try {
    await _postRequest(fullUrl: ApiConstants.logout, body: const {});
  } catch (_) {}
  authToken = '';
  await AuthStorageService.clear();
}

  static Future<String> forgotPassword({required String email}) async {
    final response = await _postRequest(
      fullUrl: ApiConstants.forgotPassword,
      body: {'email': email.trim()},
    );
    return response['message']?.toString() ??
        'Password reset link sent successfully.';
  }

  

  // ═══════════════════════════════════════════════════════════════════════════
  // DASHBOARD
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<List<ProjectDashboardModel>> fetchDashboardProjects() async {
    final token = await AuthStorageService.getToken();
    if (token == null || token.isEmpty) {
      throw ApiException('You are not logged in.');
    }
    final body = await _getRequest(ApiConstants.dashboardProjects);
    final rawList = _extractList(body, ['projects', 'data']);
    return rawList
        .whereType<Map>()
        .map((e) =>
            ProjectDashboardModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PROFILE
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> fetchProfile() async {
    final body = await _getRequest(ApiConstants.profile);
    return Map<String, dynamic>.from(body['user'] ?? body['data'] ?? body);
  }

  static Future<String> updateProfile({
    required String name,
    required String email,
  }) async {
    final body = await _patchRequest(
      fullUrl: ApiConstants.profile,
      body: {'name': name, 'email': email},
    );
    final user = body['user'] as Map<String, dynamic>?;
    if (user != null) {
      await AuthStorageService.saveAuth(
        token: (await AuthStorageService.getToken()) ?? '',
        userName: user['name']?.toString(),
        userRole: user['role']?.toString(),
        userId: int.tryParse(user['id']?.toString() ?? ''),
        permissions: await AuthStorageService.getPermissions(),
      );
    }
    return body['message']?.toString() ?? 'Profile updated successfully';
  }

  static Future<String> updateProfilePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final body = await _patchRequest(
      fullUrl: ApiConstants.profilePassword,
      body: {
        'current_password': currentPassword,
        'password': newPassword,
        'password_confirmation': confirmPassword,
      },
    );
    return body['message']?.toString() ?? 'Password updated successfully';
  }

  static Future<String> updateThemeMode({required String themeMode}) async {
    final body = await _postRequest(
      fullUrl: ApiConstants.updateThemeMode,
      body: {'themeMode': themeMode},
    );
    return body['message']?.toString() ?? 'Theme updated successfully';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PROJECTS
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> fetchProjectList() async {
    final url = Uri.parse(ApiConstants.projectList);
    try {
      final response = await http
          .get(url, headers: await _authHeaders())
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final safeBody =
            body is Map<String, dynamic> ? body : <String, dynamic>{};
        final rawProjects = _extractList(safeBody, ['projects', 'data']);
        final projects = rawProjects
            .whereType<Map>()
            .map((e) =>
                ProjectListItemModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        return {
          'projects': projects,
          'canAddProject': safeBody['can_add_project'] == true,
        };
      }
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to load project list (${response.statusCode})',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Project list error: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchProjectProcesses(
      int projectId) async {
    final url = Uri.parse(ApiConstants.projectProcesses(projectId));
    try {
      final response = await http
          .get(url, headers: await _authHeaders())
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      developer.log(
          '[ApiService] fetchProjectProcesses status=${response.statusCode}',
          name: 'ApiService');
      developer.log(
          '[ApiService] fetchProjectProcesses body=${response.body}',
          name: 'ApiService');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final safeBody =
            body is Map<String, dynamic> ? body : <String, dynamic>{};
        final raw = _extractList(safeBody, ['processes', 'data']);
        for (final item in raw.whereType<Map>()) {
          developer.log(
              '[ApiService] process stage=${item['stage']} name=${item['process_name']}',
              name: 'ApiService');
        }
        return raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to load project processes (${response.statusCode})',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Project processes error: $e');
    }
  }

  static Future<int?> _fetchLatestProjectId() async {
    try {
      final url = Uri.parse(ApiConstants.projectList);
      final response = await http
          .get(url, headers: await _authHeaders())
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final safeBody =
            body is Map<String, dynamic> ? body : <String, dynamic>{};
        final rawProjects = _extractList(safeBody, ['projects', 'data']);
        int? maxId;
        for (final raw in rawProjects) {
          if (raw is Map) {
            final id = int.tryParse(raw['id']?.toString() ?? '');
            if (id != null && id > 0) {
              if (maxId == null || id > maxId) maxId = id;
            }
          }
        }
        return maxId;
      }
    } catch (e) {
      developer.log('[ApiService] fetchLatestProjectId error: $e',
          name: 'ApiService');
    }
    return null;
  }

   static Future<Map<String, dynamic>> createProject({
    required String projectType,
    required String societyName,
    required String address,
    String? contactNo,
    String? societyEmail,
    String? chairmanName,
    String? chairmanEmail,
    String? chairmanNo,
    String? secretaryName,
    String? secretaryEmail,
    String? secretaryNo,
    String? treasurerName,
    String? treasurerEmail,
    String? treasurerNo,
  }) async {
    final url = Uri.parse(ApiConstants.createProject);
    final requestBody = {
      'project_type': projectType,
      'society_name': societyName.trim(),
      'address': address.trim(),
      'contact_no': (contactNo ?? '').trim(),
      'society_email': (societyEmail ?? '').trim(),
      'chairman_name': (chairmanName ?? '').trim(),
      'chairman_email': (chairmanEmail ?? '').trim(),
      'chairman_no': (chairmanNo ?? '').trim(),
      'secretary_name': (secretaryName ?? '').trim(),
      'secretary_email': (secretaryEmail ?? '').trim(),
      'secretary_no': (secretaryNo ?? '').trim(),
      'treasurer_name': (treasurerName ?? '').trim(),
      'treasurer_email': (treasurerEmail ?? '').trim(),
      'treasurer_no': (treasurerNo ?? '').trim(),
    };
    late final http.Response response;
    try {
      response = await http
          .post(url,
              headers: await _authHeaders(), body: jsonEncode(requestBody))
          .timeout(ApiConstants.requestTimeout);
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      throw ApiException('Create project error: $e');
    }
    final decoded = _decode(response.body);
    developer.log(
        '[ApiService] createProject raw response (${response.statusCode}): ${response.body}',
        name: 'ApiService');
    if (response.statusCode >= 200 && response.statusCode < 300) {
      int? projectId = _deepExtractId(decoded);
      if (projectId == null || projectId <= 0) {
        projectId = await _fetchLatestProjectId();
      }
      if (projectId == null || projectId <= 0) {
        throw ApiException(
            'Project was created on the server but the ID could not be '
            'determined. Please refresh the project list.');
      }
 
      // ── Extract email_notified from server response ────────────────────
      // The server's apiStore returns:
      //   { success: true, data: { email_notified: true/false, ... }, ... }
      // We surface this so the UI can show a confirmation message.
      bool emailNotified = false;
      if (decoded is Map) {
        // Try direct key first
        final direct = decoded['email_notified'];
        if (direct is bool) {
          emailNotified = direct;
        } else {
          // Try nested under 'data'
          final data = decoded['data'];
          if (data is Map) {
            final nested = data['email_notified'];
            if (nested is bool) emailNotified = nested;
          }
        }
      }
 
      return {
        'message': (decoded is Map ? decoded['message']?.toString() : null) ??
            'Project created successfully',
        'projectId': projectId,
        'emailNotified': emailNotified, // ← NEW: forwarded to UI
        'project':
            decoded is Map<String, dynamic> ? decoded : <String, dynamic>{},
      };
    }
    if (response.statusCode == 401) {
      throw ApiException('Session expired. Please login again.');
    }
    if (decoded is Map && decoded['errors'] is Map) {
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
          (decoded is Map ? decoded['error']?.toString() : null) ??
          'Failed to create project (${response.statusCode})',
    );
  }

  static Future<String> createProjectInfo({
    required int projectId,
    required String ownershipType,
    required String existingInfo,
    String? plotArea,
    String? surveyNo,
    String? ownerName,
    String? deduction,
    String? deductionComment,
    String? location,
    String? locationLink,
    String? fsiAvailable,
    String? fsiComment,
    String? totalMembers,
    required List<Map<String, dynamic>> unitTypes,
    List<PlatformFile> ownershipDocuments = const [],
    List<PlatformFile> surveyDrawings = const [],
    List<PlatformFile> titleSurveys = const [],
  }) async {
    final token = await AuthStorageService.getToken();
    if (token == null || token.isEmpty) {
      throw ApiException('Session expired. Please login again.');
    }
    final uri = Uri.parse(ApiConstants.projectInfo(projectId));
    try {
      final request = http.MultipartRequest('POST', uri);
      request.headers['Accept'] = ApiConstants.accept;
      request.headers['Authorization'] = 'Bearer $token';
      void addField(String key, String? value) {
        if (value != null && value.trim().isNotEmpty) {
          request.fields[key] = value.trim();
        }
      }

      addField('plot_area', plotArea);
      addField('survey_no', surveyNo);
      addField('owner_name', ownerName);
      addField('deduction', deduction);
      addField('deduction_comment', deductionComment);
      addField('location', location);
      addField('location_link', locationLink);
      addField('fsi_available', fsiAvailable);
      addField('fsi_comment', fsiComment);
      addField('total_members', totalMembers);
      request.fields['ownership_type'] = ownershipType;
      request.fields['existing_info'] = existingInfo;
      for (int i = 0; i < unitTypes.length; i++) {
        final unit = unitTypes[i];
        if ((unit['type']?.toString().trim() ?? '').isEmpty) continue;
        request.fields['unit_types[$i][type]'] = unit['type'].toString();
        request.fields['unit_types[$i][number_of_units]'] =
            unit['number_of_units'].toString();
        request.fields['unit_types[$i][carpet_area]'] =
            unit['carpet_area'].toString();
        if (unit['id'] != null && unit['id'].toString().isNotEmpty) {
          request.fields['unit_types[$i][id]'] = unit['id'].toString();
        }
      }
      Future<void> addFiles(String fieldName, List<PlatformFile> files) async {
        for (final file in files) {
          if (file.path == null || file.path!.isEmpty) continue;
          request.files.add(await http.MultipartFile.fromPath(
            fieldName,
            file.path!,
            filename: file.name,
          ));
        }
      }

      await addFiles('ownership_documents[]', ownershipDocuments);
      await addFiles('survey_drawings[]', surveyDrawings);
      await addFiles('title_surveys[]', titleSurveys);
      final streamedResponse =
          await request.send().timeout(ApiConstants.requestTimeout);
      final response = await http.Response.fromStream(streamedResponse);
      final decoded = _decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded['message']?.toString() ??
            'Project information has been saved successfully.';
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      if (decoded['errors'] is Map) {
        final errors =
            Map<String, dynamic>.from(decoded['errors'] as Map);
        final firstKey = errors.keys.isNotEmpty ? errors.keys.first : null;
        if (firstKey != null &&
            errors[firstKey] is List &&
            (errors[firstKey] as List).isNotEmpty) {
          throw ApiException((errors[firstKey] as List).first.toString());
        }
      }
      throw ApiException(
        decoded['message']?.toString() ??
            decoded['error']?.toString() ??
            'Failed to save project info (${response.statusCode})',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Create project info error: $e');
    }
  }

  static Future<Map<String, dynamic>> fetchProjectForEdit(
      int projectId) async {
    final url = Uri.parse('${ApiConstants.projects}/$projectId');
    try {
      final response = await http
          .get(url, headers: await _authHeaders())
          .timeout(ApiConstants.requestTimeout);
      final decoded = _decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (decoded is Map<String, dynamic>) {
          return decoded['project'] is Map
              ? Map<String, dynamic>.from(decoded['project'] as Map)
              : decoded['data'] is Map
                  ? Map<String, dynamic>.from(decoded['data'] as Map)
                  : Map<String, dynamic>.from(decoded);
        }
        throw ApiException('Invalid project details response.');
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(
        (decoded is Map ? decoded['message']?.toString() : null) ??
            'Failed to load project details (${response.statusCode})',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Load project details error: $e');
    }
  }

  /// GET /api/mobile/project/team-members
/// Returns the team members of the logged-in team leader.
static Future<Map<String, dynamic>> getTeamMembersForAssignment() async {
  return _getRequest('${ApiConstants.baseUrl}/api/mobile/project/team-members');
}

/// POST /api/mobile/project/assign-team-member
/// Assigns a project to a team member.
static Future<void> assignProjectToTeamMember({
  required int projectId,
  required int memberId,
}) async {
  final response = await _rawPost(
    fullUrl: '${ApiConstants.baseUrl}/api/mobile/project/assign-team-member',
    body: {'project_id': projectId, 'member_id': memberId},
  );

  final decoded = _decode(response.body);

  if (response.statusCode >= 200 && response.statusCode < 300) return;

  if (response.statusCode == 401) {
    throw ApiException('Session expired.');
  }

  throw ApiException(
    (decoded is Map ? decoded['message']?.toString() : null) ??
        'Failed to assign project (${response.statusCode})',
  );
}

  static Future<Map<String, dynamic>> updateProject({
    required int projectId,
    required String projectType,
    required String societyName,
    required String address,
    String? contactNo,
    String? societyEmail,
    String? chairmanName,
    String? chairmanEmail,
    String? chairmanNo,
    String? secretaryName,
    String? secretaryEmail,
    String? secretaryNo,
    String? treasurerName,
    String? treasurerEmail,
    String? treasurerNo,
  }) async {
    // FIX: Use POST with _method:PUT spoofing instead of http.put()
    // LiteSpeed WAF blocks raw PUT requests, returning 403 Forbidden.
    // This is the same fix applied to updateGeneralTask, updateCementChecklist,
    // updateShutteringChecklist, updateSiteInstruction, etc. throughout this file.
    final url = Uri.parse('${ApiConstants.projects}/$projectId');
    final body = {
      '_method': 'PUT',                          // ← Laravel method spoofing
      'project_type': projectType,
      'society_name': societyName.trim(),
      'address': address.trim(),
      'contact_no': (contactNo ?? '').trim(),
      'society_email': (societyEmail ?? '').trim(),
      'chairman_name': (chairmanName ?? '').trim(),
      'chairman_email': (chairmanEmail ?? '').trim(),
      'chairman_no': (chairmanNo ?? '').trim(),
      'secretary_name': (secretaryName ?? '').trim(),
      'secretary_email': (secretaryEmail ?? '').trim(),
      'secretary_no': (secretaryNo ?? '').trim(),
      'treasurer_name': (treasurerName ?? '').trim(),
      'treasurer_email': (treasurerEmail ?? '').trim(),
      'treasurer_no': (treasurerNo ?? '').trim(),
    };
    try {
      // POST instead of PUT — avoids LiteSpeed 403
      final response = await http
          .post(url, headers: await _authHeaders(), body: jsonEncode(body))
          .timeout(ApiConstants.requestTimeout);
      final decoded = _decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        int? extractedId = _deepExtractId(decoded);
        extractedId ??= projectId;
        return {
          'message': decoded['message']?.toString() ??
              'Project updated successfully',
          'projectId': extractedId,
          'project': decoded is Map<String, dynamic>
              ? decoded
              : <String, dynamic>{'id': projectId},
        };
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      if (decoded is Map && decoded['errors'] is Map) {
        final errors =
            Map<String, dynamic>.from(decoded['errors'] as Map);
        final firstKey = errors.keys.isNotEmpty ? errors.keys.first : null;
        if (firstKey != null &&
            errors[firstKey] is List &&
            (errors[firstKey] as List).isNotEmpty) {
          throw ApiException((errors[firstKey] as List).first.toString());
        }
      }
      throw ApiException(
        (decoded is Map ? decoded['message']?.toString() : null) ??
            (decoded is Map ? decoded['error']?.toString() : null) ??
            'Failed to update project (${response.statusCode})',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Update project error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GENERAL TASKS
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<List<GeneralTaskModel>> fetchGeneralTasks() async {
    final response = await _getRequest(ApiConstants.generalTasks);
    developer.log('[ApiService] fetchGeneralTasks raw: $response',
        name: 'ApiService');
    final raw = _extractList(response, [
      'tasks',
      'data',
      'general_tasks',
      'items',
      'results',
      'list',
    ]);
    developer.log(
        '[ApiService] fetchGeneralTasks parsed ${raw.length} tasks',
        name: 'ApiService');
    return raw
        .whereType<Map>()
        .map((e) => GeneralTaskModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<List<AssignableUserModel>> fetchAssignableUsers() async {
    final response =
        await _getRequest(ApiConstants.generalTaskAssignableUsers);
    final raw = _extractList(response, ['users', 'data']);
    return raw
        .whereType<Map>()
        .map((e) =>
            AssignableUserModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<Map<String, dynamic>> createGeneralTask({
    required String taskName,
    required String taskDescription,
    String? taskDeadline,
  }) async {
    final body = <String, dynamic>{
      'task_name': taskName,
      'task_description': taskDescription,
      if (taskDeadline != null && taskDeadline.isNotEmpty)
        'task_deadline': taskDeadline,
    };
    final candidates = [
      ApiConstants.generalTasksCreate,
      '${ApiConstants.baseUrl}/api/mobile/general-tasks/store',
      '${ApiConstants.baseUrl}/api/general-tasks',
    ];
    http.Response? lastResponse;
    dynamic lastDecoded;
    for (final url in candidates) {
      developer.log(
          '[ApiService] createGeneralTask → trying POST $url  body: $body',
          name: 'ApiService');
      late http.Response response;
      try {
        response = await _rawPost(fullUrl: url, body: body);
      } on TimeoutException {
        throw ApiException('Request timed out. Please try again.');
      } catch (e) {
        throw ApiException('Create task network error: $e');
      }
      final decoded = _decode(response.body);
      developer.log(
          '[ApiService] createGeneralTask ← ${response.statusCode} from $url : ${response.body}',
          name: 'ApiService');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      if (response.statusCode == 404 || response.statusCode == 405) {
        lastResponse = response;
        lastDecoded = decoded;
        continue;
      }
      if (decoded is Map && decoded['errors'] is Map) {
        final errors =
            Map<String, dynamic>.from(decoded['errors'] as Map);
        final firstKey = errors.keys.isNotEmpty ? errors.keys.first : null;
        if (firstKey != null &&
            errors[firstKey] is List &&
            (errors[firstKey] as List).isNotEmpty) {
          throw ApiException((errors[firstKey] as List).first.toString());
        }
      }
      throw ApiException(
        (decoded is Map ? decoded['message']?.toString() : null) ??
            'Failed to create task (${response.statusCode})',
      );
    }
    throw ApiException(
      (lastDecoded is Map ? lastDecoded['message']?.toString() : null) ??
          'Could not find a valid route to create the task. Please contact your administrator (HTTP ${lastResponse?.statusCode}).',
    );
  }

  static Future<Map<String, dynamic>> updateGeneralTask({
  required int taskId,
  required String taskName,
  required String taskDescription,
  String? taskDeadline,
}) async {
  final url = ApiConstants.generalTaskUpdate(taskId);
 
  developer.log(
    '[ApiService] updateGeneralTask → POST $url (spoofing PUT)',
    name: 'ApiService',
  );
 
  late http.Response response;
  try {
    response = await _rawPostWithMethod(
      fullUrl: url,
      method: 'PUT',
      body: {
        'task_name': taskName,
        'task_description': taskDescription,
        if (taskDeadline != null && taskDeadline.isNotEmpty)
          'task_deadline': taskDeadline,
      },
    );
  } on TimeoutException {
    throw ApiException('Request timed out. Please try again.');
  } catch (e) {
    throw ApiException('Update task network error: $e');
  }
 
  developer.log(
    '[ApiService] updateGeneralTask ← ${response.statusCode} : ${response.body}',
    name: 'ApiService',
  );
 
  final decoded = _decode(response.body);
 
  if (response.statusCode >= 200 && response.statusCode < 300) {
    return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
  }
  if (response.statusCode == 401) {
    throw ApiException('Session expired. Please login again.');
  }
  if (response.statusCode == 403) {
    throw ApiException(
      (decoded is Map ? decoded['message']?.toString() : null) ??
          'You do not have permission to edit this task.',
    );
  }
  if (decoded is Map && decoded['errors'] is Map) {
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
        'Failed to update task (${response.statusCode})',
  );
}

  static Future<Map<String, dynamic>> assignGeneralTask({
    required int taskId,
    required List<int> assignedTo,
    required String assignedDate,
  }) async {
    return _postRequest(
      fullUrl: ApiConstants.generalTaskAssign,
      body: {
        'task_id': taskId,
        'assigned_to': assignedTo,
        'assigned_date': assignedDate,
      },
    );
  }

  static Future<Map<String, dynamic>> uploadGeneralTaskFile({
  required int    taskId,
  required File   file,
  required String fileName,
  required String uploadedDate,
}) async {
  final url = ApiConstants.generalTaskUploadFile(taskId);
 
  developer.log(
    '[ApiService] uploadGeneralTaskFile → POST $url  file: $fileName',
    name: 'ApiService',
  );
 
  final token = await AuthStorageService.getToken();
  final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
  final mimeParts = mimeType.split('/');
 
  final request = http.MultipartRequest('POST', Uri.parse(url))
    ..headers.addAll({
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    })
    ..fields['uploaded_date'] = uploadedDate
    ..files.add(await http.MultipartFile.fromPath(
      'file',           // ← matches Laravel: $request->file('file')
      file.path,
      filename: fileName,
      contentType: MediaType(mimeParts[0], mimeParts[1]),
    ));
 
  late http.StreamedResponse streamed;
  try {
    streamed = await request.send().timeout(const Duration(seconds: 60));
  } on TimeoutException {
    throw ApiException('Upload timed out. Please try again.');
  } catch (e) {
    throw ApiException('Upload network error: $e');
  }
 
  final body     = await streamed.stream.bytesToString();
  final decoded  = _decode(body);
 
  developer.log(
    '[ApiService] uploadGeneralTaskFile ← ${streamed.statusCode} : $body',
    name: 'ApiService',
  );
 
  if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
    return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
  }
  if (streamed.statusCode == 401) {
    throw ApiException('Session expired. Please login again.');
  }
  if (streamed.statusCode == 403) {
    throw ApiException(
      (decoded is Map ? decoded['message']?.toString() : null) ??
          'You do not have permission to upload for this task.',
    );
  }
  if (streamed.statusCode == 422) {
    if (decoded is Map && decoded['errors'] is Map) {
      final errors  = Map<String, dynamic>.from(decoded['errors'] as Map);
      final firstKey = errors.keys.isNotEmpty ? errors.keys.first : null;
      if (firstKey != null &&
          errors[firstKey] is List &&
          (errors[firstKey] as List).isNotEmpty) {
        throw ApiException((errors[firstKey] as List).first.toString());
      }
    }
  }
  throw ApiException(
    (decoded is Map ? decoded['message']?.toString() : null) ??
        'Upload failed (${streamed.statusCode})',
  );
}

  static Future<Map<String, dynamic>> updateGeneralTaskStatus({
    required int taskId,
    required String status,
  }) async {
    return _postRequest(
      fullUrl: ApiConstants.generalTaskUpdateStatus(taskId),
      body: {'status': status},
    );
  }

  static Future<Map<String, dynamic>> deleteGeneralTask(int taskId) async {
  final url = ApiConstants.generalTaskDelete(taskId);
 
  developer.log(
    '[ApiService] deleteGeneralTask → POST $url (spoofing DELETE)',
    name: 'ApiService',
  );
 
  late http.Response response;
  try {
    response = await _rawPostWithMethod(
      fullUrl: url,
      method: 'POST',
      body: {}, // DELETE body is empty; _method is injected by helper
    );
  } on TimeoutException {
    throw ApiException('Request timed out. Please try again.');
  } catch (e) {
    throw ApiException('Delete task network error: $e');
  }
 
  developer.log(
    '[ApiService] deleteGeneralTask ← ${response.statusCode} : ${response.body}',
    name: 'ApiService',
  );
 
  final decoded = _decode(response.body);
 
  if (response.statusCode >= 200 && response.statusCode < 300) {
    return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
  }
  if (response.statusCode == 401) {
    throw ApiException('Session expired. Please login again.');
  }
  if (response.statusCode == 403) {
    throw ApiException(
      (decoded is Map ? decoded['message']?.toString() : null) ??
          'You do not have permission to delete this task.',
    );
  }
  throw ApiException(
    (decoded is Map ? decoded['message']?.toString() : null) ??
        'Failed to delete task (${response.statusCode})',
  );
}

  // ═══════════════════════════════════════════════════════════════════════════
  // CALENDAR TASKS
  // ═══════════════════════════════════════════════════════════════════════════
 
  /// Fetches calendar events from the dedicated mobile calendar controller.
  ///
  /// FIX #1 : uses ApiConstants.calendarTasks → /api/mobile/calendar/tasks
  /// FIX #2 : passes start_date / end_date (not start / end)
  static Future<List<TaskCalendarEventModel>> fetchCalendarTasks({
    List<int> teamIds   = const [],
    List<int> memberIds = const [],
    String? startDate,
    String? endDate,
  }) async {
    final token = await AuthStorageService.getToken();
    if (token == null || token.isEmpty) {
      throw ApiException('Session expired. Please login again.');
    }
 
    final uri = _buildCalendarUri(
      teamIds,
      memberIds,
      startDate: startDate,
      endDate:   endDate,
    );
 
    developer.log(
      '[ApiService] fetchCalendarTasks → GET $uri',
      name: 'ApiService',
    );
 
    try {
      final response = await http
          .get(uri, headers: await _authHeaders())
          .timeout(ApiConstants.requestTimeout);
 
      developer.log(
        '[ApiService] fetchCalendarTasks ← ${response.statusCode}: '
        '${response.body.substring(0, response.body.length.clamp(0, 400))}',
        name: 'ApiService',
      );
 
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
 
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body     = _decode(response.body);
        final safeBody = body is Map<String, dynamic> ? body : <String, dynamic>{};
 
        // The mobile controller wraps events in {"success":true,"data":[...]}
        final raw = _extractList(safeBody, ['data', 'tasks', 'items', 'events']);
 
        developer.log(
          '[ApiService] fetchCalendarTasks parsed ${raw.length} events',
          name: 'ApiService',
        );
 
        return raw
            .whereType<Map>()
            .map((e) => TaskCalendarEventModel.fromJson(
                  Map<String, dynamic>.from(e)))
            .toList();
      }
 
      return [];
    } catch (e) {
      if (e is ApiException) rethrow;
      developer.log(
        '[ApiService] fetchCalendarTasks error: $e',
        name: 'ApiService',
      );
      return [];
    }
  }
 
  /// Fetches task statistics from the mobile calendar controller.
  ///
  /// FIX #1: uses ApiConstants.calendarTaskStatistics →
  ///         /api/mobile/calendar/statistics
  static Future<Map<String, dynamic>> fetchCalendarTaskStatistics() async {
    try {
      final response =
          await _getRequest(ApiConstants.calendarTaskStatistics);
 
      // Mobile controller returns {"success":true,"data":{...}}
      if (response['data'] is Map<String, dynamic>) {
        return Map<String, dynamic>.from(response['data']);
      }
      return response;
    } catch (e) {
      developer.log(
        '[ApiService] fetchCalendarTaskStatistics error: $e',
        name: 'ApiService',
      );
      return {};
    }
  }
 
  static Future<List<Map<String, dynamic>>> fetchRecentCalendarTasks(
      {int limit = 10}) async {
    try {
      final response = await _getRequest(
        '${ApiConstants.calendarRecentTasks}/$limit',
      );
      final raw = _extractList(response, ['data', 'tasks']);
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }
 
  /// Marks a general task as complete via the mobile calendar controller.
  ///
  /// FIX #5: uses ApiConstants.calendarCompleteTask →
  ///         /api/mobile/calendar/tasks/{id}/complete  (PUT)
  static Future<Map<String, dynamic>> completeCalendarTask(int taskId) async {
    return _putRequest(fullUrl: ApiConstants.calendarCompleteTask(taskId));
  }
 
  // ═══════════════════════════════════════════════════════════════════════════
  // TEAMS  (calendar-specific overloads)
  // ═══════════════════════════════════════════════════════════════════════════
 
  /// Returns all teams visible to the current user, using the mobile calendar
  /// controller endpoint.
  ///
  /// FIX #3: was calling `/api/teams/fetch` (web-only route).
  ///         Now calls /api/mobile/calendar/teams.
  static Future<List<Map<String, dynamic>>> fetchTeamsAndMembers() async {
    try {
      final response =
          await _getRequest(ApiConstants.calendarTeams);
 
      // Mobile controller returns {"success":true,"data":[...]}
      final raw = _extractList(response, ['data', 'teams']);
 
      return raw
          .whereType<Map>()
          .map((e) {
            final team = Map<String, dynamic>.from(e);
            return {
              ...team,
              'id':        _parseInt(team['id']),
              'team_name': team['team_name'] ?? team['name'] ?? 'Team',
            };
          })
          .toList();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to fetch teams: $e');
    }
  }
 
  /// Returns members for a specific team from the mobile calendar controller.
  ///
  /// FIX #4: was calling `/api/team-members/fetch` + client-side filter.
  ///         Now calls /api/mobile/calendar/teams/{id}/members directly.
  static Future<List<Map<String, dynamic>>> fetchTeamMembers(int teamId) async {
    try {
      final response = await _getRequest(
        ApiConstants.calendarTeamMembers(teamId),
      );
 
      // Mobile controller returns
      // {"success":true,"data":[...],"members":[...]}
      final raw = _extractList(response, ['data', 'members']);
 
      return raw
          .whereType<Map>()
          .map((e) {
            final member = Map<String, dynamic>.from(e);
            return {
              ...member,
              'id':   _parseInt(member['id']   ?? member['user_id']),
              'name': member['display_name']   ??
                      member['name']           ??
                      member['user_name']      ??
                      member['full_name']      ??
                      'Member',
            };
          })
          .toList();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to fetch team members: $e');
    }
  }

  static Future<List<TeamMemberModel>> fetchTeamMembersForAssign(
    int teamId, {
    bool excludeLeaders = true,
  }) async {
    developer.log(
        '[ApiService] fetchTeamMembersForAssign → teamId=$teamId, excludeLeaders=$excludeLeaders',
        name: 'ApiService');
    final body = await _getRequest(ApiConstants.teamMembers(teamId));
    developer.log(
        '[ApiService] fetchTeamMembersForAssign ← raw keys: ${body.keys.toList()}',
        name: 'ApiService');
    final raw = _extractList(body, ['members', 'data', 'users']);
    developer.log(
        '[ApiService] fetchTeamMembersForAssign → parsed ${raw.length} entries',
        name: 'ApiService');
    if (raw.isEmpty) {
      developer.log(
          '[ApiService] fetchTeamMembersForAssign WARNING: empty list. Full body: $body',
          name: 'ApiService');
    }
    final members = raw
        .whereType<Map>()
        .map((e) =>
            TeamMemberModel.fromJson(Map<String, dynamic>.from(e)))
        .where((m) => m.id > 0 && m.name.isNotEmpty)
        .where((m) => !excludeLeaders || !m.isLeader)
        .toList();
    members
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return members;
  }

  static Future<List<int>> fetchLeaderOwnedTeamIds() async {
    final userId = await AuthStorageService.getUserId();
    final userRole =
        (await AuthStorageService.getUserRole() ?? '').trim().toLowerCase();
    if (userId == null || userId <= 0) return [];
    if (userRole != 'leader' && userRole != 'team leader') return [];
    final teams = await fetchTeamsAndMembers();
    final ownedTeamIds = <int>[];
    for (final team in teams) {
      final teamId = _parseInt(team['id'] ?? team['team_id']);
      final rawMembers = team['members'];
      if (teamId <= 0 || rawMembers is! List) continue;
      final hasCurrentUserAsLeader = rawMembers.any((rawMember) {
        if (rawMember is! Map) return false;
        final member = Map<String, dynamic>.from(rawMember);
        final memberUserId = _parseInt(
            member['id'] ?? member['user_id'] ?? member['member_id']);
        final role =
            (member['role']?.toString() ?? '').trim().toLowerCase();
        return memberUserId == userId && role == 'leader';
      });
      if (hasCurrentUserAsLeader) {
        ownedTeamIds.add(teamId);
      }
    }
    return ownedTeamIds.toSet().toList()..sort();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WORK REPORTS
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<List<WorkReportUser>> fetchWorkReportUsers() async {
    try {
      final body = await _getRequest(ApiConstants.workReportUsers);
      final raw = _extractList(body, ['users', 'data', 'members', 'results', 'items']);
      if (raw.isEmpty && body is List) {
        return (body as List)
            .whereType<Map>()
            .map((e) =>
                WorkReportUser.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      return raw
          .whereType<Map>()
          .map((e) =>
              WorkReportUser.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on ApiException catch (e) {
      if (e.toString().contains('403') ||
          e.toString().contains('Unauthorized') ||
          e.toString().contains('Access denied')) {
        return [];
      }
      rethrow;
    } catch (_) {
      return [];
    }
  }

  static Future<List<WorkReportCalendarEvent>> fetchWorkReportCalendar({
    required int userId,
    required String startDate,
    required String endDate,
  }) async {
    final token = await AuthStorageService.getToken();
    if (token == null || token.isEmpty) {
      throw ApiException('Not logged in. Please log in again.');
    }
    if (userId == 0) {
      throw ApiException('User ID is 0. Please log out and log in again.');
    }
    final uri = Uri.parse(ApiConstants.workReportsCalendar).replace(
      queryParameters: {
        'user_id': userId.toString(),
        'start': startDate,
        'end': endDate,
      },
    );
    developer.log('[ApiService] fetchWorkReportCalendar → GET $uri',
        name: 'ApiService');
    try {
      final response = await http
          .get(uri, headers: await _authHeaders())
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      developer.log(
          '[ApiService] fetchWorkReportCalendar ← ${response.statusCode}: '
          '${response.body.substring(0, response.body.length.clamp(0, 500))}',
          name: 'ApiService');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final safeBody =
            body is Map<String, dynamic> ? body : <String, dynamic>{};
        final raw =
            _extractList(safeBody, ['data', 'events', 'tasks', 'items']);
        return raw
            .whereType<Map>()
            .map((e) => WorkReportCalendarEvent.fromJson(
                Map<String, dynamic>.from(e)))
            .toList();
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please log in again.');
      }
      if (response.statusCode == 403) {
        throw ApiException('Access denied (403). You do not have permission.');
      }
      if (response.statusCode == 404) {
        throw ApiException(
            'Work report endpoint not found (404). Make sure the Laravel routes are registered.');
      }
      if (response.statusCode == 500) {
        final serverMsg =
            (body is Map ? body['message']?.toString() : null) ??
                (body is Map ? body['error']?.toString() : null) ??
                response.body.substring(0, response.body.length.clamp(0, 200));
        throw ApiException('Server error (500): $serverMsg');
      }
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Request failed (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Connection timed out.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Work report calendar error: $e');
    }
  }

  static Future<Map<String, dynamic>> fetchWorkReportDetail({
    required int userId,
    required String date,
    required int attendanceId,
  }) async {
    final uri = Uri.parse(ApiConstants.workReportGet).replace(
      queryParameters: {
        'user_id': userId.toString(),
        'date': date,
        'attendance_id': attendanceId.toString(),
      },
    );
    try {
      final response = await http
          .get(uri, headers: await _authHeaders())
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      developer.log(
          '[ApiService] fetchWorkReportDetail ${response.statusCode}: ${response.body}',
          name: 'ApiService');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final safeBody =
            body is Map<String, dynamic> ? body : <String, dynamic>{};
        return safeBody['data'] is Map<String, dynamic>
            ? safeBody['data'] as Map<String, dynamic>
            : safeBody;
      }
      if (response.statusCode == 401) throw ApiException('Session expired.');
      if (response.statusCode == 403) {
        throw ApiException('Unauthorized access.');
      }
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to fetch work report (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Fetch work report error: $e');
    }
  }

  static Future<String> saveWorkReport({
    required int userId,
    required int attendanceId,
    required String date,
    required String workDescription,
    String? tasksCompleted,
    required double hoursWorked,
    String? challengesFaced,
    String? nextDayPlan,
    required String status,
  }) async {
    final body = <String, dynamic>{
      'user_id': userId,
      'attendance_id': attendanceId,
      'date': date,
      'work_description': workDescription,
      'tasks_completed': tasksCompleted ?? '',
      'hours_worked': hoursWorked,
      'challenges_faced': challengesFaced ?? '',
      'next_day_plan': nextDayPlan ?? '',
      'status': status,
    };
    try {
      final response =
          await _rawPost(fullUrl: ApiConstants.workReportsStore, body: body);
      final decoded = _decode(response.body);
      developer.log(
          '[ApiService] saveWorkReport ${response.statusCode}: ${response.body}',
          name: 'ApiService');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return (decoded is Map ? decoded['message']?.toString() : null) ??
            'Work report saved successfully';
      }
      if (response.statusCode == 401) throw ApiException('Session expired.');
      if (response.statusCode == 403) {
        throw ApiException('Unauthorized to submit report for this user.');
      }
      if (response.statusCode == 422 &&
          decoded is Map &&
          decoded['errors'] is Map) {
        final errors =
            Map<String, dynamic>.from(decoded['errors'] as Map);
        final firstKey = errors.keys.isNotEmpty ? errors.keys.first : null;
        if (firstKey != null &&
            errors[firstKey] is List &&
            (errors[firstKey] as List).isNotEmpty) {
          throw ApiException((errors[firstKey] as List).first.toString());
        }
      }
      throw ApiException(
        (decoded is Map ? decoded['message']?.toString() : null) ??
            'Failed to save work report (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Save work report error: $e');
    }
  }

  static Future<String> deleteWorkReport(int reportId) async {
    final url = ApiConstants.workReportDestroy(reportId);
    try {
      final response = await _rawPost(fullUrl: url, body: const {});
      final decoded = _decode(response.body);
      developer.log(
          '[ApiService] deleteWorkReport ${response.statusCode}: ${response.body}',
          name: 'ApiService');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return (decoded is Map ? decoded['message']?.toString() : null) ??
            'Work report deleted successfully';
      }
      if (response.statusCode == 401) throw ApiException('Session expired.');
      if (response.statusCode == 403) {
        throw ApiException('Unauthorized to delete this report.');
      }
      throw ApiException(
        (decoded is Map ? decoded['message']?.toString() : null) ??
            'Failed to delete work report (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Delete work report error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RE-EXECUTION — Daily Progress Reports
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> fetchReExecutionReports({
    required int projectId,
    int page = 1,
    int perPage = 15,
  }) async {
    final url =
        '${ApiConstants.reExecutionList(projectId)}?page=$page&per_page=$perPage';
    developer.log('[ApiService] fetchReExecutionReports → GET $url',
        name: 'ApiService');
    final body = await _getRequest(url);
    final rawList = body['data'] as List? ?? [];
    final reports = rawList
        .whereType<Map>()
        .map((e) =>
            ReExecutionModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return {
      'reports': reports,
      'project': body['project'] ?? <String, dynamic>{},
      'current_page': (body['current_page'] as num?)?.toInt() ?? 1,
      'last_page': (body['last_page'] as num?)?.toInt() ?? 1,
      'total': (body['total'] as num?)?.toInt() ?? 0,
    };
  }

  static Future<ReExecutionDetailModel> fetchReExecutionDetail({
    required int projectId,
    required int reportId,
  }) async {
    developer.log(
        '[ApiService] fetchReExecutionDetail → GET projectId=$projectId reportId=$reportId',
        name: 'ApiService');
    final body = await _getRequest(
        ApiConstants.reExecutionDetail(projectId, reportId));
    final data = body['data'];
    if (data is Map<String, dynamic>) {
      return ReExecutionDetailModel.fromJson(data);
    }
    return ReExecutionDetailModel.fromJson(
        body.map((k, v) => MapEntry(k.toString(), v)));
  }

  static Future<ReExecutionDetailModel> createReExecutionReport({
    required int projectId,
    required String reportDate,
    required List<Map<String, dynamic>> laborAgencies,
    required List<Map<String, dynamic>> previousProgress,
    required List<Map<String, dynamic>> plannedWorks,
    String decisionsApprovals = '',
    String bottleNecks = '',
    String changeAuthorizations = '',
    String materialDelivered = '',
    String ehsIncidentReports = '',
  }) async {
    developer.log(
        '[ApiService] createReExecutionReport → POST projectId=$projectId date=$reportDate',
        name: 'ApiService');
    final response = await _postRequest(
      fullUrl: ApiConstants.reExecutionCreate(projectId),
      body: {
        'report_date': reportDate,
        'labor_agencies': laborAgencies,
        'previous_progress': previousProgress,
        'planned_works': plannedWorks,
        'decisions_approvals': decisionsApprovals,
        'bottle_necks': bottleNecks,
        'change_authorizations': changeAuthorizations,
        'material_delivered': materialDelivered,
        'ehs_incident_reports': ehsIncidentReports,
      },
    );
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return ReExecutionDetailModel.fromJson(data);
    }
    return ReExecutionDetailModel.fromJson(
        response.map((k, v) => MapEntry(k.toString(), v)));
  }

  static Future<ReExecutionDetailModel> updateReExecutionReport({
    required int projectId,
    required int reportId,
    required String reportDate,
    required List<Map<String, dynamic>> laborAgencies,
    required List<Map<String, dynamic>> previousProgress,
    required List<Map<String, dynamic>> plannedWorks,
    String decisionsApprovals = '',
    String bottleNecks = '',
    String changeAuthorizations = '',
    String materialDelivered = '',
    String ehsIncidentReports = '',
  }) async {
    developer.log(
        '[ApiService] updateReExecutionReport → PUT projectId=$projectId reportId=$reportId',
        name: 'ApiService');
    final response = await _putRequest(
      fullUrl: ApiConstants.reExecutionUpdate(projectId, reportId),
      body: {
        'report_date': reportDate,
        'labor_agencies': laborAgencies,
        'previous_progress': previousProgress,
        'planned_works': plannedWorks,
        'decisions_approvals': decisionsApprovals,
        'bottle_necks': bottleNecks,
        'change_authorizations': changeAuthorizations,
        'material_delivered': materialDelivered,
        'ehs_incident_reports': ehsIncidentReports,
      },
    );
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return ReExecutionDetailModel.fromJson(data);
    }
    return ReExecutionDetailModel.fromJson(
        response.map((k, v) => MapEntry(k.toString(), v)));
  }

  static Future<void> deleteReExecutionReport({
    required int projectId,
    required int reportId,
  }) async {
    developer.log(
        '[ApiService] deleteReExecutionReport → DELETE projectId=$projectId reportId=$reportId',
        name: 'ApiService');
    await _deleteRequest(ApiConstants.reExecutionDelete(projectId, reportId));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CEMENT CHECKLIST
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<Map<String, String>> _cementHeaders() async {
    final token = await AuthStorageService.getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<List<CementChecklistModel>> fetchCementChecklists(
      int projectId) async {
    final url = Uri.parse(ApiConstants.cementChecklistIndex(projectId));
    developer.log('[ApiService] fetchCementChecklists → GET $url',
        name: 'ApiService');
    try {
      final response = await http
          .get(url, headers: await _cementHeaders())
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      developer.log(
          '[ApiService] fetchCementChecklists ← ${response.statusCode}',
          name: 'ApiService');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = (body is Map ? body['checklists'] : null);
        if (raw is List) {
          return raw
              .whereType<Map>()
              .map((e) =>
                  CementChecklistModel.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
        return [];
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to load cement checklists (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Cement checklist fetch error: $e');
    }
  }

  static Future<String> generateCementChecklistNumber(int projectId) async {
    final url = Uri.parse(ApiConstants.cementChecklistCreate(projectId));
    developer.log('[ApiService] generateCementChecklistNumber → GET $url',
        name: 'ApiService');
    try {
      final response = await http
          .get(url, headers: await _cementHeaders())
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return body['checklist_no']?.toString() ?? '';
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to generate checklist number (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Generate checklist number error: $e');
    }
  }

  static Future<CementChecklistModel> createCementChecklist({
    required int projectId,
    required String checklistNo,
    required String checklistDate,
    required String material,
    required String quantity,
    required String suppliedBy,
    String? challanNo,
    String? challanDate,
    String? tradeMark,
    String? testTakenBy,
    required List<Map<String, String>> testResults,
  }) async {
    final url = Uri.parse(ApiConstants.cementChecklistStore(projectId));
    developer.log(
        '[ApiService] createCementChecklist → POST $url projectId=$projectId',
        name: 'ApiService');
    final payload = <String, dynamic>{
      'checklist_no': checklistNo,
      'checklist_date': checklistDate,
      'material': material,
      'quantity': quantity,
      'supplied_by': suppliedBy,
      if (challanNo != null && challanNo.isNotEmpty) 'challan_no': challanNo,
      if (challanDate != null && challanDate.isNotEmpty)
        'challan_date': challanDate,
      if (tradeMark != null && tradeMark.isNotEmpty) 'trade_mark': tradeMark,
      if (testTakenBy != null && testTakenBy.isNotEmpty)
        'test_taken_by': testTakenBy,
      'test_results': testResults,
    };
    try {
      final response = await http
          .post(url, headers: await _cementHeaders(), body: jsonEncode(payload))
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      developer.log(
          '[ApiService] createCementChecklist ← ${response.statusCode}: ${response.body}',
          name: 'ApiService');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = body['checklist'];
        if (raw is Map<String, dynamic>) {
          return CementChecklistModel.fromJson(raw);
        }
        throw ApiException('Unexpected response format from server.');
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
            'Failed to create cement checklist (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Create cement checklist error: $e');
    }
  }

  static Future<CementChecklistModel> fetchCementChecklist(
      int projectId, int id) async {
    final url = Uri.parse(ApiConstants.cementChecklistShow(projectId, id));
    developer.log('[ApiService] fetchCementChecklist → GET $url',
        name: 'ApiService');
    try {
      final response = await http
          .get(url, headers: await _cementHeaders())
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = body['checklist'];
        if (raw is Map<String, dynamic>) {
          return CementChecklistModel.fromJson(raw);
        }
        throw ApiException('Unexpected response format from server.');
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Checklist not found (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Fetch cement checklist error: $e');
    }
  }

  static Future<CementChecklistModel> updateCementChecklist({
    required int projectId,
    required int id,
    required String checklistDate,
    required String material,
    required String quantity,
    required String suppliedBy,
    String? challanNo,
    String? challanDate,
    String? tradeMark,
    String? testTakenBy,
    required List<Map<String, String>> testResults,
  }) async {
    final url = Uri.parse(ApiConstants.cementChecklistUpdate(projectId, id));
    developer.log('[ApiService] updateCementChecklist → PUT $url id=$id',
        name: 'ApiService');
    final payload = <String, dynamic>{
      'checklist_date': checklistDate,
      'material': material,
      'quantity': quantity,
      'supplied_by': suppliedBy,
      if (challanNo != null && challanNo.isNotEmpty) 'challan_no': challanNo,
      if (challanDate != null && challanDate.isNotEmpty)
        'challan_date': challanDate,
      if (tradeMark != null && tradeMark.isNotEmpty) 'trade_mark': tradeMark,
      if (testTakenBy != null && testTakenBy.isNotEmpty)
        'test_taken_by': testTakenBy,
      'test_results': testResults,
    };
    try {
      final response = await http
          .put(url, headers: await _cementHeaders(), body: jsonEncode(payload))
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      developer.log(
          '[ApiService] updateCementChecklist ← ${response.statusCode}: ${response.body}',
          name: 'ApiService');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = body['checklist'];
        if (raw is Map<String, dynamic>) {
          return CementChecklistModel.fromJson(raw);
        }
        throw ApiException('Unexpected response format from server.');
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
            'Failed to update cement checklist (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Update cement checklist error: $e');
    }
  }

  static Future<void> deleteCementChecklist(int projectId, int id) async {
    final url = Uri.parse(ApiConstants.cementChecklistDestroy(projectId, id));
    developer.log('[ApiService] deleteCementChecklist → POST $url id=$id',
        name: 'ApiService');
    try {
      final response = await http
          .post(url,
              headers: await _cementHeaders(),
              body: jsonEncode({'_method': 'DELETE'}))
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      developer.log(
          '[ApiService] deleteCementChecklist ← ${response.statusCode}',
          name: 'ApiService');
      if (response.statusCode >= 200 && response.statusCode < 300) return;
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to delete cement checklist (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Delete cement checklist error: $e');
    }
  }

  static String cementChecklistPrintUrl(int projectId, int id) =>
      ApiConstants.cementChecklistPrint(projectId, id);

  static String cementChecklistDownloadUrl(int projectId, int id) =>
      ApiConstants.cementChecklistDownload(projectId, id);

  // ═══════════════════════════════════════════════════════════════════════════
  // STEEL CHECKLIST
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<Map<String, String>> _steelHeaders() async {
    final token = await AuthStorageService.getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<List<SteelChecklistModel>> fetchSteelChecklists(
      int projectId) async {
    final url = Uri.parse(ApiConstants.steelChecklistIndex(projectId));
    developer.log('[ApiService] fetchSteelChecklists → GET $url',
        name: 'ApiService');
    try {
      final response = await http
          .get(url, headers: await _steelHeaders())
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      developer.log(
          '[ApiService] fetchSteelChecklists ← ${response.statusCode}',
          name: 'ApiService');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = (body is Map ? body['checklists'] : null);
        if (raw is List) {
          return raw
              .whereType<Map>()
              .map((e) =>
                  SteelChecklistModel.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
        return [];
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to load steel checklists (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Steel checklist fetch error: $e');
    }
  }

  static Future<String> generateSteelChecklistNumber(int projectId) async {
    final url = Uri.parse(ApiConstants.steelChecklistCreate(projectId));
    developer.log('[ApiService] generateSteelChecklistNumber → GET $url',
        name: 'ApiService');
    try {
      final response = await http
          .get(url, headers: await _steelHeaders())
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return body['checklist_no']?.toString() ?? '';
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to generate checklist number (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Generate steel checklist number error: $e');
    }
  }

  static Future<SteelChecklistModel> createSteelChecklist({
    required int projectId,
    required String checklistNo,
    required String checklistDate,
    required String material,
    required String quantity,
    required String suppliedBy,
    String? challanNo,
    String? challanDate,
    String? tradeMark,
    String? testTakenBy,
    required List<Map<String, dynamic>> testResults,
  }) async {
    final url = Uri.parse(ApiConstants.steelChecklistStore(projectId));
    developer.log(
        '[ApiService] createSteelChecklist → POST $url projectId=$projectId',
        name: 'ApiService');
    final payload = <String, dynamic>{
      'checklist_no': checklistNo,
      'checklist_date': checklistDate,
      'material': material,
      'quantity': quantity,
      'supplied_by': suppliedBy,
      if (challanNo != null && challanNo.isNotEmpty) 'challan_no': challanNo,
      if (challanDate != null && challanDate.isNotEmpty)
        'challan_date': challanDate,
      if (tradeMark != null && tradeMark.isNotEmpty) 'trade_mark': tradeMark,
      if (testTakenBy != null && testTakenBy.isNotEmpty)
        'test_taken_by': testTakenBy,
      'test_results': testResults,
    };
    try {
      final response = await http
          .post(url, headers: await _steelHeaders(), body: jsonEncode(payload))
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      developer.log(
          '[ApiService] createSteelChecklist ← ${response.statusCode}: ${response.body}',
          name: 'ApiService');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = body['checklist'];
        if (raw is Map<String, dynamic>) {
          return SteelChecklistModel.fromJson(raw);
        }
        throw ApiException('Unexpected response format from server.');
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
            'Failed to create steel checklist (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Create steel checklist error: $e');
    }
  }

  static Future<SteelChecklistModel> fetchSteelChecklist(
      int projectId, int id) async {
    final url = Uri.parse(ApiConstants.steelChecklistShow(projectId, id));
    developer.log('[ApiService] fetchSteelChecklist → GET $url',
        name: 'ApiService');
    try {
      final response = await http
          .get(url, headers: await _steelHeaders())
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = body['checklist'];
        if (raw is Map<String, dynamic>) {
          return SteelChecklistModel.fromJson(raw);
        }
        throw ApiException('Unexpected response format from server.');
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Checklist not found (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Fetch steel checklist error: $e');
    }
  }

  static Future<SteelChecklistModel> updateSteelChecklist({
    required int projectId,
    required int id,
    required String checklistDate,
    required String material,
    required String quantity,
    required String suppliedBy,
    String? challanNo,
    String? challanDate,
    String? tradeMark,
    String? testTakenBy,
    required List<Map<String, dynamic>> testResults,
  }) async {
    final url = Uri.parse(ApiConstants.steelChecklistUpdate(projectId, id));
    developer.log('[ApiService] updateSteelChecklist → PUT $url id=$id',
        name: 'ApiService');
    final payload = <String, dynamic>{
      'checklist_date': checklistDate,
      'material': material,
      'quantity': quantity,
      'supplied_by': suppliedBy,
      if (challanNo != null && challanNo.isNotEmpty) 'challan_no': challanNo,
      if (challanDate != null && challanDate.isNotEmpty)
        'challan_date': challanDate,
      if (tradeMark != null && tradeMark.isNotEmpty) 'trade_mark': tradeMark,
      if (testTakenBy != null && testTakenBy.isNotEmpty)
        'test_taken_by': testTakenBy,
      'test_results': testResults,
    };
    try {
      final response = await http
          .put(url, headers: await _steelHeaders(), body: jsonEncode(payload))
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      developer.log(
          '[ApiService] updateSteelChecklist ← ${response.statusCode}: ${response.body}',
          name: 'ApiService');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = body['checklist'];
        if (raw is Map<String, dynamic>) {
          return SteelChecklistModel.fromJson(raw);
        }
        throw ApiException('Unexpected response format from server.');
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
            'Failed to update steel checklist (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Update steel checklist error: $e');
    }
  }

  static Future<void> deleteSteelChecklist(int projectId, int id) async {
    final url = Uri.parse(ApiConstants.steelChecklistDestroy(projectId, id));
    developer.log('[ApiService] deleteSteelChecklist → POST $url id=$id',
        name: 'ApiService');
    try {
      final response = await http
          .post(url,
              headers: await _steelHeaders(),
              body: jsonEncode({'_method': 'DELETE'}))
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      developer.log(
          '[ApiService] deleteSteelChecklist ← ${response.statusCode}',
          name: 'ApiService');
      if (response.statusCode >= 200 && response.statusCode < 300) return;
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to delete steel checklist (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Delete steel checklist error: $e');
    }
  }

  static String steelChecklistPrintUrl(int projectId, int id) =>
      ApiConstants.steelChecklistPrint(projectId, id);

  static String steelChecklistDownloadUrl(int projectId, int id) =>
      ApiConstants.steelChecklistDownload(projectId, id);


         // ═══════════════════════════════════════════════════════════════════════════
  // EXCAVATION CHECKLIST
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<Map<String, String>> _excavationHeaders() async {
    final token = await AuthStorageService.getToken();
    authToken = token ?? '';

    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
      if (authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
    };
  }

  static Future<List<ExcavationChecklistModel>> fetchExcavationChecklists(
      int projectId) async {
    final url = Uri.parse(ApiConstants.excavationChecklistIndex(projectId));
    developer.log('[ApiService] fetchExcavationChecklists → GET $url',
        name: 'ApiService');

    try {
      final response = await http
          .get(url, headers: await _excavationHeaders())
          .timeout(ApiConstants.requestTimeout);

      final body = _decode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = (body is Map ? body['checklists'] : null);
        if (raw is List) {
          return raw
              .whereType<Map>()
              .map((e) => ExcavationChecklistModel.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList();
        }
        return [];
      }

      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }

      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to load excavation checklists (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Excavation checklist fetch error: $e');
    }
  }

  static Future<String> generateExcavationChecklistNumber(int projectId) async {
    final url = Uri.parse(ApiConstants.excavationChecklistCreate(projectId));
    developer.log('[ApiService] generateExcavationChecklistNumber → GET $url',
        name: 'ApiService');

    try {
      final response = await http
          .get(url, headers: await _excavationHeaders())
          .timeout(ApiConstants.requestTimeout);

      final body = _decode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return body['checklist_no']?.toString() ?? '';
      }

      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }

      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to generate excavation checklist number (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Generate excavation checklist number error: $e');
    }
  }

  static Future<ExcavationChecklistModel> createExcavationChecklist({
    required int projectId,
    required String checklistNo,
    required String checklistDate,
    String? location,
    String? partWing,
    String? activityDate,
    String? jobNo,
    String? drawingNo,
    String? contractorName,
    String? excavationVolume,
    required List<Map<String, dynamic>> checklistItems,
    String? remarks,
  }) async {
    final url = Uri.parse(ApiConstants.excavationChecklistStore(projectId));
    developer.log(
        '[ApiService] createExcavationChecklist → POST $url projectId=$projectId',
        name: 'ApiService');

    final payload = <String, dynamic>{
      'checklist_no': checklistNo,
      'checklist_date': checklistDate,
      if (location != null && location.isNotEmpty) 'location': location,
      if (partWing != null && partWing.isNotEmpty) 'part_wing': partWing,
      if (activityDate != null && activityDate.isNotEmpty)
        'activity_date': activityDate,
      if (jobNo != null && jobNo.isNotEmpty) 'job_no': jobNo,
      if (drawingNo != null && drawingNo.isNotEmpty) 'drawing_no': drawingNo,
      if (contractorName != null && contractorName.isNotEmpty)
        'contractor_name': contractorName,
      if (excavationVolume != null && excavationVolume.isNotEmpty)
        'excavation_volume': excavationVolume,
      'checklist_items': checklistItems,
      if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
    };

    try {
      final response = await http
          .post(
            url,
            headers: await _excavationHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(ApiConstants.requestTimeout);

      final body = _decode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = body['checklist'];
        if (raw is Map<String, dynamic>) {
          return ExcavationChecklistModel.fromJson(raw);
        }
        throw ApiException('Unexpected response format from server.');
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
            'Failed to create excavation checklist (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Create excavation checklist error: $e');
    }
  }

  static Future<ExcavationChecklistModel> fetchExcavationChecklist(
      int projectId, int id) async {
    final url = Uri.parse(ApiConstants.excavationChecklistShow(projectId, id));
    developer.log('[ApiService] fetchExcavationChecklist → GET $url',
        name: 'ApiService');

    try {
      final response = await http
          .get(url, headers: await _excavationHeaders())
          .timeout(ApiConstants.requestTimeout);

      final body = _decode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = body['checklist'];
        if (raw is Map<String, dynamic>) {
          return ExcavationChecklistModel.fromJson(raw);
        }
        throw ApiException('Unexpected response format from server.');
      }

      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }

      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Checklist not found (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Fetch excavation checklist error: $e');
    }
  }

  static Future<ExcavationChecklistModel> updateExcavationChecklist({
    required int projectId,
    required int id,
    required String checklistNo,
    required String checklistDate,
    String? location,
    String? partWing,
    String? activityDate,
    String? jobNo,
    String? drawingNo,
    String? contractorName,
    String? excavationVolume,
    required List<Map<String, dynamic>> checklistItems,
    String? remarks,
  }) async {
    // Use the dedicated POST /update route to avoid LiteSpeed blocking PUT
    final url = Uri.parse(
        ApiConstants.excavationChecklistUpdatePost(projectId, id));
    developer.log(
        '[ApiService] updateExcavationChecklist → POST $url id=$id',
        name: 'ApiService');
 
    final payload = <String, dynamic>{
      '_method': 'POST',                         // ← method spoofing
      'checklist_no': checklistNo,
      'checklist_date': checklistDate,
      if (location != null && location.isNotEmpty) 'location': location,
      if (partWing != null && partWing.isNotEmpty) 'part_wing': partWing,
      if (activityDate != null && activityDate.isNotEmpty)
        'activity_date': activityDate,
      if (jobNo != null && jobNo.isNotEmpty) 'job_no': jobNo,
      if (drawingNo != null && drawingNo.isNotEmpty)
        'drawing_no': drawingNo,
      if (contractorName != null && contractorName.isNotEmpty)
        'contractor_name': contractorName,
      if (excavationVolume != null && excavationVolume.isNotEmpty)
        'excavation_volume': excavationVolume,
      'checklist_items': checklistItems,
      if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
    };
 
    try {
      final response = await http
          .post(
            url,
            headers: await _excavationHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(ApiConstants.requestTimeout);
 
      final body = _decode(response.body);
 
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = body['checklist'];
        if (raw is Map<String, dynamic>) {
          return ExcavationChecklistModel.fromJson(raw);
        }
        throw ApiException('Unexpected response format from server.');
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
            'Failed to update excavation checklist (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Update excavation checklist error: $e');
    }
  }

  static Future<void> deleteExcavationChecklist(int projectId, int id) async {
    final url = Uri.parse(ApiConstants.excavationChecklistDestroy(projectId, id));
    developer.log('[ApiService] deleteExcavationChecklist → POST $url id=$id',
        name: 'ApiService');

    try {
      // ← FIX: use POST + _method:DELETE (LiteSpeed blocks raw DELETE requests)
      final response = await http
          .post(
            url,
            headers: await _excavationHeaders(),
            body: jsonEncode({'_method': 'DELETE'}),
          )
          .timeout(ApiConstants.requestTimeout);

      final body = _decode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }

      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }

      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to delete excavation checklist (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Delete excavation checklist error: $e');
    }
  }

  static String excavationChecklistPrintUrl(int projectId, int id) =>
      ApiConstants.excavationChecklistPrint(projectId, id);

  static String excavationChecklistDownloadUrl(int projectId, int id) =>
      ApiConstants.excavationChecklistDownload(projectId, id);


     // ═══════════════════════════════════════════════════════════════════════════
  // SHUTTERING CHECKLIST — ApiService methods
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<Map<String, String>> _shutteringHeaders() async {
    final token = await AuthStorageService.getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // ── Fetch list ──────────────────────────────────────────────────────────────
  static Future<List<ShutteringChecklistModel>> fetchShutteringChecklists(
      int projectId) async {
    final url = Uri.parse(ApiConstants.shutteringChecklistIndex(projectId));
    developer.log('[ApiService] fetchShutteringChecklists → GET $url',
        name: 'ApiService');
    try {
      final response = await http
          .get(url, headers: await _shutteringHeaders())
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = (body is Map ? body['checklists'] : null);
        if (raw is List) {
          return raw
              .whereType<Map>()
              .map((e) =>
                  ShutteringChecklistModel.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
        return [];
      }
      if (response.statusCode == 401) throw ApiException('Session expired. Please login again.');
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to load shuttering checklists (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Shuttering checklist fetch error: $e');
    }
  }

  // ── Generate number ─────────────────────────────────────────────────────────
  static Future<String> generateShutteringChecklistNumber(int projectId) async {
    final url = Uri.parse(ApiConstants.shutteringChecklistCreate(projectId));
    developer.log('[ApiService] generateShutteringChecklistNumber → GET $url',
        name: 'ApiService');
    try {
      final response = await http
          .get(url, headers: await _shutteringHeaders())
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return body['checklist_no']?.toString() ?? '';
      }
      if (response.statusCode == 401) throw ApiException('Session expired. Please login again.');
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to generate checklist number (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Generate shuttering checklist number error: $e');
    }
  }

  // ── Create ──────────────────────────────────────────────────────────────────
  static Future<ShutteringChecklistModel> createShutteringChecklist({
    required int projectId,
    required String checklistNo,
    required String checklistDate,
    String? location,
    String? wing,
    String? castingDate,
    String? slabLevel,
    String? areaOfSlab,
    String? typeOfShuttering,
    String? contractor,
    required bool hfl,
    required bool level,
    required bool shuttering,
    required bool reinforcement,
    required bool electrical,
    required bool plumbing,
    required bool architect,
    String? rcc,
    String? electricalDetail,
    String? plumbingDetail,
    String? architectDetail,
    required List<Map<String, dynamic>> testResults,
    String? additionalObservations,
  }) async {
    final url = Uri.parse(ApiConstants.shutteringChecklistStore(projectId));
    developer.log('[ApiService] createShutteringChecklist → POST $url',
        name: 'ApiService');

    final payload = <String, dynamic>{
      'checklist_no': checklistNo,
      'checklist_date': checklistDate,
      if (location?.isNotEmpty == true) 'location': location,
      if (wing?.isNotEmpty == true) 'wing': wing,
      if (castingDate?.isNotEmpty == true) 'casting_date': castingDate,
      if (slabLevel?.isNotEmpty == true) 'slab_level': slabLevel,
      if (areaOfSlab?.isNotEmpty == true) 'area_of_slab': areaOfSlab,
      if (typeOfShuttering?.isNotEmpty == true) 'type_of_shuttering': typeOfShuttering,
      if (contractor?.isNotEmpty == true) 'contractor': contractor,
      'hfl': hfl,
      'level': level,
      'shuttering': shuttering,
      'reinforcement': reinforcement,
      'electrical': electrical,
      'plumbing': plumbing,
      'architect': architect,
      if (rcc?.isNotEmpty == true) 'rcc': rcc,
      if (electricalDetail?.isNotEmpty == true) 'electrical_detail': electricalDetail,
      if (plumbingDetail?.isNotEmpty == true) 'plumbing_detail': plumbingDetail,
      if (architectDetail?.isNotEmpty == true) 'architect_detail': architectDetail,
      'test_results': testResults,
      if (additionalObservations?.isNotEmpty == true)
        'additional_observations': additionalObservations,
    };

    try {
      final response = await http
          .post(url, headers: await _shutteringHeaders(), body: jsonEncode(payload))
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      developer.log('[ApiService] createShutteringChecklist ← ${response.statusCode}',
          name: 'ApiService');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = body['checklist'];
        if (raw is Map<String, dynamic>) return ShutteringChecklistModel.fromJson(raw);
        throw ApiException('Unexpected response format from server.');
      }
      if (response.statusCode == 401) throw ApiException('Session expired. Please login again.');
      if (response.statusCode == 422 && body is Map && body['errors'] is Map) {
        final errors = Map<String, dynamic>.from(body['errors'] as Map);
        final firstKey = errors.keys.firstOrNull;
        if (firstKey != null && errors[firstKey] is List && (errors[firstKey] as List).isNotEmpty) {
          throw ApiException((errors[firstKey] as List).first.toString());
        }
      }
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to create shuttering checklist (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Create shuttering checklist error: $e');
    }
  }

  // ── Fetch single ────────────────────────────────────────────────────────────
  static Future<ShutteringChecklistModel> fetchShutteringChecklist(
      int projectId, int id) async {
    final url = Uri.parse(ApiConstants.shutteringChecklistShow(projectId, id));
    try {
      final response = await http
          .get(url, headers: await _shutteringHeaders())
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = body['checklist'];
        if (raw is Map<String, dynamic>) return ShutteringChecklistModel.fromJson(raw);
        throw ApiException('Unexpected response format from server.');
      }
      if (response.statusCode == 401) throw ApiException('Session expired. Please login again.');
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Checklist not found (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Fetch shuttering checklist error: $e');
    }
  }

  // ── Update ──────────────────────────────────────────────────────────────────
  //
  // ROOT CAUSE OF 403 / blank form:
  //   The old code sent HTTP PUT.  Some Android HTTP stacks (OkHttp behind
  //   dart:io) either silently drop the request body on PUT, or the server
  //   sat behind a reverse proxy that rejected PUT with 403.
  //
  // FIX:
  //   Use POST to the dedicated /update sub-path instead of PUT.
  //   The backend controller's update() method handles both PUT /{id}
  //   and POST /{id}/update identically.
  // ──────────────────────────────────────────────────────────────────────────
  static Future<ShutteringChecklistModel> updateShutteringChecklist({
    required int projectId,
    required int id,
    required String checklistDate,
    String? location,
    String? wing,
    String? castingDate,
    String? slabLevel,
    String? areaOfSlab,
    String? typeOfShuttering,
    String? contractor,
    required bool hfl,
    required bool level,
    required bool shuttering,
    required bool reinforcement,
    required bool electrical,
    required bool plumbing,
    required bool architect,
    String? rcc,
    String? electricalDetail,
    String? plumbingDetail,
    String? architectDetail,
    required List<Map<String, dynamic>> testResults,
    String? additionalObservations,
  }) async {
    // Use the POST /update fallback — avoids Android PUT body-drop issues
    // and proxy-level 403s on PUT.
    final url = Uri.parse(
        ApiConstants.shutteringChecklistUpdatePost(projectId, id));
    developer.log('[ApiService] updateShutteringChecklist → POST $url',
        name: 'ApiService');

    final payload = <String, dynamic>{
      'checklist_date': checklistDate,
      if (location?.isNotEmpty == true) 'location': location,
      if (wing?.isNotEmpty == true) 'wing': wing,
      if (castingDate?.isNotEmpty == true) 'casting_date': castingDate,
      if (slabLevel?.isNotEmpty == true) 'slab_level': slabLevel,
      if (areaOfSlab?.isNotEmpty == true) 'area_of_slab': areaOfSlab,
      if (typeOfShuttering?.isNotEmpty == true) 'type_of_shuttering': typeOfShuttering,
      if (contractor?.isNotEmpty == true) 'contractor': contractor,
      'hfl': hfl,
      'level': level,
      'shuttering': shuttering,
      'reinforcement': reinforcement,
      'electrical': electrical,
      'plumbing': plumbing,
      'architect': architect,
      if (rcc?.isNotEmpty == true) 'rcc': rcc,
      if (electricalDetail?.isNotEmpty == true) 'electrical_detail': electricalDetail,
      if (plumbingDetail?.isNotEmpty == true) 'plumbing_detail': plumbingDetail,
      if (architectDetail?.isNotEmpty == true) 'architect_detail': architectDetail,
      'test_results': testResults,
      if (additionalObservations?.isNotEmpty == true)
        'additional_observations': additionalObservations,
    };

    try {
      final response = await http
          .post(url, headers: await _shutteringHeaders(), body: jsonEncode(payload))
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      developer.log('[ApiService] updateShutteringChecklist ← ${response.statusCode}',
          name: 'ApiService');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = body['checklist'];
        if (raw is Map<String, dynamic>) return ShutteringChecklistModel.fromJson(raw);
        throw ApiException('Unexpected response format from server.');
      }
      if (response.statusCode == 401) throw ApiException('Session expired. Please login again.');
      if (response.statusCode == 422 && body is Map && body['errors'] is Map) {
        final errors = Map<String, dynamic>.from(body['errors'] as Map);
        final firstKey = errors.keys.firstOrNull;
        if (firstKey != null && errors[firstKey] is List && (errors[firstKey] as List).isNotEmpty) {
          throw ApiException((errors[firstKey] as List).first.toString());
        }
      }
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to update shuttering checklist (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Update shuttering checklist error: $e');
    }
  }

  // ── Delete ──────────────────────────────────────────────────────────────────
  // FIX: POSTs to /{id}/delete — no collision with store (POST /{projectId}).
  static Future<void> deleteShutteringChecklist(int projectId, int id) async {
    final url =
        Uri.parse(ApiConstants.shutteringChecklistDestroy(projectId, id));
    developer.log('[ApiService] deleteShutteringChecklist → POST $url',
        name: 'ApiService');
    try {
      final response = await http
          .post(url, headers: await _shutteringHeaders(), body: jsonEncode({}))
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) return;
      if (response.statusCode == 401) throw ApiException('Session expired. Please login again.');
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to delete shuttering checklist (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Delete shuttering checklist error: $e');
    }
  }

  // ── Print / Download URL helpers ────────────────────────────────────────────
  // FIX: return WEB routes (no /api/mobile prefix).
  // Flutter calls launchUrl() with these; the browser opens the real HTML
  // print page or streams the PDF — not the JSON API endpoint.
  static String shutteringChecklistPrintUrl(int projectId, int id) =>
      ApiConstants.shutteringChecklistPrint(projectId, id);

  static String shutteringChecklistDownloadUrl(int projectId, int id) =>
      ApiConstants.shutteringChecklistDownload(projectId, id);

        // ═══════════════════════════════════════════════════════════════════════════
// CONCRETING CHECKLIST
// ═══════════════════════════════════════════════════════════════════════════

static Future<Map<String, String>> _concretingHeaders() async {
  final token = await AuthStorageService.getToken();
  return {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'X-Requested-With': 'XMLHttpRequest',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };
}

static Future<Map<String, String>> _concretingFileHeaders() async {
  final token = await AuthStorageService.getToken();
  return {
    'Accept': 'application/pdf',
    'X-Requested-With': 'XMLHttpRequest',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };
}

static Future<List<ConcretingChecklistModel>> fetchConcretingChecklists(
    int projectId) async {
  final url = Uri.parse(ApiConstants.concretingChecklistIndex(projectId));
  developer.log('[ApiService] fetchConcretingChecklists → GET $url',
      name: 'ApiService');

  try {
    final response = await http
        .get(url, headers: await _concretingHeaders())
        .timeout(ApiConstants.requestTimeout);

    final body = _decode(response.body);

    developer.log(
      '[ApiService] fetchConcretingChecklists ← ${response.statusCode}',
      name: 'ApiService',
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final raw = (body is Map ? body['checklists'] : null);
      if (raw is List) {
        final list = raw
            .whereType<Map>()
            .map((e) => ConcretingChecklistModel.fromJson(
                  Map<String, dynamic>.from(e),
                ))
            .toList();

        // Keep serial order stable: oldest first, newest below previous
        list.sort((a, b) => a.id.compareTo(b.id));
        return list;
      }
      return [];
    }

    if (response.statusCode == 401) {
      throw ApiException('Session expired. Please login again.');
    }

    throw ApiException(
      (body is Map ? body['message']?.toString() : null) ??
          'Failed to load concreting checklists (${response.statusCode})',
    );
  } on TimeoutException {
    throw ApiException('Request timed out. Please try again.');
  } catch (e) {
    if (e is ApiException) rethrow;
    throw ApiException('Concreting checklist fetch error: $e');
  }
}

static Future<String> generateConcretingChecklistNumber(int projectId) async {
  final url = Uri.parse(ApiConstants.concretingChecklistCreate(projectId));
  developer.log(
      '[ApiService] generateConcretingChecklistNumber → GET $url',
      name: 'ApiService');

  try {
    final response = await http
        .get(url, headers: await _concretingHeaders())
        .timeout(ApiConstants.requestTimeout);

    final body = _decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body['checklist_no']?.toString() ?? '';
    }

    if (response.statusCode == 401) {
      throw ApiException('Session expired. Please login again.');
    }

    throw ApiException(
      (body is Map ? body['message']?.toString() : null) ??
          'Failed to generate checklist number (${response.statusCode})',
    );
  } on TimeoutException {
    throw ApiException('Request timed out. Please try again.');
  } catch (e) {
    if (e is ApiException) rethrow;
    throw ApiException('Generate concreting checklist number error: $e');
  }
}

static Future<ConcretingChecklistModel> createConcretingChecklist({
  required int projectId,
  required String checklistNo,
  required String checklistDate,
  String? location,
  String? partWing,
  String? dateOfCasting,
  String? hflReference,
  String? shuttering,
  String? reinforcement,
  String? electrical,
  String? plumbing,
  String? general,
  String? rcc,
  String? rccDrawing,
  String? plumbingDrawing,
  String? architectDrawing,
  required List<Map<String, dynamic>> testResults,
  String? additionalObservations,
}) async {
  final url = Uri.parse(ApiConstants.concretingChecklistStore(projectId));

  developer.log(
      '[ApiService] createConcretingChecklist → POST $url projectId=$projectId',
      name: 'ApiService');

  final payload = <String, dynamic>{
    'checklist_no': checklistNo,
    'checklist_date': checklistDate,
    if (location != null && location.isNotEmpty) 'location': location,
    if (partWing != null && partWing.isNotEmpty) 'part_wing': partWing,
    if (dateOfCasting != null && dateOfCasting.isNotEmpty)
      'date_of_casting': dateOfCasting,
    if (hflReference != null && hflReference.isNotEmpty)
      'hfl_reference': hflReference,
    if (shuttering != null && shuttering.isNotEmpty) 'shuttering': shuttering,
    if (reinforcement != null && reinforcement.isNotEmpty)
      'reinforcement': reinforcement,
    if (electrical != null && electrical.isNotEmpty) 'electrical': electrical,
    if (plumbing != null && plumbing.isNotEmpty) 'plumbing': plumbing,
    if (general != null && general.isNotEmpty) 'general': general,
    if (rcc != null && rcc.isNotEmpty) 'rcc': rcc,
    if (rccDrawing != null && rccDrawing.isNotEmpty) 'rcc_drawing': rccDrawing,
    if (plumbingDrawing != null && plumbingDrawing.isNotEmpty)
      'plumbing_drawing': plumbingDrawing,
    if (architectDrawing != null && architectDrawing.isNotEmpty)
      'architect_drawing': architectDrawing,
    'test_results': testResults,
    if (additionalObservations != null && additionalObservations.isNotEmpty)
      'additional_observations': additionalObservations,
  };

  try {
    final response = await http
        .post(
          url,
          headers: await _concretingHeaders(),
          body: jsonEncode(payload),
        )
        .timeout(ApiConstants.requestTimeout);

    final body = _decode(response.body);

    developer.log(
      '[ApiService] createConcretingChecklist ← ${response.statusCode}: ${response.body}',
      name: 'ApiService',
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final raw = body['checklist'];
      if (raw is Map<String, dynamic>) {
        return ConcretingChecklistModel.fromJson(raw);
      }
      throw ApiException('Unexpected response format from server.');
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
          'Failed to create concreting checklist (${response.statusCode})',
    );
  } on TimeoutException {
    throw ApiException('Request timed out. Please try again.');
  } catch (e) {
    if (e is ApiException) rethrow;
    throw ApiException('Create concreting checklist error: $e');
  }
}

static Future<ConcretingChecklistModel> fetchConcretingChecklist(
    int projectId, int id) async {
  final url = Uri.parse(ApiConstants.concretingChecklistShow(projectId, id));
  developer.log('[ApiService] fetchConcretingChecklist → GET $url',
      name: 'ApiService');

  try {
    final response = await http
        .get(url, headers: await _concretingHeaders())
        .timeout(ApiConstants.requestTimeout);

    final body = _decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final raw = body['checklist'];
      if (raw is Map<String, dynamic>) {
        return ConcretingChecklistModel.fromJson(raw);
      }
      throw ApiException('Unexpected response format from server.');
    }

    if (response.statusCode == 401) {
      throw ApiException('Session expired. Please login again.');
    }

    throw ApiException(
      (body is Map ? body['message']?.toString() : null) ??
          'Checklist not found (${response.statusCode})',
    );
  } on TimeoutException {
    throw ApiException('Request timed out. Please try again.');
  } catch (e) {
    if (e is ApiException) rethrow;
    throw ApiException('Fetch concreting checklist error: $e');
  }
}

static Future<ConcretingChecklistModel> fetchConcretingChecklistForEdit(
    int projectId, int id) async {
  final url = Uri.parse(ApiConstants.concretingChecklistEdit(projectId, id));
  developer.log('[ApiService] fetchConcretingChecklistForEdit → GET $url',
      name: 'ApiService');

  try {
    final response = await http
        .get(url, headers: await _concretingHeaders())
        .timeout(ApiConstants.requestTimeout);

    final body = _decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final raw = body['checklist'];
      if (raw is Map<String, dynamic>) {
        return ConcretingChecklistModel.fromJson(raw);
      }
      throw ApiException('Unexpected response format from server.');
    }

    if (response.statusCode == 401) {
      throw ApiException('Session expired. Please login again.');
    }

    throw ApiException(
      (body is Map ? body['message']?.toString() : null) ??
          'Checklist not found (${response.statusCode})',
    );
  } on TimeoutException {
    throw ApiException('Request timed out. Please try again.');
  } catch (e) {
    if (e is ApiException) rethrow;
    throw ApiException('Fetch edit checklist error: $e');
  }
}

static Future<ConcretingChecklistModel> updateConcretingChecklist({
  required int projectId,
  required int id,
  required String checklistDate,
  String? location,
  String? partWing,
  String? dateOfCasting,
  String? hflReference,
  String? shuttering,
  String? reinforcement,
  String? electrical,
  String? plumbing,
  String? general,
  String? rcc,
  String? rccDrawing,
  String? plumbingDrawing,
  String? architectDrawing,
  required List<Map<String, dynamic>> testResults,
  String? additionalObservations,
}) async {
  final url = Uri.parse(ApiConstants.concretingChecklistUpdatePost(projectId, id));

  developer.log(
    '[ApiService] updateConcretingChecklist → POST $url id=$id',
    name: 'ApiService',
  );

  final payload = <String, dynamic>{
    '_method': 'POST',
    'checklist_date': checklistDate,
    if (location != null && location.isNotEmpty) 'location': location,
    if (partWing != null && partWing.isNotEmpty) 'part_wing': partWing,
    if (dateOfCasting != null && dateOfCasting.isNotEmpty)
      'date_of_casting': dateOfCasting,
    if (hflReference != null && hflReference.isNotEmpty)
      'hfl_reference': hflReference,
    if (shuttering != null && shuttering.isNotEmpty) 'shuttering': shuttering,
    if (reinforcement != null && reinforcement.isNotEmpty)
      'reinforcement': reinforcement,
    if (electrical != null && electrical.isNotEmpty) 'electrical': electrical,
    if (plumbing != null && plumbing.isNotEmpty) 'plumbing': plumbing,
    if (general != null && general.isNotEmpty) 'general': general,
    if (rcc != null && rcc.isNotEmpty) 'rcc': rcc,
    if (rccDrawing != null && rccDrawing.isNotEmpty) 'rcc_drawing': rccDrawing,
    if (plumbingDrawing != null && plumbingDrawing.isNotEmpty)
      'plumbing_drawing': plumbingDrawing,
    if (architectDrawing != null && architectDrawing.isNotEmpty)
      'architect_drawing': architectDrawing,
    'test_results': testResults,
    if (additionalObservations != null && additionalObservations.isNotEmpty)
      'additional_observations': additionalObservations,
  };

  try {
    final response = await http
        .post(
          url,
          headers: await _concretingHeaders(),
          body: jsonEncode(payload),
        )
        .timeout(ApiConstants.requestTimeout);

    final body = _decode(response.body);

    developer.log(
      '[ApiService] updateConcretingChecklist ← ${response.statusCode}: ${response.body}',
      name: 'ApiService',
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final raw = body['checklist'];
      if (raw is Map<String, dynamic>) {
        return ConcretingChecklistModel.fromJson(raw);
      }
      throw ApiException('Unexpected response format from server.');
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
          'Failed to update concreting checklist (${response.statusCode})',
    );
  } on TimeoutException {
    throw ApiException('Request timed out. Please try again.');
  } catch (e) {
    if (e is ApiException) rethrow;
    throw ApiException('Update concreting checklist error: $e');
  }
}

static Future<void> deleteConcretingChecklist(int projectId, int id) async {
  final url = Uri.parse(ApiConstants.concretingChecklistDestroyPost(projectId, id));

  developer.log(
      '[ApiService] deleteConcretingChecklist → POST $url id=$id',
      name: 'ApiService');

  try {
    final response = await http
        .post(
          url,
          headers: await _concretingHeaders(),
          body: jsonEncode({'_method': 'DELETE'}),
        )
        .timeout(ApiConstants.requestTimeout);

    final body = _decode(response.body);

    developer.log(
      '[ApiService] deleteConcretingChecklist ← ${response.statusCode}',
      name: 'ApiService',
    );

    if (response.statusCode >= 200 && response.statusCode < 300) return;

    if (response.statusCode == 401) {
      throw ApiException('Session expired. Please login again.');
    }

    throw ApiException(
      (body is Map ? body['message']?.toString() : null) ??
          'Failed to delete concreting checklist (${response.statusCode})',
    );
  } on TimeoutException {
    throw ApiException('Request timed out. Please try again.');
  } catch (e) {
    if (e is ApiException) rethrow;
    throw ApiException('Delete concreting checklist error: $e');
  }
}

static Future<Uint8List> fetchConcretingChecklistPdfBytes(
    int projectId, int id) async {
  final url = Uri.parse(ApiConstants.concretingChecklistDownload(projectId, id));

  developer.log(
    '[ApiService] fetchConcretingChecklistPdfBytes → GET $url',
    name: 'ApiService',
  );

  try {
    final response = await http
        .get(url, headers: await _concretingFileHeaders())
        .timeout(const Duration(seconds: 60));

    developer.log(
      '[ApiService] fetchConcretingChecklistPdfBytes ← ${response.statusCode}',
      name: 'ApiService',
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }

    if (response.statusCode == 401) {
      throw ApiException('Session expired. Please login again.');
    }

    final text = response.body.isNotEmpty ? response.body : '';
    throw ApiException(
      text.isNotEmpty
          ? 'Failed to load PDF (${response.statusCode})'
          : 'Failed to load PDF (${response.statusCode})',
    );
  } on TimeoutException {
    throw ApiException('PDF request timed out. Please try again.');
  } catch (e) {
    if (e is ApiException) rethrow;
    throw ApiException('Fetch concreting checklist PDF error: $e');
  }
}

static String concretingChecklistPrintUrl(int projectId, int id) =>
    ApiConstants.concretingChecklistPrint(projectId, id);

static String concretingChecklistDownloadUrl(int projectId, int id) =>
    ApiConstants.concretingChecklistDownload(projectId, id);


       // ─────────────────────────────────────────────────────────────────────────────
// SITE INSTRUCTION — FIXED (403 on Edit resolved by using POST fallback update)
// ─────────────────────────────────────────────────────────────────────────────

static Future<Map<String, String>> _siteInstructionHeaders() async {
  final token = await AuthStorageService.getToken();
  return {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'X-Requested-With': 'XMLHttpRequest',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };
}

/// For PDF endpoints
static Future<Map<String, String>> _siteInstructionFileHeaders() async {
  final token = await AuthStorageService.getToken();
  return {
    'Accept': 'application/pdf',
    'X-Requested-With': 'XMLHttpRequest',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };
}

/// Fetch all site instructions for a project.
static Future<List<SiteInstructionModel>> fetchSiteInstructions(
    int projectId) async {
  final url = Uri.parse(ApiConstants.siteInstructionIndex(projectId));
  developer.log('[ApiService] fetchSiteInstructions → GET $url',
      name: 'ApiService');

  try {
    final response = await http
        .get(url, headers: await _siteInstructionHeaders())
        .timeout(ApiConstants.requestTimeout);

    final body = _decode(response.body);
    developer.log(
      '[ApiService] fetchSiteInstructions ← ${response.statusCode}',
      name: 'ApiService',
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final raw = (body is Map ? body['instructions'] : null);
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((e) => SiteInstructionModel.fromJson(
                  Map<String, dynamic>.from(e),
                ))
            .toList();
      }
      return [];
    }

    if (response.statusCode == 401) {
      throw ApiException('Session expired. Please login again.');
    }

    throw ApiException(
      (body is Map ? body['message']?.toString() : null) ??
          'Failed to load site instructions (${response.statusCode})',
    );
  } on TimeoutException {
    throw ApiException('Request timed out. Please try again.');
  } catch (e) {
    if (e is ApiException) rethrow;
    throw ApiException('Site instruction fetch error: $e');
  }
}

/// Generate a unique instruction number for a project.
static Future<String> generateSiteInstructionNumber(int projectId) async {
  final url = Uri.parse(ApiConstants.siteInstructionCreate(projectId));
  developer.log(
    '[ApiService] generateSiteInstructionNumber → GET $url',
    name: 'ApiService',
  );

  try {
    final response = await http
        .get(url, headers: await _siteInstructionHeaders())
        .timeout(ApiConstants.requestTimeout);

    final body = _decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body['instruction_no']?.toString() ?? '';
    }

    if (response.statusCode == 401) {
      throw ApiException('Session expired. Please login again.');
    }

    throw ApiException(
      (body is Map ? body['message']?.toString() : null) ??
          'Failed to generate instruction number (${response.statusCode})',
    );
  } on TimeoutException {
    throw ApiException('Request timed out. Please try again.');
  } catch (e) {
    if (e is ApiException) rethrow;
    throw ApiException('Generate site instruction number error: $e');
  }
}

/// Create a new site instruction.
static Future<SiteInstructionModel> createSiteInstruction({
  required int projectId,
  required String instructionNo,
  required String date,
  String? projectNumber,
  String? issuedBy,
  String? issuedTo,
  String? reference,
  String? instructions,
  String? actionTaken,
  String? contractorAcceptanceDate,
  String? authorityAcceptanceDate,
}) async {
  final url = Uri.parse(ApiConstants.siteInstructionStore(projectId));
  developer.log(
    '[ApiService] createSiteInstruction → POST $url projectId=$projectId',
    name: 'ApiService',
  );

  final payload = <String, dynamic>{
    'instruction_no': instructionNo,
    'date': date,
    if (projectNumber != null && projectNumber.isNotEmpty)
      'project_number': projectNumber,
    if (issuedBy != null && issuedBy.isNotEmpty) 'issued_by': issuedBy,
    if (issuedTo != null && issuedTo.isNotEmpty) 'issued_to': issuedTo,
    if (reference != null && reference.isNotEmpty) 'reference': reference,
    if (instructions != null && instructions.isNotEmpty)
      'instructions': instructions,
    if (actionTaken != null && actionTaken.isNotEmpty)
      'action_taken': actionTaken,
    if (contractorAcceptanceDate != null &&
        contractorAcceptanceDate.isNotEmpty)
      'contractor_acceptance_date': contractorAcceptanceDate,
    if (authorityAcceptanceDate != null && authorityAcceptanceDate.isNotEmpty)
      'authority_acceptance_date': authorityAcceptanceDate,
  };

  try {
    final response = await http
        .post(
          url,
          headers: await _siteInstructionHeaders(),
          body: jsonEncode(payload),
        )
        .timeout(ApiConstants.requestTimeout);

    final body = _decode(response.body);
    developer.log(
      '[ApiService] createSiteInstruction ← ${response.statusCode}: ${response.body}',
      name: 'ApiService',
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final raw = body['instruction'];
      if (raw is Map<String, dynamic>) {
        return SiteInstructionModel.fromJson(raw);
      }
      throw ApiException('Unexpected response format from server.');
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
          'Failed to create site instruction (${response.statusCode})',
    );
  } on TimeoutException {
    throw ApiException('Request timed out. Please try again.');
  } catch (e) {
    if (e is ApiException) rethrow;
    throw ApiException('Create site instruction error: $e');
  }
}

/// Fetch a single site instruction.
/// Uses the /edit endpoint to avoid ambiguous route conflicts on Android.
static Future<SiteInstructionModel> fetchSiteInstruction(
    int projectId, int id) async {
  // ✅ FIX: Use the dedicated /edit endpoint instead of show.
  // On Android, GET /{projectId}/{id} can be blocked by reverse proxies
  // (LiteSpeed in this case) as a 403 when the auth token is stripped.
  // The /edit route is unambiguous and avoids route-pattern conflicts.
  final url = Uri.parse(ApiConstants.siteInstructionEdit(projectId, id));
  developer.log('[ApiService] fetchSiteInstruction → GET $url',
      name: 'ApiService');

  try {
    final response = await http
        .get(url, headers: await _siteInstructionHeaders())
        .timeout(ApiConstants.requestTimeout);

    final body = _decode(response.body);

    developer.log(
      '[ApiService] fetchSiteInstruction ← ${response.statusCode}',
      name: 'ApiService',
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final raw = body['instruction'];
      if (raw is Map<String, dynamic>) {
        return SiteInstructionModel.fromJson(raw);
      }
      throw ApiException('Unexpected response format from server.');
    }

    if (response.statusCode == 401) {
      throw ApiException('Session expired. Please login again.');
    }

    if (response.statusCode == 403) {
      throw ApiException(
          'Access denied. Please check your login session and try again.');
    }

    throw ApiException(
      (body is Map ? body['message']?.toString() : null) ??
          'Site instruction not found (${response.statusCode})',
    );
  } on TimeoutException {
    throw ApiException('Request timed out. Please try again.');
  } catch (e) {
    if (e is ApiException) rethrow;
    throw ApiException('Fetch site instruction error: $e');
  }
}

/// Update an existing site instruction.
/// ✅ FIX: Uses POST fallback route /{projectId}/{id}/update instead of PUT.
/// Android HTTP clients and some reverse proxies (e.g. LiteSpeed) block or
/// mangle PUT requests, returning 403 Forbidden. The POST fallback route is
/// already registered in Laravel and is functionally identical.
static Future<SiteInstructionModel> updateSiteInstruction({
  required int projectId,
  required int id,
  required String date,
  String? projectNumber,
  String? issuedBy,
  String? issuedTo,
  String? reference,
  String? instructions,
  String? actionTaken,
  String? contractorAcceptanceDate,
  String? authorityAcceptanceDate,
}) async {
  // Use POST /update fallback — avoids 403 from PUT being blocked by LiteSpeed
  final url =
      Uri.parse(ApiConstants.siteInstructionUpdatePost(projectId, id));
  developer.log(
    '[ApiService] updateSiteInstruction → POST $url id=$id (POST fallback)',
    name: 'ApiService',
  );

  final payload = <String, dynamic>{
    'date': date,
    if (projectNumber != null && projectNumber.isNotEmpty)
      'project_number': projectNumber,
    if (issuedBy != null && issuedBy.isNotEmpty) 'issued_by': issuedBy,
    if (issuedTo != null && issuedTo.isNotEmpty) 'issued_to': issuedTo,
    if (reference != null && reference.isNotEmpty) 'reference': reference,
    if (instructions != null && instructions.isNotEmpty)
      'instructions': instructions,
    if (actionTaken != null && actionTaken.isNotEmpty)
      'action_taken': actionTaken,
    if (contractorAcceptanceDate != null &&
        contractorAcceptanceDate.isNotEmpty)
      'contractor_acceptance_date': contractorAcceptanceDate,
    if (authorityAcceptanceDate != null && authorityAcceptanceDate.isNotEmpty)
      'authority_acceptance_date': authorityAcceptanceDate,
  };

  try {
    final response = await http
        .post(
          url,
          headers: await _siteInstructionHeaders(),
          body: jsonEncode(payload),
        )
        .timeout(ApiConstants.requestTimeout);

    final body = _decode(response.body);
    developer.log(
      '[ApiService] updateSiteInstruction ← ${response.statusCode}: ${response.body}',
      name: 'ApiService',
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final raw = body['instruction'];
      if (raw is Map<String, dynamic>) {
        return SiteInstructionModel.fromJson(raw);
      }
      throw ApiException('Unexpected response format from server.');
    }

    if (response.statusCode == 401) {
      throw ApiException('Session expired. Please login again.');
    }

    if (response.statusCode == 403) {
      throw ApiException(
          'Access denied. Please check your login session and try again.');
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
          'Failed to update site instruction (${response.statusCode})',
    );
  } on TimeoutException {
    throw ApiException('Request timed out. Please try again.');
  } catch (e) {
    if (e is ApiException) rethrow;
    throw ApiException('Update site instruction error: $e');
  }
}

/// Delete a site instruction.
/// Uses dedicated POST delete path because some Android clients are unreliable with DELETE.
static Future<void> deleteSiteInstruction(int projectId, int id) async {
  final url = Uri.parse(ApiConstants.siteInstructionDeletePost(projectId, id));
  developer.log(
    '[ApiService] deleteSiteInstruction → POST $url id=$id',
    name: 'ApiService',
  );

  try {
    final response = await http
        .post(
          url,
          headers: await _siteInstructionHeaders(),
        )
        .timeout(ApiConstants.requestTimeout);

    final body = _decode(response.body);
    developer.log(
      '[ApiService] deleteSiteInstruction ← ${response.statusCode}',
      name: 'ApiService',
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    if (response.statusCode == 401) {
      throw ApiException('Session expired. Please login again.');
    }

    throw ApiException(
      (body is Map ? body['message']?.toString() : null) ??
          'Failed to delete site instruction (${response.statusCode})',
    );
  } on TimeoutException {
    throw ApiException('Request timed out. Please try again.');
  } catch (e) {
    if (e is ApiException) rethrow;
    throw ApiException('Delete site instruction error: $e');
  }
}

/// Fetch print PDF bytes for in-app printing.
static Future<Uint8List> printSiteInstructionPdf(
  int projectId,
  int id,
) async {
  final url = Uri.parse(ApiConstants.siteInstructionPrint(projectId, id));
  developer.log(
    '[ApiService] printSiteInstructionPdf → GET $url',
    name: 'ApiService',
  );

  try {
    final response = await http
        .get(url, headers: await _siteInstructionFileHeaders())
        .timeout(ApiConstants.requestTimeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }

    if (response.statusCode == 401) {
      throw ApiException('Session expired. Please login again.');
    }

    final body = response.body.isNotEmpty ? _decode(response.body) : null;
    throw ApiException(
      (body is Map ? body['message']?.toString() : null) ??
          'Failed to prepare print PDF (${response.statusCode})',
    );
  } on TimeoutException {
    throw ApiException('Request timed out. Please try again.');
  } catch (e) {
    if (e is ApiException) rethrow;
    throw ApiException('Print PDF error: $e');
  }
}

/// Fetch download PDF bytes for in-app download/share.
static Future<Uint8List> downloadSiteInstructionPdf(
  int projectId,
  int id,
) async {
  final url = Uri.parse(ApiConstants.siteInstructionDownload(projectId, id));
  developer.log(
    '[ApiService] downloadSiteInstructionPdf → GET $url',
    name: 'ApiService',
  );

  try {
    final response = await http
        .get(url, headers: await _siteInstructionFileHeaders())
        .timeout(ApiConstants.requestTimeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }

    if (response.statusCode == 401) {
      throw ApiException('Session expired. Please login again.');
    }

    final body = response.body.isNotEmpty ? _decode(response.body) : null;
    throw ApiException(
      (body is Map ? body['message']?.toString() : null) ??
          'Failed to download PDF (${response.statusCode})',
    );
  } on TimeoutException {
    throw ApiException('Request timed out. Please try again.');
  } catch (e) {
    if (e is ApiException) rethrow;
    throw ApiException('Download PDF error: $e');
  }
}

/// Returns the web print URL for a site instruction (opens in browser).
static String siteInstructionPrintUrl(int projectId, int id) =>
    ApiConstants.siteInstructionPrint(projectId, id);

/// Returns the PDF download URL for a site instruction.
static String siteInstructionDownloadUrl(int projectId, int id) =>
    ApiConstants.siteInstructionDownload(projectId, id);

      // ═══════════════════════════════════════════════════════════════════════════
// REINFORCEMENT CHECKLIST  — add these methods inside the ApiService class
// ═══════════════════════════════════════════════════════════════════════════

  static Future<Map<String, String>> _reinforcementHeaders() async {
    final token = await AuthStorageService.getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<List<ReinforcementChecklistModel>> fetchReinforcementChecklists(
      int projectId) async {
    final url =
        Uri.parse(ApiConstants.reinforcementChecklistIndex(projectId));
    developer.log('[ApiService] fetchReinforcementChecklists → GET $url',
        name: 'ApiService');
    try {
      final response = await http
          .get(url, headers: await _reinforcementHeaders())
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      developer.log(
          '[ApiService] fetchReinforcementChecklists ← ${response.statusCode}',
          name: 'ApiService');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = (body is Map ? body['checklists'] : null);
        if (raw is List) {
          return raw
              .whereType<Map>()
              .map((e) => ReinforcementChecklistModel.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList();
        }
        return [];
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to load reinforcement checklists (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Reinforcement checklist fetch error: $e');
    }
  }

  static Future<String> generateReinforcementChecklistNumber(
      int projectId) async {
    final url =
        Uri.parse(ApiConstants.reinforcementChecklistCreate(projectId));
    developer.log(
        '[ApiService] generateReinforcementChecklistNumber → GET $url',
        name: 'ApiService');
    try {
      final response = await http
          .get(url, headers: await _reinforcementHeaders())
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return body['checklist_no']?.toString() ?? '';
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to generate checklist number (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
          'Generate reinforcement checklist number error: $e');
    }
  }

  static Future<ReinforcementChecklistModel> createReinforcementChecklist({
    required int projectId,
    required String checklistNo,
    required String dateOfChecking,
    String? projectName,
    String? location,
    String? partWing,
    String? dateOfCasting,
    String? hflReference,
    String? level,
    String? shuttering,
    String? reinforcement,
    String? electrical,
    String? plumbing,
    String? general,
    String? rccDrawing,
    String? electricalDrawing,
    String? plumbingDrawing,
    String? architectDrawing,
    required List<Map<String, dynamic>> checklistItems,
    String? additionalObservations,
  }) async {
    final url =
        Uri.parse(ApiConstants.reinforcementChecklistStore(projectId));
    developer.log(
        '[ApiService] createReinforcementChecklist → POST $url projectId=$projectId',
        name: 'ApiService');

    final payload = <String, dynamic>{
      'checklist_no': checklistNo,
      'date_of_checking': dateOfChecking,
      if (projectName != null && projectName.isNotEmpty)
        'project_name': projectName,
      if (location != null && location.isNotEmpty) 'location': location,
      if (partWing != null && partWing.isNotEmpty) 'part_wing': partWing,
      if (dateOfCasting != null && dateOfCasting.isNotEmpty)
        'date_of_casting': dateOfCasting,
      if (hflReference != null && hflReference.isNotEmpty)
        'hfl_reference': hflReference,
      if (level != null && level.isNotEmpty) 'level': level,
      if (shuttering != null && shuttering.isNotEmpty)
        'shuttering': shuttering,
      if (reinforcement != null && reinforcement.isNotEmpty)
        'reinforcement': reinforcement,
      if (electrical != null && electrical.isNotEmpty)
        'electrical': electrical,
      if (plumbing != null && plumbing.isNotEmpty) 'plumbing': plumbing,
      if (general != null && general.isNotEmpty) 'general': general,
      if (rccDrawing != null && rccDrawing.isNotEmpty)
        'rcc_drawing': rccDrawing,
      if (electricalDrawing != null && electricalDrawing.isNotEmpty)
        'electrical_drawing': electricalDrawing,
      if (plumbingDrawing != null && plumbingDrawing.isNotEmpty)
        'plumbing_drawing': plumbingDrawing,
      if (architectDrawing != null && architectDrawing.isNotEmpty)
        'architect_drawing': architectDrawing,
      'checklist_items': checklistItems,
      if (additionalObservations != null &&
          additionalObservations.isNotEmpty)
        'additional_observations': additionalObservations,
    };

    try {
      final response = await http
          .post(
            url,
            headers: await _reinforcementHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      developer.log(
          '[ApiService] createReinforcementChecklist ← ${response.statusCode}: ${response.body}',
          name: 'ApiService');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = body['checklist'];
        if (raw is Map<String, dynamic>) {
          return ReinforcementChecklistModel.fromJson(raw);
        }
        throw ApiException('Unexpected response format from server.');
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      if (response.statusCode == 422 && body is Map && body['errors'] is Map) {
        final errors =
            Map<String, dynamic>.from(body['errors'] as Map);
        final firstKey =
            errors.keys.isNotEmpty ? errors.keys.first : null;
        if (firstKey != null &&
            errors[firstKey] is List &&
            (errors[firstKey] as List).isNotEmpty) {
          throw ApiException(
              (errors[firstKey] as List).first.toString());
        }
      }
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to create reinforcement checklist (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Create reinforcement checklist error: $e');
    }
  }

  static Future<ReinforcementChecklistModel> fetchReinforcementChecklist(
      int projectId, int id) async {
    final url =
        Uri.parse(ApiConstants.reinforcementChecklistShow(projectId, id));
    developer.log('[ApiService] fetchReinforcementChecklist → GET $url',
        name: 'ApiService');
    try {
      final response = await http
          .get(url, headers: await _reinforcementHeaders())
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = body['checklist'];
        if (raw is Map<String, dynamic>) {
          return ReinforcementChecklistModel.fromJson(raw);
        }
        throw ApiException('Unexpected response format from server.');
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Checklist not found (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Fetch reinforcement checklist error: $e');
    }
  }

  static Future<ReinforcementChecklistModel> updateReinforcementChecklist({
    required int projectId,
    required int id,
    required String dateOfChecking,
    String? projectName,
    String? location,
    String? partWing,
    String? dateOfCasting,
    String? hflReference,
    String? level,
    String? shuttering,
    String? reinforcement,
    String? electrical,
    String? plumbing,
    String? general,
    String? rccDrawing,
    String? electricalDrawing,
    String? plumbingDrawing,
    String? architectDrawing,
    required List<Map<String, dynamic>> checklistItems,
    String? additionalObservations,
  }) async {
    final url =
        Uri.parse(ApiConstants.reinforcementChecklistUpdate(projectId, id));
    developer.log(
        '[ApiService] updateReinforcementChecklist → PUT $url id=$id',
        name: 'ApiService');

    final payload = <String, dynamic>{
      'date_of_checking': dateOfChecking,
      if (projectName != null && projectName.isNotEmpty)
        'project_name': projectName,
      if (location != null && location.isNotEmpty) 'location': location,
      if (partWing != null && partWing.isNotEmpty) 'part_wing': partWing,
      if (dateOfCasting != null && dateOfCasting.isNotEmpty)
        'date_of_casting': dateOfCasting,
      if (hflReference != null && hflReference.isNotEmpty)
        'hfl_reference': hflReference,
      if (level != null && level.isNotEmpty) 'level': level,
      if (shuttering != null && shuttering.isNotEmpty)
        'shuttering': shuttering,
      if (reinforcement != null && reinforcement.isNotEmpty)
        'reinforcement': reinforcement,
      if (electrical != null && electrical.isNotEmpty)
        'electrical': electrical,
      if (plumbing != null && plumbing.isNotEmpty) 'plumbing': plumbing,
      if (general != null && general.isNotEmpty) 'general': general,
      if (rccDrawing != null && rccDrawing.isNotEmpty)
        'rcc_drawing': rccDrawing,
      if (electricalDrawing != null && electricalDrawing.isNotEmpty)
        'electrical_drawing': electricalDrawing,
      if (plumbingDrawing != null && plumbingDrawing.isNotEmpty)
        'plumbing_drawing': plumbingDrawing,
      if (architectDrawing != null && architectDrawing.isNotEmpty)
        'architect_drawing': architectDrawing,
      'checklist_items': checklistItems,
      if (additionalObservations != null &&
          additionalObservations.isNotEmpty)
        'additional_observations': additionalObservations,
    };

    try {
      final response = await http
          .put(
            url,
            headers: await _reinforcementHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      developer.log(
          '[ApiService] updateReinforcementChecklist ← ${response.statusCode}: ${response.body}',
          name: 'ApiService');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = body['checklist'];
        if (raw is Map<String, dynamic>) {
          return ReinforcementChecklistModel.fromJson(raw);
        }
        throw ApiException('Unexpected response format from server.');
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      if (response.statusCode == 422 && body is Map && body['errors'] is Map) {
        final errors =
            Map<String, dynamic>.from(body['errors'] as Map);
        final firstKey =
            errors.keys.isNotEmpty ? errors.keys.first : null;
        if (firstKey != null &&
            errors[firstKey] is List &&
            (errors[firstKey] as List).isNotEmpty) {
          throw ApiException(
              (errors[firstKey] as List).first.toString());
        }
      }
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to update reinforcement checklist (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Update reinforcement checklist error: $e');
    }
  }

  static Future<void> deleteReinforcementChecklist(
      int projectId, int id) async {
    final url =
        Uri.parse(ApiConstants.reinforcementChecklistDestroy(projectId, id));
    developer.log(
        '[ApiService] deleteReinforcementChecklist → POST $url id=$id',
        name: 'ApiService');
    try {
      final response = await http
          .post(
            url,
            headers: await _reinforcementHeaders(),
            body: jsonEncode({'_method': 'DELETE'}),
          )
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      developer.log(
          '[ApiService] deleteReinforcementChecklist ← ${response.statusCode}',
          name: 'ApiService');
      if (response.statusCode >= 200 && response.statusCode < 300) return;
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to delete reinforcement checklist (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Delete reinforcement checklist error: $e');
    }
  }

  static String reinforcementChecklistPrintUrl(int projectId, int id) =>
      ApiConstants.reinforcementChecklistPrint(projectId, id);

  static String reinforcementChecklistDownloadUrl(int projectId, int id) =>
      ApiConstants.reinforcementChecklistDownload(projectId, id);


     // ═══════════════════════════════════════════════════════════════════════════
  // CONCRETE CUBE RESULTS
  // ═══════════════════════════════════════════════════════════════════════════
 
  static Future<Map<String, String>> _concreteCubeHeaders() async {
    final token = await AuthStorageService.getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }
 
  /// Fetch all concrete cube results for a project.
  static Future<List<ConcreteCubeResultModel>> fetchConcreteCubeResults(
      int projectId) async {
    final url =
        Uri.parse(ApiConstants.concreteCubeResultsIndex(projectId));
    developer.log('[ApiService] fetchConcreteCubeResults → GET $url',
        name: 'ApiService');
    try {
      final response = await http
          .get(url, headers: await _concreteCubeHeaders())
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      developer.log(
          '[ApiService] fetchConcreteCubeResults ← ${response.statusCode}',
          name: 'ApiService');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = (body is Map ? body['results'] : null);
        if (raw is List) {
          return raw
              .whereType<Map>()
              .map((e) => ConcreteCubeResultModel.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList();
        }
        return [];
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to load concrete cube results (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Concrete cube results fetch error: $e');
    }
  }
 
  /// Create a new concrete cube result.
  static Future<ConcreteCubeResultModel> createConcreteCubeResult({
    required int projectId,
    required List<Map<String, dynamic>> testData,
    double? avg7Days,
    double? avg28Days,
    String? checkedBy,
    String? qaBy,
    String? preparedBy,
  }) async {
    final url = Uri.parse(ApiConstants.concreteCubeResultsStore(projectId));
    developer.log(
        '[ApiService] createConcreteCubeResult → POST $url projectId=$projectId',
        name: 'ApiService');
 
    final payload = <String, dynamic>{
      'test_data': testData,
      if (avg7Days != null) 'avg_7_days': avg7Days,
      if (avg28Days != null) 'avg_28_days': avg28Days,
      if (checkedBy != null && checkedBy.isNotEmpty) 'checked_by': checkedBy,
      if (qaBy != null && qaBy.isNotEmpty) 'qa_by': qaBy,
      if (preparedBy != null && preparedBy.isNotEmpty)
        'prepared_by': preparedBy,
    };
 
    try {
      final response = await http
          .post(
            url,
            headers: await _concreteCubeHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      developer.log(
          '[ApiService] createConcreteCubeResult ← ${response.statusCode}: ${response.body}',
          name: 'ApiService');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = body['result'];
        if (raw is Map<String, dynamic>) {
          return ConcreteCubeResultModel.fromJson(raw);
        }
        throw ApiException('Unexpected response format from server.');
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
            'Failed to create concrete cube result (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Create concrete cube result error: $e');
    }
  }
 
  /// Fetch a single concrete cube result by id.
  static Future<ConcreteCubeResultModel> fetchConcreteCubeResult(
      int projectId, int id) async {
    final url = Uri.parse(ApiConstants.concreteCubeResultsShow(projectId, id));
    developer.log('[ApiService] fetchConcreteCubeResult → GET $url',
        name: 'ApiService');
    try {
      final response = await http
          .get(url, headers: await _concreteCubeHeaders())
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = body['result'];
        if (raw is Map<String, dynamic>) {
          return ConcreteCubeResultModel.fromJson(raw);
        }
        throw ApiException('Unexpected response format from server.');
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Result not found (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Fetch concrete cube result error: $e');
    }
  }
 
  /// Update an existing concrete cube result.
  /// Update an existing concrete cube result.
static Future<ConcreteCubeResultModel> updateConcreteCubeResult({
  required int projectId,
  required int id,
  required List<Map<String, dynamic>> testData,
  double? avg7Days,
  double? avg28Days,
  String? checkedBy,
  String? qaBy,
  String? preparedBy,
}) async {
  final url =
      Uri.parse(ApiConstants.concreteCubeResultsUpdate(projectId, id));
  developer.log(
      '[ApiService] updateConcreteCubeResult → POST $url id=$id',
      name: 'ApiService');

  final payload = <String, dynamic>{
    'test_data': testData,
    if (avg7Days != null) 'avg_7_days': avg7Days,
    if (avg28Days != null) 'avg_28_days': avg28Days,
    if (checkedBy != null && checkedBy.isNotEmpty) 'checked_by': checkedBy,
    if (qaBy != null && qaBy.isNotEmpty) 'qa_by': qaBy,
    if (preparedBy != null && preparedBy.isNotEmpty)
      'prepared_by': preparedBy,
  };

  try {
    final response = await http
        .post(
          url,
          headers: await _concreteCubeHeaders(),
          body: jsonEncode(payload),
        )
        .timeout(ApiConstants.requestTimeout);

    final body = _decode(response.body);
    developer.log(
        '[ApiService] updateConcreteCubeResult ← ${response.statusCode}: ${response.body}',
        name: 'ApiService');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final raw = body['result'];
      if (raw is Map<String, dynamic>) {
        return ConcreteCubeResultModel.fromJson(raw);
      }
      throw ApiException('Unexpected response format from server.');
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
          'Failed to update concrete cube result (${response.statusCode})',
    );
  } on TimeoutException {
    throw ApiException('Request timed out. Please try again.');
  } catch (e) {
    if (e is ApiException) rethrow;
    throw ApiException('Update concrete cube result error: $e');
  }
}

/// Delete a concrete cube result.
static Future<void> deleteConcreteCubeResult(int projectId, int id) async {
  final url = Uri.parse(
    '${ApiConstants.concreteCubeResultsDestroy(projectId, id)}/delete',
  );

  developer.log(
      '[ApiService] deleteConcreteCubeResult → POST $url id=$id',
      name: 'ApiService');

  try {
    final response = await http
        .post(
          url,
          headers: await _concreteCubeHeaders(),
        )
        .timeout(ApiConstants.requestTimeout);

    final body = _decode(response.body);
    developer.log(
        '[ApiService] deleteConcreteCubeResult ← ${response.statusCode}',
        name: 'ApiService');

    if (response.statusCode >= 200 && response.statusCode < 300) return;

    if (response.statusCode == 401) {
      throw ApiException('Session expired. Please login again.');
    }

    throw ApiException(
      (body is Map ? body['message']?.toString() : null) ??
          'Failed to delete concrete cube result (${response.statusCode})',
    );
  } on TimeoutException {
    throw ApiException('Request timed out. Please try again.');
  } catch (e) {
    if (e is ApiException) rethrow;
    throw ApiException('Delete concrete cube result error: $e');
  }
}
 
  /// Returns the web print URL for a concrete cube result.
  static String concreteCubeResultPrintUrl(int projectId, int id) =>
      ApiConstants.concreteCubeResultsPrint(projectId, id);
 
  /// Returns the PDF download URL for a concrete cube result.
  static String concreteCubeResultDownloadUrl(int projectId, int id) =>
      ApiConstants.concreteCubeResultsDownload(projectId, id);

      // ═══════════════════════════════════════════════════════════════════════════
// APPROVAL FORM — Add these methods inside the ApiService class

  static Future<Map<String, String>> _approvalFormHeaders() async {
    final token = await AuthStorageService.getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }
 
  /// Fetch all approval forms for a project.
  static Future<List<ApprovalFormModel>> fetchApprovalForms(
      int projectId) async {
    final url = Uri.parse(ApiConstants.approvalFormIndex(projectId));
    developer.log('[ApiService] fetchApprovalForms → GET $url',
        name: 'ApiService');
    try {
      final response = await http
          .get(url, headers: await _approvalFormHeaders())
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      developer.log(
          '[ApiService] fetchApprovalForms ← ${response.statusCode}',
          name: 'ApiService');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = (body is Map ? body['approvalForms'] : null);
        if (raw is List) {
          return raw
              .whereType<Map>()
              .map((e) =>
                  ApprovalFormModel.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
        return [];
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to load approval forms (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Approval form fetch error: $e');
    }
  }
 
  /// Generate a unique form number for a project.
  static Future<String> generateApprovalFormNumber(int projectId) async {
    final url = Uri.parse(ApiConstants.approvalFormCreate(projectId));
    developer.log('[ApiService] generateApprovalFormNumber → GET $url',
        name: 'ApiService');
    try {
      final response = await http
          .get(url, headers: await _approvalFormHeaders())
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return body['form_no']?.toString() ?? '';
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to generate form number (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Generate approval form number error: $e');
    }
  }
 
  /// Create a new approval form.
  static Future<ApprovalFormModel> createApprovalForm({
    required int projectId,
    required String formNo,
    String? dateOfSubmission,
    String? contractor,
    String? contractorSubmittalNumber,
    String? tradePackage,
    String? sampleMaterial,
    String? sampleNo,
    String? sampleSize,
    String? areaOfUsage,
    String? modelNumber,
    String? make,
    String? colour,
    String? finish,
    String? thickness,
    String? otherSpecs,
    String? comments,
    String approvalStatus = 'pending',
    String? consultantComments,
    String? consultantSignatureDate,
  }) async {
    final url = Uri.parse(ApiConstants.approvalFormStore(projectId));
    developer.log(
        '[ApiService] createApprovalForm → POST $url projectId=$projectId',
        name: 'ApiService');
 
    final payload = <String, dynamic>{
      'form_no': formNo,
      if (dateOfSubmission != null && dateOfSubmission.isNotEmpty)
        'date_of_submission': dateOfSubmission,
      if (contractor != null && contractor.isNotEmpty) 'contractor': contractor,
      if (contractorSubmittalNumber != null &&
          contractorSubmittalNumber.isNotEmpty)
        'contractor_submittal_number': contractorSubmittalNumber,
      if (tradePackage != null && tradePackage.isNotEmpty)
        'trade_package': tradePackage,
      if (sampleMaterial != null && sampleMaterial.isNotEmpty)
        'sample_material': sampleMaterial,
      if (sampleNo != null && sampleNo.isNotEmpty) 'sample_no': sampleNo,
      if (sampleSize != null && sampleSize.isNotEmpty)
        'sample_size': sampleSize,
      if (areaOfUsage != null && areaOfUsage.isNotEmpty)
        'area_of_usage': areaOfUsage,
      if (modelNumber != null && modelNumber.isNotEmpty)
        'model_number': modelNumber,
      if (make != null && make.isNotEmpty) 'make': make,
      if (colour != null && colour.isNotEmpty) 'colour': colour,
      if (finish != null && finish.isNotEmpty) 'finish': finish,
      if (thickness != null && thickness.isNotEmpty) 'thickness': thickness,
      if (otherSpecs != null && otherSpecs.isNotEmpty)
        'other_specs': otherSpecs,
      if (comments != null && comments.isNotEmpty) 'comments': comments,
      'approval_status': approvalStatus,
      if (consultantComments != null && consultantComments.isNotEmpty)
        'consultant_comments': consultantComments,
      if (consultantSignatureDate != null && consultantSignatureDate.isNotEmpty)
        'consultant_signature_date': consultantSignatureDate,
    };
 
    try {
      final response = await http
          .post(
            url,
            headers: await _approvalFormHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      developer.log(
          '[ApiService] createApprovalForm ← ${response.statusCode}: ${response.body}',
          name: 'ApiService');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = body['approvalForm'];
        if (raw is Map<String, dynamic>) {
          return ApprovalFormModel.fromJson(raw);
        }
        throw ApiException('Unexpected response format from server.');
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
            'Failed to create approval form (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Create approval form error: $e');
    }
  }
 
  /// Fetch a single approval form by id.
  static Future<ApprovalFormModel> fetchApprovalForm(
      int projectId, int id) async {
    final url = Uri.parse(ApiConstants.approvalFormShow(projectId, id));
    developer.log('[ApiService] fetchApprovalForm → GET $url',
        name: 'ApiService');
    try {
      final response = await http
          .get(url, headers: await _approvalFormHeaders())
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = body['approvalForm'];
        if (raw is Map<String, dynamic>) {
          return ApprovalFormModel.fromJson(raw);
        }
        throw ApiException('Unexpected response format from server.');
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Approval form not found (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Fetch approval form error: $e');
    }
  }
 
  /// Update an existing approval form.
  static Future<ApprovalFormModel> updateApprovalForm({
    required int projectId,
    required int id,
    String? dateOfSubmission,
    String? contractor,
    String? contractorSubmittalNumber,
    String? tradePackage,
    String? sampleMaterial,
    String? sampleNo,
    String? sampleSize,
    String? areaOfUsage,
    String? modelNumber,
    String? make,
    String? colour,
    String? finish,
    String? thickness,
    String? otherSpecs,
    String? comments,
    String approvalStatus = 'pending',
    String? consultantComments,
    String? consultantSignatureDate,
  }) async {
    final url = Uri.parse(ApiConstants.approvalFormUpdate(projectId, id));
    developer.log(
        '[ApiService] updateApprovalForm → POST $url id=$id',
        name: 'ApiService');
 
    final payload = <String, dynamic>{
      if (dateOfSubmission != null && dateOfSubmission.isNotEmpty)
        'date_of_submission': dateOfSubmission,
      if (contractor != null && contractor.isNotEmpty) 'contractor': contractor,
      if (contractorSubmittalNumber != null &&
          contractorSubmittalNumber.isNotEmpty)
        'contractor_submittal_number': contractorSubmittalNumber,
      if (tradePackage != null && tradePackage.isNotEmpty)
        'trade_package': tradePackage,
      if (sampleMaterial != null && sampleMaterial.isNotEmpty)
        'sample_material': sampleMaterial,
      if (sampleNo != null && sampleNo.isNotEmpty) 'sample_no': sampleNo,
      if (sampleSize != null && sampleSize.isNotEmpty)
        'sample_size': sampleSize,
      if (areaOfUsage != null && areaOfUsage.isNotEmpty)
        'area_of_usage': areaOfUsage,
      if (modelNumber != null && modelNumber.isNotEmpty)
        'model_number': modelNumber,
      if (make != null && make.isNotEmpty) 'make': make,
      if (colour != null && colour.isNotEmpty) 'colour': colour,
      if (finish != null && finish.isNotEmpty) 'finish': finish,
      if (thickness != null && thickness.isNotEmpty) 'thickness': thickness,
      if (otherSpecs != null && otherSpecs.isNotEmpty)
        'other_specs': otherSpecs,
      if (comments != null && comments.isNotEmpty) 'comments': comments,
      'approval_status': approvalStatus,
      if (consultantComments != null && consultantComments.isNotEmpty)
        'consultant_comments': consultantComments,
      if (consultantSignatureDate != null && consultantSignatureDate.isNotEmpty)
        'consultant_signature_date': consultantSignatureDate,
    };
 
    try {
      final response = await http
          .post(
            url,
            headers: await _approvalFormHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      developer.log(
          '[ApiService] updateApprovalForm ← ${response.statusCode}: ${response.body}',
          name: 'ApiService');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = body['approvalForm'];
        if (raw is Map<String, dynamic>) {
          return ApprovalFormModel.fromJson(raw);
        }
        throw ApiException('Unexpected response format from server.');
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
            'Failed to update approval form (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Update approval form error: $e');
    }
  }
 
  // ── FIX: DELETE uses http.delete (HTTP DELETE verb) ──────────────────────
  // The original used http.post with body {'_method': 'DELETE'}.
  // Laravel API routes do NOT process form-method-spoofing for JSON requests,
  // so that trick never worked — the server received a plain POST which has
  // no matching route, causing the "DELETE method is not supported" error.
  // Switching to http.delete matches Route::delete on the server.
  /// Delete an approval form.
  static Future<void> deleteApprovalForm(int projectId, int id) async {
    final url = Uri.parse(ApiConstants.approvalFormDestroy(projectId, id));
    developer.log('[ApiService] deleteApprovalForm → POST $url id=$id',
        name: 'ApiService');
    try {
      final response = await http
          .post(url, headers: await _approvalFormHeaders())
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      developer.log(
          '[ApiService] deleteApprovalForm ← ${response.statusCode}',
          name: 'ApiService');
      if (response.statusCode >= 200 && response.statusCode < 300) return;
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to delete approval form (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Delete approval form error: $e');
    }
  }
 
  // ── NEW: Download PDF bytes with auth header ──────────────────────────────
  // The original approvalFormDownloadUrl opened a browser URL without auth,
  // resulting in a 403. This method fetches the PDF binary directly from
  // Dart using the Bearer token, then returns raw bytes so the UI layer can
  // save and open the file with open_filex.
  /// Fetch raw PDF bytes for an approval form (authenticated).
  static Future<List<int>> downloadApprovalFormPdfBytes(
      int projectId, int id) async {
    final url = Uri.parse(ApiConstants.approvalFormDownload(projectId, id));
    developer.log(
        '[ApiService] downloadApprovalFormPdfBytes → GET $url',
        name: 'ApiService');
 
    // Accept header must request PDF, not JSON
    final token = await AuthStorageService.getToken();
    final headers = {
      'Accept': 'application/pdf,*/*',
      'X-Requested-With': 'XMLHttpRequest',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
 
    try {
      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 60)); // PDFs may be larger
 
      developer.log(
          '[ApiService] downloadApprovalFormPdfBytes ← ${response.statusCode} '
          'contentType=${response.headers['content-type']}',
          name: 'ApiService');
 
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(
          'Failed to download PDF (${response.statusCode})');
    } on TimeoutException {
      throw ApiException('PDF download timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('PDF download error: $e');
    }
  }
 
  /// Returns the web print URL for an approval form.
  /// Used by _InAppWebViewPage to load the URL with injected auth header.
  static String approvalFormPrintUrl(int projectId, int id) =>
      ApiConstants.approvalFormPrint(projectId, id);
 
  /// Returns the PDF download URL (kept for reference; prefer downloadApprovalFormPdfBytes).
  static String approvalFormDownloadUrl(int projectId, int id) =>
      ApiConstants.approvalFormDownload(projectId, id);

       // ── Architecture Checklist ─────────────────────────────────────────────────
 
  static Future<Map<String, String>> _architectureHeaders({
  String? methodOverride,
}) async {
  final token = await AuthStorageService.getToken();
  return {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'X-Requested-With': 'XMLHttpRequest',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    // FIX #2 & #3: Tell Laravel the real method when LiteSpeed blocks PUT/DELETE
    if (methodOverride != null) 'X-HTTP-Method-Override': methodOverride,
  };
}
 
  /// Fetch all architecture checklists for a project.
  static Future<List<ArchitectureChecklistModel>> fetchArchitectureChecklists(
      int projectId) async {
    final url =
        Uri.parse(ApiConstants.architectureChecklistIndex(projectId));
    developer.log('[ApiService] fetchArchitectureChecklists → GET $url',
        name: 'ApiService');
    try {
      final response = await http
          .get(url, headers: await _architectureHeaders())
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      developer.log(
          '[ApiService] fetchArchitectureChecklists ← ${response.statusCode}',
          name: 'ApiService');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = (body is Map ? body['checklists'] : null);
        if (raw is List) {
          return raw
              .whereType<Map>()
              .map((e) => ArchitectureChecklistModel.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList();
        }
        return [];
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to load architecture checklists (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Architecture checklist fetch error: $e');
    }
  }
 
  /// Generate a unique checklist number for a project.
  static Future<String> generateArchitectureChecklistNumber(
      int projectId) async {
    final url =
        Uri.parse(ApiConstants.architectureChecklistCreate(projectId));
    developer.log(
        '[ApiService] generateArchitectureChecklistNumber → GET $url',
        name: 'ApiService');
    try {
      final response = await http
          .get(url, headers: await _architectureHeaders())
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return body['checklist_no']?.toString() ?? '';
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to generate checklist number (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
          'Generate architecture checklist number error: $e');
    }
  }
 
  /// Create a new architecture checklist.
  static Future<ArchitectureChecklistModel> createArchitectureChecklist({
    required int projectId,
    required String checklistNo,
    required String checklistDate,
    String? jobNo,
    String? projectName,
    bool beamNotInLine = false,
    bool columnNotPlumb = false,
    String? honeycombColumn,
    String? beamNo,
    required List<Map<String, dynamic>> inspectionItems,
    String? barChartAvailable,
    bool workInProgress = false,
    bool timeLimitAvailable = false,
    String? balanceWorkMonths,
    String? lastDateTimePeriod,
    String? sanctionDate,
    required List<Map<String, dynamic>> openSpaceData,
    String? constructionStatement,
    String? additionalInstructions,
    String? architectSignature,
    String? clientSignature,
  }) async {
    final url =
        Uri.parse(ApiConstants.architectureChecklistStore(projectId));
    developer.log(
        '[ApiService] createArchitectureChecklist → POST $url projectId=$projectId',
        name: 'ApiService');
 
    final payload = <String, dynamic>{
      'checklist_no': checklistNo,
      'checklist_date': checklistDate,
      if (jobNo != null && jobNo.isNotEmpty) 'job_no': jobNo,
      if (projectName != null && projectName.isNotEmpty)
        'project_name': projectName,
      'beam_not_in_line': beamNotInLine,
      'column_not_plumb': columnNotPlumb,
      if (honeycombColumn != null && honeycombColumn.isNotEmpty)
        'honeycomb_column': honeycombColumn,
      if (beamNo != null && beamNo.isNotEmpty) 'beam_no': beamNo,
      'inspection_items': inspectionItems,
      if (barChartAvailable != null && barChartAvailable.isNotEmpty)
        'bar_chart_available': barChartAvailable,
      'work_in_progress': workInProgress,
      'time_limit_available': timeLimitAvailable,
      if (balanceWorkMonths != null && balanceWorkMonths.isNotEmpty)
        'balance_work_months': balanceWorkMonths,
      if (lastDateTimePeriod != null && lastDateTimePeriod.isNotEmpty)
        'last_date_time_period': lastDateTimePeriod,
      if (sanctionDate != null && sanctionDate.isNotEmpty)
        'sanction_date': sanctionDate,
      'open_space_data': openSpaceData,
      if (constructionStatement != null && constructionStatement.isNotEmpty)
        'construction_statement': constructionStatement,
      if (additionalInstructions != null && additionalInstructions.isNotEmpty)
        'additional_instructions': additionalInstructions,
      if (architectSignature != null && architectSignature.isNotEmpty)
        'architect_signature': architectSignature,
      if (clientSignature != null && clientSignature.isNotEmpty)
        'client_signature': clientSignature,
    };
 
    try {
      final response = await http
          .post(
            url,
            headers: await _architectureHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      developer.log(
          '[ApiService] createArchitectureChecklist ← ${response.statusCode}: ${response.body}',
          name: 'ApiService');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = body['checklist'];
        if (raw is Map<String, dynamic>) {
          return ArchitectureChecklistModel.fromJson(raw);
        }
        throw ApiException('Unexpected response format from server.');
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
            'Failed to create architecture checklist (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Create architecture checklist error: $e');
    }
  }
 
  /// Fetch a single architecture checklist by id.
  static Future<ArchitectureChecklistModel> fetchArchitectureChecklist(
      int projectId, int id) async {
    final url = Uri.parse(
        ApiConstants.architectureChecklistShow(projectId, id));
    developer.log('[ApiService] fetchArchitectureChecklist → GET $url',
        name: 'ApiService');
    try {
      final response = await http
          .get(url, headers: await _architectureHeaders())
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = body['checklist'];
        if (raw is Map<String, dynamic>) {
          return ArchitectureChecklistModel.fromJson(raw);
        }
        throw ApiException('Unexpected response format from server.');
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Checklist not found (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Fetch architecture checklist error: $e');
    }
  }
 
  /// Update an existing architecture checklist.
  static Future<ArchitectureChecklistModel> updateArchitectureChecklist({
  required int projectId,
  required int id,
  required String checklistDate,
  String? jobNo,
  String? projectName,
  bool beamNotInLine = false,
  bool columnNotPlumb = false,
  String? honeycombColumn,
  String? beamNo,
  required List<Map<String, dynamic>> inspectionItems,
  String? barChartAvailable,
  bool workInProgress = false,
  bool timeLimitAvailable = false,
  String? balanceWorkMonths,
  String? lastDateTimePeriod,
  String? sanctionDate,
  required List<Map<String, dynamic>> openSpaceData,
  String? constructionStatement,
  String? additionalInstructions,
  String? architectSignature,
  String? clientSignature,
}) async {
  // Use the PUT endpoint URL (same as before)
  final url = Uri.parse(
      ApiConstants.architectureChecklistUpdate(projectId, id));
  developer.log(
      '[ApiService] updateArchitectureChecklist → POST(PUT override) $url id=$id',
      name: 'ApiService');
 
  final payload = <String, dynamic>{
    // Add _method field as extra safety for Laravel method spoofing
    '_method': 'PUT',
    'checklist_date': checklistDate,
    if (jobNo != null && jobNo.isNotEmpty) 'job_no': jobNo,
    if (projectName != null && projectName.isNotEmpty)
      'project_name': projectName,
    'beam_not_in_line': beamNotInLine,
    'column_not_plumb': columnNotPlumb,
    if (honeycombColumn != null && honeycombColumn.isNotEmpty)
      'honeycomb_column': honeycombColumn,
    if (beamNo != null && beamNo.isNotEmpty) 'beam_no': beamNo,
    'inspection_items': inspectionItems,
    if (barChartAvailable != null && barChartAvailable.isNotEmpty)
      'bar_chart_available': barChartAvailable,
    'work_in_progress': workInProgress,
    'time_limit_available': timeLimitAvailable,
    if (balanceWorkMonths != null && balanceWorkMonths.isNotEmpty)
      'balance_work_months': balanceWorkMonths,
    if (lastDateTimePeriod != null && lastDateTimePeriod.isNotEmpty)
      'last_date_time_period': lastDateTimePeriod,
    if (sanctionDate != null && sanctionDate.isNotEmpty)
      'sanction_date': sanctionDate,
    'open_space_data': openSpaceData,
    if (constructionStatement != null && constructionStatement.isNotEmpty)
      'construction_statement': constructionStatement,
    if (additionalInstructions != null && additionalInstructions.isNotEmpty)
      'additional_instructions': additionalInstructions,
    if (architectSignature != null && architectSignature.isNotEmpty)
      'architect_signature': architectSignature,
    if (clientSignature != null && clientSignature.isNotEmpty)
      'client_signature': clientSignature,
  };
 
  try {
    // KEY FIX: Send as POST with X-HTTP-Method-Override: PUT
    final response = await http
        .post(
          url,
          headers: await _architectureHeaders(methodOverride: 'PUT'),
          body: jsonEncode(payload),
        )
        .timeout(ApiConstants.requestTimeout);
 
    final body = _decode(response.body);
    developer.log(
        '[ApiService] updateArchitectureChecklist ← ${response.statusCode}: ${response.body}',
        name: 'ApiService');
 
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final raw = body['checklist'];
      if (raw is Map<String, dynamic>) {
        return ArchitectureChecklistModel.fromJson(raw);
      }
      throw ApiException('Unexpected response format from server.');
    }
    if (response.statusCode == 401) {
      throw ApiException('Session expired. Please login again.');
    }
    if (response.statusCode == 422 &&
        body is Map &&
        body['errors'] is Map) {
      final errors =
          Map<String, dynamic>.from(body['errors'] as Map);
      final firstKey =
          errors.keys.isNotEmpty ? errors.keys.first : null;
      if (firstKey != null &&
          errors[firstKey] is List &&
          (errors[firstKey] as List).isNotEmpty) {
        throw ApiException(
            (errors[firstKey] as List).first.toString());
      }
    }
    throw ApiException(
      (body is Map ? body['message']?.toString() : null) ??
          'Failed to update architecture checklist (${response.statusCode})',
    );
  } on TimeoutException {
    throw ApiException('Request timed out. Please try again.');
  } catch (e) {
    if (e is ApiException) rethrow;
    throw ApiException('Update architecture checklist error: $e');
  }
}
 
// ── deleteArchitectureChecklist ────────────────────────────────────────────
// FIX #3 (Delete 403):
// Changed http.delete → http.post with X-HTTP-Method-Override: DELETE header.
// Same root cause as the Edit 403 — LiteSpeed blocks DELETE at the server
// level. Sending as POST with the override header lets it pass through.
 
static Future<void> deleteArchitectureChecklist(
    int projectId, int id) async {
  final url = Uri.parse(
      ApiConstants.architectureChecklistDestroy(projectId, id));
  developer.log(
      '[ApiService] deleteArchitectureChecklist → POST(DELETE override) $url id=$id',
      name: 'ApiService');
  try {
    // KEY FIX: Send as POST with X-HTTP-Method-Override: DELETE
    final response = await http
        .post(
          url,
          headers: await _architectureHeaders(methodOverride: 'DELETE'),
          // Send _method in body too as a belt-and-suspenders approach
          body: jsonEncode({'_method': 'DELETE'}),
        )
        .timeout(ApiConstants.requestTimeout);
 
    final body = _decode(response.body);
    developer.log(
        '[ApiService] deleteArchitectureChecklist ← ${response.statusCode}',
        name: 'ApiService');
 
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    if (response.statusCode == 401) {
      throw ApiException('Session expired. Please login again.');
    }
    throw ApiException(
      (body is Map ? body['message']?.toString() : null) ??
          'Failed to delete architecture checklist (${response.statusCode})',
    );
  } on TimeoutException {
    throw ApiException('Request timed out. Please try again.');
  } catch (e) {
    if (e is ApiException) rethrow;
    throw ApiException('Delete architecture checklist error: $e');
  }
}
 
  /// Returns the web print URL for an architecture checklist.
  static String architectureChecklistPrintUrl(int projectId, int id) =>
      ApiConstants.architectureChecklistPrint(projectId, id);
 
  /// Returns the PDF download URL for an architecture checklist.
  static String architectureChecklistDownloadUrl(int projectId, int id) =>
      ApiConstants.architectureChecklistDownload(projectId, id);

      // ═══════════════════════════════════════════════════════════════════════════
  // CONCRETE POUR CARD
  // ═══════════════════════════════════════════════════════════════════════════
 
  static Future<Map<String, String>> _concretePourCardHeaders() async {
    final token = await AuthStorageService.getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }
 
  /// Fetch all concrete pour cards for a project.
  static Future<List<ConcretePourCardModel>> fetchConcretePourCards(
      int projectId) async {
    final url = Uri.parse(ApiConstants.concretePourCardIndex(projectId));
    developer.log('[ApiService] fetchConcretePourCards → GET $url',
        name: 'ApiService');
    try {
      final response = await http
          .get(url, headers: await _concretePourCardHeaders())
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      developer.log(
          '[ApiService] fetchConcretePourCards ← ${response.statusCode}',
          name: 'ApiService');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = (body is Map ? body['cards'] : null);
        if (raw is List) {
          return raw
              .whereType<Map>()
              .map((e) =>
                  ConcretePourCardModel.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
        return [];
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to load concrete pour cards (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Concrete pour card fetch error: $e');
    }
  }
 
  /// Generate a unique card number for a project.
  static Future<String> generateConcretePourCardNumber(int projectId) async {
    final url = Uri.parse(ApiConstants.concretePourCardCreate(projectId));
    developer.log('[ApiService] generateConcretePourCardNumber → GET $url',
        name: 'ApiService');
    try {
      final response = await http
          .get(url, headers: await _concretePourCardHeaders())
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return body['card_no']?.toString() ?? '';
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to generate card number (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Generate concrete pour card number error: $e');
    }
  }
 
  /// Create a new concrete pour card.
  static Future<ConcretePourCardModel> createConcretePourCard({
    required int projectId,
    required String cardNo,
    required String date,
    String? time,
    String? grade,
    String? startTime,
    String? endTime,
    String? workName,
    required List<Map<String, dynamic>> checklistItems,
    String? checkedBy,
  }) async {
    final url = Uri.parse(ApiConstants.concretePourCardStore(projectId));
    developer.log(
        '[ApiService] createConcretePourCard → POST $url projectId=$projectId',
        name: 'ApiService');
 
    final payload = <String, dynamic>{
      'card_no': cardNo,
      'date': date,
      if (time != null && time.isNotEmpty) 'time': time,
      if (grade != null && grade.isNotEmpty) 'grade': grade,
      if (startTime != null && startTime.isNotEmpty) 'start_time': startTime,
      if (endTime != null && endTime.isNotEmpty) 'end_time': endTime,
      if (workName != null && workName.isNotEmpty) 'work_name': workName,
      'checklist_items': checklistItems,
      if (checkedBy != null && checkedBy.isNotEmpty) 'checked_by': checkedBy,
    };
 
    try {
      final response = await http
          .post(
            url,
            headers: await _concretePourCardHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      developer.log(
          '[ApiService] createConcretePourCard ← ${response.statusCode}: ${response.body}',
          name: 'ApiService');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = body['card'];
        if (raw is Map<String, dynamic>) {
          return ConcretePourCardModel.fromJson(raw);
        }
        throw ApiException('Unexpected response format from server.');
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
            'Failed to create concrete pour card (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Create concrete pour card error: $e');
    }
  }
 
  /// Fetch a single concrete pour card by id.
  static Future<ConcretePourCardModel> fetchConcretePourCard(
      int projectId, int id) async {
    final url = Uri.parse(ApiConstants.concretePourCardShow(projectId, id));
    developer.log('[ApiService] fetchConcretePourCard → GET $url',
        name: 'ApiService');
    try {
      final response = await http
          .get(url, headers: await _concretePourCardHeaders())
          .timeout(ApiConstants.requestTimeout);
      final body = _decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = body['card'];
        if (raw is Map<String, dynamic>) {
          return ConcretePourCardModel.fromJson(raw);
        }
        throw ApiException('Unexpected response format from server.');
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Card not found (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Fetch concrete pour card error: $e');
    }
  }
 
  /// Update an existing concrete pour card.
  static Future<ConcretePourCardModel> updateConcretePourCard({
  required int projectId,
  required int id,
  required String date,
  String? time,
  String? grade,
  String? startTime,
  String? endTime,
  String? workName,
  required List<Map<String, dynamic>> checklistItems,
  String? checkedBy,
}) async {
  // Use the POST-based destroy route pattern (same WAF workaround already used
  // for delete). Laravel's HandleCors / method spoofing middleware reads
  // _method from the JSON body.
  final url = Uri.parse(ApiConstants.concretePourCardUpdate(projectId, id));
  developer.log(
      '[ApiService] updateConcretePourCard → POST(PUT) $url id=$id',
      name: 'ApiService');
 
  // Include _method so Laravel's method-spoofing middleware treats this POST
  // as a PUT, matching Route::put('{projectId}/{id}', 'update').
  final payload = <String, dynamic>{
    
    'date': date,
    if (time != null && time.isNotEmpty) 'time': time,
    if (grade != null && grade.isNotEmpty) 'grade': grade,
    if (startTime != null && startTime.isNotEmpty) 'start_time': startTime,
    if (endTime != null && endTime.isNotEmpty) 'end_time': endTime,
    if (workName != null && workName.isNotEmpty) 'work_name': workName,
    'checklist_items': checklistItems,
    if (checkedBy != null && checkedBy.isNotEmpty) 'checked_by': checkedBy,
  };
 
  try {
    final response = await http
        .post( // ← POST, not put()
          url,
          headers: await _concretePourCardHeaders(),
          body: jsonEncode(payload),
        )
        .timeout(ApiConstants.requestTimeout);
    final body = _decode(response.body);
    developer.log(
        '[ApiService] updateConcretePourCard ← ${response.statusCode}: ${response.body}',
        name: 'ApiService');
 
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final raw = body['card'];
      if (raw is Map<String, dynamic>) {
        return ConcretePourCardModel.fromJson(raw);
      }
      throw ApiException('Unexpected response format from server.');
    }
    if (response.statusCode == 401) {
      throw ApiException('Session expired. Please login again.');
    }
    if (response.statusCode == 403) {
      // 403 from WAF — still happening? Check that the route accepts POST.
      throw ApiException(
          'Access denied (403). Ensure the update route accepts POST requests.');
    }
    if (response.statusCode == 422 && body is Map && body['errors'] is Map) {
      final errors = Map<String, dynamic>.from(body['errors'] as Map);
      final firstKey =
          errors.keys.isNotEmpty ? errors.keys.first : null;
      if (firstKey != null &&
          errors[firstKey] is List &&
          (errors[firstKey] as List).isNotEmpty) {
        throw ApiException(
            (errors[firstKey] as List).first.toString());
      }
    }
    throw ApiException(
      (body is Map ? body['message']?.toString() : null) ??
          'Failed to update concrete pour card (${response.statusCode})',
    );
  } on TimeoutException {
    throw ApiException('Request timed out. Please try again.');
  } catch (e) {
    if (e is ApiException) rethrow;
    throw ApiException('Update concrete pour card error: $e');
  }
}

/// Delete a concrete pour card.
static Future<void> deleteConcretePourCard(int projectId, int id) async {
  // LiteSpeed WAF blocks raw DELETE — use POST + _method=DELETE override
  final url = Uri.parse(ApiConstants.concretePourCardDestroy(projectId, id));
  developer.log('[ApiService] deleteConcretePourCard → POST(DELETE) $url id=$id',
      name: 'ApiService');

  final payload = <String, dynamic>{'_method': 'DELETE'};

  try {
    final response = await http
        .post(
          url,
          headers: await _concretePourCardHeaders(),
          body: jsonEncode(payload),
        )
        .timeout(ApiConstants.requestTimeout);
    final body = _decode(response.body);
    developer.log(
        '[ApiService] deleteConcretePourCard ← ${response.statusCode}',
        name: 'ApiService');

    if (response.statusCode >= 200 && response.statusCode < 300) return;
    if (response.statusCode == 401) {
      throw ApiException('Session expired. Please login again.');
    }
    throw ApiException(
      (body is Map ? body['message']?.toString() : null) ??
          'Failed to delete concrete pour card (${response.statusCode})',
    );
  } on TimeoutException {
    throw ApiException('Request timed out. Please try again.');
  } catch (e) {
    if (e is ApiException) rethrow;
    throw ApiException('Delete concrete pour card error: $e');
  }
}
 
// ── FIX #2: Download PDF as bytes (in-app, no browser redirect) ──────────────
 
/// Downloads the PDF for a concrete pour card and returns raw bytes.
/// The caller passes these to `Printing.sharePdf()` so the file is handled
/// entirely inside the app — no browser redirect, no login page.
static Future<Uint8List> downloadConcretePourCardPdf(
    int projectId, int id) async {
  final url =
      Uri.parse(ApiConstants.concretePourCardDownload(projectId, id));
  developer.log(
      '[ApiService] downloadConcretePourCardPdf → GET $url',
      name: 'ApiService');
 
  try {
    final response = await http
        .get(url, headers: await _concretePourCardHeaders())
        .timeout(const Duration(seconds: 60)); // PDF can be large
 
    developer.log(
        '[ApiService] downloadConcretePourCardPdf ← ${response.statusCode} '
        'contentType=${response.headers['content-type']} '
        'bytes=${response.bodyBytes.length}',
        name: 'ApiService');
 
    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Verify we actually got a PDF, not an HTML error/login page
      final contentType =
          response.headers['content-type'] ?? '';
      if (!contentType.contains('pdf') &&
          !contentType.contains('octet-stream')) {
        // Server returned HTML (likely a login redirect)
        throw ApiException(
            'Server returned unexpected content. Please check your session.');
      }
      return response.bodyBytes;
    }
    if (response.statusCode == 401) {
      throw ApiException('Session expired. Please login again.');
    }
    throw ApiException(
        'Failed to download PDF (${response.statusCode})');
  } on TimeoutException {
    throw ApiException('PDF download timed out. Please try again.');
  } catch (e) {
    if (e is ApiException) rethrow;
    throw ApiException('PDF download error: $e');
  }
}
 
  /// Returns the web print URL for a concrete pour card.
  static String concretePourCardPrintUrl(int projectId, int id) =>
      ApiConstants.concretePourCardPrint(projectId, id);
 
  /// Returns the PDF download URL for a concrete pour card.
  static String concretePourCardDownloadUrl(int projectId, int id) =>
      ApiConstants.concretePourCardDownload(projectId, id);

        // ═══════════════════════════════════════════════════════════════════════════
  // MINUTES OF MEETING (MOM)
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<Map<String, String>> _momHeaders() async {
    final token = await AuthStorageService.getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // ── Calendar Events ──────────────────────────────────────────────────────

  static Future<List<CalendarMeetingEvent>> fetchCalendarEvents(
      int projectId) async {
    final url = Uri.parse(ApiConstants.calendarEvents(projectId));
    developer.log('[ApiService] fetchCalendarEvents → GET $url',
        name: 'ApiService');

    try {
      final response = await http
          .get(url, headers: await _momHeaders())
          .timeout(ApiConstants.requestTimeout);

      final body = _decode(response.body);

      developer.log(
        '[ApiService] fetchCalendarEvents ← ${response.statusCode}',
        name: 'ApiService',
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = (body is Map ? body['data'] : null);
        if (raw is List) {
          return raw
              .whereType<Map>()
              .map((e) => CalendarMeetingEvent.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList();
        }
        return [];
      }

      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }

      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to load calendar events (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Calendar events error: $e');
    }
  }

  // ── Meetings List ────────────────────────────────────────────────────────

  static Future<List<ScheduledMeetingModel>> fetchMeetingsList(
      int projectId) async {
    final url = Uri.parse(ApiConstants.meetingsDatatable(projectId));
    developer.log('[ApiService] fetchMeetingsList → GET $url',
        name: 'ApiService');

    try {
      final response = await http
          .get(url, headers: await _momHeaders())
          .timeout(ApiConstants.requestTimeout);

      final body = _decode(response.body);

      developer.log(
        '[ApiService] fetchMeetingsList ← ${response.statusCode}: '
        '${response.body.substring(0, response.body.length.clamp(0, 300))}',
        name: 'ApiService',
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = (body is Map
            ? (body['data'] ?? body['meetings'] ?? body['list'])
            : null);

        if (raw is List) {
          return raw
              .whereType<Map>()
              .map((e) => ScheduledMeetingModel.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList();
        }
        return [];
      }

      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }

      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to load meetings (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Meetings list error: $e');
    }
  }

  static Future<ScheduledMeetingModel> fetchScheduledMeetingDetails(
      int meetingId) async {
    final url = Uri.parse(ApiConstants.scheduledMeetingDetails(meetingId));

    try {
      final response = await http
          .get(url, headers: await _momHeaders())
          .timeout(ApiConstants.requestTimeout);

      final body = _decode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = body['data'];
        if (raw is Map<String, dynamic>) {
          return ScheduledMeetingModel.fromJson(raw);
        }
        throw ApiException('Unexpected response format.');
      }

      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }

      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to load meeting details (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Meeting details error: $e');
    }
  }

  static Future<ScheduledMeetingModel> fetchScheduledMeetingForMom(
      int meetingId) async {
    final url = Uri.parse(ApiConstants.scheduledMeetingForMom(meetingId));

    try {
      final response = await http
          .get(url, headers: await _momHeaders())
          .timeout(ApiConstants.requestTimeout);

      final body = _decode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = body['data'];
        if (raw is Map<String, dynamic>) {
          return ScheduledMeetingModel.fromJson(raw);
        }
        throw ApiException('Unexpected response format.');
      }

      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }

      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to load meeting (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Fetch meeting error: $e');
    }
  }

  static Future<Map<String, dynamic>> storeScheduledMeeting({
    required int projectId,
    required String meetingTitle,
    required String meetingDate,
    String? meetingTime,
    String? venue,
    String? meetingAgenda,
    required List<Map<String, String>> attendees,
  }) async {
    final url = Uri.parse(ApiConstants.storeScheduledMeeting());

    final payload = <String, dynamic>{
      'project_id': projectId,
      'meeting_title': meetingTitle,
      'meeting_date': meetingDate,
      if (meetingTime != null && meetingTime.isNotEmpty)
        'meeting_time': meetingTime,
      if (venue != null && venue.isNotEmpty) 'venue': venue,
      if (meetingAgenda != null && meetingAgenda.isNotEmpty)
        'meeting_agenda': meetingAgenda,
      'attendees': attendees,
    };

    try {
      final response = await http
          .post(
            url,
            headers: await _momHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(ApiConstants.requestTimeout);

      final body = _decode(response.body);

      developer.log(
        '[ApiService] storeScheduledMeeting ← ${response.statusCode}: ${response.body}',
        name: 'ApiService',
      );

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
            'Failed to schedule meeting (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Schedule meeting error: $e');
    }
  }

  static Future<void> deleteScheduledMeeting(int meetingId) async {
    final url = Uri.parse(ApiConstants.deleteScheduledMeeting(meetingId));

    try {
      final response = await http
          .post(
            url,
            headers: await _momHeaders(),
            body: jsonEncode({}),
          )
          .timeout(ApiConstants.requestTimeout);

      final body = _decode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) return;

      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }

      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to delete meeting (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Delete meeting error: $e');
    }
  }

  // ── Minutes of Meeting ──────────────────────────────────────────────────

  static Future<Map<String, dynamic>> storeMom({
    required int projectId,
    int? scheduledMeetingId,
    required String title,
    required String meetingDate,
    String? meetingTime,
    String? venue,
    required String description,
    List<Map<String, String>> additionalAttendees = const [],
  }) async {
    final url = Uri.parse(ApiConstants.storeMom());

    final payload = <String, dynamic>{
      'project_id': projectId,
      if (scheduledMeetingId != null)
        'scheduled_meeting_id': scheduledMeetingId,
      'title': title,
      'meeting_date': meetingDate,
      if (meetingTime != null && meetingTime.isNotEmpty)
        'meeting_time': meetingTime,
      if (venue != null && venue.isNotEmpty) 'venue': venue,
      'description': description,
      if (additionalAttendees.isNotEmpty)
        'additional_attendees': additionalAttendees,
    };

    try {
      final response = await http
          .post(
            url,
            headers: await _momHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 60));

      final body = _decode(response.body);

      developer.log(
        '[ApiService] storeMom ← ${response.statusCode}: ${response.body}',
        name: 'ApiService',
      );

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
            'Failed to save MOM (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. PDF generation may take time.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Store MOM error: $e');
    }
  }

  static Future<MinutesOfMeetingModel> fetchMomDetails(int momId) async {
    final url = Uri.parse(ApiConstants.momDetails(momId));

    try {
      final response = await http
          .get(url, headers: await _momHeaders())
          .timeout(ApiConstants.requestTimeout);

      final body = _decode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = body['data'];
        if (raw is Map<String, dynamic>) {
          return MinutesOfMeetingModel.fromJson(raw);
        }
        throw ApiException('Unexpected response format.');
      }

      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }

      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'MOM not found (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Fetch MOM error: $e');
    }
  }

  static Future<Map<String, dynamic>> updateMom({
    required int momId,
    required String title,
    required String meetingDate,
    String? meetingTime,
    String? venue,
    required String description,
    List<Map<String, String>> additionalAttendees = const [],
  }) async {
    final url = Uri.parse(ApiConstants.updateMom(momId));

    final payload = <String, dynamic>{
      'title': title,
      'meeting_date': meetingDate,
      if (meetingTime != null && meetingTime.isNotEmpty)
        'meeting_time': meetingTime,
      if (venue != null && venue.isNotEmpty) 'venue': venue,
      'description': description,
      if (additionalAttendees.isNotEmpty)
        'additional_attendees': additionalAttendees,
    };

    try {
      final response = await http
          .post(
            url,
            headers: await _momHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 60));

      final body = _decode(response.body);

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
            'Failed to update MOM (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Update MOM error: $e');
    }
  }

  static Future<void> deleteMom(int momId) async {
    final url = Uri.parse(ApiConstants.deleteMom(momId));

    try {
      final response = await http
          .post(
            url,
            headers: await _momHeaders(),
            body: jsonEncode({}),
          )
          .timeout(ApiConstants.requestTimeout);

      final body = _decode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) return;

      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }

      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to delete MOM (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Delete MOM error: $e');
    }
  }

  static Future<Uint8List> downloadMomPdf(int momId) async {
    final url = Uri.parse(ApiConstants.downloadMomPdf(momId));
    final token = await AuthStorageService.getToken();

    try {
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/pdf,*/*',
          'X-Requested-With': 'XMLHttpRequest',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      }

      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }

      throw ApiException('Failed to download PDF (${response.statusCode})');
    } on TimeoutException {
      throw ApiException('PDF download timed out.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('PDF download error: $e');
    }
  }

  // ── CC Progress API Service methods ───────────────────────────────────────────

    static Future<Map<String, String>> _ccProgressHeaders() async {
    final token = await AuthStorageService.getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }
 
  /// Fetch all CC Progress stages with processes + summary counts.
  static Future<List<CcStageDataModel>> fetchCcProgress(int projectId) async {
    final url = Uri.parse(ApiConstants.ccProgressIndex(projectId));
    developer.log('[ApiService] fetchCcProgress → GET $url', name: 'ApiService');
 
    try {
      final response = await http
          .get(url, headers: await _ccProgressHeaders())
          .timeout(ApiConstants.requestTimeout);
 
      final body = _decode(response.body);
      developer.log(
          '[ApiService] fetchCcProgress ← ${response.statusCode}',
          name: 'ApiService');
 
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = (body is Map ? body['data'] : null);
        if (raw is List) {
          return raw
              .whereType<Map>()
              .map((e) => _parseCcStageData(Map<String, dynamic>.from(e)))
              .toList();
        }
        return [];
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to load CC Progress (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('CC Progress fetch error: $e');
    }
  }
 
  static CcStageDataModel _parseCcStageData(Map<String, dynamic> json) {
    final rawProcesses = json['processes'];
    final processes = <CcProcessModel>[];
    if (rawProcesses is List) {
      for (final p in rawProcesses) {
        if (p is Map) {
          processes.add(CcProcessModel.fromJson(Map<String, dynamic>.from(p)));
        }
      }
    }
 
    CcStageSummaryModel? summary;
    final rawSummary = json['summary'];
    if (rawSummary is Map<String, dynamic>) {
      summary = CcStageSummaryModel.fromJson(rawSummary);
    }
 
    return CcStageDataModel(
      stageKey: json['stage_key']?.toString() ?? '',
      stageLabel: json['stage_label']?.toString() ?? json['stage_name']?.toString() ?? '',
      processes: processes,
      summary: summary,
    );
  }
 
  /// Update CC process status (Completed | N.A).
  static Future<Map<String, dynamic>> updateCcProcessStatus({
    required int projectId,
    required int processId,
    required String status, // 'Completed' or 'N.A'
  }) async {
    developer.log(
        '[ApiService] updateCcProcessStatus → projectId=$projectId processId=$processId status=$status',
        name: 'ApiService');
 
    try {
      final response = await _rawPost(
        fullUrl: ApiConstants.ccProgressUpdateStatus,
        body: {
          'project_id': projectId,
          'process_id': processId,
          'status': status,
        },
      );
 
      final decoded = _decode(response.body);
      developer.log(
          '[ApiService] updateCcProcessStatus ← ${response.statusCode}: ${response.body}',
          name: 'ApiService');
 
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded is Map<String, dynamic> ? decoded : {'success': true};
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(
        (decoded is Map ? decoded['message']?.toString() : null) ??
            'Failed to update status (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Update CC status error: $e');
    }
  }
 
  /// Remove CC process status (revert to pending).
  static Future<Map<String, dynamic>> removeCcProcessStatus({
    required int projectId,
    required int processId,
  }) async {
    developer.log(
        '[ApiService] removeCcProcessStatus → projectId=$projectId processId=$processId',
        name: 'ApiService');
 
    try {
      final response = await _rawPost(
        fullUrl: ApiConstants.ccProgressRemoveStatus,
        body: {
          'project_id': projectId,
          'process_id': processId,
        },
      );
 
      final decoded = _decode(response.body);
      developer.log(
          '[ApiService] removeCcProcessStatus ← ${response.statusCode}',
          name: 'ApiService');
 
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded is Map<String, dynamic> ? decoded : {'success': true};
      }
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
      throw ApiException(
        (decoded is Map ? decoded['message']?.toString() : null) ??
            'Failed to remove status (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Remove CC status error: $e');
    }
  }
 
  /// Upload a document for a CC process item.
  static Future<Map<String, dynamic>> uploadCcProcessFile({
    required int projectId,
    required int processId,
    required File file,
    required String fileName,
    required String uploadedDate,
  }) async {
    final url = ApiConstants.ccProgressUploadFile;
 
    developer.log(
        '[ApiService] uploadCcProcessFile → POST $url  '
        'project=$projectId process=$processId file=$fileName',
        name: 'ApiService');
 
    // Guard: file must exist on disk before we try to send it
    if (!file.existsSync()) {
      throw ApiException(
          'The selected file no longer exists. Please pick the file again.');
    }
 
    final token = await AuthStorageService.getToken();
    final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
    final mimeParts = mimeType.split('/');
 
    final request = http.MultipartRequest('POST', Uri.parse(url))
      ..headers.addAll({
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
        if (token != null && token.isNotEmpty)
          'Authorization': 'Bearer $token',
      })
      ..fields['project_id'] = projectId.toString()
      ..fields['process_id'] = processId.toString()
      ..fields['upload_date'] = uploadedDate // yyyy-MM-dd
      ..files.add(await http.MultipartFile.fromPath(
        'document',          // ← MUST match backend: $request->file('document')
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
        '[ApiService] uploadCcProcessFile ← ${streamed.statusCode}: $bodyStr',
        name: 'ApiService');
 
    if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
      return decoded is Map<String, dynamic> ? decoded : {'success': true};
    }
 
    if (streamed.statusCode == 401) {
      throw ApiException('Session expired. Please login again.');
    }
 
    // Validation errors (422)
    if (streamed.statusCode == 422 && decoded is Map) {
      if (decoded['errors'] is Map) {
        final errors =
            Map<String, dynamic>.from(decoded['errors'] as Map);
        final firstKey =
            errors.keys.isNotEmpty ? errors.keys.first : null;
        if (firstKey != null &&
            errors[firstKey] is List &&
            (errors[firstKey] as List).isNotEmpty) {
          throw ApiException(
              (errors[firstKey] as List).first.toString());
        }
      }
      // Single message
      final msg = decoded['message']?.toString();
      if (msg != null && msg.isNotEmpty) throw ApiException(msg);
    }
 
    // Server errors (500)
    if (streamed.statusCode == 500) {
      final msg = (decoded is Map ? decoded['message']?.toString() : null) ??
          'Server error. Please try again or contact support.';
      throw ApiException(msg);
    }
 
    throw ApiException(
      (decoded is Map ? decoded['message']?.toString() : null) ??
          'Upload failed (HTTP ${streamed.statusCode})',
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LAYOUT APPROVAL PROGRESS
  // ══════════════════════════════════════════════════════════════════════════
 
  static Future<Map<String, String>> _layoutApprovalHeaders() async {
    final token = await AuthStorageService.getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }
 
  /// Fetch all Layout Approval stages with processes + summary for a project.
  static Future<List<LayoutApprovalStageModel>> fetchLayoutApprovalProgress(
      int projectId) async {
    final url = Uri.parse(ApiConstants.layoutApprovalIndex(projectId));
    developer.log('[ApiService] fetchLayoutApprovalProgress → GET $url',
        name: 'ApiService');
 
    try {
      final response = await http
          .get(url, headers: await _layoutApprovalHeaders())
          .timeout(ApiConstants.requestTimeout);
 
      final body = _decode(response.body);
      developer.log(
          '[ApiService] fetchLayoutApprovalProgress ← ${response.statusCode}',
          name: 'ApiService');
 
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = (body is Map ? body['data'] : null);
        if (raw is List) {
          return raw
              .whereType<Map>()
              .map((e) => LayoutApprovalStageModel.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList();
        }
        return [];
      }
 
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
 
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to load Layout Approval (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Layout Approval fetch error: $e');
    }
  }
 
  /// Fetch a single Layout Approval stage (lighter call on tab switch).
  static Future<LayoutApprovalStageModel> fetchLayoutApprovalStage(
      int projectId, String stageName) async {
    final url =
        Uri.parse(ApiConstants.layoutApprovalStage(projectId, stageName));
    developer.log('[ApiService] fetchLayoutApprovalStage → GET $url',
        name: 'ApiService');
 
    try {
      final response = await http
          .get(url, headers: await _layoutApprovalHeaders())
          .timeout(ApiConstants.requestTimeout);
 
      final body = _decode(response.body);
 
      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Build a stage model from the flat response
        return LayoutApprovalStageModel.fromJson(
          Map<String, dynamic>.from(body is Map ? body : {}),
        );
      }
 
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
 
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to load stage (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Fetch layout approval stage error: $e');
    }
  }
 
  /// Mark a process as Completed or N.A.
  static Future<Map<String, dynamic>> updateLayoutApprovalStatus({
    required int projectId,
    required int processId,
    required String status, // 'Completed' or 'N.A'
  }) async {
    developer.log(
        '[ApiService] updateLayoutApprovalStatus → projectId=$projectId processId=$processId status=$status',
        name: 'ApiService');
 
    try {
      final response = await _rawPost(
        fullUrl: ApiConstants.layoutApprovalUpdateStatus,
        body: {
          'project_id': projectId,
          'process_id': processId,
          'status': status,
        },
      );
 
      final decoded = _decode(response.body);
      developer.log(
          '[ApiService] updateLayoutApprovalStatus ← ${response.statusCode}',
          name: 'ApiService');
 
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded is Map<String, dynamic> ? decoded : {'success': true};
      }
 
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
 
      throw ApiException(
        (decoded is Map ? decoded['message']?.toString() : null) ??
            'Failed to update status (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Update layout approval status error: $e');
    }
  }
 
  /// Remove / reset a process status back to pending.
  static Future<Map<String, dynamic>> removeLayoutApprovalStatus({
    required int projectId,
    required int processId,
  }) async {
    developer.log(
        '[ApiService] removeLayoutApprovalStatus → projectId=$projectId processId=$processId',
        name: 'ApiService');
 
    try {
      final response = await _rawPost(
        fullUrl: ApiConstants.layoutApprovalRemoveStatus,
        body: {
          'project_id': projectId,
          'process_id': processId,
        },
      );
 
      final decoded = _decode(response.body);
      developer.log(
          '[ApiService] removeLayoutApprovalStatus ← ${response.statusCode}',
          name: 'ApiService');
 
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded is Map<String, dynamic> ? decoded : {'success': true};
      }
 
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
 
      throw ApiException(
        (decoded is Map ? decoded['message']?.toString() : null) ??
            'Failed to remove status (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Remove layout approval status error: $e');
    }
  }
 
  /// Upload a document file for a layout approval process item.
  static Future<Map<String, dynamic>> uploadLayoutApprovalFile({
    required int projectId,
    required int processId,
    required File file,
    required String fileName,
    required String uploadedDate, // yyyy-MM-dd
  }) async {
    final url = ApiConstants.layoutApprovalUploadFile;
 
    developer.log(
        '[ApiService] uploadLayoutApprovalFile → POST $url  '
        'project=$projectId process=$processId file=$fileName',
        name: 'ApiService');
 
    if (!file.existsSync()) {
      throw ApiException(
          'The selected file no longer exists. Please pick the file again.');
    }
 
    final token    = await AuthStorageService.getToken();
    final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
    final mimeParts = mimeType.split('/');
 
    final request = http.MultipartRequest('POST', Uri.parse(url))
      ..headers.addAll({
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      })
      ..fields['project_id']  = projectId.toString()
      ..fields['process_id']  = processId.toString()
      ..fields['upload_date'] = uploadedDate
      ..files.add(await http.MultipartFile.fromPath(
        'document',
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
        '[ApiService] uploadLayoutApprovalFile ← ${streamed.statusCode}: $bodyStr',
        name: 'ApiService');
 
    if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
      return decoded is Map<String, dynamic> ? decoded : {'success': true};
    }
 
    if (streamed.statusCode == 401) {
      throw ApiException('Session expired. Please login again.');
    }
 
    if (streamed.statusCode == 422 && decoded is Map) {
      if (decoded['errors'] is Map) {
        final errors    = Map<String, dynamic>.from(decoded['errors'] as Map);
        final firstKey  = errors.keys.isNotEmpty ? errors.keys.first : null;
        if (firstKey != null &&
            errors[firstKey] is List &&
            (errors[firstKey] as List).isNotEmpty) {
          throw ApiException((errors[firstKey] as List).first.toString());
        }
      }
      final msg = decoded['message']?.toString();
      if (msg != null && msg.isNotEmpty) throw ApiException(msg);
    }
 
    throw ApiException(
      (decoded is Map ? decoded['message']?.toString() : null) ??
          'Upload failed (HTTP ${streamed.statusCode})',
    );
  }
 
  /// Delete an uploaded file for a layout approval process item.
  static Future<Map<String, dynamic>> deleteLayoutApprovalFile({
    required int projectId,
    required int processId,
  }) async {
    developer.log(
        '[ApiService] deleteLayoutApprovalFile → projectId=$projectId processId=$processId',
        name: 'ApiService');
 
    try {
      final response = await _rawPost(
        fullUrl: ApiConstants.layoutApprovalDeleteFile,
        body: {
          'project_id': projectId,
          'process_id': processId,
        },
      );
 
      final decoded = _decode(response.body);
 
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded is Map<String, dynamic> ? decoded : {'success': true};
      }
 
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
 
      throw ApiException(
        (decoded is Map ? decoded['message']?.toString() : null) ??
            'Failed to delete file (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Delete layout approval file error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NOC MAP
  // ═══════════════════════════════════════════════════════════════════════════
 
  static Future<Map<String, String>> _nocMapHeaders() async {
    final token = await AuthStorageService.getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }
 
  /// Fetch full NOC map data for a project (summary + processes + gantt).
  static Future<NocMapDataModel> fetchNocMapData(int projectId) async {
    final url = Uri.parse(ApiConstants.nocMapIndex(projectId));
    developer.log('[ApiService] fetchNocMapData → GET $url', name: 'ApiService');
 
    try {
      final response = await http
          .get(url, headers: await _nocMapHeaders())
          .timeout(ApiConstants.requestTimeout);
 
      final body = _decode(response.body);
      developer.log('[ApiService] fetchNocMapData ← ${response.statusCode}',
          name: 'ApiService');
 
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return NocMapDataModel.fromJson(
            body is Map<String, dynamic> ? body : {'data': body});
      }
 
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
 
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to load NOC map (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('NOC Map fetch error: $e');
    }
  }
 
  /// Fetch filtered/searched NOC processes for a project.
  static Future<List<NocProcessModel>> fetchNocMapFiltered({
    required int projectId,
    String status = 'all',
    String search = '',
  }) async {
    final uri = Uri.parse(ApiConstants.nocMapFilter(projectId))
        .replace(queryParameters: {
      if (status != 'all') 'status': status,
      if (search.isNotEmpty) 'search': search,
    });
 
    developer.log('[ApiService] fetchNocMapFiltered → GET $uri',
        name: 'ApiService');
 
    try {
      final response = await http
          .get(uri, headers: await _nocMapHeaders())
          .timeout(ApiConstants.requestTimeout);
 
      final body = _decode(response.body);
 
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = (body is Map ? body['data'] : null) as List? ?? [];
        return raw
            .whereType<Map>()
            .map((e) => NocProcessModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
 
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
 
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Filter failed (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('NOC Map filter error: $e');
    }
  }
 
  // ═══════════════════════════════════════════════════════════════════════════
  // NOC ANALYTICS
  // ═══════════════════════════════════════════════════════════════════════════
 
  static Future<Map<String, String>> _nocAnalyticsHeaders() async {
    final token = await AuthStorageService.getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }
 
  /// Fetch overall NOC analytics stats across all projects.
  static Future<NocOverallStatsModel> fetchNocOverallStats() async {
    final url = Uri.parse(ApiConstants.nocAnalyticsOverallStats);
    developer.log('[ApiService] fetchNocOverallStats → GET $url',
        name: 'ApiService');
 
    try {
      final response = await http
          .get(url, headers: await _nocAnalyticsHeaders())
          .timeout(ApiConstants.requestTimeout);
 
      final body = _decode(response.body);
 
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return NocOverallStatsModel.fromJson(
            body is Map<String, dynamic> ? body : {});
      }
 
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
 
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to load stats (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('NOC Analytics stats error: $e');
    }
  }
 
  /// Fetch all projects with NOC analytics summary.
  static Future<List<NocProjectSummaryModel>> fetchNocAnalyticsProjects() async {
    final url = Uri.parse(ApiConstants.nocAnalyticsProjects);
    developer.log('[ApiService] fetchNocAnalyticsProjects → GET $url',
        name: 'ApiService');
 
    try {
      final response = await http
          .get(url, headers: await _nocAnalyticsHeaders())
          .timeout(ApiConstants.requestTimeout);
 
      final body = _decode(response.body);
 
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final raw = (body is Map ? body['data'] : null) as List? ?? [];
        return raw
            .whereType<Map>()
            .map((e) =>
                NocProjectSummaryModel.fromJson(Map<String, dynamic>.from(e)))
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
      throw ApiException('NOC Analytics projects error: $e');
    }
  }
 
  /// Fetch detailed analytics for a single project.
  static Future<NocAnalyticsDetailModel> fetchNocAnalyticsDetail(
      int projectId) async {
    final url = Uri.parse(ApiConstants.nocAnalyticsProjectDetail(projectId));
    developer.log('[ApiService] fetchNocAnalyticsDetail → GET $url',
        name: 'ApiService');
 
    try {
      final response = await http
          .get(url, headers: await _nocAnalyticsHeaders())
          .timeout(ApiConstants.requestTimeout);
 
      final body = _decode(response.body);
 
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return NocAnalyticsDetailModel.fromJson(
            body is Map<String, dynamic> ? body : {});
      }
 
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
 
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to load analytics (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('NOC Analytics detail error: $e');
    }
  }
 
  /// Fetch NOC list grouped by heading for a project.
  static Future<List<NocGroupedSectionModel>> fetchNocGroupedByHeading(
      int projectId) async {
    final url = Uri.parse(ApiConstants.nocAnalyticsGrouped(projectId));
    developer.log('[ApiService] fetchNocGroupedByHeading → GET $url',
        name: 'ApiService');
 
    try {
      final response = await http
          .get(url, headers: await _nocAnalyticsHeaders())
          .timeout(ApiConstants.requestTimeout);
 
      final body = _decode(response.body);
 
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = body is Map ? body['data'] : null;
        final raw  = (data is Map ? data['sections'] : null) as List? ?? [];
        return raw
            .whereType<Map>()
            .map((e) =>
                NocGroupedSectionModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
 
      if (response.statusCode == 401) {
        throw ApiException('Session expired. Please login again.');
      }
 
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed to load grouped data (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('NOC grouped fetch error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ALL TASKS
  // ═══════════════════════════════════════════════════════════════════════════
  //
  // These methods use the existing _getRequest() helper which is already
  // defined above in this class. Do NOT re-define _baseUrl, _headers,
  // _get, _handleResponse, or _tryDecode here — that causes duplicate
  // member errors.
  //
  // All paths are relative to ApiConstants.baseUrl.
  // ═══════════════════════════════════════════════════════════════════════════

  /// GET /api/mobile/all-tasks/teams
  static Future<List<TeamModel>> fetchAllTaskTeams() async {
    final body = await _getRequest(
      '${ApiConstants.baseUrl}/api/mobile/all-tasks/teams',
    );
    if (body['success'] != true) {
      throw ApiException(
          body['message']?.toString() ?? 'Failed to fetch teams.');
    }
    final list = body['data'] as List<dynamic>? ?? [];
    return list
        .whereType<Map>()
        .map((e) => TeamModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// GET /api/mobile/all-tasks/employees
  static Future<List<EmployeeModel>> fetchAllTaskEmployees() async {
    final body = await _getRequest(
      '${ApiConstants.baseUrl}/api/mobile/all-tasks/employees',
    );
    if (body['success'] != true) {
      throw ApiException(
          body['message']?.toString() ?? 'Failed to fetch employees.');
    }
    final list = body['data'] as List<dynamic>? ?? [];
    return list
        .whereType<Map>()
        .map((e) => EmployeeModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// GET /api/mobile/all-tasks/team-members?team_id=
  static Future<List<EmployeeModel>> fetchAllTaskTeamMembers(
      int teamId) async {
    final body = await _getRequest(
      '${ApiConstants.baseUrl}/api/mobile/all-tasks/team-members?team_id=$teamId',
    );
    if (body['success'] != true) {
      throw ApiException(
          body['message']?.toString() ?? 'Failed to fetch team members.');
    }
    final list = body['data'] as List<dynamic>? ?? [];
    return list
        .whereType<Map>()
        .map((e) => EmployeeModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// GET /api/mobile/all-tasks/list?user_id=&tab=&search=&page=&per_page=
  static Future<TaskListResult> fetchAllTasks({
    required int userId,
    String tab = 'all',
    String? search,
    int page = 1,
    int perPage = 15,
  }) async {
    final params = StringBuffer(
      '${ApiConstants.baseUrl}/api/mobile/all-tasks/list'
      '?user_id=$userId&tab=$tab&page=$page&per_page=$perPage',
    );
    if (search != null && search.isNotEmpty) {
      params.write('&search=${Uri.encodeQueryComponent(search)}');
    }
    final body = await _getRequest(params.toString());
    if (body['success'] != true) {
      throw ApiException(
          body['message']?.toString() ?? 'Failed to fetch tasks.');
    }
    return TaskListResult.fromJson(body);
  }

  /// GET /api/mobile/all-tasks/statistics?user_id=
  static Future<TaskStatsCombined> fetchAllTaskStatistics(int userId) async {
    final body = await _getRequest(
      '${ApiConstants.baseUrl}/api/mobile/all-tasks/statistics?user_id=$userId',
    );
    if (body['success'] != true) {
      throw ApiException(
          body['message']?.toString() ?? 'Failed to fetch statistics.');
    }
    
    return TaskStatsCombined.fromJson(
        body['data'] as Map<String, dynamic>? ?? {});
  }

  /// GET /api/mobile/all-tasks/detail?task_id=&task_type=
  static Future<Map<String, dynamic>> fetchAllTaskDetail({
    required int taskId,
    required String taskType,
  }) async {
    final body = await _getRequest(
      '${ApiConstants.baseUrl}/api/mobile/all-tasks/detail'
      '?task_id=$taskId&task_type=$taskType',
    );
    if (body['success'] != true) {
      throw ApiException(
          body['message']?.toString() ?? 'Failed to fetch task detail.');
    }
    return body['data'] as Map<String, dynamic>;
  }

  /// POST /api/mobile/all-tasks/upload
  static Future<bool> uploadAllTaskFile(
    int taskId,
    String taskType,
    File file,
  ) async {
    final url =
        '${ApiConstants.baseUrl}/api/mobile/all-tasks/upload';
    final token = await AuthStorageService.getToken();

    developer.log(
      '[ApiService] uploadAllTaskFile → POST $url taskId=$taskId taskType=$taskType',
      name: 'ApiService',
    );

    final mimeType =
        lookupMimeType(file.path) ?? 'application/octet-stream';
    final mimeParts = mimeType.split('/');

    final request =
        http.MultipartRequest('POST', Uri.parse(url))
          ..headers.addAll({
            'Accept': 'application/json',
            'X-Requested-With': 'XMLHttpRequest',
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          })
          ..fields['task_id'] = taskId.toString()
          ..fields['task_type'] = taskType
          ..files.add(await http.MultipartFile.fromPath(
            'file',
            file.path,
            contentType: MediaType(mimeParts[0], mimeParts[1]),
          ));

    late http.StreamedResponse streamed;
    try {
      streamed =
          await request.send().timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw ApiException('Upload timed out. Please try again.');
    } catch (e) {
      throw ApiException('Upload network error: $e');
    }

    final bodyStr = await streamed.stream.bytesToString();
    final decoded = _decode(bodyStr);

    developer.log(
      '[ApiService] uploadAllTaskFile ← ${streamed.statusCode}: $bodyStr',
      name: 'ApiService',
    );

    if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
      return decoded is Map && decoded['success'] == true;
    }
    if (streamed.statusCode == 401) {
      throw ApiException('Session expired. Please login again.');
    }
    if (streamed.statusCode == 422 && decoded is Map) {
      if (decoded['errors'] is Map) {
        final errors =
            Map<String, dynamic>.from(decoded['errors'] as Map);
        final firstKey =
            errors.keys.isNotEmpty ? errors.keys.first : null;
        if (firstKey != null &&
            errors[firstKey] is List &&
            (errors[firstKey] as List).isNotEmpty) {
          throw ApiException(
              (errors[firstKey] as List).first.toString());
        }
      }
    }
    throw ApiException(
      (decoded is Map ? decoded['message']?.toString() : null) ??
          'Upload failed (${streamed.statusCode})',
    );
  }

   // ═══════════════════════════════════════════════════════════════════════════
// EMPLOYEE REPORT  –  api_service.dart  (replace the three methods below)
// ═══════════════════════════════════════════════════════════════════════════

/// GET /api/mobile/employee-report/init
/// Returns users + teams for filter dropdowns.
static Future<Map<String, dynamic>> fetchEmployeeReportInit() async {
  final body = await _getRequest(ApiConstants.employeeReportInit);

  // Handle both { data: { users, teams } } and flat { users, teams } shapes
  final data = (body['data'] is Map<String, dynamic>)
      ? body['data'] as Map<String, dynamic>
      : body;

  final rawUsers = data['users'] as List<dynamic>? ?? [];
  final rawTeams = data['teams'] as List<dynamic>? ?? [];

  return {
    'users': rawUsers
        .whereType<Map<String, dynamic>>()
        .map(ReportUser.fromJson)
        .toList(),
    'teams': rawTeams
        .whereType<Map<String, dynamic>>()
        .map(ReportTeam.fromJson)
        .toList(),
  };
}

/// POST /api/mobile/employee-report/generate
/// Returns task-count matrix grouped by team.
static Future<EmployeeReportData> generateEmployeeReport({
  required String startDate,
  required String endDate,
  required List<String> employeeIds, // ['all'] or list of id strings
  String? teamId,                    // null | 'all' | numeric id string
}) async {
  try {
    // ── Build employee_ids payload ──────────────────────────────────────
    // The backend now accepts:
    //   • ['all']         → fetch every eligible employee
    //   • [1, 2, 3, ...]  → fetch specific employees
    // We ALWAYS send an array so Laravel's validation never chokes.
    final List<dynamic> employeeIdsPayload = employeeIds.contains('all')
        ? ['all']                                              // string inside array
        : employeeIds
            .map((id) => int.tryParse(id) ?? id)
            .toList();                                         // integers

    final body = <String, dynamic>{
      'start_date':   startDate,
      'end_date':     endDate,
      'employee_ids': employeeIdsPayload,
      // Only include team_id when it's a real numeric filter
      if (teamId != null && teamId != 'all') 'team_id': teamId,
    };

    developer.log(
      '[ApiService] generateEmployeeReport → POST '
      '${ApiConstants.employeeReportGenerate} body: $body',
      name: 'ApiService',
    );

    final response = await _rawPost(
      fullUrl: ApiConstants.employeeReportGenerate,
      body: body,
    );

    final decoded = _decode(response.body);

    developer.log(
      '[ApiService] generateEmployeeReport ← '
      '${response.statusCode}: ${response.body}',
      name: 'ApiService',
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return EmployeeReportData.fromJson(
        decoded is Map<String, dynamic> ? decoded : {},
      );
    }

    if (response.statusCode == 401) {
      throw ApiException('Session expired. Please login again.');
    }

    // Surface validation errors from Laravel
    if (decoded is Map && decoded['errors'] is Map) {
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
          'Failed to generate report (${response.statusCode})',
    );
  } on TimeoutException {
    throw ApiException('Request timed out. Please try again.');
  } catch (e) {
    if (e is ApiException) rethrow;
    throw ApiException('Generate employee report error: $e');
  }
}

/// POST /api/mobile/employee-report/task-details
/// Returns process + general tasks for a specific employee on a specific date.
static Future<TaskDetailResult> fetchEmployeeTaskDetails({
  required int employeeId,
  required String date,
}) async {
  try {
    developer.log(
      '[ApiService] fetchEmployeeTaskDetails → POST '
      '${ApiConstants.employeeReportDetails} '
      'employeeId=$employeeId date=$date',
      name: 'ApiService',
    );

    final response = await _rawPost(
      fullUrl: ApiConstants.employeeReportDetails,
      body: {
        'employee_id': employeeId,
        'date':        date,
      },
    );

    final decoded = _decode(response.body);

    developer.log(
      '[ApiService] fetchEmployeeTaskDetails ← '
      '${response.statusCode}: ${response.body}',
      name: 'ApiService',
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Handle both { data: { process_tasks, general_tasks } }
      // and flat { process_tasks, general_tasks } shapes.
      final payload =
          (decoded is Map && decoded['data'] is Map<String, dynamic>)
              ? decoded['data'] as Map<String, dynamic>
              : (decoded is Map<String, dynamic>
                  ? decoded
                  : <String, dynamic>{});
      return TaskDetailResult.fromJson(payload);
    }

    if (response.statusCode == 401) {
      throw ApiException('Session expired. Please login again.');
    }

    throw ApiException(
      (decoded is Map ? decoded['message']?.toString() : null) ??
          'Failed to load task details (${response.statusCode})',
    );
  } on TimeoutException {
    throw ApiException('Request timed out. Please try again.');
  } catch (e) {
    if (e is ApiException) rethrow;
    throw ApiException('Fetch task details error: $e');
  }
}

    // ═══════════════════════════════════════════════════════════════════════════
// PROJECT REPORT — add these methods inside ApiService class
// ═══════════════════════════════════════════════════════════════════════════

/// GET /api/mobile/project-report/projects
/// Returns the project list for the dropdown.
static Future<List<ReportProject>> fetchProjectReportProjects() async {
  final body = await _getRequest(ApiConstants.projectReportProjects);

  final rawList = (body['data'] is List)
      ? body['data'] as List<dynamic>
      : _extractList(body, ['data', 'projects']);

  return rawList
      .whereType<Map<String, dynamic>>()
      .map(ReportProject.fromJson)
      .toList();
}

/// GET /api/mobile/project-report/generate?project_id={id}
/// Returns team-wise task breakdown for the selected project.
static Future<ProjectReportData> generateProjectReport({
  required int projectId,
}) async {
  try {
    final url =
        '${ApiConstants.projectReportGenerate}?project_id=$projectId';

    developer.log(
      '[ApiService] generateProjectReport → GET $url',
      name: 'ApiService',
    );

    final body = await _getRequest(url);

    developer.log(
      '[ApiService] generateProjectReport ← success: ${body['success']}',
      name: 'ApiService',
    );

    if (body['success'] == true || body.containsKey('data')) {
      return ProjectReportData.fromJson(body);
    }

    throw ApiException(
      body['message']?.toString() ?? 'Failed to generate project report',
    );
  } on ApiException {
    rethrow;
  } catch (e) {
    throw ApiException('Generate project report error: $e');
  }
}

       // ═══════════════════════════════════════════════════════════════════════════
  // TEAM REPORT
  // ═══════════════════════════════════════════════════════════════════════════
 
  /// GET /api/mobile/team-report/teams
  /// Returns all teams for the filter dropdown.
  static Future<List<TeamReportTeamItem>> fetchTeamReportTeams() async {
    final body = await _getRequest(ApiConstants.teamReportTeams);
    final raw = _extractList(body, ['data', 'teams']);
    return raw
        .whereType<Map<String, dynamic>>()
        .map(TeamReportTeamItem.fromJson)
        .toList();
  }
 
  /// GET /api/mobile/team-report/members?team_id={id}
  /// Returns team leader + members for a selected team.
  static Future<List<TeamReportMemberItem>> fetchTeamReportMembers(
      int teamId) async {
    final url = '${ApiConstants.teamReportMembers}?team_id=$teamId';
    final body = await _getRequest(url);
    final raw = _extractList(body, ['data', 'members']);
    return raw
        .whereType<Map<String, dynamic>>()
        .map(TeamReportMemberItem.fromJson)
        .toList();
  }
 
  /// GET /api/mobile/team-report/generate?team_id={id}&member_id={id?}&page=&per_page=&search=
  /// Generates the team-wise project report.
  static Future<TeamReportResult> generateTeamReport({
    required int teamId,
    int? memberId,
    int page = 1,
    int perPage = 20,
    String search = '',
  }) async {
    final params = StringBuffer(
      '${ApiConstants.teamReportGenerate}'
      '?team_id=$teamId&page=$page&per_page=$perPage',
    );
    if (memberId != null) params.write('&member_id=$memberId');
    if (search.isNotEmpty) {
      params.write('&search=${Uri.encodeQueryComponent(search)}');
    }
 
    developer.log(
      '[ApiService] generateTeamReport → GET $params',
      name: 'ApiService',
    );
 
    final body = await _getRequest(params.toString());
 
    if (body['success'] == true || body.containsKey('data')) {
      return TeamReportResult.fromJson(body);
    }
 
    throw ApiException(
      body['message']?.toString() ?? 'Failed to generate team report',
    );
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
          .get(Uri.parse(url), headers: await _authHeaders())
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
            headers: await _authHeaders(),
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
          .get(Uri.parse(url), headers: await _authHeaders())
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
          .get(Uri.parse(url), headers: await _authHeaders())
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

  // ═══════════════════════════════════════════════════════════════════════════
// RE-DEVELOPMENT PROCESS (PROCESS MANAGEMENT)
// ═══════════════════════════════════════════════════════════════════════════

static Future<Map<String, String>> _processHeaders() async {
  final token = await AuthStorageService.getToken();
  return {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'X-Requested-With': 'XMLHttpRequest',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };
}

/// Fetch all processes for a given stage from the mobile API.
/// GET /api/mobile/processes?stage={stage}
static Future<List<ProcessModel>> fetchProcesses({String? stage}) async {
  // FIX: was `const` — string interpolation makes this non-constant
  final buffer = StringBuffer('${ApiConstants.baseUrl}/api/mobile/processes');
  if (stage != null && stage.isNotEmpty) {
    buffer.write('?stage=$stage');
  }
  final url = buffer.toString();

  developer.log('[ProcessApi] fetchProcesses → GET $url', name: 'ProcessApi');

  try {
    final response = await http
        .get(Uri.parse(url), headers: await _processHeaders())
        .timeout(ApiConstants.requestTimeout);

    final body = _decode(response.body);

    developer.log(
      '[ProcessApi] fetchProcesses ← ${response.statusCode}',
      name: 'ProcessApi',
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      List<dynamic> raw = [];
      if (body is Map) {
        raw = (body['data'] as List?) ??
            (body['processes'] as List?) ??
            (body['items'] as List?) ??
            [];
      } else if (body is List) {
        raw = body;
      }
      return raw
          .whereType<Map<String, dynamic>>()
          .map(ProcessModel.fromJson)
          .toList();
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
    throw ApiException('Fetch processes error: $e');
  }
}

/// Fetch teams for process assignment dropdowns.
/// GET /api/mobile/processes/teams
static Future<List<ProcessTeamModel>> fetchProcessTeams() async {
  // FIX: was `const` — string interpolation makes this non-constant
  final url = '${ApiConstants.baseUrl}/api/mobile/processes/teams';
  developer.log('[ProcessApi] fetchProcessTeams → GET $url', name: 'ProcessApi');

  try {
    final response = await http
        .get(Uri.parse(url), headers: await _processHeaders())
        .timeout(ApiConstants.requestTimeout);

    final body = _decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      List<dynamic> raw = [];
      if (body is Map) {
        raw = (body['teams'] as List?) ?? (body['data'] as List?) ?? [];
      } else if (body is List) {
        raw = body;
      }
      return raw
          .whereType<Map<String, dynamic>>()
          .map(ProcessTeamModel.fromJson)
          .toList();
    }

    if (response.statusCode == 401) {
      throw ApiException('Session expired. Please login again.');
    }

    throw ApiException(
      (body is Map ? body['message']?.toString() : null) ??
          'Failed to load teams (${response.statusCode})',
    );
  } on TimeoutException {
    throw ApiException('Request timed out. Please try again.');
  } catch (e) {
    if (e is ApiException) rethrow;
    throw ApiException('Fetch process teams error: $e');
  }
}

/// Create a new process.
/// POST /api/mobile/processes
static Future<Map<String, dynamic>> createProcess({
  required String processName,
  required int workingTeam,
  required String stage,
  int? day,
}) async {
  // FIX: was `const` — string interpolation makes this non-constant
  final url = '${ApiConstants.baseUrl}/api/mobile/processes';
  developer.log('[ProcessApi] createProcess → POST $url', name: 'ProcessApi');

  try {
    final response = await http
        .post(
          Uri.parse(url),
          headers: await _processHeaders(),
          body: jsonEncode({
            'process_name': processName,
            'working_team': workingTeam,
            'stage': stage,
            if (day != null) 'day': day,
          }),
        )
        .timeout(ApiConstants.requestTimeout);

    final body = _decode(response.body);

    developer.log(
      '[ProcessApi] createProcess ← ${response.statusCode}: ${response.body}',
      name: 'ProcessApi',
    );

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
          'Failed to create process (${response.statusCode})',
    );
  } on TimeoutException {
    throw ApiException('Request timed out. Please try again.');
  } catch (e) {
    if (e is ApiException) rethrow;
    throw ApiException('Create process error: $e');
  }
}

/// Fetch a single process for editing.
/// GET /api/mobile/processes/{orderNo}
static Future<ProcessModel> fetchProcessForEdit(int orderNo) async {
  // FIX: was `const` — string interpolation makes this non-constant
  final url = '${ApiConstants.baseUrl}/api/mobile/processes/$orderNo';
  developer.log('[ProcessApi] fetchProcessForEdit → GET $url', name: 'ProcessApi');

  try {
    final response = await http
        .get(Uri.parse(url), headers: await _processHeaders())
        .timeout(ApiConstants.requestTimeout);

    final body = _decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final raw = (body is Map ? (body['data'] ?? body['process'] ?? body) : body);
      if (raw is Map<String, dynamic>) {
        return ProcessModel.fromJson(raw);
      }
      throw ApiException('Unexpected response format.');
    }

    if (response.statusCode == 401) {
      throw ApiException('Session expired. Please login again.');
    }

    throw ApiException(
      (body is Map ? body['message']?.toString() : null) ??
          'Process not found (${response.statusCode})',
    );
  } on TimeoutException {
    throw ApiException('Request timed out. Please try again.');
  } catch (e) {
    if (e is ApiException) rethrow;
    throw ApiException('Fetch process error: $e');
  }
}

/// Update a process.
/// POST /api/mobile/processes/{orderNo}/update
static Future<Map<String, dynamic>> updateProcess({
  required int orderNo,
  required String processName,
  required int workingTeam,
  required String stage,
  int? day,
}) async {
  // FIX: was `const` — string interpolation makes this non-constant
  final url = '${ApiConstants.baseUrl}/api/mobile/processes/$orderNo/update';
  developer.log('[ProcessApi] updateProcess → POST $url', name: 'ProcessApi');

  try {
    final response = await http
        .post(
          Uri.parse(url),
          headers: await _processHeaders(),
          body: jsonEncode({
            'process_name': processName,
            'working_team': workingTeam,
            'stage': stage,
            if (day != null) 'day': day,
          }),
        )
        .timeout(ApiConstants.requestTimeout);

    final body = _decode(response.body);

    developer.log(
      '[ProcessApi] updateProcess ← ${response.statusCode}: ${response.body}',
      name: 'ProcessApi',
    );

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
          'Failed to update process (${response.statusCode})',
    );
  } on TimeoutException {
    throw ApiException('Request timed out. Please try again.');
  } catch (e) {
    if (e is ApiException) rethrow;
    throw ApiException('Update process error: $e');
  }
}

/// Delete a process.
/// POST /api/mobile/processes/{orderNo}/delete
static Future<Map<String, dynamic>> deleteProcess(int orderNo) async {
  // FIX: was `const` — string interpolation makes this non-constant
  final url = '${ApiConstants.baseUrl}/api/mobile/processes/$orderNo/delete';
  developer.log('[ProcessApi] deleteProcess → POST $url', name: 'ProcessApi');

  try {
    final response = await http
        .post(
          Uri.parse(url),
          headers: await _processHeaders(),
          body: jsonEncode({}),
        )
        .timeout(ApiConstants.requestTimeout);

    final body = _decode(response.body);

    developer.log(
      '[ProcessApi] deleteProcess ← ${response.statusCode}',
      name: 'ProcessApi',
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body is Map<String, dynamic> ? body : {'success': true};
    }

    if (response.statusCode == 401) {
      throw ApiException('Session expired. Please login again.');
    }

    throw ApiException(
      (body is Map ? body['message']?.toString() : null) ??
          'Failed to delete process (${response.statusCode})',
    );
  } on TimeoutException {
    throw ApiException('Request timed out. Please try again.');
  } catch (e) {
    if (e is ApiException) rethrow;
    throw ApiException('Delete process error: $e');
  }
}

/// Update the review team for a process.
/// POST /api/mobile/processes/{orderNo}/update-team
static Future<Map<String, dynamic>> updateProcessTeam({
  required int orderNo,
  required int teamId,
}) async {
  // FIX: was `const` — string interpolation makes this non-constant
  final url = '${ApiConstants.baseUrl}/api/mobile/processes/$orderNo/update-team';
  developer.log('[ProcessApi] updateProcessTeam → POST $url', name: 'ProcessApi');

  try {
    final response = await http
        .post(
          Uri.parse(url),
          headers: await _processHeaders(),
          body: jsonEncode({'team_id': teamId}),
        )
        .timeout(ApiConstants.requestTimeout);

    final body = _decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body is Map<String, dynamic> ? body : {'success': true};
    }

    if (response.statusCode == 401) {
      throw ApiException('Session expired. Please login again.');
    }

    throw ApiException(
      (body is Map ? body['message']?.toString() : null) ??
          'Failed to update team (${response.statusCode})',
    );
  } on TimeoutException {
    throw ApiException('Request timed out. Please try again.');
  } catch (e) {
    if (e is ApiException) rethrow;
    throw ApiException('Update process team error: $e');
  }
}

// ════════════════════════════════════════════════════════════════════════════
  // DEVELOPMENT PROCESS — correct http-package implementation
  // ════════════════════════════════════════════════════════════════════════════
 
  /// Fetch all processes for a given stage (0–3).
  /// GET /api/mobile/development-process/processes?stage={stage}
  static Future<List<DevProcessModel>> fetchDevProcesses({int stage = 0}) async {
    final uri = Uri.parse(ApiConstants.devProcessList)
        .replace(queryParameters: {'stage': '$stage'});
 
    developer.log('[DevProcess] fetchDevProcesses → GET $uri',
        name: 'ApiService');
 
    try {
      final response = await http
          .get(uri, headers: await _authHeaders())
          .timeout(ApiConstants.requestTimeout);
 
      final body = _decode(response.body);
 
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final list = (body is Map ? body['processes'] : null) as List<dynamic>? ?? [];
        return list
            .whereType<Map<String, dynamic>>()
            .map(DevProcessModel.fromJson)
            .toList();
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
      throw ApiException('fetchDevProcesses error: $e');
    }
  }
 
  /// Fetch all stages with process counts (for tab badges).
  /// GET /api/mobile/development-process/all-stages
  static Future<List<DevProcessStageModel>> fetchDevProcessAllStages() async {
    developer.log('[DevProcess] fetchDevProcessAllStages → GET',
        name: 'ApiService');
    try {
      final response = await http
          .get(Uri.parse(ApiConstants.devProcessAllStages),
              headers: await _authHeaders())
          .timeout(ApiConstants.requestTimeout);
 
      final body = _decode(response.body);
 
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final stages =
            (body is Map ? body['stages'] : null) as List<dynamic>? ?? [];
        return stages
            .whereType<Map<String, dynamic>>()
            .map(DevProcessStageModel.fromJson)
            .toList();
      }
      if (response.statusCode == 401) throw ApiException('Session expired.');
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('fetchDevProcessAllStages error: $e');
    }
  }
 
  /// Fetch all teams for the team picker.
  /// GET /api/mobile/development-process/teams
  static Future<List<DevProcessTeamModel>> fetchDevProcessTeams() async {
    developer.log('[DevProcess] fetchDevProcessTeams → GET', name: 'ApiService');
    try {
      final response = await http
          .get(Uri.parse(ApiConstants.devProcessTeams),
              headers: await _authHeaders())
          .timeout(ApiConstants.requestTimeout);
 
      final body = _decode(response.body);
 
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final teams =
            (body is Map ? body['teams'] : null) as List<dynamic>? ?? [];
        return teams
            .whereType<Map<String, dynamic>>()
            .map(DevProcessTeamModel.fromJson)
            .toList();
      }
      if (response.statusCode == 401) throw ApiException('Session expired.');
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('fetchDevProcessTeams error: $e');
    }
  }
 
  /// Get the next suggested order number for a stage.
  /// GET /api/mobile/development-process/max-order?stage={stage}
  static Future<int> fetchDevProcessNextOrder({int stage = 0}) async {
    final uri = Uri.parse(ApiConstants.devProcessMaxOrder)
        .replace(queryParameters: {'stage': '$stage'});
 
    try {
      final response = await http
          .get(uri, headers: await _authHeaders())
          .timeout(ApiConstants.requestTimeout);
 
      final body = _decode(response.body);
 
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return (body is Map ? (body['next_order'] as num?)?.toInt() : null) ?? 1;
      }
      if (response.statusCode == 401) throw ApiException('Session expired.');
      throw ApiException('Failed (${response.statusCode})');
    } on TimeoutException {
      throw ApiException('Request timed out.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('fetchDevProcessNextOrder error: $e');
    }
  }
 
  /// Create a new development process.
  /// POST /api/mobile/development-process/store
  static Future<void> addDevProcess({
    required String processName,
    required int teamId,
    required int stage,
    required int orderNo,
  }) async {
    developer.log('[DevProcess] addDevProcess → POST', name: 'ApiService');
    try {
      final response = await http
          .post(
            Uri.parse(ApiConstants.devProcessStore),
            headers: await _authHeaders(),
            body: jsonEncode({
              'process_name': processName,
              'team_id':      teamId,
              'stage':        stage,
              'order_no':     orderNo,
            }),
          )
          .timeout(ApiConstants.requestTimeout);
 
      final body = _decode(response.body);
 
      if (response.statusCode >= 200 && response.statusCode < 300) return;
      if (response.statusCode == 401) throw ApiException('Session expired.');
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
            'Failed (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('addDevProcess error: $e');
    }
  }
 
  /// Fetch a single process by processId (for pre-filling edit form).
  /// GET /api/mobile/development-process/edit/{processId}
  static Future<Map<String, dynamic>> fetchDevProcessById(int processId) async {
    developer.log('[DevProcess] fetchDevProcessById → GET processId=$processId',
        name: 'ApiService');
    try {
      final response = await http
          .get(Uri.parse(ApiConstants.devProcessEdit(processId)),
              headers: await _authHeaders())
          .timeout(ApiConstants.requestTimeout);
 
      final body = _decode(response.body);
 
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return body is Map<String, dynamic> ? body : <String, dynamic>{};
      }
      if (response.statusCode == 401) throw ApiException('Session expired.');
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Process not found (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('fetchDevProcessById error: $e');
    }
  }
 
  /// Update an existing development process.
  /// POST /api/mobile/development-process/update
  static Future<void> updateDevProcess({
    required int processId,
    required String processName,
    required int teamId,
    required int stage,
    required int orderNo,
  }) async {
    developer.log('[DevProcess] updateDevProcess → POST processId=$processId',
        name: 'ApiService');
    try {
      final response = await http
          .post(
            Uri.parse(ApiConstants.devProcessUpdate),
            headers: await _authHeaders(),
            body: jsonEncode({
              'process_id':   processId,
              'process_name': processName,
              'team_id':      teamId,
              'stage':        stage,
              'order_no':     orderNo,
            }),
          )
          .timeout(ApiConstants.requestTimeout);
 
      final body = _decode(response.body);
 
      if (response.statusCode >= 200 && response.statusCode < 300) return;
      if (response.statusCode == 401) throw ApiException('Session expired.');
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
            'Failed (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('updateDevProcess error: $e');
    }
  }
 
  /// Delete a development process by processId.
  /// DELETE /api/mobile/development-process/delete/{processId}
  static Future<void> deleteDevProcess(int processId) async {
    developer.log('[DevProcess] deleteDevProcess → DELETE processId=$processId',
        name: 'ApiService');
    try {
      final response = await http
          .delete(
            Uri.parse(ApiConstants.devProcessDelete(processId)),
            headers: await _authHeaders(),
          )
          .timeout(ApiConstants.requestTimeout);
 
      final body = _decode(response.body);
 
      if (response.statusCode >= 200 && response.statusCode < 300) return;
      if (response.statusCode == 401) throw ApiException('Session expired.');
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('deleteDevProcess error: $e');
    }
  }
 
  /// Fetch processes grouped by stage for a specific project (role-aware).
  /// GET /api/mobile/development-process/project/{projectId}
  static Future<Map<String, dynamic>> fetchDevProjectProcesses(
      int projectId) async {
    developer.log(
        '[DevProcess] fetchDevProjectProcesses → GET projectId=$projectId',
        name: 'ApiService');
    try {
      final response = await http
          .get(Uri.parse(ApiConstants.devProcessProject(projectId)),
              headers: await _authHeaders())
          .timeout(ApiConstants.requestTimeout);
 
      final body = _decode(response.body);
 
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return body is Map<String, dynamic> ? body : <String, dynamic>{};
      }
      if (response.statusCode == 401) throw ApiException('Session expired.');
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('fetchDevProjectProcesses error: $e');
    }
  }
 
  /// Assign a development process to a user for a project.
  /// POST /api/mobile/development-process/assign
  static Future<void> assignDevProcess({
    required int projectId,
    required int processId,
    required int assignedTo,
    String? deadline,
  }) async {
    developer.log('[DevProcess] assignDevProcess → POST', name: 'ApiService');
 
    final payload = <String, dynamic>{
      'project_id':  projectId,
      'process_id':  processId,
      'assigned_to': assignedTo,
      if (deadline != null) 'deadline': deadline,
    };
 
    try {
      final response = await http
          .post(
            Uri.parse(ApiConstants.devProcessAssign),
            headers: await _authHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(ApiConstants.requestTimeout);
 
      final body = _decode(response.body);
 
      if (response.statusCode >= 200 && response.statusCode < 300) return;
      if (response.statusCode == 401) throw ApiException('Session expired.');
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('assignDevProcess error: $e');
    }
  }
 
  /// Fetch team members for a given team (for assignment picker).
  /// GET /api/mobile/development-process/team-members/{teamId}
  static Future<List<Map<String, dynamic>>> fetchDevProcessTeamMembers(
      int teamId) async {
    developer.log(
        '[DevProcess] fetchDevProcessTeamMembers → GET teamId=$teamId',
        name: 'ApiService');
    try {
      final response = await http
          .get(Uri.parse(ApiConstants.devProcessTeamMembers(teamId)),
              headers: await _authHeaders())
          .timeout(ApiConstants.requestTimeout);
 
      final body = _decode(response.body);
 
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final members =
            (body is Map ? body['members'] : null) as List<dynamic>? ?? [];
        return members
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      }
      if (response.statusCode == 401) throw ApiException('Session expired.');
      throw ApiException(
        (body is Map ? body['message']?.toString() : null) ??
            'Failed (${response.statusCode})',
      );
    } on TimeoutException {
      throw ApiException('Request timed out.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('fetchDevProcessTeamMembers error: $e');
    }
  }

}