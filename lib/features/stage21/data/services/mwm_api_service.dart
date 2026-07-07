// lib/features/stage21/data/services/mwm_api_service.dart
//
// UPDATED: Cement + Steel dual-type support.
// Multi-photo arrays sent as files[i][field][] and captured[i][field][].

import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../../../../core/constants/api_constants.dart';
import '../../../../core/services/auth_storage_service.dart';
import '../models/material_weight_measurement_model.dart';

class MwmApiService {
  MwmApiService._();

  static String _base(int projectId) =>
      '${ApiConstants.baseUrl}/api/mobile/mwm/$projectId';

  static Future<Map<String, String>> _headers() async {
    final token = await AuthStorageService.getToken();
    return {
      'Accept': 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── List ───────────────────────────────────────────────────────────────────

  static Future<List<MwmListModel>> fetchList(int projectId) async {
    final res = await http.get(
      Uri.parse(_base(projectId)),
      headers: await _headers(),
    );
    _assertOk(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['success'] != true) throw Exception(body['message'] ?? 'Failed');
    final records = body['records'] as List? ?? [];
    return records
        .whereType<Map<String, dynamic>>()
        .map(MwmListModel.fromJson)
        .toList();
  }

  // ── Detail ─────────────────────────────────────────────────────────────────

  static Future<MwmDetailModel> fetchDetail(int projectId, int id) async {
    final url = '${_base(projectId)}/$id';
    developer.log('MWM fetchDetail → GET $url', name: 'MwmApiService');
    final res = await http.get(Uri.parse(url), headers: await _headers());
    _assertOk(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['success'] != true) throw Exception(body['message'] ?? 'Failed');
    return MwmDetailModel.fromJson(body['record'] as Map<String, dynamic>);
  }

  // ── Edit prefill ───────────────────────────────────────────────────────────

  static Future<MwmEditModel> fetchEdit(int projectId, int id) async {
    final res = await http.get(
      Uri.parse('${_base(projectId)}/$id/edit'),
      headers: await _headers(),
    );
    _assertOk(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['success'] != true) throw Exception(body['message'] ?? 'Failed');
    return MwmEditModel.fromJson(body['record'] as Map<String, dynamic>);
  }

  // ── Create meta ────────────────────────────────────────────────────────────

  static Future<Map<String, String>> fetchCreateMeta(int projectId) async {
    final res = await http.get(
      Uri.parse('${_base(projectId)}/create'),
      headers: await _headers(),
    );
    _assertOk(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return {
      'mwm_no': body['mwm_no']?.toString() ?? '',
      'today': body['today']?.toString() ?? '',
    };
  }

  // ── Material types ─────────────────────────────────────────────────────────

  static Future<List<MwmMaterialTypeModel>> fetchMaterialTypes() async {
    final res = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/api/mobile/mwm/material-types'),
      headers: await _headers(),
    );
    _assertOk(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['success'] != true) throw Exception(body['message'] ?? 'Failed');
    final types = body['types'] as List? ?? [];
    return types
        .whereType<Map<String, dynamic>>()
        .map(MwmMaterialTypeModel.fromJson)
        .toList();
  }

  // ── Create ─────────────────────────────────────────────────────────────────

  static Future<void> create(
    int projectId, {
    required String? remarks,
    required List<MwmEntryForm> entries,
  }) async {
    final req = http.MultipartRequest('POST', Uri.parse(_base(projectId)));
    req.headers.addAll(await _headers());

    final fields = <String, String>{};
    if (remarks != null && remarks.isNotEmpty) fields['remarks'] = remarks;
    for (var i = 0; i < entries.length; i++) {
      fields.addAll(_entryFields(i, entries[i]));
    }
    req.fields.addAll(fields);

    for (var i = 0; i < entries.length; i++) {
      await _attachEntryFiles(req, i, entries[i]);
    }

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    _assertOk(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['success'] != true) throw Exception(_extractError(body));
  }

  // ── Update ─────────────────────────────────────────────────────────────────

  static Future<void> update(
    int projectId,
    int id, {
    required String? remarks,
    required List<MwmEntryForm> entries,
    required List<int> removedOriginalIndices,
  }) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('${_base(projectId)}/$id/update'),
    );
    req.headers.addAll(await _headers());

    final fields = <String, String>{};
    if (remarks != null && remarks.isNotEmpty) fields['remarks'] = remarks;

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      fields.addAll(_entryFields(i, entry));
      fields['existing_index[$i]'] = entry.originalIndex?.toString() ?? 'new';

      if (entry.isSteel) {
        if (entry.grossWeightSlip.removed) {
          fields['removed_photos[$i][gross_weight_slip][]'] = '';
        }
        if (entry.vehicleWithMaterialImage.removed) {
          fields['removed_photos[$i][vehicle_with_material_image][]'] = '';
        }
        if (entry.tareWeightSlip.removed) {
          fields['removed_photos[$i][tare_weight_slip][]'] = '';
        }
      } else {
        if (entry.orderedBagReceiptImage.removed) {
          fields['removed_photos[$i][ordered_bag_receipt_image][]'] = '';
        }
        if (entry.receivedBagImage.removed) {
          fields['removed_photos[$i][received_bag_image][]'] = '';
        }
      }
    }

    for (final origIdx in removedOriginalIndices) {
      fields['removed_indices[]'] = origIdx.toString();
    }
    req.fields.addAll(fields);

    for (var i = 0; i < entries.length; i++) {
      await _attachEntryFiles(req, i, entries[i]);
    }

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    _assertOk(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['success'] != true) throw Exception(_extractError(body));
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  static Future<void> delete(int projectId, int id) async {
    final headers = await _headers();
    final res = await http.post(
      Uri.parse('${_base(projectId)}/$id'),
      headers: {...headers, 'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'_method': 'DELETE'},
    );
    _assertOk(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['success'] != true) throw Exception(body['message'] ?? 'Delete failed');
  }

  // ── Download URL ───────────────────────────────────────────────────────────

  static String downloadUrl(int projectId, int id) =>
      '${_base(projectId)}/$id/download';

  // ── Helpers ────────────────────────────────────────────────────────────────

  static Map<String, String> _entryFields(int i, MwmEntryForm e) {
    final fields = <String, String>{
      'entries[$i][entry_type]': e.entryType.value,
      'entries[$i][vehicle_number]': e.vehicleNumber,
      'entries[$i][challan_number]': e.challanNumber,
      'entries[$i][material_type_id]': e.materialType?.id.toString() ?? '',
    };

    if (e.isSteel) {
      fields['entries[$i][gross_weight]'] = e.grossWeight.toString();
      fields['entries[$i][tare_weight]'] = e.tareWeight.toString();
      void addGeo(String slot, MwmFileSlot slot_) {
        if (slot_.geo != null) {
          fields['geo[$i][$slot][]'] = jsonEncode(slot_.geo!.toJson());
        }
      }
      addGeo('gross_weight_slip', e.grossWeightSlip);
      addGeo('vehicle_with_material_image', e.vehicleWithMaterialImage);
      addGeo('tare_weight_slip', e.tareWeightSlip);
    } else {
      fields['entries[$i][total_ordered_bags]'] = e.totalOrderedBags.toString();
      fields['entries[$i][total_received_bags]'] = e.totalReceivedBags.toString();
      void addGeo(String slot, MwmFileSlot slot_) {
        if (slot_.geo != null) {
          fields['geo[$i][$slot][]'] = jsonEncode(slot_.geo!.toJson());
        }
      }
      addGeo('ordered_bag_receipt_image', e.orderedBagReceiptImage);
      addGeo('received_bag_image', e.receivedBagImage);
    }

    return fields;
  }

  static Future<void> _attachEntryFiles(
    http.MultipartRequest req,
    int i,
    MwmEntryForm e,
  ) async {
    Future<void> addFile(String slot, MwmFileSlot fileSlot) async {
      final file = fileSlot.newFile;
      if (file == null) return;
      // Send as array element: files[i][slot][]
      req.files.add(
        await http.MultipartFile.fromPath('files[$i][$slot][]', file.path),
      );
    }

    if (e.isSteel) {
      await addFile('gross_weight_slip', e.grossWeightSlip);
      await addFile('vehicle_with_material_image', e.vehicleWithMaterialImage);
      await addFile('tare_weight_slip', e.tareWeightSlip);
    } else {
      await addFile('ordered_bag_receipt_image', e.orderedBagReceiptImage);
      await addFile('received_bag_image', e.receivedBagImage);
    }
  }

  static void _assertOk(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String msg = 'Server error (${res.statusCode})';
      try {
        final b = jsonDecode(res.body) as Map<String, dynamic>;
        msg = _extractError(b);
      } catch (_) {}
      throw Exception(msg);
    }
  }

  static String _extractError(Map<String, dynamic> body) {
    if (body['errors'] is Map) {
      final errs = body['errors'] as Map;
      final msgs = errs.values
          .expand((v) => v is List ? v : [v])
          .map((e) => e.toString())
          .take(3)
          .join(', ');
      return msgs.isNotEmpty ? msgs : (body['message']?.toString() ?? 'Error');
    }
    return body['message']?.toString() ?? 'An error occurred';
  }
}