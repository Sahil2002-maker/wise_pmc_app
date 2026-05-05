// lib/features/cc_progress/presentation/cc_progress_page.dart

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/auth_storage_service.dart';
import '../../../core/utils/api_exception.dart';
import '../data/models/cc_progress_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Stage tab definitions — mirrors backend STAGES map exactly
// ─────────────────────────────────────────────────────────────────────────────
class _StageDef {
  final String apiName;
  final String label;
  final IconData icon;
  const _StageDef(
      {required this.apiName, required this.label, required this.icon});
}

const _stageDefs = [
  _StageDef(
      apiName: 'Service',
      label: 'CC Application',
      icon: Icons.settings_outlined),
  _StageDef(
      apiName: 'Document',
      label: 'Scrutiny',
      icon: Icons.description_outlined),
  _StageDef(
      apiName: 'Approval',
      label: 'Approval',
      icon: Icons.check_circle_outline),
  _StageDef(
      apiName: 'Payment',
      label: 'Documents',
      icon: Icons.credit_card_outlined),
];

// Stage accent colours — matches layout approval style
const _stageAccentColors = {
  'Service': Color(0xFF3B82F6),
  'Document': Color(0xFF0EA5E9),
  'Approval': Color(0xFF22C55E),
  'Payment': Color(0xFFF59E0B),
};

// ─────────────────────────────────────────────────────────────────────────────
// URL / file-type helpers
// ─────────────────────────────────────────────────────────────────────────────

String? _extractDriveFileId(String raw) {
  final filePattern = RegExp(r'drive\.google\.com/file/d/([^/?&]+)');
  final m = filePattern.firstMatch(raw);
  if (m != null) return m.group(1);
  final uri = Uri.tryParse(raw);
  if (uri != null) {
    final id = uri.queryParameters['id'];
    if (id != null && id.isNotEmpty) return id;
  }
  return null;
}

bool _isGoogleDriveUrl(String url) =>
    url.contains('drive.google.com') || url.contains('docs.google.com');

/// Returns lowercase extension without the dot, e.g. "jpg", "pdf", "docx".
String _fileExtension(String path) {
  try {
    final uri = Uri.tryParse(path);
    final p = uri?.path ?? path;
    final dot = p.lastIndexOf('.');
    if (dot != -1 && dot < p.length - 1) {
      return p.substring(dot + 1).toLowerCase().split('?').first;
    }
  } catch (_) {}
  return '';
}

bool _isImageExt(String ext) =>
    ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext);

bool _isPdfExt(String ext) => ext == 'pdf';

/// Converts a raw file_path from the server into an absolute HTTPS URL.
String _toAbsoluteUrl(String raw) {
  final t = raw.trim();

  if (_isGoogleDriveUrl(t)) {
    final id = _extractDriveFileId(t);
    if (id != null && id.isNotEmpty) {
      return 'https://drive.google.com/uc?export=view&id=$id';
    }
    return t;
  }

  if (t.startsWith('http://') || t.startsWith('https://')) return t;

  final base = ApiConstants.baseUrl.replaceAll(RegExp(r'/$'), '');
  final rel = t.startsWith('/') ? t : '/$t';
  return '$base$rel';
}

// ─────────────────────────────────────────────────────────────────────────────
// Fetches a file from the server with auth and returns raw bytes.
// ─────────────────────────────────────────────────────────────────────────────
class _FetchResult {
  final List<int>? bytes;
  final String ext;
  final String mimeType;
  final String? error;

  const _FetchResult({
    required this.bytes,
    required this.ext,
    required this.mimeType,
    this.error,
  });

  factory _FetchResult.error(String msg) =>
      _FetchResult(bytes: null, ext: '', mimeType: '', error: msg);

  bool get isSuccess => bytes != null && error == null;
}

String _mimeForExt(String ext) {
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'bmp':
      return 'image/bmp';
    case 'webp':
      return 'image/webp';
    case 'svg':
      return 'image/svg+xml';
    case 'pdf':
      return 'application/pdf';
    default:
      return 'application/octet-stream';
  }
}

Future<_FetchResult> _fetchFileBytes(String rawPath) async {
  final url = _toAbsoluteUrl(rawPath);
  String ext = _fileExtension(rawPath);
  final token = await AuthStorageService.getToken() ?? '';

  try {
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Accept': '*/*',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (ext.isEmpty) {
        final contentType = response.headers['content-type'] ?? '';
        if (contentType.contains('image/jpeg')) ext = 'jpg';
        else if (contentType.contains('image/png')) ext = 'png';
        else if (contentType.contains('application/pdf')) ext = 'pdf';
      }

      return _FetchResult(
        bytes: response.bodyBytes,
        ext: ext,
        mimeType: _mimeForExt(ext),
      );
    }

    return _FetchResult.error(
      'Server returned HTTP ${response.statusCode}.\nCheck file permissions.',
    );
  } on SocketException {
    return _FetchResult.error('Network error — check your connection.');
  } catch (e) {
    return _FetchResult.error('Failed to fetch file: $e');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Builds static HTML that embeds the file as a base64 data URI.
// ─────────────────────────────────────────────────────────────────────────────
String _buildDataUriHtml({
  required List<int> bytes,
  required String mimeType,
  required String ext,
}) {
  final b64 = base64Encode(bytes);
  final dataUri = 'data:$mimeType;base64,$b64';

  if (_isImageExt(ext)) {
    return '''<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width,initial-scale=1.0,user-scalable=yes">
<style>
  *{margin:0;padding:0;box-sizing:border-box}
  html,body{width:100%;min-height:100vh;background:#111;
    display:flex;align-items:center;justify-content:center}
  img{max-width:100%;height:auto;display:block;margin:auto}
</style>
</head>
<body><img src="$dataUri" alt="Document"/></body>
</html>''';
  }

  if (_isPdfExt(ext)) {
    return '''<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<style>
  *{margin:0;padding:0;box-sizing:border-box}
  html,body{width:100%;height:100%;background:#525659}
  iframe{width:100%;height:100vh;border:none;display:block}
</style>
</head>
<body><iframe src="$dataUri" title="PDF Document"></iframe></body>
</html>''';
  }

  return '''<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<style>
  *{margin:0;padding:0;box-sizing:border-box}
  body{background:#f8fafc;display:flex;align-items:center;
    justify-content:center;min-height:100vh;font-family:sans-serif;padding:24px}
  .card{background:#fff;border-radius:12px;padding:32px 24px;
    max-width:320px;width:100%;text-align:center;
    box-shadow:0 4px 20px rgba(0,0,0,.08);border:1px solid #e2e8f0}
  .icon{font-size:56px;margin-bottom:16px}
  .title{font-size:16px;font-weight:700;color:#1e293b;margin-bottom:8px}
  .sub{font-size:13px;color:#64748b;line-height:1.5}
  .badge{display:inline-block;margin-top:12px;background:#f1f5f9;
    color:#475569;font-size:11px;font-weight:700;padding:4px 10px;
    border-radius:6px;text-transform:uppercase;letter-spacing:.5px}
</style>
</head>
<body>
  <div class="card">
    <div class="icon">📄</div>
    <div class="title">Preview Not Available</div>
    <div class="sub">This file type cannot be previewed in the app.<br>
      Use Replace to update or download the file externally.</div>
    <span class="badge">.${ext.isNotEmpty ? ext : 'file'}</span>
  </div>
</body>
</html>''';
}

// ─────────────────────────────────────────────────────────────────────────────
// In-app file viewer
// ─────────────────────────────────────────────────────────────────────────────
class _FileViewerPage extends StatefulWidget {
  final String rawPath;
  final String title;

  const _FileViewerPage({required this.rawPath, required this.title});

  @override
  State<_FileViewerPage> createState() => _FileViewerPageState();
}

class _FileViewerPageState extends State<_FileViewerPage> {
  late final WebViewController _controller;

  String _viewState = 'loading';
  String _errorMessage = '';
  int _webProgress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF111111))
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _webProgress = p);
        },
        onPageFinished: (_) {
          if (mounted && _viewState == 'loading') {
            setState(() => _viewState = 'ready');
          }
        },
        onWebResourceError: (err) {
          if ((err.isForMainFrame ?? false) && mounted) {
            setState(() {
              _viewState = 'error';
              _errorMessage = 'Page failed to load (${err.description})';
            });
          }
        },
      ));

    _loadFile();
  }

  Future<void> _loadFile() async {
    if (!mounted) return;

    setState(() {
      _viewState = 'loading';
      _errorMessage = '';
      _webProgress = 0;
    });

    try {
      final result = await _fetchFileBytes(widget.rawPath);

      if (!mounted) return;

      if (!result.isSuccess) {
        setState(() {
          _viewState = 'error';
          _errorMessage = result.error ?? 'Unknown error';
        });
        return;
      }

      final html = _buildDataUriHtml(
        bytes: result.bytes!,
        mimeType: result.mimeType,
        ext: result.ext,
      );

      await _controller.loadHtmlString(html);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _viewState = 'error';
        _errorMessage = 'Unexpected error: $e';
      });
    }
  }

  void _retry() => _loadFile();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Text('Document Viewer',
                style: TextStyle(fontSize: 10, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Reload',
            onPressed: _retry,
          ),
        ],
        bottom: _viewState == 'loading'
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  value: (_webProgress > 0 && _webProgress < 100)
                      ? _webProgress / 100
                      : null,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                  minHeight: 3,
                ),
              )
            : null,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_viewState == 'loading')
            Container(
              color: const Color(0xFF111111),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                        color: AppColors.primaryGreen, strokeWidth: 3),
                    const SizedBox(height: 16),
                    const Text(
                      'Loading document…',
                      style:
                          TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          if (_viewState == 'error')
            Container(
              color: const Color(0xFFF8FAFC),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                            color: Color(0xFFFEF2F2),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.broken_image_outlined,
                            size: 48, color: Color(0xFFEF4444)),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Could not load document',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _retry,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Try Again',
                            style:
                                TextStyle(fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CcProgressPage
// ─────────────────────────────────────────────────────────────────────────────
class CcProgressPage extends StatefulWidget {
  final int projectId;
  final String projectName;

  const CcProgressPage({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<CcProgressPage> createState() => _CcProgressPageState();
}

class _CcProgressPageState extends State<CcProgressPage>
    with TickerProviderStateMixin {
  TabController? _tabController;

  final List<CcStageDataModel?> _stageData =
      List.filled(_stageDefs.length, null);
  final List<bool> _stageLoading =
      List.filled(_stageDefs.length, false);
  bool _initialLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: _stageDefs.length, vsync: this);
    _tabController!.addListener(_onTabChanged);
    _loadAllStages();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController!.indexIsChanging) {
      final idx = _tabController!.index;
      if (_stageData[idx] == null && !_stageLoading[idx]) {
        _loadStage(idx);
      }
    }
  }

  Future<void> _loadAllStages() async {
    if (!mounted) return;
    setState(() {
      _initialLoading = true;
      _errorMessage = null;
    });
    try {
      final allData =
          await ApiService.fetchCcProgress(widget.projectId);
      if (!mounted) return;
      setState(() {
        for (int i = 0; i < _stageDefs.length; i++) {
          if (i < allData.length) _stageData[i] = allData[i];
        }
        _initialLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            e is ApiException ? e.message : e.toString();
        _initialLoading = false;
      });
    }
  }

  Future<void> _loadStage(int idx) async {
    if (!mounted) return;
    setState(() => _stageLoading[idx] = true);
    try {
      final all =
          await ApiService.fetchCcProgress(widget.projectId);
      if (!mounted) return;
      setState(() {
        for (int i = 0;
            i < _stageDefs.length && i < all.length;
            i++) {
          _stageData[i] = all[i];
        }
        _stageLoading[idx] = false;
      });
    } catch (_) {
      if (mounted) setState(() => _stageLoading[idx] = false);
    }
  }

  Future<void> _refresh() => _loadAllStages();

  Future<void> _toggleStatus(
    CcProcessModel process,
    String status,
    int stageIndex,
  ) async {
    final isCurrentlySet =
        status == 'Completed' ? process.isCompleted : process.isNa;
    final willEnable = !isCurrentlySet;

    _applyLocalStatusChange(
        stageIndex, process.processId, status, willEnable);

    try {
      if (willEnable) {
        await ApiService.updateCcProcessStatus(
          projectId: widget.projectId,
          processId: process.processId,
          status: status,
        );
      } else {
        await ApiService.removeCcProcessStatus(
          projectId: widget.projectId,
          processId: process.processId,
        );
      }
      await _loadAllStages();
    } catch (e) {
      _applyLocalStatusChange(
          stageIndex, process.processId, status, !willEnable);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              e is ApiException ? e.message : e.toString()),
          backgroundColor: const Color(0xFFEF4444),
        ));
      }
    }
  }

  void _applyLocalStatusChange(
      int stageIndex, int processId, String status, bool checked) {
    final stage = _stageData[stageIndex];
    if (stage == null || !mounted) return;

    final updated = stage.processes.map((p) {
      if (p.processId != processId) return p;
      return CcProcessModel(
        processId: p.processId,
        processName: p.processName,
        stage: p.stage,
        headStage: p.headStage,
        currentStatus: checked ? status : null,
        isCompleted: status == 'Completed' ? checked : false,
        isNa: status == 'N.A' ? checked : false,
        hasFile: p.hasFile,
        fileInfo: p.fileInfo,
      );
    }).toList();

    setState(() {
      _stageData[stageIndex] = CcStageDataModel(
        stageKey: stage.stageKey,
        stageLabel: stage.stageLabel,
        processes: updated,
        summary: _recomputeSummary(updated),
      );
    });
  }

  CcStageSummaryModel _recomputeSummary(
      List<CcProcessModel> processes) {
    final total = processes.length;
    final completed =
        processes.where((p) => p.isCompleted).length;
    final na = processes.where((p) => p.isNa).length;
    return CcStageSummaryModel(
      total: total,
      completed: completed,
      na: na,
      remaining: total - completed - na,
      completionPercentage:
          total > 0 ? (completed + na) / total * 100 : 0,
    );
  }

  void _showUploadSheet(CcProcessModel process, int stageIndex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CcUploadSheet(
        process: process,
        projectId: widget.projectId,
        onUploaded: _loadAllStages,
      ),
    );
  }

  void _openFile(CcProcessModel process) {
    final rawPath = process.fileInfo?.filePath;
    if (rawPath == null || rawPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No file available to view.'),
        backgroundColor: Color(0xFFEF4444),
      ));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FileViewerPage(
          rawPath: rawPath,
          title: process.fileInfo?.fileName ?? process.processName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) return _loadingView();
    if (_errorMessage != null) return _errorView();

    return Column(children: [
      _buildTabBar(),
      Expanded(
        child: TabBarView(
          controller: _tabController,
          children: List.generate(
              _stageDefs.length, (i) => _buildStageTab(i)),
        ),
      ),
    ]);
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: AppColors.primaryGreen,
        unselectedLabelColor: const Color(0xFF94A3B8),
        indicatorColor: AppColors.primaryGreen,
        indicatorWeight: 2.5,
        labelStyle: const TextStyle(
            fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500, fontSize: 12),
        tabs: List.generate(_stageDefs.length, (i) {
          final def = _stageDefs[i];
          final summary = _stageData[i]?.summary;
          return Tab(
            child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
              Icon(def.icon, size: 13),
              const SizedBox(width: 5),
              Text(def.label),
              if (summary != null) ...[
                const SizedBox(width: 6),
                _TabBadge(summary: summary),
              ],
            ]),
          );
        }),
      ),
    );
  }

  Widget _buildStageTab(int idx) {
    if (_stageLoading[idx]) {
      return Center(
          child: CircularProgressIndicator(
              color: AppColors.primaryGreen));
    }
    final stage = _stageData[idx];
    if (stage == null) {
      return Center(
          child: CircularProgressIndicator(
              color: AppColors.primaryGreen));
    }

    final accentColor =
        _stageAccentColors[_stageDefs[idx].apiName] ?? AppColors.primaryGreen;

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.primaryGreen,
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: _StageSummaryBanner(
            summary: stage.summary,
            stageLabel: _stageDefs[idx].label,
            stageIcon: _stageDefs[idx].icon,
            accentColor: accentColor,
          ),
        ),
        if (stage.processes.isEmpty)
          SliverFillRemaining(child: _emptyState())
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _ProcessCard(
                process: stage.processes[i],
                index: i,
                onToggleCompleted: () => _toggleStatus(
                    stage.processes[i], 'Completed', idx),
                onToggleNa: () => _toggleStatus(
                    stage.processes[i], 'N.A', idx),
                onUpload: () =>
                    _showUploadSheet(stage.processes[i], idx),
                onViewFile: () => _openFile(stage.processes[i]),
              ),
              childCount: stage.processes.length,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ]),
    );
  }

  Widget _loadingView() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: AppColors.primaryGreen),
          const SizedBox(height: 14),
          const Text('Loading CC Progress…',
              style: TextStyle(
                  color: Color(0xFF64748B), fontSize: 14)),
        ]),
      );

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined,
                size: 52, color: Color(0xFFEF4444)),
            const SizedBox(height: 16),
            Text(_errorMessage!,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white),
            ),
          ]),
        ),
      );

  Widget _emptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.construction_outlined,
                size: 52,
                color: AppColors.primaryGreen.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            const Text('No CC processes found',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Color(0xFF94A3B8), fontSize: 14)),
          ]),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab badge
// ─────────────────────────────────────────────────────────────────────────────
class _TabBadge extends StatelessWidget {
  final CcStageSummaryModel summary;
  const _TabBadge({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _dot(const Color(0xFF22C55E), summary.completed),
      const SizedBox(width: 2),
      _dot(const Color(0xFF94A3B8), summary.na),
      const SizedBox(width: 2),
      _dot(const Color(0xFFF59E0B), summary.remaining),
    ]);
  }

  Widget _dot(Color color, int count) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(8)),
        child: Text('$count',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Stage summary banner — redesigned to match Layout Approval screenshot style
// ─────────────────────────────────────────────────────────────────────────────
class _StageSummaryBanner extends StatelessWidget {
  final CcStageSummaryModel? summary;
  final String stageLabel;
  final IconData stageIcon;
  final Color accentColor;

  const _StageSummaryBanner({
    this.summary,
    required this.stageLabel,
    required this.stageIcon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final s = summary;
    if (s == null) return const SizedBox.shrink();
    final percent = (s.completionPercentage / 100).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row: icon + title + percentage ──────────────────────
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(stageIcon, color: accentColor, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  '$stageLabel Processes',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: accentColor),
                ),
                Text(
                  '${s.completed + s.na} of ${s.total} actioned',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF64748B)),
                ),
              ]),
            ),
            Text(
              '${s.completionPercentage.toStringAsFixed(0)}%',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: accentColor),
            ),
          ]),

          const SizedBox(height: 14),

          // ── Three chip cards ────────────────────────────────────────────
          Row(children: [
            _summaryChip(
              label: 'Completed',
              count: s.completed,
              color: const Color(0xFF22C55E),
            ),
            const SizedBox(width: 8),
            _summaryChip(
              label: 'N.A',
              count: s.na,
              color: const Color(0xFFEF4444),
            ),
            const SizedBox(width: 8),
            _summaryChip(
              label: 'Pending',
              count: s.remaining,
              color: const Color(0xFFF59E0B),
            ),
          ]),

          const SizedBox(height: 12),

          // ── Progress bar ────────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip({
    required String label,
    required int count,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.2))),
        child: Column(children: [
          Text(
            '$count',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Process card
// ─────────────────────────────────────────────────────────────────────────────
class _ProcessCard extends StatelessWidget {
  final CcProcessModel process;
  final int index;
  final VoidCallback onToggleCompleted;
  final VoidCallback onToggleNa;
  final VoidCallback onUpload;
  final VoidCallback onViewFile;

  const _ProcessCard({
    required this.process,
    required this.index,
    required this.onToggleCompleted,
    required this.onToggleNa,
    required this.onUpload,
    required this.onViewFile,
  });

  Color get _borderColor {
    if (process.isCompleted) return const Color(0xFF22C55E);
    if (process.isNa) return const Color(0xFF94A3B8);
    return const Color(0xFFE2E8F0);
  }

  Color get _statusColor {
    if (process.isCompleted) return const Color(0xFF22C55E);
    if (process.isNa) return const Color(0xFF94A3B8);
    return const Color(0xFFF59E0B);
  }

  String get _statusLabel {
    if (process.isCompleted) return 'Completed';
    if (process.isNa) return 'N.A';
    return 'Pending';
  }

  Color get _headerBg {
    if (process.isCompleted) return const Color(0xFFF0FDF4);
    if (process.isNa) return const Color(0xFFF8FAFC);
    return const Color(0xFFFFFBEB);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 5,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _headerBg,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8)),
              ),
              child: Row(children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: _borderColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text('${index + 1}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _borderColor)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(process.processName,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B))),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_statusLabel,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
            ),

            // ── Body ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Expanded(
                    child: _CheckboxTile(
                      label: 'Completed',
                      icon: Icons.check_circle_outline,
                      color: const Color(0xFF22C55E),
                      checked: process.isCompleted,
                      onChanged: onToggleCompleted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _CheckboxTile(
                      label: 'Not Applicable',
                      icon: Icons.remove_circle_outline,
                      color: const Color(0xFF94A3B8),
                      checked: process.isNa,
                      onChanged: onToggleNa,
                    ),
                  ),
                ]),
                if (process.hasFile && process.fileInfo != null) ...[
                  const SizedBox(height: 10),
                  _FileInfoRow(fileInfo: process.fileInfo!),
                ],
                const SizedBox(height: 10),
                if (process.hasFile)
                  Row(children: [
                    Expanded(
                      child: _ActionButton(
                        label: 'View File',
                        icon: Icons.visibility_outlined,
                        color: const Color(0xFF3B82F6),
                        onTap: onViewFile,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        label: 'Replace',
                        icon: Icons.upload_rounded,
                        color: const Color(0xFFF59E0B),
                        onTap: onUpload,
                      ),
                    ),
                  ])
                else
                  _ActionButton(
                    label: 'Upload Document',
                    icon: Icons.upload_file_outlined,
                    color: AppColors.primaryGreen,
                    onTap: onUpload,
                  ),
              ]),
            ),
          ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Checkbox tile
// ─────────────────────────────────────────────────────────────────────────────
class _CheckboxTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool checked;
  final VoidCallback onChanged;

  const _CheckboxTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.checked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChanged,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: checked
              ? color.withValues(alpha: 0.1)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: checked ? color : const Color(0xFFE2E8F0),
            width: checked ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: checked
                ? Icon(Icons.check_circle_rounded,
                    key: const ValueKey('on'), size: 16, color: color)
                : Icon(icon,
                    key: const ValueKey('off'),
                    size: 16,
                    color: const Color(0xFFCBD5E1)),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: checked
                        ? color
                        : const Color(0xFF64748B)),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// File info row
// ─────────────────────────────────────────────────────────────────────────────
class _FileInfoRow extends StatelessWidget {
  final CcFileInfoModel fileInfo;
  const _FileInfoRow({required this.fileInfo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(children: [
        const Icon(Icons.insert_drive_file_outlined,
            size: 14, color: Color(0xFF22C55E)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(fileInfo.fileName ?? 'Document',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF166534)),
                overflow: TextOverflow.ellipsis),
            if (fileInfo.fileSize != null ||
                fileInfo.uploadedDate != null)
              Text(
                [
                  if (fileInfo.fileSize != null) fileInfo.fileSize!,
                  if (fileInfo.uploadedDate != null)
                    fileInfo.uploadedDate!,
                ].join(' • '),
                style: const TextStyle(
                    fontSize: 10, color: Color(0xFF4ADE80)),
              ),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action button
// ─────────────────────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(8)),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CC Upload Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _CcUploadSheet extends StatefulWidget {
  final CcProcessModel process;
  final int projectId;
  final Future<void> Function() onUploaded;

  const _CcUploadSheet({
    required this.process,
    required this.projectId,
    required this.onUploaded,
  });

  @override
  State<_CcUploadSheet> createState() => _CcUploadSheetState();
}

class _CcUploadSheetState extends State<_CcUploadSheet> {
  PlatformFile? _pickedFile;
  DateTime _uploadedDate = DateTime.now();
  bool _isSaving = false;
  bool _isPicking = false;

  static const _allowedExtensions = [
    'pdf',
    'doc',
    'docx',
    'jpg',
    'jpeg',
    'png',
    'zip'
  ];

  String get _isoDate =>
      '${_uploadedDate.year}-'
      '${_uploadedDate.month.toString().padLeft(2, '0')}-'
      '${_uploadedDate.day.toString().padLeft(2, '0')}';

  String get _displayDate =>
      '${_uploadedDate.day.toString().padLeft(2, '0')}/'
      '${_uploadedDate.month.toString().padLeft(2, '0')}/'
      '${_uploadedDate.year}';

  Future<void> _pickFile() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
        withData: false,
        withReadStream: false,
      );
      if (result != null && result.files.isNotEmpty && mounted) {
        final f = result.files.first;
        final ext = (f.extension ?? '').toLowerCase();
        if (!_allowedExtensions.contains(ext)) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('File type .$ext is not allowed.\n'
                'Supported: ${_allowedExtensions.join(', ')}'),
            backgroundColor: const Color(0xFFEF4444),
          ));
          return;
        }
        setState(() => _pickedFile = f);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not pick file: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ));
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _uploadedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme:
                ColorScheme.light(primary: AppColors.primaryGreen)),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _uploadedDate = picked);
    }
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (_pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select a file first.'),
        backgroundColor: Color(0xFFEF4444),
      ));
      return;
    }
    final path = _pickedFile!.path;
    if (path == null || path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cannot read the selected file path.'),
        backgroundColor: Color(0xFFEF4444),
      ));
      return;
    }
    if (!File(path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Selected file no longer exists. Please pick again.'),
        backgroundColor: Color(0xFFEF4444),
      ));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final result = await ApiService.uploadCcProcessFile(
        projectId: widget.projectId,
        processId: widget.process.processId,
        file: File(path),
        fileName: _pickedFile!.name,
        uploadedDate: _isoDate,
      );
      if (!mounted) return;
      final message =
          (result is Map ? result['message']?.toString() : null) ??
              'File uploaded successfully.';
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primaryGreen,
        duration: const Duration(seconds: 3),
      ));
      await widget.onUploaded();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            e is ApiException ? e.message : 'Upload error: $e'),
        backgroundColor: const Color(0xFFEF4444),
        duration: const Duration(seconds: 4),
      ));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData _fileIcon(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'doc':
      case 'docx':
        return Icons.description_outlined;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image_outlined;
      case 'zip':
        return Icons.folder_zip_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          margin: const EdgeInsets.only(top: 10),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2)),
        ),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          decoration: BoxDecoration(color: AppColors.primaryGreen),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(
                widget.process.hasFile
                    ? Icons.upload_rounded
                    : Icons.upload_file_outlined,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  widget.process.hasFile
                      ? 'Replace Document'
                      : 'Upload Document',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.process.processName,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ]),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.close,
                    color: Colors.white, size: 18),
              ),
            ),
          ]),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: const Color(0xFFBFDBFE))),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Icon(Icons.info_outline,
                      size: 15, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Allowed: PDF, DOC, DOCX, JPG, JPEG, PNG, ZIP\n'
                      'Maximum size: 10 MB',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF1D4ED8),
                          height: 1.5),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 18),
              const Text('Select File',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151))),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _isPicking ? null : _pickFile,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: _pickedFile != null
                            ? AppColors.primaryGreen
                            : AppColors.primaryGreen
                                .withValues(alpha: 0.35),
                        width: _pickedFile != null ? 1.5 : 1),
                    borderRadius: BorderRadius.circular(10),
                    color: _pickedFile != null
                        ? AppColors.primaryGreen
                            .withValues(alpha: 0.05)
                        : const Color(0xFFF8FAFC),
                  ),
                  child: _isPicking
                      ? Center(
                          child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryGreen)))
                      : _pickedFile != null
                          ? _pickedFileRow()
                          : _emptyPickerHint(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Upload Date',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151))),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                      border: Border.all(
                          color: const Color(0xFFD1D5DB)),
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white),
                  child: Row(children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 17, color: AppColors.primaryGreen),
                    const SizedBox(width: 10),
                    Text(_displayDate,
                        style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1E293B))),
                  ]),
                ),
              ),
              const SizedBox(height: 24),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed:
                    _isSaving ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF374151),
                    side: const BorderSide(
                        color: Color(0xFFD1D5DB)),
                    padding: const EdgeInsets.symmetric(
                        vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(10))),
                child: const Text('Cancel',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(10))),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white))
                    : Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                        const Icon(Icons.upload_rounded,
                            size: 16),
                        const SizedBox(width: 6),
                        Text(
                          widget.process.hasFile
                              ? 'Replace'
                              : 'Upload',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700),
                        ),
                      ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _pickedFileRow() => Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(_fileIcon(_pickedFile!.extension),
              color: AppColors.primaryGreen, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(_pickedFile!.name,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B)),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(_formatSize(_pickedFile!.size),
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF94A3B8))),
          ]),
        ),
        GestureDetector(
          onTap: () => setState(() => _pickedFile = null),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.close,
                size: 16, color: Color(0xFF94A3B8)),
          ),
        ),
      ]);

  Widget _emptyPickerHint() => Column(children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.08),
              shape: BoxShape.circle),
          child: Icon(Icons.cloud_upload_outlined,
              size: 32, color: AppColors.primaryGreen),
        ),
        const SizedBox(height: 10),
        Text('Tap to select a file',
            style: TextStyle(
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.w700,
                fontSize: 14)),
        const SizedBox(height: 4),
        const Text('PDF, DOC, DOCX, JPG, PNG, ZIP',
            style:
                TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
      ]);
}