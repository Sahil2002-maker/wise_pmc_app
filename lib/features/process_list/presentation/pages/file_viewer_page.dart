import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class FileViewerPage extends StatefulWidget {
  final String url;
  final String title;
  final String? authToken;
  final String? serverBaseUrl;

  const FileViewerPage({
    super.key,
    required this.url,
    required this.title,
    this.authToken,
    this.serverBaseUrl,
  });

  @override
  State<FileViewerPage> createState() => _FileViewerPageState();
}

class _FileViewerPageState extends State<FileViewerPage> {
  WebViewController? _controller;
  bool _isLoading = true;
  int _loadingProgress = 0;
  String? _errorMessage;

  static const String _chromeUserAgent =
      'Mozilla/5.0 (Linux; Android 10; K) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/124.0.0.0 Mobile Safari/537.36';

  int _strategyIndex = 0;
  late List<String> _urlStrategies;

  @override
  void initState() {
    super.initState();
    _urlStrategies = _buildStrategies(widget.url);
    _initWebView(_urlStrategies[0]);
  }

  // ── Strategy builder ───────────────────────────────────────────────────────
  // KEY CHANGE: For server-hosted files, always try Google Docs Viewer FIRST
  // (before direct load), because auth-header injection via loadRequest is
  // unreliable on many Android WebView versions.
  List<String> _buildStrategies(String raw) {
    final strategies = <String>[];

    // Google Drive links
    if (raw.contains('drive.google.com')) {
      final preview = _toDrivePreview(raw);
      strategies.add(preview);
      strategies.add(
        'https://docs.google.com/viewer'
        '?url=${Uri.encodeComponent(preview)}&embedded=true',
      );
      return strategies;
    }

    // Google Docs / Sheets / Slides
    if (raw.contains('docs.google.com')) {
      strategies.add(_toDocsPreview(raw));
      return strategies;
    }

    // Server-hosted file
    final lower = raw.toLowerCase();
    final isPdf = lower.endsWith('.pdf') || lower.contains('.pdf?');
    final isImage = lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp');
    final isOffice = lower.endsWith('.doc') ||
        lower.endsWith('.docx') ||
        lower.endsWith('.xls') ||
        lower.endsWith('.xlsx') ||
        lower.endsWith('.ppt') ||
        lower.endsWith('.pptx');

    if (isPdf || isOffice) {
      // Strategy 1: Google Docs Viewer (no auth needed, works for public URLs)
      // For auth-protected URLs this won't work, but we try it first
      // because it renders PDFs/Office docs reliably in WebView.
      strategies.add(
        'https://docs.google.com/viewer'
        '?url=${Uri.encodeComponent(raw)}&embedded=true',
      );
      // Strategy 2: Direct load with auth header
      strategies.add(raw);
    } else if (isImage) {
      // Images: load directly (auth injected)
      strategies.add(raw);
    } else {
      // Unknown type: try Google Docs Viewer first, then direct
      strategies.add(
        'https://docs.google.com/viewer'
        '?url=${Uri.encodeComponent(raw)}&embedded=true',
      );
      strategies.add(raw);
    }

    return strategies;
  }

  String _toDrivePreview(String url) {
    if (url.contains('/preview')) return url;
    final m = RegExp(r'drive\.google\.com/file/d/([^/?#]+)').firstMatch(url);
    if (m != null) {
      return 'https://drive.google.com/file/d/${m.group(1)}/preview';
    }
    final id = RegExp(r'[?&]id=([^&]+)').firstMatch(url)?.group(1);
    if (id != null) {
      return 'https://drive.google.com/file/d/$id/preview';
    }
    return url;
  }

  String _toDocsPreview(String url) {
    if (url.contains('/preview')) return url;
    return url
        .replaceAll('/edit', '/preview')
        .replaceAll('/view', '/preview')
        .replaceAll('/copy', '/preview');
  }

  bool _requiresAuth(String url) {
    if (widget.authToken == null || widget.authToken!.isEmpty) return false;
    if (url.contains('google.com') || url.contains('googleapis.com')) {
      return false;
    }
    if (url.contains('docs.google.com/viewer')) return false;
    if (widget.serverBaseUrl != null && widget.serverBaseUrl!.isNotEmpty) {
      return url.startsWith(widget.serverBaseUrl!);
    }
    return true;
  }

  // ── WebView init ───────────────────────────────────────────────────────────
  void _initWebView(String urlToLoad) {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _loadingProgress = 0;
    });

    try {
      WebViewPlatform.instance ??= AndroidWebViewPlatform();

      final controller = WebViewController();

      if (controller.platform is AndroidWebViewController) {
        final androidCtrl = controller.platform as AndroidWebViewController;
        AndroidWebViewController.enableDebugging(false);
        androidCtrl.setMediaPlaybackRequiresUserGesture(false);
        controller.setUserAgent(_chromeUserAgent);
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
            onPageFinished: (url) {
              if (mounted) setState(() => _isLoading = false);
            },
            onProgress: (p) {
              if (mounted) setState(() => _loadingProgress = p);
            },
            onWebResourceError: (error) {
              if (!mounted || error.isForMainFrame != true) return;
              debugPrint(
                  'WebView error: ${error.description} | url: ${error.url}');

              final next = _tryNextStrategy();
              if (next != null) {
                _loadUrl(controller, next);
              } else {
                setState(() {
                  _isLoading = false;
                  _errorMessage =
                      'Could not load document.\nError: ${error.description}';
                });
              }
            },
            onNavigationRequest: (req) {
              final u = req.url;
              if (u.contains('accounts.google.com') ||
                  u.startsWith('intent://') ||
                  u.startsWith('googledrive://') ||
                  u.startsWith('com.google.android')) {
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
          ),
        );

      _loadUrl(controller, urlToLoad);
      if (mounted) setState(() => _controller = controller);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to initialize viewer: $e';
        });
      }
    }
  }

  void _loadUrl(WebViewController controller, String url) {
    debugPrint('FileViewer loading: $url');
    if (_requiresAuth(url)) {
      controller.loadRequest(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer ${widget.authToken}',
          'Accept': '*/*',
        },
      );
    } else {
      controller.loadRequest(Uri.parse(url));
    }
  }

  String? _tryNextStrategy() {
    _strategyIndex++;
    if (_strategyIndex < _urlStrategies.length) {
      return _urlStrategies[_strategyIndex];
    }
    return null;
  }

  void _reload() {
    _strategyIndex = 0;
    _initWebView(_urlStrategies[0]);
  }

  void _copyUrl() async {
    await Clipboard.setData(ClipboardData(text: widget.url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('URL copied to clipboard'),
          backgroundColor: const Color(0xFF334155),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final showProgress =
        _isLoading && _loadingProgress > 0 && _loadingProgress < 100;
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E293B)),
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
          icon: const Icon(Icons.copy_rounded, color: Color(0xFF64748B)),
          onPressed: _copyUrl,
          tooltip: 'Copy URL',
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
          onPressed: _reload,
          tooltip: 'Reload',
        ),
      ],
      bottom: showProgress
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
    );
  }

  Widget _buildBody() {
    if (_controller == null && _errorMessage == null) {
      return _buildLoader('Initializing viewer…');
    }
    if (_errorMessage != null) {
      return _buildError(_errorMessage!);
    }
    return Stack(
      children: [
        WebViewWidget(controller: _controller!),
        if (_isLoading && _loadingProgress < 20)
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
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: Color(0xFF22C55E),
                strokeWidth: 3,
                backgroundColor: Color(0xFFDCFCE7),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Please wait…',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
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
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(36),
              ),
              child: const Icon(
                Icons.broken_image_outlined,
                color: Color(0xFFEF4444),
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Unable to load document',
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _copyUrl,
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy URL'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}