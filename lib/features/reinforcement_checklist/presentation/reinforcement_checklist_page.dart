// lib/features/reinforcement_checklist/presentation/reinforcement_checklist_page.dart

import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/utils/api_exception.dart';
import '../data/models/reinforcement_checklist_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Checklist item constants (mirrors web blade template)
// ─────────────────────────────────────────────────────────────────────────────
const List<String> _kParticulars = [
  'Diameter & number & spacing are as per drawing.',
  'Lap length is as per drawing.',
  'Bends & L are as per drawing.',
  'Chairs in proper position & adequate number. (Hidden beam if any ? Please check).',
  'Cover blocks are adequate in No. & thickness.',
  'All the coverings are in contact of steel & shuttering from both sides of beam.',
  'No one covering Blocks are suspended.',
  'Joints are well tied with Binding wire.',
  'For reduced column; bars to be joggled within beam in slop 1:6',
  'Dowels for further expansion if required (like – Chajja, Elevation feature etc) are provided.',
];

const List<String> _kLetters = [
  'a)', 'b)', 'c)', 'd)', 'e)',
  'f)', 'g)', 'h)', 'i)', 'j)',
];

// ─────────────────────────────────────────────────────────────────────────────
// Main page widget
// ─────────────────────────────────────────────────────────────────────────────

class ReinforcementChecklistPage extends StatefulWidget {
  final int projectId;
  final String projectName;

  const ReinforcementChecklistPage({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<ReinforcementChecklistPage> createState() =>
      _ReinforcementChecklistPageState();
}

class _ReinforcementChecklistPageState
    extends State<ReinforcementChecklistPage> {
  List<ReinforcementChecklistModel> _checklists = [];
  bool _isLoading = true;
  String? _error;

  static const _accentColor = Color(0xFF9F1239); // crimson-red accent

  @override
  void initState() {
    super.initState();
    _loadChecklists();
  }

  Future<void> _loadChecklists() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list =
          await ApiService.fetchReinforcementChecklists(widget.projectId);

      final sortedList = List<ReinforcementChecklistModel>.from(list)
        ..sort((a, b) {
          if (a.createdAt != null && b.createdAt != null) {
            return a.createdAt!.compareTo(b.createdAt!);
          }

          if (a.updatedAt != null && b.updatedAt != null) {
            return a.updatedAt!.compareTo(b.updatedAt!);
          }

          return a.id.compareTo(b.id);
        });

      if (!mounted) return;
      setState(() {
        _checklists = sortedList;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openForm({ReinforcementChecklistModel? existing}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _ReinforcementChecklistFormPage(
          projectId: widget.projectId,
          projectName: widget.projectName,
          existing: existing,
        ),
        fullscreenDialog: true,
      ),
    );
    if (result == true) _loadChecklists();
  }

  Future<void> _confirmDelete(ReinforcementChecklistModel c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Checklist',
            style:
                TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text(
            'Delete checklist ${c.checklistNo}? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiService.deleteReinforcementChecklist(
          widget.projectId, c.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Checklist deleted successfully'),
        backgroundColor: Color(0xFF22C55E),
      ));
      _loadChecklists();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: const Color(0xFFEF4444),
      ));
    }
  }

  void _openView(ReinforcementChecklistModel c) {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _ReinforcementChecklistViewPage(
            checklist: c,
            projectName: widget.projectName,
          ),
        ));
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final d = DateTime.parse(dateStr);
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return dateStr;
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                  color: _accentColor))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadChecklists,
                  color: _accentColor,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _buildHeader()),
                      _checklists.isEmpty
                          ? SliverFillRemaining(child: _buildEmpty())
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (_, i) => _buildCard(
                                    _checklists[i], i),
                                childCount: _checklists.length,
                              ),
                            ),
                      const SliverToBoxAdapter(
                          child: SizedBox(height: 90)),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Checklist',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildHeader() => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: _accentColor.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.settings_outlined,
                color: _accentColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text('Reinforcement Checklists',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _accentColor)),
              const SizedBox(height: 2),
              Text('WR/EXE — ${widget.projectName}',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _accentColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_checklists.length}',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13),
            ),
          ),
        ]),
      );

  Widget _buildCard(ReinforcementChecklistModel c, int index) {
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
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            color: _accentColor.withValues(alpha: 0.06),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _accentColor,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  c.checklistNo,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _accentColor),
                ),
                Text(
                  _formatDate(c.dateOfChecking),
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF64748B)),
                ),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Reinforcement',
                style: TextStyle(
                    fontSize: 10,
                    color: _accentColor,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),

        // Body
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              _infoItem(Icons.location_on_outlined, 'Location',
                  c.location),
              const SizedBox(width: 16),
              _infoItem(Icons.layers_outlined, 'Part/Wing',
                  c.partWing),
              const SizedBox(width: 16),
              _infoItem(
                  Icons.calendar_today_outlined,
                  'Casting Date',
                  c.dateOfCasting != null
                      ? _formatDate(c.dateOfCasting)
                      : null),
            ]),

            if (c.creator != null &&
                c.creator!.name.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.account_circle_outlined,
                    size: 13, color: Color(0xFF94A3B8)),
                const SizedBox(width: 5),
                Text(
                  'Created by ${c.creator!.name}',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF64748B)),
                ),
              ]),
            ],

            // Quick yes/no indicators
            const SizedBox(height: 10),
            _buildQuickIndicators(c),

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),

            // Action buttons
            Wrap(spacing: 8, runSpacing: 8, children: [
              _actionBtn(
                label: 'View',
                icon: Icons.visibility_outlined,
                color: const Color(0xFF0EA5E9),
                onTap: () => _openView(c),
              ),
              _actionBtn(
                label: 'Edit',
                icon: Icons.edit_outlined,
                color: const Color(0xFFF59E0B),
                onTap: () => _openForm(existing: c),
              ),
              _actionBtn(
                label: 'Print',
                icon: Icons.print_outlined,
                color: const Color(0xFF22C55E),
                onTap: () => _launchUrl(
                    ApiService.reinforcementChecklistPrintUrl(
                        widget.projectId, c.id)),
              ),
              _actionBtn(
                label: 'PDF',
                icon: Icons.download_outlined,
                color: const Color(0xFF8B5CF6),
                onTap: () => _launchUrl(
                    ApiService.reinforcementChecklistDownloadUrl(
                        widget.projectId, c.id)),
              ),
              _actionBtn(
                label: 'Delete',
                icon: Icons.delete_outline,
                color: const Color(0xFFEF4444),
                onTap: () => _confirmDelete(c),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _buildQuickIndicators(ReinforcementChecklistModel c) {
    final checks = <String, String?>{
      'HFL': c.hflReference,
      'Level': c.level,
      'Shuttering': c.shuttering,
      'Reinforcement': c.reinforcement,
      'Electrical': c.electrical,
      'Plumbing': c.plumbing,
      'General': c.general,
    };

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: checks.entries.map((e) {
        final val = e.value;
        final isYes = val == 'yes';
        final isNo = val == 'no';
        final color = isYes
            ? const Color(0xFF22C55E)
            : isNo
                ? const Color(0xFFEF4444)
                : const Color(0xFF94A3B8);
        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              isYes
                  ? Icons.check_circle_outline
                  : isNo
                      ? Icons.cancel_outlined
                      : Icons.help_outline,
              size: 10,
              color: color,
            ),
            const SizedBox(width: 3),
            Text(e.key,
                style: TextStyle(
                    fontSize: 9,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ]),
        );
      }).toList(),
    );
  }

  Widget _infoItem(IconData icon, String label, String? value) =>
      Expanded(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 9,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3)),
          const SizedBox(height: 2),
          Row(children: [
            Icon(icon, size: 11, color: const Color(0xFF64748B)),
            const SizedBox(width: 3),
            Expanded(
              child: Text(
                (value != null && value.isNotEmpty) ? value : 'N/A',
                style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ]),
      );

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  Widget _buildEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.settings_outlined,
                  size: 56, color: _accentColor),
            ),
            const SizedBox(height: 20),
            const Text('No Reinforcement Checklists',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            const Text(
              'Tap the button below to create your first reinforcement checklist.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
          ]),
        ),
      );

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline,
                color: Color(0xFFEF4444), size: 48),
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF1E293B))),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadChecklists,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.white),
            ),
          ]),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// View Page
// ─────────────────────────────────────────────────────────────────────────────

class _ReinforcementChecklistViewPage extends StatelessWidget {
  final ReinforcementChecklistModel checklist;
  final String projectName;

  const _ReinforcementChecklistViewPage({
    required this.checklist,
    required this.projectName,
  });

  static const _accent = Color(0xFF9F1239);

  String _fmtDate(String? d) {
    if (d == null || d.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(d);
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return d;
    }
  }

  String _yesNo(String? val) {
    if (val == 'yes') return '✓ Yes';
    if (val == 'no') return '✗ No';
    return 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          const Text('Reinforcement Checklist',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B))),
          Text(checklist.checklistNo,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF64748B))),
        ]),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Header banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                Text(checklist.checklistNo,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B))),
                const Text('WISE REALTY',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B))),
              ]),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  'CHECKLIST FOR REINFORCEMENT',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),

          // Basic info
          _sectionCard(
            title: 'Basic Information',
            icon: Icons.info_outline,
            children: [
              _row2('Checklist No.',
                  checklist.checklistNo,
                  'Date of Checking',
                  _fmtDate(checklist.dateOfChecking)),
              const SizedBox(height: 10),
              _row2('Project', projectName, 'Location',
                  checklist.location),
              const SizedBox(height: 10),
              _row2('Part/Wing', checklist.partWing,
                  'Date of Casting',
                  _fmtDate(checklist.dateOfCasting)),
            ],
          ),
          const SizedBox(height: 12),

          // Check points
          _sectionCard(
            title: 'Check Following Points',
            icon: Icons.checklist_outlined,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                      _checkRow('01) HFL Reference point',
                          checklist.hflReference),
                      _checkRow('02) Level', checklist.level),
                      _checkRow(
                          '03) Shuttering', checklist.shuttering),
                      _checkRow('04) Reinforcement',
                          checklist.reinforcement),
                      _checkRow(
                          '05) Electrical', checklist.electrical),
                      _checkRow(
                          '06) Plumbing', checklist.plumbing),
                      _checkRow('07) General', checklist.general),
                    ]),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                      const Text('Drawings available.',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF374151))),
                      const SizedBox(height: 8),
                      _checkRow(
                          '01) RCC', checklist.rccDrawing),
                      _checkRow('02) Electrical',
                          checklist.electricalDrawing),
                      _checkRow('03) Plumbing',
                          checklist.plumbingDrawing),
                      _checkRow('04) Architect',
                          checklist.architectDrawing),
                    ]),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Checklist items table
          _sectionCard(
            title: 'REINFORCEMENT (Clean & Rust Free)',
            icon: Icons.table_chart_outlined,
            children: [
              // Table header
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6)),
                child: const Row(children: [
                  SizedBox(
                      width: 30,
                      child: Text('SR',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B)))),
                  Expanded(
                      child: Text('PARTICULARS',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B)))),
                  SizedBox(
                      width: 32,
                      child: Text('YES',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B)))),
                  SizedBox(
                      width: 32,
                      child: Text('NO',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B)))),
                  SizedBox(
                      width: 80,
                      child: Text('REMARK',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B)))),
                ]),
              ),
              const SizedBox(height: 4),

              // Rows
              ...List.generate(
                  _kParticulars.length > checklist.checklistItems.length
                      ? _kParticulars.length
                      : checklist.checklistItems.length, (i) {
                if (i >= _kParticulars.length) return const SizedBox();
                final item = i < checklist.checklistItems.length
                    ? checklist.checklistItems[i]
                    : <String, dynamic>{};
                final check = item['check']?.toString();
                final remark =
                    item['remark']?.toString() ?? '';
                final isYes = check == 'yes';
                final isNo = check == 'no';

                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 7),
                  decoration: BoxDecoration(
                    color: i % 2 == 0
                        ? Colors.white
                        : const Color(0xFFFAFAFB),
                    border: Border(
                        bottom: BorderSide(
                            color: const Color(0xFFF1F5F9),
                            width: 1)),
                  ),
                  child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                    SizedBox(
                      width: 30,
                      child: Text(_kLetters[i],
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600)),
                    ),
                    Expanded(
                      child: Text(_kParticulars[i],
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF1E293B),
                              height: 1.4)),
                    ),
                    SizedBox(
                      width: 32,
                      child: Center(
                        child: Icon(
                          isYes
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 16,
                          color: isYes
                              ? const Color(0xFF22C55E)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      child: Center(
                        child: Icon(
                          isNo
                              ? Icons.cancel
                              : Icons.radio_button_unchecked,
                          size: 16,
                          color: isNo
                              ? const Color(0xFFEF4444)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child: Text(remark,
                          style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF64748B)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                );
              }),
            ],
          ),
          const SizedBox(height: 12),

          // Additional observations
          _sectionCard(
            title: 'Additional Observations',
            icon: Icons.notes_outlined,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  checklist.additionalObservations?.isNotEmpty == true
                      ? checklist.additionalObservations!
                      : 'No additional observations.',
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1E293B),
                      height: 1.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Signature section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Expanded(
                child: Column(children: [
                  const SizedBox(height: 40),
                  const Divider(color: Color(0xFF1E293B)),
                  const Text('Contractor Representative',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text('Date:',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B))),
                ]),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(children: [
                  const SizedBox(height: 40),
                  const Divider(color: Color(0xFF1E293B)),
                  const Text('Project Engineer / Client',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text('Date:',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B))),
                ]),
              ),
            ]),
          ),

          const SizedBox(height: 32),
        ]),
      ),
    );
  }

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
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10)),
            ),
            child: Row(children: [
              Icon(icon, size: 15, color: _accent),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _accent)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children),
          ),
        ]),
      );

  Widget _row2(String l1, String? v1, String l2, String? v2) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _infoRow(l1, v1)),
          const SizedBox(width: 12),
          Expanded(child: _infoRow(l2, v2)),
        ],
      );

  Widget _infoRow(String label, String? value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3)),
          const SizedBox(height: 2),
          Text(
            (value != null && value.isNotEmpty) ? value : 'N/A',
            style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w500),
          ),
        ],
      );

  Widget _checkRow(String label, String? val) {
    final isYes = val == 'yes';
    final isNo = val == 'no';
    final color = isYes
        ? const Color(0xFF22C55E)
        : isNo
            ? const Color(0xFFEF4444)
            : const Color(0xFF94A3B8);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF374151))),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            isYes
                ? '✓ Yes'
                : isNo
                    ? '✗ No'
                    : 'N/A',
            style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Form Page (Create / Edit)
// ─────────────────────────────────────────────────────────────────────────────

class _ReinforcementChecklistFormPage extends StatefulWidget {
  final int projectId;
  final String projectName;
  final ReinforcementChecklistModel? existing;

  const _ReinforcementChecklistFormPage({
    required this.projectId,
    required this.projectName,
    this.existing,
  });

  @override
  State<_ReinforcementChecklistFormPage> createState() =>
      _ReinforcementChecklistFormPageState();
}

class _ReinforcementChecklistFormPageState
    extends State<_ReinforcementChecklistFormPage> {
  static const _accent = Color(0xFF9F1239);

  // ── Form fields ─────────────────────────────────────────────────────────────
  String _checklistNo = '';
  bool _isLoadingNo = false;

  DateTime? _dateOfChecking;
  DateTime? _dateOfCasting;

  final _locationCtrl = TextEditingController();
  final _partWingCtrl = TextEditingController();

  // Check following points
  String? _hflReference;
  String? _level;
  String? _shuttering;
  String? _reinforcement;
  String? _electrical;
  String? _plumbing;
  String? _general;

  // Drawings available
  String? _rccDrawing;
  String? _electricalDrawing;
  String? _plumbingDrawing;
  String? _architectDrawing;

  // Checklist items: list of {check: 'yes'|'no'|null, remark: String}
  late List<Map<String, String?>> _checklistItems;

  final _additionalObservationsCtrl = TextEditingController();

  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _checklistItems = List.generate(
        _kParticulars.length, (_) => {'check': null, 'remark': null});

    if (_isEditing) {
      _populateFromExisting();
    } else {
      _dateOfChecking = DateTime.now();
      _loadChecklistNumber();
    }
  }

  void _populateFromExisting() {
    final c = widget.existing!;
    _checklistNo = c.checklistNo;

    try {
      _dateOfChecking = DateTime.parse(c.dateOfChecking);
    } catch (_) {
      _dateOfChecking = DateTime.now();
    }
    if (c.dateOfCasting != null && c.dateOfCasting!.isNotEmpty) {
      try {
        _dateOfCasting = DateTime.parse(c.dateOfCasting!);
      } catch (_) {}
    }

    _locationCtrl.text = c.location ?? '';
    _partWingCtrl.text = c.partWing ?? '';
    _hflReference = c.hflReference;
    _level = c.level;
    _shuttering = c.shuttering;
    _reinforcement = c.reinforcement;
    _electrical = c.electrical;
    _plumbing = c.plumbing;
    _general = c.general;
    _rccDrawing = c.rccDrawing;
    _electricalDrawing = c.electricalDrawing;
    _plumbingDrawing = c.plumbingDrawing;
    _architectDrawing = c.architectDrawing;
    _additionalObservationsCtrl.text =
        c.additionalObservations ?? '';

    if (c.checklistItems.isNotEmpty) {
      for (int i = 0; i < _kParticulars.length; i++) {
        if (i < c.checklistItems.length) {
          final item = c.checklistItems[i];
          _checklistItems[i] = {
            'check': item['check']?.toString(),
            'remark': item['remark']?.toString(),
          };
        }
      }
    }
  }

  Future<void> _loadChecklistNumber() async {
    if (!mounted) return;
    setState(() => _isLoadingNo = true);
    try {
      final no = await ApiService.generateReinforcementChecklistNumber(
          widget.projectId);
      if (mounted) setState(() => _checklistNo = no);
    } catch (_) {}
    if (mounted) setState(() => _isLoadingNo = false);
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    _partWingCtrl.dispose();
    _additionalObservationsCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<void> _pickDate(bool isChecking) async {
    final initial = isChecking
        ? (_dateOfChecking ?? DateTime.now())
        : (_dateOfCasting ?? DateTime.now());

    final lastDate = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(lastDate) ? lastDate : initial,
      firstDate: DateTime(2020),
      lastDate: lastDate,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
                primary: Color(0xFF9F1239))),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isChecking) {
          _dateOfChecking = picked;
        } else {
          _dateOfCasting = picked;
        }
      });
    }
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return 'Select date';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  List<Map<String, dynamic>> _buildChecklistPayload() {
    return _checklistItems.map((item) {
      return <String, dynamic>{
        'check': item['check'],
        'remark': item['remark'] ?? '',
      };
    }).toList();
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (_dateOfChecking == null) {
      _showError('Please select a date of checking.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (_isEditing) {
        await ApiService.updateReinforcementChecklist(
          projectId: widget.projectId,
          id: widget.existing!.id,
          dateOfChecking: _isoDate(_dateOfChecking!),
          projectName: widget.projectName,
          location: _locationCtrl.text.trim(),
          partWing: _partWingCtrl.text.trim(),
          dateOfCasting:
              _dateOfCasting != null ? _isoDate(_dateOfCasting!) : null,
          hflReference: _hflReference,
          level: _level,
          shuttering: _shuttering,
          reinforcement: _reinforcement,
          electrical: _electrical,
          plumbing: _plumbing,
          general: _general,
          rccDrawing: _rccDrawing,
          electricalDrawing: _electricalDrawing,
          plumbingDrawing: _plumbingDrawing,
          architectDrawing: _architectDrawing,
          checklistItems: _buildChecklistPayload(),
          additionalObservations:
              _additionalObservationsCtrl.text.trim(),
        );
      } else {
        await ApiService.createReinforcementChecklist(
          projectId: widget.projectId,
          checklistNo: _checklistNo,
          dateOfChecking: _isoDate(_dateOfChecking!),
          projectName: widget.projectName,
          location: _locationCtrl.text.trim(),
          partWing: _partWingCtrl.text.trim(),
          dateOfCasting:
              _dateOfCasting != null ? _isoDate(_dateOfCasting!) : null,
          hflReference: _hflReference,
          level: _level,
          shuttering: _shuttering,
          reinforcement: _reinforcement,
          electrical: _electrical,
          plumbing: _plumbing,
          general: _general,
          rccDrawing: _rccDrawing,
          electricalDrawing: _electricalDrawing,
          plumbingDrawing: _plumbingDrawing,
          architectDrawing: _architectDrawing,
          checklistItems: _buildChecklistPayload(),
          additionalObservations:
              _additionalObservationsCtrl.text.trim(),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEditing
            ? 'Reinforcement Checklist updated successfully!'
            : 'Reinforcement Checklist created successfully!'),
        backgroundColor: const Color(0xFF22C55E),
      ));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showError(e is ApiException ? e.message : e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFFEF4444),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(
            _isEditing
                ? 'Edit Reinforcement Checklist'
                : 'New Reinforcement Checklist',
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B)),
          ),
          Text(widget.projectName,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF64748B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _isSaving ? null : _submit,
              style: TextButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(
                      _isEditing ? 'Update' : 'Save',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeaderSection()),
          SliverToBoxAdapter(
              child: _buildCheckFollowingPoints()),
          SliverToBoxAdapter(child: _buildChecklistTable()),
          SliverToBoxAdapter(
              child: _buildAdditionalObservations()),
          SliverToBoxAdapter(child: _buildSignatureSection()),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  // ── Section builders ───────────────────────────────────────────────────────

  Widget _buildHeaderSection() => _card(
        title: 'Checklist Details',
        icon: Icons.info_outline,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // WR/EXE reference
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
            Text('WR/EXE/07',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B))),
            Text('WISE REALTY',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B))),
          ]),
          const SizedBox(height: 6),
          const Center(
            child: Text('CHECKLIST FOR REINFORCEMENT',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151))),
          ),
          const SizedBox(height: 14),

          // Checklist No
          _label('Checklist No.'),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Expanded(
                child: Text(
                  _isLoadingNo ? 'Generating…' : _checklistNo,
                  style: TextStyle(
                      fontSize: 13,
                      color: _isLoadingNo
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF1E293B)),
                ),
              ),
              if (_isLoadingNo)
                const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF9F1239))),
            ]),
          ),
          const SizedBox(height: 14),

          // Date of checking & project
          Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _label('Date of Checking *'),
                _datePicker(
                  value: _dateOfChecking,
                  hint: 'Select date',
                  onTap: () => _pickDate(true),
                ),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _label('Project'),
                _readOnlyField(widget.projectName),
              ]),
            ),
          ]),
          const SizedBox(height: 14),

          // Location
          _inputField(_locationCtrl, 'Location',
              hint: 'Enter location'),
          const SizedBox(height: 14),

          // Part Wing & Date of casting
          Row(children: [
            Expanded(
              child: _inputField(_partWingCtrl, 'Part/Wing',
                  hint: 'e.g. A/Wing'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _label('Date of Casting'),
                _datePicker(
                  value: _dateOfCasting,
                  hint: 'Optional',
                  onTap: () => _pickDate(false),
                ),
              ]),
            ),
          ]),
        ]),
      );

  Widget _buildCheckFollowingPoints() => _card(
        title: 'Check Following Points & Drawings',
        icon: Icons.checklist_outlined,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Check following points.',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374151))),
                const SizedBox(height: 10),
                _yesNoRow('01) HFL. Reference point',
                    _hflReference, (v) {
                  setState(() => _hflReference = v);
                }),
                _yesNoRow('02) Level', _level, (v) {
                  setState(() => _level = v);
                }),
                _yesNoRow('03) Shuttering', _shuttering, (v) {
                  setState(() => _shuttering = v);
                }),
                _yesNoRow('04) Reinforcement', _reinforcement, (v) {
                  setState(() => _reinforcement = v);
                }),
                _yesNoRow('05) Electrical', _electrical, (v) {
                  setState(() => _electrical = v);
                }),
                _yesNoRow('06) Plumbing', _plumbing, (v) {
                  setState(() => _plumbing = v);
                }),
                _yesNoRow('07) General', _general, (v) {
                  setState(() => _general = v);
                }),
              ]),
            ),
            const SizedBox(width: 16),
            // Right column
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Drawings available.',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374151))),
                const SizedBox(height: 10),
                _yesNoRow('01) RCC', _rccDrawing, (v) {
                  setState(() => _rccDrawing = v);
                }),
                _yesNoRow('02) Electrical', _electricalDrawing, (v) {
                  setState(() => _electricalDrawing = v);
                }),
                _yesNoRow('03) Plumbing', _plumbingDrawing, (v) {
                  setState(() => _plumbingDrawing = v);
                }),
                _yesNoRow('04) Architect', _architectDrawing, (v) {
                  setState(() => _architectDrawing = v);
                }),
              ]),
            ),
          ],
        ),
      );

  Widget _buildChecklistTable() => _card(
        title: 'REINFORCEMENT (Clean & Rust Free)',
        icon: Icons.table_chart_outlined,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6)),
            child: const Row(children: [
              SizedBox(
                  width: 28,
                  child: Text('SR',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B)))),
              Expanded(
                  child: Text('PARTICULARS',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B)))),
              SizedBox(
                  width: 38,
                  child: Text('YES',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B)))),
              SizedBox(
                  width: 38,
                  child: Text('NO',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B)))),
              SizedBox(
                  width: 90,
                  child: Text('REMARK',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B)))),
            ]),
          ),
          const SizedBox(height: 4),

          // Rows
          ...List.generate(_kParticulars.length, (i) {
            final item = _checklistItems[i];
            final check = item['check'];

            return Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: i % 2 == 0
                    ? Colors.white
                    : const Color(0xFFFAFAFB),
                border: Border(
                    bottom: BorderSide(
                        color: const Color(0xFFF1F5F9), width: 1)),
              ),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                SizedBox(
                  width: 28,
                  child: Text(_kLetters[i],
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  child: Text(_kParticulars[i],
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF1E293B),
                          height: 1.4)),
                ),
                const SizedBox(width: 4),
                // YES radio
                SizedBox(
                  width: 38,
                  child: Center(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _checklistItems[i] = {
                          ...item,
                          'check':
                              check == 'yes' ? null : 'yes',
                        };
                      }),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: check == 'yes'
                              ? const Color(0xFF22C55E)
                              : Colors.white,
                          border: Border.all(
                              color: check == 'yes'
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFFD1D5DB),
                              width: 2),
                        ),
                        child: check == 'yes'
                            ? const Icon(Icons.check,
                                size: 13, color: Colors.white)
                            : null,
                      ),
                    ),
                  ),
                ),
                // NO radio
                SizedBox(
                  width: 38,
                  child: Center(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _checklistItems[i] = {
                          ...item,
                          'check': check == 'no' ? null : 'no',
                        };
                      }),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: check == 'no'
                              ? const Color(0xFFEF4444)
                              : Colors.white,
                          border: Border.all(
                              color: check == 'no'
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFFD1D5DB),
                              width: 2),
                        ),
                        child: check == 'no'
                            ? const Icon(Icons.close,
                                size: 13, color: Colors.white)
                            : null,
                      ),
                    ),
                  ),
                ),
                // Remark input
                SizedBox(
                  width: 90,
                  child: SizedBox(
                    height: 32,
                    child: TextField(
                      controller: TextEditingController(
                          text: item['remark'] ?? ''),
                      onChanged: (v) {
                        _checklistItems[i] = {
                          ...item,
                          'remark': v,
                        };
                      },
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF1E293B)),
                      decoration: InputDecoration(
                        hintText: 'Remark',
                        hintStyle: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFFCBD5E1)),
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(4),
                            borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(4),
                            borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(4),
                            borderSide: const BorderSide(
                                color: Color(0xFF9F1239),
                                width: 1.5)),
                        contentPadding:
                            const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                        isDense: true,
                      ),
                    ),
                  ),
                ),
              ]),
            );
          }),
        ]),
      );

  Widget _buildAdditionalObservations() => _card(
        title: 'Additional Observations if any',
        icon: Icons.notes_outlined,
        child: TextField(
          controller: _additionalObservationsCtrl,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Enter additional observations…',
            hintStyle: const TextStyle(
                fontSize: 13, color: Color(0xFFCBD5E1)),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                    color: Color(0xFF9F1239), width: 1.5)),
            contentPadding: const EdgeInsets.all(12),
          ),
          style: const TextStyle(
              fontSize: 13, color: Color(0xFF1E293B)),
        ),
      );

  Widget _buildSignatureSection() => _card(
        title: 'Signatures',
        icon: Icons.draw_outlined,
        child: Row(children: [
          Expanded(
            child: Column(children: [
              const SizedBox(height: 40),
              const Divider(color: Color(0xFF1E293B)),
              const Text('Contractor Representative',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              const Text('Date:',
                  style: TextStyle(
                      fontSize: 11, color: Color(0xFF64748B))),
            ]),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(children: [
              const SizedBox(height: 40),
              const Divider(color: Color(0xFF1E293B)),
              const Text('Project Engineer / Client',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              const Text('Date:',
                  style: TextStyle(
                      fontSize: 11, color: Color(0xFF64748B))),
            ]),
          ),
        ]),
      );

  // ── Reusable widgets ───────────────────────────────────────────────────────

  Widget _card({
    required String title,
    required IconData icon,
    required Widget child,
  }) =>
      Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: _accent.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12)),
            ),
            child: Row(children: [
              Icon(icon, size: 15, color: _accent),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _accent)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        ]),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151))),
      );

  Widget _readOnlyField(String value) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(value,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF64748B))),
      );

  Widget _inputField(
    TextEditingController ctrl,
    String label, {
    String? hint,
    TextInputType? type,
    int maxLines = 1,
  }) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label(label),
        TextField(
          controller: ctrl,
          keyboardType: type,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
                fontSize: 13, color: Color(0xFFCBD5E1)),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                    color: Color(0xFF9F1239), width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 11),
            isDense: true,
          ),
          style: const TextStyle(
              fontSize: 13, color: Color(0xFF1E293B)),
        ),
      ]);

  Widget _datePicker({
    required DateTime? value,
    required String hint,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Expanded(
              child: Text(
                value != null ? _fmtDate(value) : hint,
                style: TextStyle(
                    fontSize: 13,
                    color: value != null
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFCBD5E1)),
              ),
            ),
            Icon(Icons.calendar_today_outlined,
                size: 16,
                color: value != null
                    ? _accent
                    : const Color(0xFF94A3B8)),
          ]),
        ),
      );

  Widget _yesNoRow(
      String label, String? value, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: Color(0xFF374151))),
        const SizedBox(height: 5),
        Row(children: [
          _radioChip('Yes', 'yes', value, onChanged),
          const SizedBox(width: 8),
          _radioChip('No', 'no', value, onChanged),
        ]),
      ]),
    );
  }

  Widget _radioChip(String label, String val, String? current,
      ValueChanged<String?> onChanged) {
    final selected = current == val;
    final color = val == 'yes'
        ? const Color(0xFF22C55E)
        : const Color(0xFFEF4444);

    return GestureDetector(
      onTap: () => onChanged(selected ? null : val),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.1)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: selected
                  ? color
                  : const Color(0xFFE2E8F0),
              width: selected ? 1.5 : 1),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                color: selected ? color : const Color(0xFF64748B),
                fontWeight: selected
                    ? FontWeight.w700
                    : FontWeight.w500)),
      ),
    );
  }
}