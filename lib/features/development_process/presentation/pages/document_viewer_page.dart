// lib/features/development_process/presentation/pages/document_viewer_page.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../../core/services/auth_storage_service.dart';

// ── Which phase the page is in ────────────────────────────────────────────────
enum _Phase { downloading, viewingPdf, viewingImage, nativeOpened, error }

class DocumentViewerPage extends StatefulWidget {
  final String url;
  final String title;

  const DocumentViewerPage({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<DocumentViewerPage> createState() => _DocumentViewerPageState();
}

class _DocumentViewerPageState extends State<DocumentViewerPage> {
  _Phase _phase = _Phase.downloading;

  // Download state
  double _dlProgress = 0;
  String _dlStatus = 'Connecting…';

  // File info
  String? _localPath;
  String _fileExt = '';

  // Error
  String _errorMessage = '';

  // PDF controller
  final PdfViewerController _pdfController = PdfViewerController();

  // ── Helpers ────────────────────────────────────────────────────────────────

  String get _httpsUrl {
    final raw = widget.url.trim();
    return raw.startsWith('http://')
        ? raw.replaceFirst('http://', 'https://')
        : raw;
  }

  static const _imageExts = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};
  static const _pdfExts = {'pdf'};

  bool get _isPdf => _pdfExts.contains(_fileExt);
  bool get _isImage => _imageExts.contains(_fileExt);

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _downloadFile();
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // _downloadFile
  //
  // Strategy:
  //  1. Download the file to a temp path using ResponseType.bytes so we have
  //     the raw bytes in memory before writing to disk.
  //  2. Inspect the ACTUAL bytes (magic-byte sniffing) to determine the true
  //     file type — this is the only 100% reliable method because:
  //       • The URL extension may be wrong / absent.
  //       • The server content-type may be wrong (e.g. octet-stream).
  //       • A server error page (HTML/JSON) may have been saved instead of
  //         the real file, which is the root cause of "Image could not be
  //         displayed."
  //  3. If the bytes are an error page (HTML / JSON), surface a clear error.
  //  4. Write the validated bytes to a correctly-named temp file.
  //  5. Render: PDF → SfPdfViewer, image → Image.file, else → native app.
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _downloadFile() async {
    setState(() {
      _phase = _Phase.downloading;
      _dlProgress = 0;
      _dlStatus = 'Connecting…';
      _errorMessage = '';
    });

    try {
      final token = await AuthStorageService.getToken();
      final dio = Dio();

      // ── Detect pre-signed / self-authenticating URLs ──────────────────────
      // URLs from S3, Azure Blob, GCS, or custom signed URLs already carry
      // auth in their query string.  Sending an extra Authorization header
      // on top causes HTTP 400 "invalid request" on most storage backends.
      //
      // We skip the Bearer header when the URL contains any known auth param.
      final parsedUri = Uri.parse(_httpsUrl);
      final queryKeys = parsedUri.queryParameters.keys
          .map((k) => k.toLowerCase())
          .toSet();
      final _presignedIndicators = {
        'x-amz-signature',   // AWS S3
        'x-amz-credential',
        'x-goog-signature',  // GCS
        'sig',               // Azure Blob
        'se',                // Azure SAS
        'sv',
        'token',             // generic
        'signature',
        'auth',
        'access_token',
        'api_key',
      };
      final isPresigned =
          queryKeys.any((k) => _presignedIndicators.contains(k));

      final authHeaders = <String, dynamic>{
        'Accept': '*/*',
        // Only send Bearer token for regular (non-pre-signed) URLs
        if (!isPresigned && token != null && token.isNotEmpty)
          'Authorization': 'Bearer $token',
      };

      setState(() => _dlStatus = 'Downloading…');

      // ── Step 1: Download bytes into memory ───────────────────────────────
      // Using ResponseType.bytes so we can magic-sniff before writing to disk.
      Response<List<int>> response;
      try {
        response = await dio.get<List<int>>(
          _httpsUrl,
          onReceiveProgress: (received, total) {
            if (!mounted) return;
            setState(() {
              if (total > 0) {
                _dlProgress = received / total;
                final r = (received / 1024).toStringAsFixed(0);
                final t = (total / 1024).toStringAsFixed(0);
                _dlStatus = '$r KB / $t KB';
              } else {
                final r = (received / 1024).toStringAsFixed(0);
                _dlStatus = '$r KB downloaded…';
              }
            });
          },
          options: Options(
            responseType: ResponseType.bytes,
            followRedirects: true,
            validateStatus: (s) => s != null && s < 500,
            headers: authHeaders,
          ),
        );
      } catch (_) {
        rethrow;
      }

      if (!mounted) return;

      // ── Step 2: Validate HTTP status ─────────────────────────────────────
      final statusCode = response.statusCode ?? 0;

      // If we got 400 and we DID send auth headers, retry WITHOUT them.
      // Some pre-signed URLs don't have obvious query params but still reject
      // a Bearer header.
      if (statusCode == 400 && authHeaders.containsKey('Authorization')) {
        setState(() {
          _dlProgress = 0;
          _dlStatus = 'Retrying without auth header…';
        });
        response = await dio.get<List<int>>(
          _httpsUrl,
          onReceiveProgress: (received, total) {
            if (!mounted) return;
            setState(() {
              if (total > 0) {
                _dlProgress = received / total;
                final r = (received / 1024).toStringAsFixed(0);
                final t = (total / 1024).toStringAsFixed(0);
                _dlStatus = '$r KB / $t KB';
              } else {
                final r = (received / 1024).toStringAsFixed(0);
                _dlStatus = '$r KB downloaded…';
              }
            });
          },
          options: Options(
            responseType: ResponseType.bytes,
            followRedirects: true,
            validateStatus: (s) => s != null && s < 500,
            headers: {'Accept': '*/*'}, // no auth
          ),
        );
        if (!mounted) return;
      }

      final finalStatus = response.statusCode ?? 0;
      if (finalStatus == 401 || finalStatus == 403) {
        throw Exception(
            'Access denied (HTTP $finalStatus). Your session may have expired.');
      }
      if (finalStatus >= 400) {
        throw Exception('Server error (HTTP $finalStatus). Please try again.');
      }

      final bytes = Uint8List.fromList(response.data ?? []);
      if (bytes.isEmpty) {
        throw Exception('The server returned an empty file.');
      }

      // ── Step 3: Magic-byte sniff to detect TRUE file type ─────────────────
      // This is the critical fix: we do NOT trust the URL extension or the
      // content-type header. We inspect the actual first bytes of the file.
      _fileExt = _sniffBytesExtension(bytes);

      // If magic bytes say it's HTML or JSON, the server returned an error
      // page instead of the actual file.
      if (_fileExt == 'html') {
        // Try to extract a helpful message from the HTML
        final body = String.fromCharCodes(bytes.take(512).toList());
        final titleMatch = RegExp(r'<title>(.*?)</title>', caseSensitive: false)
            .firstMatch(body);
        final hint = titleMatch?.group(1)?.trim() ?? 'Server returned an error page';
        throw Exception('Could not load file: $hint.\nPlease check your access or try again.');
      }
      if (_fileExt == 'json') {
        final body = String.fromCharCodes(bytes.take(256).toList());
        throw Exception('Server returned an error: $body');
      }

      // If still unknown, fall back to content-type header
      if (_fileExt.isEmpty) {
        final ct = response.headers.value('content-type') ?? '';
        _fileExt = _extFromContentType(ct);
      }

      // Last resort: try URL extension
      if (_fileExt.isEmpty) {
        final uri = Uri.parse(_httpsUrl);
        String seg =
            uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
        if (seg.contains('?')) seg = seg.split('?').first;
        final dot = seg.lastIndexOf('.');
        if (dot != -1) _fileExt = seg.substring(dot + 1).toLowerCase();
      }

      if (_fileExt.isEmpty) _fileExt = 'bin';

      // ── Step 4: Write validated bytes to a temp file ──────────────────────
      final tempDir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final savePath = '${tempDir.path}/doc_${ts}.$_fileExt';
      await File(savePath).writeAsBytes(bytes, flush: true);
      _localPath = savePath;

      if (!mounted) return;

      // ── Step 5: Render ────────────────────────────────────────────────────
      if (_isPdf) {
        setState(() => _phase = _Phase.viewingPdf);
      } else if (_isImage) {
        setState(() => _phase = _Phase.viewingImage);
      } else {
        await _openNative(_localPath!);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _errorMessage = _dioError(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Magic-byte sniffing
  //
  // Reads the first few bytes of the file to determine its true type.
  // Far more reliable than trusting URL extensions or HTTP headers.
  // ─────────────────────────────────────────────────────────────────────────
  String _sniffBytesExtension(Uint8List bytes) {
    if (bytes.length < 4) return '';

    // PDF: %PDF
    if (bytes[0] == 0x25 && bytes[1] == 0x50 &&
        bytes[2] == 0x44 && bytes[3] == 0x46) return 'pdf';

    // PNG: \x89PNG
    if (bytes[0] == 0x89 && bytes[1] == 0x50 &&
        bytes[2] == 0x4E && bytes[3] == 0x47) return 'png';

    // JPEG: \xFF\xD8\xFF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return 'jpg';

    // GIF: GIF87a or GIF89a
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return 'gif';

    // BMP: BM
    if (bytes[0] == 0x42 && bytes[1] == 0x4D) return 'bmp';

    // WebP: RIFF????WEBP
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 && bytes[1] == 0x49 &&
        bytes[2] == 0x46 && bytes[3] == 0x46 &&
        bytes[8] == 0x57 && bytes[9] == 0x45 &&
        bytes[10] == 0x42 && bytes[11] == 0x50) return 'webp';

    // ZIP-based (docx, xlsx, pptx): PK\x03\x04
    if (bytes[0] == 0x50 && bytes[1] == 0x4B &&
        bytes[2] == 0x03 && bytes[3] == 0x04) {
      // Could be docx/xlsx/pptx — return generic zip; caller opens natively
      return 'zip';
    }

    // HTML: starts with '<' or common HTML tags (error pages)
    final head = String.fromCharCodes(bytes.take(64).toList()).trimLeft().toLowerCase();
    if (head.startsWith('<!doctype') ||
        head.startsWith('<html') ||
        head.startsWith('<head') ||
        head.startsWith('<body')) return 'html';

    // JSON: starts with '{' or '['
    if (head.startsWith('{') || head.startsWith('[')) return 'json';

    return '';
  }

  /// Maps a MIME content-type string to a lowercase file extension.
  String _extFromContentType(String ct) {
    ct = ct.toLowerCase();
    if (ct.contains('pdf')) return 'pdf';
    if (ct.contains('png')) return 'png';
    if (ct.contains('jpeg') || ct.contains('jpg')) return 'jpg';
    if (ct.contains('gif')) return 'gif';
    if (ct.contains('webp')) return 'webp';
    if (ct.contains('bmp')) return 'bmp';
    if (ct.contains('msword') ||
        ct.contains('wordprocessingml') ||
        ct.contains('docx') ||
        ct.contains('doc')) return 'docx';
    if (ct.contains('spreadsheetml') ||
        ct.contains('excel') ||
        ct.contains('xlsx')) return 'xlsx';
    if (ct.contains('presentationml') ||
        ct.contains('powerpoint') ||
        ct.contains('pptx')) return 'pptx';
    return '';
  }

  // ── Open with native app ───────────────────────────────────────────────────

  Future<void> _openNative(String path) async {
    try {
      final result = await OpenFilex.open(path);
      if (!mounted) return;
      if (result.type == ResultType.done) {
        setState(() => _phase = _Phase.nativeOpened);
      } else {
        setState(() {
          _phase = _Phase.error;
          _errorMessage =
              'No app found to open this file type (.$_fileExt).\n'
              'Please install a compatible viewer app.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _errorMessage = 'Could not open file: $e';
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case _Phase.downloading:
        return _buildDownloadingUI();
      case _Phase.viewingPdf:
        return _buildPdfViewer();
      case _Phase.viewingImage:
        return _buildImageViewer();
      case _Phase.nativeOpened:
        return _buildNativeOpenedUI();
      case _Phase.error:
        return _buildErrorUI();
    }
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF7C3AED),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            _subtitle,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w400),
          ),
        ],
      ),
      actions: [
        // PDF zoom controls
        if (_phase == _Phase.viewingPdf) ...[
          IconButton(
            icon: const Icon(Icons.zoom_in_rounded, color: Colors.white),
            tooltip: 'Zoom in',
            onPressed: () => _pdfController.zoomLevel =
                (_pdfController.zoomLevel + 0.25).clamp(1.0, 5.0),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out_rounded, color: Colors.white),
            tooltip: 'Zoom out',
            onPressed: () => _pdfController.zoomLevel =
                (_pdfController.zoomLevel - 0.25).clamp(1.0, 5.0),
          ),
        ],
        // Open in native app (when file is ready)
        if ((_phase == _Phase.viewingPdf ||
                _phase == _Phase.viewingImage ||
                _phase == _Phase.nativeOpened) &&
            _localPath != null)
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded, color: Colors.white),
            tooltip: 'Open with native app',
            onPressed: () => _openNative(_localPath!),
          ),
      ],
    );
  }

  String get _subtitle {
    switch (_phase) {
      case _Phase.downloading:
        return 'Preparing document…';
      case _Phase.viewingPdf:
        return 'PDF Viewer';
      case _Phase.viewingImage:
        return 'Image Viewer';
      case _Phase.nativeOpened:
        return 'Opened in external app';
      case _Phase.error:
        return 'Error';
    }
  }

  // ── PDF Viewer ─────────────────────────────────────────────────────────────

  Widget _buildPdfViewer() {
    return SfPdfViewer.file(
      File(_localPath!),
      controller: _pdfController,
      canShowScrollHead: true,
      canShowScrollStatus: true,
      enableDoubleTapZooming: true,
      pageLayoutMode: PdfPageLayoutMode.continuous,
      onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
        // PDF corrupt / unreadable — try native
        if (mounted) _openNative(_localPath!);
      },
    );
  }

  // ── Image Viewer ───────────────────────────────────────────────────────────

  Widget _buildImageViewer() {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 5.0,
        child: Center(
          child: Image.file(
            File(_localPath!),
            fit: BoxFit.contain,
            // FIX: gaplessPlayback avoids flicker on rebuild
            gaplessPlayback: true,
            errorBuilder: (_, error, __) {
              // Show a more descriptive error with a retry option
              return _centeredMessage(
                Icons.broken_image_rounded,
                const Color(0xFFEF4444),
                'Image could not be displayed.\n'
                'The file may be corrupt or an unsupported format.',
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Downloading UI ─────────────────────────────────────────────────────────

  Widget _buildDownloadingUI() {
    return Container(
      color: const Color(0xFFF0F4F8),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Spinner card
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: CircularProgressIndicator(
                    value: _dlProgress > 0 ? _dlProgress : null,
                    strokeWidth: 3,
                    color: const Color(0xFF7C3AED),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Loading Document',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),

              Text(
                _dlStatus,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF64748B), fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 24),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _dlProgress > 0 ? _dlProgress : null,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF7C3AED)),
                  minHeight: 8,
                ),
              ),
              if (_dlProgress > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '${(_dlProgress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Color(0xFF7C3AED),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Secure badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        color: Color(0xFF7C3AED), size: 14),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Fetching securely with your credentials',
                        style: TextStyle(
                          color: Color(0xFF5B21B6),
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Native opened UI ───────────────────────────────────────────────────────

  Widget _buildNativeOpenedUI() {
    return Container(
      color: const Color(0xFFF0F4F8),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(44),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF22C55E), size: 44),
              ),
              const SizedBox(height: 20),
              const Text(
                'Document Opened',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'The document has been opened in your device\'s native app.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Color(0xFF64748B), fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 28),
              if (_localPath != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openNative(_localPath!),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Open Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                      textStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text('Go Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF7C3AED),
                    side: const BorderSide(color: Color(0xFF7C3AED)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Error UI ───────────────────────────────────────────────────────────────

  Widget _buildErrorUI() {
    return Container(
      color: const Color(0xFFF0F4F8),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(44),
                ),
                child: const Icon(Icons.error_outline_rounded,
                    color: Color(0xFFEF4444), size: 44),
              ),
              const SizedBox(height: 20),
              const Text(
                'Could Not Load Document',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage.isNotEmpty
                    ? _errorMessage
                    : 'Something went wrong. Please try again.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF64748B), fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _downloadFile,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                    textStyle: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text('Go Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Utility ────────────────────────────────────────────────────────────────

  Widget _centeredMessage(IconData icon, Color color, String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 48),
            const SizedBox(height: 12),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF64748B), fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  String _dioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out. Please check your internet.';
      case DioExceptionType.connectionError:
        return 'Could not reach the server. Check your connection.';
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode ?? 0;
        if (code == 401 || code == 403) {
          return 'Access denied (HTTP $code). Your session may have expired.';
        }
        return 'Server error (HTTP $code). Please try again.';
      default:
        return e.message ?? 'Download failed. Please try again.';
    }
  }
}