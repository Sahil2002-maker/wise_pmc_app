// lib/features/noc_map/presentation/pages/noc_file_viewer_page.dart

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class NocFileViewerPage extends StatefulWidget {
  final String url;
  final String title;

  const NocFileViewerPage({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<NocFileViewerPage> createState() => _NocFileViewerPageState();
}

class _NocFileViewerPageState extends State<NocFileViewerPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  int  _loadingProgress = 0;
  String? _error;

  static const _primary   = Color(0xFF7367F0);
  static const _textDark  = Color(0xFF5E5873);
  static const _textMuted = Color(0xFF6E6B7B);

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    final viewerUrl = _buildViewerUrl(widget.url);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF8F7FA))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() {
            _isLoading = true;
            _error     = null;
          }),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onProgress: (p) => setState(() => _loadingProgress = p),
          onWebResourceError: (err) => setState(() {
            _isLoading = false;
            _error     = 'Failed to load file.\n${err.description}';
          }),
        ),
      )
      ..loadRequest(Uri.parse(viewerUrl));
  }

  /// Converts any supported file URL into a viewable URL.
  ///
  /// • Google Drive share links  → Google Docs viewer embed
  /// • Direct file URLs (.pdf, .doc, etc.) → Google Docs viewer embed
  /// • Everything else           → load directly in WebView
  String _buildViewerUrl(String raw) {
    // Strip accidental double-prefix  (server/storage/https://...)
    if (raw.contains('/storage/https://') ||
        raw.contains('/storage/http://')) {
      final idx = raw.indexOf('http', raw.indexOf('/storage/') + 1);
      raw = raw.substring(idx);
    }

    // Google Drive: convert to embeddable preview
    final gdriveFile = RegExp(r'drive\.google\.com/file/d/([^/?]+)');
    final gdriveOpen = RegExp(r'drive\.google\.com/open\?id=([^&]+)');

    String? driveId;
    driveId ??= gdriveFile.firstMatch(raw)?.group(1);
    driveId ??= gdriveOpen.firstMatch(raw)?.group(1);

    if (driveId != null) {
      // Use Google Drive preview embed — no login required for public files
      return 'https://drive.google.com/file/d/$driveId/preview';
    }

    // For PDFs / Office docs hosted on your server, wrap in Google Docs viewer
    final ext = raw.split('?').first.split('.').last.toLowerCase();
    const docViewerExts = {'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'};
    if (docViewerExts.contains(ext)) {
      final encoded = Uri.encodeComponent(raw);
      return 'https://docs.google.com/viewer?embedded=true&url=$encoded';
    }

    // Images and other URLs — load directly
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FA),
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: _textDark, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
                color: _textDark,
                fontSize: 14,
                fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Text('Document Viewer',
              style: TextStyle(color: _textMuted, fontSize: 10)),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: _primary),
          onPressed: () {
            setState(() { _isLoading = true; _error = null; });
            _controller.reload();
          },
          tooltip: 'Reload',
        ),
      ],
      bottom: _isLoading
          ? PreferredSize(
              preferredSize: const Size.fromHeight(3),
              child: LinearProgressIndicator(
                value: _loadingProgress > 0 && _loadingProgress < 100
                    ? _loadingProgress / 100
                    : null,
                backgroundColor: Colors.transparent,
                color: _primary,
                minHeight: 3,
              ),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return _buildError();
    }
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading) _buildOverlayLoader(),
      ],
    );
  }

  Widget _buildOverlayLoader() {
    return Container(
      color: const Color(0xFFF8F7FA),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _primary),
            SizedBox(height: 16),
            Text('Loading document…',
                style: TextStyle(color: _textMuted, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                  color: Colors.red.shade50, shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded,
                  color: Colors.red, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textDark, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() { _isLoading = true; _error = null; });
                _controller.reload();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}