// lib/features/stage21/data/services/mwm_audit_trail_service.dart
//
// Fetches Audit Trail – Removed Entries from:
//   GET /api/mobile/mwm/{projectId}/deleted-entries
//
// Route registered in api.php:
//   Route::get('/{projectId}/deleted-entries',
//       [MobileMaterialWeightMeasurementController::class, 'deletedEntries']);
//
// The backend returns all MwmDeletedEntry rows for the project, ordered by
// deleted_at DESC. No server-side pagination is implemented on this endpoint,
// so we load all rows and paginate / filter client-side.

import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../../../../core/constants/api_constants.dart';
import '../../../../core/services/auth_storage_service.dart';
import '../models/mwm_deleted_entry_model.dart';

class MwmAuditTrailService {
  MwmAuditTrailService._();

  // ── URL builder ─────────────────────────────────────────────────────────────

  static String _url(int projectId) =>
      '${ApiConstants.baseUrl}/api/mobile/mwm/$projectId/deleted-entries';

  // ── Auth headers ─────────────────────────────────────────────────────────────

  static Future<Map<String, String>> _headers() async {
    final token = await AuthStorageService.getToken();
    return {
      'Accept': 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Fetch deleted entries ────────────────────────────────────────────────────

  /// Returns all audit-trail entries for [projectId] ordered by removal time
  /// descending (mirrors the backend ORDER BY deleted_at DESC).
  static Future<List<MwmDeletedEntryModel>> fetchDeletedEntries(
      int projectId) async {
    final url = _url(projectId);
    developer.log('MwmAuditTrail → GET $url', name: 'MwmAuditTrailService');

    final res = await http.get(
      Uri.parse(url),
      headers: await _headers(),
    );

    _assertOk(res);

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['success'] != true) {
      throw Exception(body['message']?.toString() ?? 'Failed to load audit trail');
    }

    final entries = body['entries'] as List? ?? [];
    return entries
        .whereType<Map<String, dynamic>>()
        .map(MwmDeletedEntryModel.fromJson)
        .toList();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static void _assertOk(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String msg = 'Server error (${res.statusCode})';
      try {
        final b = jsonDecode(res.body) as Map<String, dynamic>;
        msg = b['message']?.toString() ?? msg;
      } catch (_) {}
      throw Exception(msg);
    }
  }
}