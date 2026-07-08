// lib/features/stage21/presentation/pages/dpr_view_page.dart

import 'package:flutter/material.dart';

import '../../data/models/daily_project_report_model.dart';
import '../../data/services/dpr_api_service.dart';
import '../../../../core/utils/api_exception.dart';
import '../../../development_process/presentation/pages/document_viewer_page.dart';

class DprViewPage extends StatefulWidget {
  final int projectId;
  final String projectName;
  final int reportId;
  final String reportNo;

  const DprViewPage({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.reportId,
    required this.reportNo,
  });

  @override
  State<DprViewPage> createState() => _DprViewPageState();
}

class _DprViewPageState extends State<DprViewPage> {
  bool _loading = true;
  String? _error;
  DailyProjectReportDetail? _report;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final report = await DprApiService.fetchReport(widget.projectId, widget.reportId);
      if (mounted) setState(() { _report = report; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiException ? e.message : e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Daily Project Report',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Text(widget.reportNo,
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.75))),
          ],
        ),
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded,
                color: Color(0xFFEF4444), size: 52),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
              ),
            ),
          ]),
        ),
      );

  Widget _buildContent() {
    final r = _report!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Meta card ────────────────────────────────────────────────────────
        _SectionCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _MetaRow(label: 'Report No.', value: r.reportNo),
            _MetaRow(label: 'Project',    value: widget.projectName),
            _MetaRow(label: 'Date',       value: r.reportDate ?? '—'),
            _MetaRow(label: 'Weather',    value: r.weather ?? '—'),
            _MetaRow(
              label: 'Prepared By',
              value: r.creator?.name ?? '—',
            ),
          ]),
        ),

        const SizedBox(height: 16),

        // ── Section A: Labor Report ───────────────────────────────────────
        // NEW: shows the independently-editable Section A date, matching
        // the web view modal's "(dd/mm/yyyy)" suffix next to the heading.
        _SectionHeading(
          label: 'A. Detailed Labor Report',
          dateLabel: r.laborReportDate,
        ),
        _SectionCard(
          padding: EdgeInsets.zero,
          child: r.laborReport.isEmpty
              ? const _EmptySection(label: 'No labor entries.')
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                        const Color(0xFFF1F5F9)),
                    columnSpacing: 20,
                    headingTextStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B)),
                    dataTextStyle: const TextStyle(
                        fontSize: 11, color: Color(0xFF475569)),
                    columns: const [
                      DataColumn(label: Text('Agency')),
                      DataColumn(label: Text('Day\nSup'), numeric: true),
                      DataColumn(label: Text('Day\nSkilled'), numeric: true),
                      DataColumn(label: Text('Day\nUnskilled'), numeric: true),
                      DataColumn(label: Text('Night\nSup'), numeric: true),
                      DataColumn(label: Text('Night\nSkilled'), numeric: true),
                      DataColumn(label: Text('Night\nUnskilled'), numeric: true),
                      DataColumn(label: Text('Total'), numeric: true),
                      DataColumn(label: Text('Remarks')),
                    ],
                    rows: r.laborReport
                        .map(
                          (l) => DataRow(cells: [
                            DataCell(Text(l.agency ?? '—')),
                            DataCell(Text(_fmt(l.daySup))),
                            DataCell(Text(_fmt(l.daySkilled))),
                            DataCell(Text(_fmt(l.dayUnskilled))),
                            DataCell(Text(_fmt(l.nightSup))),
                            DataCell(Text(_fmt(l.nightSkilled))),
                            DataCell(Text(_fmt(l.nightUnskilled))),
                            DataCell(Text(
                              _fmt(l.total),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF7C3AED)),
                            )),
                            DataCell(Text(l.remarks ?? '')),
                          ]),
                        )
                        .toList(),
                  ),
                ),
        ),

        const SizedBox(height: 16),

        // ── Section B: Progress Previous ──────────────────────────────────
        // NEW: shows the independently-editable Section B date.
        _SectionHeading(
          label: 'B. Progress Achieved on Previous Day',
          dateLabel: r.progressPreviousDate,
        ),
        _SectionCard(
          padding: EdgeInsets.zero,
          child: r.progressPrevious.isEmpty
              ? const _EmptySection(label: 'No progress entries.')
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                        const Color(0xFFF1F5F9)),
                    columnSpacing: 16,
                    headingTextStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B)),
                    dataTextStyle: const TextStyle(
                        fontSize: 11, color: Color(0xFF475569)),
                    columns: const [
                      DataColumn(label: Text('Activity')),
                      DataColumn(label: Text('Planned %'), numeric: true),
                      DataColumn(label: Text('Actual %'), numeric: true),
                      DataColumn(label: Text('Planned\nCumul.'), numeric: true),
                      DataColumn(label: Text('Actual\nCumul.'), numeric: true),
                      DataColumn(label: Text('Material Used')),
                      DataColumn(label: Text('Remarks')),
                    ],
                    rows: r.progressPrevious
                        .map(
                          (p) => DataRow(cells: [
                            DataCell(Text(p.activity ?? '—')),
                            DataCell(Text('${_fmt(p.plannedPct)}%')),
                            DataCell(Text('${_fmt(p.actualPct)}%')),
                            DataCell(Text(_fmt(p.plannedCumulative))),
                            DataCell(Text(_fmt(p.actualCumulative))),
                            DataCell(Text(p.materialUsed ?? '—')),
                            DataCell(Text(p.remarks ?? '')),
                          ]),
                        )
                        .toList(),
                  ),
                ),
        ),

        const SizedBox(height: 16),

        // ── Section B2: Works Planned ─────────────────────────────────────
        _SectionHeading(label: 'B. Works Planned for Today'),
        _SectionCard(
          padding: EdgeInsets.zero,
          child: r.worksPlanned.isEmpty
              ? const _EmptySection(label: 'No planned works.')
              : DataTable(
                  headingRowColor: WidgetStateProperty.all(
                      const Color(0xFFF1F5F9)),
                  columnSpacing: 24,
                  headingTextStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B)),
                  dataTextStyle: const TextStyle(
                      fontSize: 11, color: Color(0xFF475569)),
                  columns: const [
                    DataColumn(label: Text('Activity')),
                    DataColumn(label: Text('Planned Qty')),
                    DataColumn(label: Text('Remarks')),
                  ],
                  rows: r.worksPlanned
                      .map(
                        (w) => DataRow(cells: [
                          DataCell(Text(w.activity ?? '—')),
                          DataCell(Text(w.plannedQty ?? '—')),
                          DataCell(Text(w.remarks ?? '')),
                        ]),
                      )
                      .toList(),
                ),
        ),

        const SizedBox(height: 16),

        // ── Section C: Text fields ────────────────────────────────────────
        _TextSection(
            label: 'C. Decisions / Approvals',
            value: r.decisionsApprovals),
        _TextSection(
            label: 'Bottle Necks / Problem Areas',
            value: r.bottleNecks),
        _TextSection(
            label: 'Change Authorizations / RFIs Submitted',
            value: r.changeAuthorizations),
        _TextSection(
            label: 'Material Delivered to Site This Date',
            value: r.materialDelivered),
        _TextSection(
            label: 'EHS Incident Reports / Near Misses This Date',
            value: r.ehsIncidentReports),

        // ── Photos ────────────────────────────────────────────────────────
        _SectionHeading(label: 'Previous Date Progress Photos'),
        _SectionCard(
          child: r.photoUrls.isEmpty
              ? const _EmptySection(label: 'No photos uploaded.')
              : Wrap(spacing: 10, runSpacing: 10, children: [
                  ...r.photoUrls.map((p) => _PhotoThumb(photo: p)),
                ]),
        ),

        const SizedBox(height: 32),
      ]),
    );
  }

  String _fmt(double v) => v == v.truncateToDouble()
      ? v.toInt().toString()
      : v.toStringAsFixed(2);
}

// ─── Reusable widgets ─────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const _SectionCard({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(14),
        child: child,
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String label;
  // NEW: optional date shown in parentheses next to the heading, mirroring
  // the web view modal's Section A / Section B date suffix.
  final String? dateLabel;
  const _SectionHeading({required this.label, this.dateLabel});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED),
              borderRadius: BorderRadius.circular(2),
            )),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(
                text: label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B)),
              ),
              if (dateLabel != null && dateLabel!.isNotEmpty)
                TextSpan(
                  text: '  ($dateLabel)',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B)),
                ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 100,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600)),
        ),
        const Text(' : ',
            style: TextStyle(fontSize: 12, color: Color(0xFFCBD5E1))),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF1E293B),
                  fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

class _EmptySection extends StatelessWidget {
  final String label;
  const _EmptySection({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(label,
            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13)),
      ),
    );
  }
}

class _TextSection extends StatelessWidget {
  final String label;
  final String? value;
  const _TextSection({required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SectionHeading(label: label),
        _SectionCard(
          child: Text(value!,
              style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF475569),
                  height: 1.5)),
        ),
      ]),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  final DprPhotoUrl photo;
  const _PhotoThumb({required this.photo});

  bool get _isImage {
    final ext = photo.path.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentViewerPage(
            url: photo.url,
            title: photo.name,
          ),
        ),
      ),
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        clipBehavior: Clip.antiAlias,
        child: _isImage
            ? Image.network(
                photo.url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image_rounded,
                      color: Color(0xFFCBD5E1)),
                ),
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF7C3AED)),
                        ),
                      ),
              )
            : const Center(
                child: Icon(Icons.picture_as_pdf_rounded,
                    color: Color(0xFFEF4444), size: 32),
              ),
      ),
    );
  }
}