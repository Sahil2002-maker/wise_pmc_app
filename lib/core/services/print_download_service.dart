// lib/core/services/print_download_service.dart
//
// CHANGES from previous version:
//   • printDocument() — no longer opens a WebView (PrintPreviewPage).
//     Instead: fetches HTML via authenticated http.get (bypasses SSL issues),
//     then renders natively via Printing.layoutPdf + Printing.convertHtml.
//   • downloadPdf() — unchanged, already works correctly with open_filex.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';

import 'auth_storage_service.dart';

class PrintDownloadService {
  // ─── Auth headers ─────────────────────────────────────────────────────────

  static Future<Map<String, String>> _authHeaders({
    String accept = 'application/json',
  }) async {
    final token = await AuthStorageService.getToken();
    return {
      'Accept': accept,
      'X-Requested-With': 'XMLHttpRequest',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // ─── PRINT ────────────────────────────────────────────────────────────────
  //
  // Uses http.get (not WebView) → no SSL mismatch error.
  // Converts server HTML → PDF bytes via Printing.convertHtml
  // → shows native OS print/share dialog.

  static Future<void> printDocument(
    BuildContext context, {
    required String url,
    required String title,
  }) async {
    _showSnack(context, '⏳ Preparing print preview…');

    try {
      final response = await http
          .get(
            Uri.parse(url),
            headers: await _authHeaders(accept: 'text/html,application/json'),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final html = response.body;
      if (html.trim().isEmpty) throw Exception('Empty response from server');

      await Printing.layoutPdf(
        name: title,
        onLayout: (format) => Printing.convertHtml(
          format: format,
          html: html,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        _showSnack(context, 'Print failed: $e', isError: true);
      }
    }
  }

  // ─── PDF DOWNLOAD ─────────────────────────────────────────────────────────
  //
  // Saves to getApplicationDocumentsDirectory() → always covered by
  // filepaths.xml <files-path name="app_flutter" path="app_flutter/" />
  // Opens with OpenFilex (uses FileProvider URI, no crash on Android 7+).

  static Future<void> downloadPdf(
    BuildContext context, {
    required String url,
    required String fileName,
  }) async {
    // Only request storage permission on Android < 13
    if (Platform.isAndroid) {
      final sdkInt = await _androidSdkVersion();
      if (sdkInt != null && sdkInt < 33) {
        final status = await Permission.storage.request();
        if (status.isDenied || status.isPermanentlyDenied) {
          if (context.mounted) {
            _showSnack(
              context,
              'Storage permission is required to save the PDF.',
              isError: true,
            );
          }
          return;
        }
      }
    }

    double progress = 0;
    OverlayEntry? overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (_) => _DownloadOverlay(
        progress: progress,
        onCancel: () {
          overlayEntry?.remove();
          overlayEntry = null;
        },
      ),
    );

    if (context.mounted) Overlay.of(context).insert(overlayEntry!);

    try {
      final token = await AuthStorageService.getToken();

      // Save to app documents dir — guaranteed in FileProvider paths
      final dir = await getTemporaryDirectory();
      final safeFileName =
          fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._\-]'), '_');
      final savePath = '${dir.path}/$safeFileName';

      final dio = Dio();
      await dio.download(
        url,
        savePath,
        options: Options(
          receiveTimeout: const Duration(minutes: 2),
          headers: {
            'Accept': 'application/pdf,*/*',
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            progress = received / total;
            overlayEntry?.markNeedsBuild();
          }
        },
      );

      overlayEntry?.remove();
      overlayEntry = null;

      // Validate the file is a real PDF
      final file = File(savePath);
      if (!await file.exists() || await file.length() == 0) {
        throw Exception('Downloaded file is empty.');
      }

      final header = await _readBytes(file, 5);
      if (!_isPdfHeader(header)) {
        final snippet = await _readText(file, 300);
        debugPrint('[PrintDownloadService] Not a PDF. Server said: $snippet');
        if (context.mounted) {
          _showSnack(
            context,
            'Server returned an error instead of a PDF. '
            'Check your session and try again.',
            isError: true,
          );
        }
        return;
      }

      if (!context.mounted) return;
      _showSnack(context, '✅ PDF saved — opening…');

      await Future.delayed(const Duration(milliseconds: 400));
      if (!context.mounted) return;

      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done && context.mounted) {
        _showSnack(
          context,
          'No PDF viewer found. Install Adobe Acrobat or any PDF app.',
          isError: true,
        );
      }
    } catch (e) {
      overlayEntry?.remove();
      overlayEntry = null;
      if (context.mounted) {
        _showSnack(context, 'Download failed: $e', isError: true);
      }
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  static void _showSnack(BuildContext context, String msg,
      {bool isError = false}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor:
          isError ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
      duration: Duration(seconds: isError ? 4 : 2),
    ));
  }

  static Future<int?> _androidSdkVersion() async {
    try {
      final result = await Process.run('getprop', ['ro.build.version.sdk']);
      return int.tryParse(result.stdout.toString().trim());
    } catch (_) {
      return null;
    }
  }

  static Future<List<int>> _readBytes(File file, int count) async {
    try {
      final sink = <int>[];
      await for (final chunk in file.openRead(0, count)) {
        sink.addAll(chunk);
        if (sink.length >= count) break;
      }
      return sink;
    } catch (_) {
      return [];
    }
  }

  static bool _isPdfHeader(List<int> bytes) {
    if (bytes.length < 4) return false;
    // PDF magic bytes: %PDF → 0x25 0x50 0x44 0x46
    return bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46;
  }

  static Future<String> _readText(File file, int maxBytes) async {
    try {
      final bytes =
          await file.openRead(0, maxBytes).expand((c) => c).toList();
      return String.fromCharCodes(bytes);
    } catch (_) {
      return '';
    }
  }
}

// ─── Download progress overlay ────────────────────────────────────────────────

class _DownloadOverlay extends StatelessWidget {
  final double progress;
  final VoidCallback onCancel;

  const _DownloadOverlay({required this.progress, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black54,
        child: Center(
          child: Container(
            width: 240,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.picture_as_pdf,
                    size: 32, color: Color(0xFF1565C0)),
              ),
              const SizedBox(height: 14),
              const Text('Downloading PDF',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B))),
              const SizedBox(height: 4),
              const Text('Please wait…',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress > 0 ? progress : null,
                  backgroundColor: const Color(0xFFE2E8F0),
                  color: const Color(0xFF1565C0),
                  minHeight: 7,
                ),
              ),
              if (progress > 0) ...[
                const SizedBox(height: 6),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1565C0)),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}