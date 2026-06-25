// lib/data/services/pdf_download_service.dart
//
// Downloads a server-generated PDF (Material Stock / Material Quotation
// register) to local device storage and opens it with the OS default
// viewer via open_filex. Opening the PDF gives the user Print + Share
// for free through the native viewer's own toolbar.
//
// Add to pubspec.yaml:
//   dio: ^5.4.0
//   open_filex: ^4.4.0
//   path_provider: ^2.1.0
//   permission_handler: ^11.3.0   // only needed if you target Android <10
//                                  // for legacy external storage writes

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class PdfDownloadService {
  final Dio _dio;

  /// Pass in your app's already-configured Dio instance (the one that
  /// already has your base URL + auth header interceptor attached) so
  /// the PDF request is authenticated the same way as every other call.
  PdfDownloadService(this._dio);

  /// Downloads the PDF from [url] and opens it.
  ///
  /// [fileName] should NOT contain path separators — it's used as-is
  /// for the saved file, e.g. "Material-Stock-WR-EXE-21-0001.pdf".
  ///
  /// Returns true on success, false on failure (caller shows a SnackBar).
  Future<PdfDownloadResult> downloadAndOpen({
    required String url,
    required String fileName,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final safeName = _sanitizeFileName(fileName);
      final filePath = '${dir.path}/$safeName';

      final response = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode != 200 || response.data == null) {
        return PdfDownloadResult.failure(
          'Server returned status ${response.statusCode}.',
        );
      }

      // Guard against the API returning a JSON error body (e.g. 404/422)
      // instead of a PDF — DomPDF output always starts with "%PDF-".
      final bytes = response.data!;
      if (bytes.length < 5 ||
          String.fromCharCodes(bytes.sublist(0, 5)) != '%PDF-') {
        return PdfDownloadResult.failure(
          'Server did not return a valid PDF file.',
        );
      }

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
    } on DioException catch (e) {
      return PdfDownloadResult.failure(_dioErrorMessage(e));
    } catch (e) {
      return PdfDownloadResult.failure('Failed to download PDF: $e');
    }
  }

  String _sanitizeFileName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^\w\-. ]'), '_');
    return cleaned.toLowerCase().endsWith('.pdf') ? cleaned : '$cleaned.pdf';
  }

  String _dioErrorMessage(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Please try again.';
    }
    if (e.response?.statusCode == 404) {
      return 'Register not found on the server.';
    }
    if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
      return 'Session expired. Please log in again.';
    }
    return 'Failed to download PDF. Please check your connection.';
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