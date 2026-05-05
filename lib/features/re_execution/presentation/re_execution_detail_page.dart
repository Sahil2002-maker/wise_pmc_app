// lib/features/re_execution/presentation/re_execution_detail_page.dart

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/api_exception.dart';
import '../data/models/re_execution_model.dart';
import '../data/services/re_execution_api_service.dart';
import 're_execution_form_page.dart';

class ReExecutionDetailPage extends StatefulWidget {
  final int projectId;
  final int reportId;
  final String projectName;

  const ReExecutionDetailPage({
    super.key,
    required this.projectId,
    required this.reportId,
    required this.projectName,
  });

  @override
  State<ReExecutionDetailPage> createState() => _ReExecutionDetailPageState();
}

class _ReExecutionDetailPageState extends State<ReExecutionDetailPage> {
  ReExecutionDetailModel? _report;
  bool _isLoading = true;
  String? _error;
  bool _didChange = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      final r = await ReExecutionApiService.fetchReportDetail(
        projectId: widget.projectId,
        reportId:  widget.reportId,
      );
      if (!mounted) return;
      setState(() { _report = r; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error     = e is ApiException ? e.message : e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (_, __) {
        if (_didChange) Navigator.of(context).pop(true);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
            onPressed: () => Navigator.pop(context, _didChange),
          ),
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Daily Progress Report',
                style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w700, fontSize: 16)),
            Text(widget.projectName,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          ]),
          actions: [
            if (_report != null)
              IconButton(
                icon: Icon(Icons.edit_outlined, color: AppColors.primaryGreen),
                onPressed: () async {
                  final changed = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReExecutionFormPage(
                        projectId:   widget.projectId,
                        projectName: widget.projectName,
                        reportId:    widget.reportId,
                      ),
                    ),
                  );
                  if (changed == true) {
                    _didChange = true;
                    _load();
                  }
                },
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: const Color(0xFFE2E8F0)),
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _load,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
            child: const Text('Retry'),
          ),
        ]),
      );
    }
    final r = _report!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Date header
        _headerCard(r),
        const SizedBox(height: 12),

        // A. Labor report
        _sectionCard(title: 'A. Detailed Labor Report', icon: Icons.people_outline, children: [
          _laborTable(r),
        ]),
        const SizedBox(height: 12),

        // B. Progress
        if (r.previousProgress.isNotEmpty) ...[
          _sectionCard(title: 'B. Progress — Previous Day', icon: Icons.trending_up_outlined, children: [
            _progressTable(r.previousProgress),
          ]),
          const SizedBox(height: 12),
        ],
        if (r.plannedWorks.isNotEmpty) ...[
          _sectionCard(title: 'Works Planned for Today', icon: Icons.checklist_outlined, children: [
            _plannedWorksTable(r.plannedWorks),
          ]),
          const SizedBox(height: 12),
        ],

        // Text sections
        if (r.decisionsApprovals.isNotEmpty)
          _textSection('C. Decisions / Approvals', r.decisionsApprovals, Icons.gavel_outlined),
        if (r.bottleNecks.isNotEmpty)
          _textSection('Bottle Necks / Problem Areas', r.bottleNecks, Icons.warning_amber_outlined),
        if (r.changeAuthorizations.isNotEmpty)
          _textSection('Change Authorizations / RFIs', r.changeAuthorizations, Icons.swap_horiz_outlined),
        if (r.materialDelivered.isNotEmpty)
          _textSection('Material Delivered to Site', r.materialDelivered, Icons.local_shipping_outlined),
        if (r.ehsIncidentReports.isNotEmpty)
          _textSection('EHS Incident Reports / Near Misses', r.ehsIncidentReports, Icons.health_and_safety_outlined),

        // Photos
        if (r.progressPhotos.isNotEmpty) ...[
          _sectionCard(title: 'Progress Photos', icon: Icons.photo_library_outlined, children: [
            _photosGrid(r.progressPhotos),
          ]),
        ],

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _headerCard(ReExecutionDetailModel r) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today_outlined, color: AppColors.primaryGreen, size: 20),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.reportDateDisplay ?? r.reportDate ?? 'N/A',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primaryGreen)),
            if (r.createdByName != null)
              Text('Created by ${r.createdByName}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          ]),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _miniStat('Day', r.totalDayManpower, const Color(0xFFF59E0B)),
            const SizedBox(height: 4),
            _miniStat('Night', r.totalNightManpower, const Color(0xFF3B82F6)),
          ]),
        ]),
      );

  Widget _miniStat(String label, int value, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(fontSize: 11, color: color)),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
          child: Text('$value',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ]);

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) =>
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(children: [
              Icon(icon, size: 16, color: AppColors.primaryGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryGreen)),
              ),
            ]),
          ),
          Divider(height: 1, color: AppColors.primaryGreen.withValues(alpha: 0.15)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ]),
      );

  Widget _textSection(String title, String content, IconData icon) => Column(children: [
        _sectionCard(
          title: title,
          icon: icon,
          children: [
            Text(content, style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.5)),
          ],
        ),
        const SizedBox(height: 12),
      ]);

  Widget _laborTable(ReExecutionDetailModel r) {
    if (r.laborAgencies.isEmpty) {
      return const Text('No labor data recorded.',
          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 32,
        dataRowMaxHeight: 48,
        columnSpacing: 12,
        headingTextStyle: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
        columns: const [
          DataColumn(label: Text('Agency')),
          DataColumn(label: Text('Sup D')),
          DataColumn(label: Text('Skd D')),
          DataColumn(label: Text('Usk D')),
          DataColumn(label: Text('Sup N')),
          DataColumn(label: Text('Skd N')),
          DataColumn(label: Text('Usk N')),
          DataColumn(label: Text('Total')),
        ],
        rows: [
          ...r.laborAgencies.map((l) {
            int i(String k) => int.tryParse(l[k]?.toString() ?? '0') ?? 0;
            final total = i('sup_day') + i('skilled_day') + i('unskilled_day') +
                i('sup_night') + i('skilled_night') + i('unskilled_night');
            return DataRow(cells: [
              DataCell(Text(l['agency']?.toString() ?? '',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
              DataCell(Text('${i('sup_day')}',     style: const TextStyle(fontSize: 12))),
              DataCell(Text('${i('skilled_day')}', style: const TextStyle(fontSize: 12))),
              DataCell(Text('${i('unskilled_day')}',style: const TextStyle(fontSize: 12))),
              DataCell(Text('${i('sup_night')}',   style: const TextStyle(fontSize: 12))),
              DataCell(Text('${i('skilled_night')}',style: const TextStyle(fontSize: 12))),
              DataCell(Text('${i('unskilled_night')}',style: const TextStyle(fontSize: 12))),
              DataCell(Text('$total',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
            ]);
          }),
          // Totals row
          DataRow(cells: [
            DataCell(Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryGreen, fontSize: 12))),
            DataCell(Text('${r.totalSupDay}',           style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            DataCell(Text('${r.totalSkilledDay}',       style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            DataCell(Text('${r.totalUnskilledDay}',     style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            DataCell(Text('${r.totalSupNight}',         style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            DataCell(Text('${r.totalSkilledNight}',     style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            DataCell(Text('${r.totalUnskilledNight}',   style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            DataCell(Text('${r.totalDayManpower + r.totalNightManpower}',
                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryGreen, fontSize: 12))),
          ]),
        ],
      ),
    );
  }

  Widget _progressTable(List<Map<String, dynamic>> data) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 36,
          dataRowMinHeight: 32,
          dataRowMaxHeight: 48,
          columnSpacing: 12,
          headingTextStyle: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
          columns: const [
            DataColumn(label: Text('Activity')),
            DataColumn(label: Text('Planned %')),
            DataColumn(label: Text('Actual %')),
            DataColumn(label: Text('Planned Qty')),
            DataColumn(label: Text('Actual Qty')),
            DataColumn(label: Text('Remarks')),
          ],
          rows: data.map((p) => DataRow(cells: [
            DataCell(Text(p['activity']?.toString() ?? '',
                style: const TextStyle(fontSize: 12))),
            DataCell(Text(p['planned_percentage']?.toString() ?? '-',
                style: const TextStyle(fontSize: 12))),
            DataCell(Text(p['actual_percentage']?.toString() ?? '-',
                style: const TextStyle(fontSize: 12))),
            DataCell(Text(p['planned_qty']?.toString() ?? '-',
                style: const TextStyle(fontSize: 12))),
            DataCell(Text(p['actual_qty']?.toString() ?? '-',
                style: const TextStyle(fontSize: 12))),
            DataCell(Text(p['remarks']?.toString() ?? '-',
                style: const TextStyle(fontSize: 12))),
          ])).toList(),
        ),
      );

  Widget _plannedWorksTable(List<Map<String, dynamic>> data) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 36,
          dataRowMinHeight: 32,
          dataRowMaxHeight: 48,
          columnSpacing: 12,
          headingTextStyle: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
          columns: const [
            DataColumn(label: Text('Activity')),
            DataColumn(label: Text('Planned Qty')),
            DataColumn(label: Text('Remarks')),
          ],
          rows: data.map((w) => DataRow(cells: [
            DataCell(Text(w['activity']?.toString() ?? '',
                style: const TextStyle(fontSize: 12))),
            DataCell(Text(w['planned_quantity']?.toString() ?? '-',
                style: const TextStyle(fontSize: 12))),
            DataCell(Text(w['remarks']?.toString() ?? '-',
                style: const TextStyle(fontSize: 12))),
          ])).toList(),
        ),
      );

  Widget _photosGrid(List<Map<String, dynamic>> photos) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: photos.length,
        itemBuilder: (_, i) {
          final p = photos[i];
          final name = p['original_name']?.toString() ?? 'File ${i + 1}';
          final mime = p['mimeType']?.toString() ?? '';
          final link = p['webViewLink']?.toString() ?? '';
          final isImage = mime.contains('image');
          return GestureDetector(
            onTap: link.isNotEmpty ? () => openLink(link) : null,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(children: [
                Expanded(
                  child: isImage
                      ? ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          child: Image.network(
                            p['thumbnailLink']?.toString() ?? link,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.broken_image_outlined,
                                color: Color(0xFF94A3B8)),
                          ),
                        )
                      : Icon(
                          mime.contains('video')
                              ? Icons.play_circle_outline
                              : Icons.insert_drive_file_outlined,
                          size: 32,
                          color: AppColors.primaryGreen),
                ),
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(name,
                      style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
          );
        },
      );

  void openLink(String url) {
    // uses the host's link-confirmation dialog
  }
}