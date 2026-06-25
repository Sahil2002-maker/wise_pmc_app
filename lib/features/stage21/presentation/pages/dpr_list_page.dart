// lib/features/stage21/presentation/pages/dpr_list_page.dart
//
// UI restyled to match the Cement Checklist screen pattern exactly
// (header info-card, tinted card header with numbered badge + tag chip,
// info row, outlined action chips). All functionality is unchanged.

import 'package:flutter/material.dart';

import '../../data/models/daily_project_report_model.dart';
import '../../data/services/dpr_api_service.dart';
import '../../data/services/pdf_download_service.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/utils/api_exception.dart';
import 'dpr_form_page.dart';
import 'dpr_view_page.dart';

// ─── DPR List Page ────────────────────────────────────────────────────────────

class DprListPage extends StatefulWidget {
  final int projectId;
  final String projectName;

  const DprListPage({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<DprListPage> createState() => _DprListPageState();
}

class _DprListPageState extends State<DprListPage> {
  static const Color _accent = Color(0xFF7C3AED);

  bool _loading = true;
  String? _error;
  List<DailyProjectReportSummary> _reports = [];

  final Set<int> _deletingIds   = {};
  int? _downloadingId; // id of the report currently being downloaded

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error   = null;
    });
    try {
      final reports = await DprApiService.fetchReports(widget.projectId);
      if (mounted) setState(() { _reports = reports; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error   = e is ApiException ? e.message : e.toString();
          _loading = false;
        });
      }
    }
  }

  // ── Navigate to form ───────────────────────────────────────────────────────

  Future<void> _openCreate() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DprFormPage(
          projectId:   widget.projectId,
          projectName: widget.projectName,
        ),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _openEdit(DailyProjectReportSummary summary) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DprFormPage(
          projectId:   widget.projectId,
          projectName: widget.projectName,
          editId:      summary.id,
        ),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _openView(DailyProjectReportSummary summary) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DprViewPage(
          projectId:   widget.projectId,
          projectName: widget.projectName,
          reportId:    summary.id,
          reportNo:    summary.reportNo,
        ),
      ),
    );
  }

  // ── Print / Download PDF ───────────────────────────────────────────────────
  // Downloads the server-generated PDF and opens it in the device's native
  // PDF viewer. The viewer's own toolbar provides Print + Share, so one
  // action covers both "Print" and "Download" — identical to Material Stock.

  Future<void> _downloadPdf(DailyProjectReportSummary summary) async {
    if (_downloadingId != null) return; // prevent double taps
    setState(() => _downloadingId = summary.id);

    final url =
        '${ApiConstants.baseUrl}/api/mobile/projects/${widget.projectId}/dpr/${summary.id}/download';

    final result = await PdfDownloadService.downloadAndOpen(
      url:      url,
      fileName: 'DPR-${summary.reportNo}.pdf',
    );

    if (!mounted) return;
    setState(() => _downloadingId = null);

    if (!result.ok) {
      _showSnackBar(
        result.errorMessage ?? 'Failed to download PDF.',
        color: const Color(0xFFEF4444),
      );
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> _confirmDelete(DailyProjectReportSummary summary) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Report',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          'Delete "${summary.reportNo}"?\nThis action soft-deletes the record.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _deletingIds.add(summary.id));
    try {
      await DprApiService.deleteReport(widget.projectId, summary.id);
      if (mounted) {
        _showSnackBar('Report deleted.', color: const Color(0xFF16A34A));
        _load();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          e is ApiException ? e.message : 'Delete failed.',
          color: const Color(0xFFEF4444),
        );
      }
    } finally {
      if (mounted) setState(() => _deletingIds.remove(summary.id));
    }
  }

  void _showSnackBar(String msg, {Color color = const Color(0xFF16A34A)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: _accent,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _buildHeader()),
                      _reports.isEmpty
                          ? SliverFillRemaining(child: _buildEmpty())
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (_, index) {
                                  final r = _reports[index];
                                  final isDeleting =
                                      _deletingIds.contains(r.id);
                                  final isDownloading =
                                      _downloadingId == r.id;
                                  return _buildCard(
                                    r,
                                    index,
                                    isDeleting:    isDeleting,
                                    isDownloading: isDownloading,
                                  );
                                },
                                childCount: _reports.length,
                              ),
                            ),
                      const SliverToBoxAdapter(child: SizedBox(height: 90)),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New DPR',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  // ── Header — matches Cement Checklist header card ─────────────────────────
  Widget _buildHeader() => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _accent.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.description_outlined,
                  color: _accent, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Daily Project Report',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _accent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.projectName,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_reports.length}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
            ),
          ],
        ),
      );

  // ── Error state ────────────────────────────────────────────────────────────
  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded,
                color: Color(0xFFEF4444), size: 52),
            const SizedBox(height: 16),
            const Text('Failed to load reports',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ]),
        ),
      );

  // ── Empty state — matches Cement Checklist empty style ─────────────────────
  Widget _buildEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.description_outlined,
                    size: 56, color: _accent.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: 20),
              const Text('No DPR records found.',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B))),
              const SizedBox(height: 8),
              const Text(
                'Tap the button below to create your first DPR.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
            ],
          ),
        ),
      );

  // ── Card — matches Cement Checklist card style ─────────────────────────────
  Widget _buildCard(
    DailyProjectReportSummary report,
    int index, {
    required bool isDeleting,
    required bool isDownloading,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── card header (tinted background) ─────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.reportNo,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _accent,
                        ),
                      ),
                      if (report.creator != null)
                        Text(
                          'By ${report.creator!.name}',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF64748B)),
                        ),
                    ],
                  ),
                ),
                if (report.weather != null && report.weather!.isNotEmpty)
                  _WeatherChip(weather: report.weather!)
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'DPR',
                      style: TextStyle(
                        fontSize: 10,
                        color: _accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── card body ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _infoItem(Icons.calendar_today_outlined, 'Date',
                        report.reportDate ?? 'N/A'),
                    const SizedBox(width: 16),
                    _infoItem(Icons.photo_library_outlined, 'Photos',
                        '${report.totalPhotos}'),
                    const SizedBox(width: 16),
                    _infoItem(Icons.people_outline, 'Agencies',
                        '${report.laborCount}'),
                  ],
                ),
                // Section indicators
                if (report.hasDecisions ||
                    report.hasBottleNecks ||
                    report.hasMaterialDelivered ||
                    report.hasEhs) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    if (report.hasDecisions)
                      _SectionDot(
                          label: 'Decisions', color: const Color(0xFF7C3AED)),
                    if (report.hasBottleNecks)
                      _SectionDot(
                          label: 'Issues', color: const Color(0xFFEF4444)),
                    if (report.hasMaterialDelivered)
                      _SectionDot(
                          label: 'Materials', color: const Color(0xFF10B981)),
                    if (report.hasEhs)
                      _SectionDot(
                          label: 'EHS', color: const Color(0xFFF59E0B)),
                  ]),
                ],
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),
                // ── Action buttons — outlined style matching Cement Checklist ──
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ActionBtn(
                      icon:  Icons.visibility_outlined,
                      label: 'View',
                      color: const Color(0xFF0EA5E9),
                      onTap: () => _openView(report),
                    ),
                    _ActionBtn(
                      icon:  Icons.edit_outlined,
                      label: 'Edit',
                      color: const Color(0xFFF59E0B),
                      onTap: () => _openEdit(report),
                    ),
                    _ActionBtn(
                      icon:      Icons.picture_as_pdf_outlined,
                      label:     isDownloading ? 'Please wait…' : 'Print / PDF',
                      color:     const Color(0xFF22C55E),
                      onTap:     isDownloading ? null : () => _downloadPdf(report),
                      isLoading: isDownloading,
                    ),
                    _ActionBtn(
                      icon:      Icons.delete_outline_rounded,
                      label:     'Delete',
                      color:     const Color(0xFFEF4444),
                      onTap:     isDeleting ? null : () => _confirmDelete(report),
                      isLoading: isDeleting,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Info item — matches Cement Checklist info item style ──────────────────
  Widget _infoItem(IconData icon, String label, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(icon, size: 11, color: const Color(0xFF64748B)),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    value.isNotEmpty ? value : 'N/A',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

// ── Action button — outlined style matching Cement Checklist ────────────────

class _ActionBtn extends StatelessWidget {
  final IconData      icon;
  final String        label;
  final Color         color;
  final VoidCallback? onTap;
  final bool          isLoading;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool disabled = onTap == null && !isLoading;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: disabled ? 0.04 : 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: color.withValues(alpha: disabled ? 0.12 : 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width:  13,
                height: 13,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  valueColor:  AlwaysStoppedAnimation<Color>(color),
                ),
              )
            else
              Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize:   11,
                fontWeight: FontWeight.w600,
                color:      color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Small helpers (unchanged) ────────────────────────────────────────────────

class _WeatherChip extends StatelessWidget {
  final String weather;
  const _WeatherChip({required this.weather});

  IconData get _icon {
    switch (weather.toLowerCase()) {
      case 'sunny':  return Icons.wb_sunny_rounded;
      case 'rainy':  return Icons.water_drop_rounded;
      case 'cloudy': return Icons.cloud_rounded;
      case 'windy':  return Icons.air_rounded;
      case 'foggy':  return Icons.cloud_rounded;
      default:       return Icons.wb_cloudy_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_icon, size: 12, color: const Color(0xFF0EA5E9)),
        const SizedBox(width: 4),
        Text(weather,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0369A1))),
      ]),
    );
  }
}

class _SectionDot extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionDot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w700, color: color)),
    );
  }
}