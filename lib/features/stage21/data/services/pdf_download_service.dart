// lib/features/stage21/data/services/pdf_download_service.dart
//
// Downloads a server-generated PDF (Material Stock / Material Quotation
// register) to local device storage and opens it with the OS default
// viewer via open_filex. Opening the PDF gives the user Print + Share
// for free through the native viewer's own toolbar.
//
// Uses the same auth pattern as the rest of the app (AuthStorageService +
// http package + Bearer token) instead of a bare, unauthenticated Dio().
//
// Add to pubspec.yaml (if not already present):
//   open_filex: ^4.4.0
//   path_provider: ^2.1.0

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/services/auth_storage_service.dart';

class PdfDownloadService {
  /// Downloads the PDF from [url] and opens it.
  ///
  /// [fileName] should NOT contain path separators — it's used as-is
  /// for the saved file, e.g. "Material-Stock-WR-EXE-21-0001.pdf".
  static Future<PdfDownloadResult> downloadAndOpen({
    required String url,
    required String fileName,
  }) async {
    try {
      final token = await AuthStorageService.getToken();
      if (token == null || token.isEmpty) {
        return PdfDownloadResult.failure(
          'Session expired. Please log in again.',
        );
      }

      developer.log('[PdfDownloadService] GET $url', name: 'PdfDownloadService');

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Accept': 'application/pdf',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 60));

      developer.log(
        '[PdfDownloadService] ← ${response.statusCode}, '
        'content-type=${response.headers['content-type']}, '
        'bytes=${response.bodyBytes.length}',
        name: 'PdfDownloadService',
      );

      if (response.statusCode == 401) {
        return PdfDownloadResult.failure('Session expired. Please log in again.');
      }

      if (response.statusCode != 200) {
        return PdfDownloadResult.failure(
          'Server returned status ${response.statusCode}.',
        );
      }

      final bytes = response.bodyBytes;

      // Guard against the API returning a JSON/HTML error body instead of
      // a PDF — DomPDF output always starts with "%PDF-".
      final looksLikePdf = bytes.length >= 5 &&
          String.fromCharCodes(bytes.sublist(0, 5)) == '%PDF-';

      if (!looksLikePdf) {
        final serverMessage = _extractServerErrorMessage(bytes);
        developer.log(
          '[PdfDownloadService] Non-PDF response: $serverMessage',
          name: 'PdfDownloadService',
        );
        return PdfDownloadResult.failure(
          'Server did not return a PDF: $serverMessage',
        );
      }

      final dir = await getTemporaryDirectory();
      final safeName = _sanitizeFileName(fileName);
      final filePath = '${dir.path}/$safeName';

      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);

      final openResult = await OpenFilex.open(filePath);
      if (openResult.type != ResultType.done) {
        return PdfDownloadResult.failure(
          'PDF saved but could not be opened: ${openResult.message}',
          filePath: filePath,
        );
      }

      return PdfDownloadResult.success(filePath);
    } catch (e) {
      return PdfDownloadResult.failure('Failed to download PDF: $e');
    }
  }

  /// Tries to decode the non-PDF response body as text/JSON so the real
  /// error (e.g. "Unauthenticated.", a 404 HTML page, a Laravel validation
  /// error, etc.) is visible instead of a generic message.
  static String _extractServerErrorMessage(List<int> bytes) {
    try {
      final text = utf8.decode(bytes, allowMalformed: true);

      try {
        final decoded = jsonDecode(text);
        if (decoded is Map) {
          if (decoded['message'] != null) return decoded['message'].toString();
          if (decoded['error'] != null) return decoded['error'].toString();
        }
      } catch (_) {
        // Not JSON — fall through.
      }

      final trimmed = text.trim();
      if (trimmed.startsWith('<')) {
        return 'Server returned an HTML page instead of a PDF '
            '(likely an auth redirect or routing error).';
      }

      return trimmed.length > 200 ? '${trimmed.substring(0, 200)}…' : trimmed;
    } catch (_) {
      return 'Unrecognized response (${bytes.length} bytes).';
    }
  }

  static String _sanitizeFileName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^\w\-. ]'), '_');
    return cleaned.toLowerCase().endsWith('.pdf') ? cleaned : '$cleaned.pdf';
  }
}

class PdfDownloadResult {
  final bool ok;
  final String? filePath;
  final String? errorMessage;

  PdfDownloadResult._(this.ok, this.filePath, this.errorMessage);

  factory PdfDownloadResult.success(String filePath) =>
      PdfDownloadResult._(true, filePath, null);

  factory PdfDownloadResult.failure(String message, {String? filePath}) =>
      PdfDownloadResult._(false, filePath, message);
}