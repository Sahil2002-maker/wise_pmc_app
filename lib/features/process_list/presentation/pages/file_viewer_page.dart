import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class FileViewerPage extends StatefulWidget {
  final String url;
  final String title;

  const FileViewerPage({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<FileViewerPage> createState() => _FileViewerPageState();
}

class _FileViewerPageState extends State<FileViewerPage> {
  WebViewController? _controller;
  bool _isLoading = true;
  int _loadingProgress = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    try {
      // Ensure Android platform is set before creating controller
      if (WebViewPlatform.instance == null) {
        WebViewPlatform.instance = AndroidWebViewPlatform();
      }

      final controller = WebViewController();

      // Enable Android-specific settings
      if (controller.platform is AndroidWebViewController) {
        AndroidWebViewController.enableDebugging(false);
        (controller.platform as AndroidWebViewController)
            .setMediaPlaybackRequiresUserGesture(false);
      }

      controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFFF8FAFC))
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) {
              if (mounted) {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
              }
            },
            onPageFinished: (_) {
              if (mounted) setState(() => _isLoading = false);
            },
            onProgress: (progress) {
              if (mounted) setState(() => _loadingProgress = progress);
            },
            onWebResourceError: (error) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  // Only show error for main frame failures
                  if (error.isForMainFrame == true) {
                    _errorMessage =
                        'Could not load document.\nError: ${error.description}';
                  }
                });
              }
            },
            onNavigationRequest: (request) {
              // Block any attempt to open native Google apps
              final url = request.url;
              if (url.contains('accounts.google.com') ||
                  url.startsWith('intent://') ||
                  url.startsWith('googledrive://') ||
                  url.startsWith('com.google.android')) {
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(Uri.parse(_buildViewerUrl(widget.url)));

      if (mounted) {
        setState(() => _controller = controller);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to initialize viewer: $e';
        });
      }
    }
  }

  /// Converts any Google Drive/Docs URL into a /preview URL
  /// so it renders in a web viewer without requiring a Google account.
  String _buildViewerUrl(String url) {
    // Already a preview URL — return as-is
    if (url.contains('/preview')) return url;

    // Google Drive file link → /preview
    final driveMatch =
        RegExp(r'drive\.google\.com/file/d/([^/?]+)').firstMatch(url);
    if (driveMatch != null) {
      final fileId = driveMatch.group(1)!;
      return 'https://drive.google.com/file/d/$fileId/preview';
    }

    // Google Docs/Sheets/Slides → /preview
    if (url.contains('docs.google.com')) {
      return url
          .replaceAll('/edit', '/preview')
          .replaceAll('/view', '/preview')
          .replaceAll('/copy', '/preview');
    }

    // For server-hosted Office docs → Google Docs Viewer (no account needed)
    final lower = url.toLowerCase();
    if (lower.endsWith('.pdf') ||
        lower.endsWith('.doc') ||
        lower.endsWith('.docx') ||
        lower.endsWith('.xls') ||
        lower.endsWith('.xlsx') ||
        lower.endsWith('.ppt') ||
        lower.endsWith('.pptx')) {
      final encoded = Uri.encodeComponent(url);
      return 'https://docs.google.com/viewer?url=$encoded&embedded=true';
    }

    // Images and other direct URLs — load as-is
    return url;
  }

  void _reload() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _loadingProgress = 0;
    });
    _controller?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Text(
              'Document Viewer',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
            onPressed: _reload,
            tooltip: 'Reload',
          ),
        ],
        bottom: (_isLoading && _loadingProgress > 0 && _loadingProgress < 100)
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  value: _loadingProgress / 100,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF22C55E),
                  ),
                  minHeight: 3,
                ),
              )
            : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // WebView not yet initialized
    if (_controller == null) {
      return _buildLoader('Initializing viewer…');
    }

    // Error state
    if (_errorMessage != null) {
      return _buildError(_errorMessage!);
    }

    return Stack(
      children: [
        // WebView — always rendered so it can load in background
        WebViewWidget(controller: _controller!),

        // Loading overlay — only shown before first content appears
        if (_isLoading && _loadingProgress < 15)
          _buildLoader('Loading document…'),
      ],
    );
  }

  Widget _buildLoader(String message) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF22C55E),
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFEF4444),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}