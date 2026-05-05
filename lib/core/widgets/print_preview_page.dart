// lib/core/widgets/print_preview_page.dart
//
// Displays the server's HTML print page inside a WebView.
// Requires: flutter_inappwebview: ^6.0.0 in pubspec.yaml
//
// Android setup (android/app/src/main/AndroidManifest.xml):
//   Add inside <application>:
//     <uses-permission android:name="android.permission.INTERNET"/>
//
// iOS setup (ios/Runner/Info.plist) — already needed for any web request.

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class PrintPreviewPage extends StatefulWidget {
  final String url;
  final String title;
  final String? bearerToken;

  const PrintPreviewPage({
    super.key,
    required this.url,
    required this.title,
    this.bearerToken,
  });

  @override
  State<PrintPreviewPage> createState() => _PrintPreviewPageState();
}

class _PrintPreviewPageState extends State<PrintPreviewPage> {
  static const _accent = Color(0xFF1565C0);

  InAppWebViewController? _webCtrl;
  bool _loading = true;
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        shadowColor: const Color(0xFFE2E8F0),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            widget.title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Text(
            'Print Preview',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ]),
        actions: [
          // Reload button
          IconButton(
            tooltip: 'Reload',
            icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
            onPressed: () => _webCtrl?.reload(),
          ),
          // Print button — triggers window.print() in the WebView
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _triggerPrint,
              icon: const Icon(Icons.print, size: 18),
              label: const Text('Print'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: _accent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
      body: Stack(children: [
        // ── WebView ───────────────────────────────────────────────────────
        InAppWebView(
          initialUrlRequest: URLRequest(
            url: WebUri(widget.url),
            headers: {
              'Accept': 'text/html,application/xhtml+xml',
              if (widget.bearerToken != null &&
                  widget.bearerToken!.isNotEmpty)
                'Authorization': 'Bearer ${widget.bearerToken}',
            },
          ),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            domStorageEnabled: true,
            databaseEnabled: true,
            useShouldOverrideUrlLoading: false,
            mediaPlaybackRequiresUserGesture: false,
            // Improves rendering of print-style CSS
            preferredContentMode: UserPreferredContentMode.DESKTOP,
            // Allow cookies (session-based auth fallback)
            sharedCookiesEnabled: true,
          ),
          onWebViewCreated: (ctrl) => _webCtrl = ctrl,
          onLoadStart: (ctrl, url) {
            if (mounted) setState(() => _loading = true);
          },
          onLoadStop: (ctrl, url) {
            if (mounted) setState(() => _loading = false);
          },
          onReceivedError: (ctrl, req, err) {
            if (mounted) {
              setState(() {
                _loading = false;
                _hasError = true;
              });
            }
          },
          onConsoleMessage: (ctrl, msg) {
            // Debug: forward JS console to Dart
            debugPrint('[WebView console] ${msg.message}');
          },
        ),

        // ── Loading indicator ─────────────────────────────────────────────
        if (_loading)
          const LinearProgressIndicator(
            minHeight: 3,
            backgroundColor: Colors.transparent,
            color: _accent,
          ),

        // ── Error state ───────────────────────────────────────────────────
        if (_hasError)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.wifi_off_rounded,
                    size: 48, color: Color(0xFF94A3B8)),
                const SizedBox(height: 12),
                const Text(
                  'Could not load the print page.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Check your network connection and make sure the server is reachable.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _hasError = false);
                    _webCtrl?.reload();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white),
                ),
              ]),
            ),
          ),
      ]),
    );
  }

  Future<void> _triggerPrint() async {
    if (_webCtrl == null) return;
    // Inject JS to trigger the browser print dialog (Android Chrome WebView
    // will show a system print sheet — choose Save as PDF or a real printer).
    try {
      await _webCtrl!.evaluateJavascript(source: 'window.print();');
    } catch (e) {
      debugPrint('[PrintPreviewPage] window.print() failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Could not trigger print. Use your browser\'s share menu.'),
          backgroundColor: Color(0xFFF59E0B),
        ));
      }
    }
  }
}