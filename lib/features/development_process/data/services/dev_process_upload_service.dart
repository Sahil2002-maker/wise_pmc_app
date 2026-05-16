// lib/features/development_process/data/services/dev_process_upload_service.dart
//
// Dedicated service for S3 document upload and signed-URL retrieval
// in the Development Process module.
//
// Endpoints used (from MobileDevelopmentProcessController):
//   POST  /api/mobile/development-process/{projectId}/upload
//         Fields: file (multipart), process_id (int), order_no (int)
//         Returns: { success, file_path, file_name, file_size, mime_type }
//
//   GET   /api/mobile/development-process/file-url?path={s3_key}
//         Returns: { success, url }  — pre-signed S3 URL (60 min TTL)

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'dart:convert';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/services/auth_storage_service.dart';
import '../../../../core/utils/api_exception.dart';

class DevProcessUploadService {
  DevProcessUploadService._();

  // ── Shared auth header builder ──────────────────────────────────────────────

  static Future<Map<String, String>> _headers({bool multipart = false}) async {
    final token = await AuthStorageService.getToken();
    return {
      'Accept': 'application/json',
      if (!multipart) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // ── Upload document to S3 via Laravel ──────────────────────────────────────

  /// Uploads [file] for the given [processId] / [orderNo] under [projectId].
  ///
  /// Returns a map with:
  ///   { file_path, file_name, file_size, mime_type }
  ///
  /// [file_path] is the private S3 key; pass it to [getFileUrl] to get a
  /// pre-signed download URL.
  ///
  /// Throws [ApiException] on any failure.
  static Future<Map<String, dynamic>> uploadDocument({
    required int projectId,
    required int processId,
    required int orderNo,
    required File file,
    /// Override the displayed file name. Defaults to the file's basename.
    String? fileName,
  }) async {
    final url = ApiConstants.devProcessUpload(projectId);
    final name = fileName ?? file.path.split('/').last;

    developer.log(
      '[DevProcessUpload] uploadDocument → POST $url '
      'projectId=$projectId processId=$processId orderNo=$orderNo file=$name',
      name: 'DevProcessUpload',
    );

    // Guard: file must actually exist before we try to send it.
    if (!file.existsSync()) {
      throw ApiException(
        'The selected file no longer exists. Please pick the file again.',
      );
    }

    final token     = await AuthStorageService.getToken();
    final mimeType  = lookupMimeType(file.path) ?? 'application/octet-stream';
    final mimeParts = mimeType.split('/');

    final request = http.MultipartRequest('POST', Uri.parse(url))
      ..headers.addAll({
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      })
      ..fields['process_id'] = processId.toString()
      ..fields['order_no']   = orderNo.toString()
      ..files.add(await http.MultipartFile.fromPath(
        'file', // ← must match $request->file('file') in the controller
        file.path,
        filename: name,
        contentType: MediaType(mimeParts[0], mimeParts[1]),
      ));

    late http.StreamedResponse streamed;
    try {
      streamed = await request.send().timeout(const Duration(seconds: 120));
    } on TimeoutException {
      throw ApiException('Upload timed out. Please check your connection.');
    } catch (e) {
      throw ApiException('Upload network error: $e');
    }

    final bodyStr = await streamed.stream.bytesToString();
    final decoded = _decode(bodyStr);

    developer.log(
      '[DevProcessUpload] uploadDocument ← ${streamed.statusCode}: $bodyStr',
      name: 'DevProcessUpload',
    );

    if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
      if (decoded is Map<String, dynamic>) return decoded;
      return {'success': true};
    }

    if (streamed.statusCode == 401) {
      throw ApiException('Session expired. Please login again.');
    }

    // Surface Laravel validation errors (422)
    if (streamed.statusCode == 422 && decoded is Map) {
      if (decoded['errors'] is Map) {
        final errors   = Map<String, dynamic>.from(decoded['errors'] as Map);
        final firstKey = errors.keys.isNotEmpty ? errors.keys.first : null;
        if (firstKey != null &&
            errors[firstKey] is List &&
            (errors[firstKey] as List).isNotEmpty) {
          throw ApiException((errors[firstKey] as List).first.toString());
        }
      }
      final msg = decoded['message']?.toString();
      if (msg != null && msg.isNotEmpty) throw ApiException(msg);
    }

    if (streamed.statusCode == 413) {
      throw ApiException(
        'File is too large. Please choose a file smaller than 10 MB.',
      );
    }

    throw ApiException(
      (decoded is Map ? decoded['message']?.toString() : null) ??
          'Upload failed (HTTP ${streamed.statusCode})',
    );
  }

  // ── Get pre-signed S3 URL ──────────────────────────────────────────────────

  /// Fetches a temporary (60-minute) pre-signed S3 download URL for [s3Path].
  ///
  /// [s3Path] is the `file_path` value returned by [uploadDocument].
  ///
  /// Throws [ApiException] on any failure.
  static Future<String> getFileUrl(String s3Path) async {
    if (s3Path.isEmpty) {
      throw ApiException('No file path provided.');
    }

    // Backend accepts either ?file_path= or ?path= — we send both.
    final uri = Uri.parse(ApiConstants.devProcessFileUrl).replace(
      queryParameters: {
        'file_path': s3Path,
        'path':      s3Path,
      },
    );

    developer.log(
      '[DevProcessUpload] getFileUrl → GET $uri',
      name: 'DevProcessUpload',
    );

    try {
      final response = await http
          .get(uri, headers: await _headers())
          .timeout(const Duration(seconds: 30));

      final decoded = _decode(response.body);

      developer.log(
        '[DevProcessUpload] getFileUrl ← ${response.statusCode}: ${response.body}',
        name: 'DevProcessUpload',
      );

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

  // ── Private helpers ────────────────────────────────────────────────────────

  static dynamic _decode(String body) {
    if (body.isEmpty) return {};
    try {
      return jsonDecode(body);
    } catch (_) {
      return {'message': body};
    }
  }
}