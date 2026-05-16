// lib/features/development_process/presentation/pages/dev_process_project_page.dart
//
// Project-scoped Development Process page.
// Shows all four stages (tabs). Each process row displays:
//   • Assignment info (assigned user + deadline)
//   • Document upload / view tile (S3 via backend)
//
// Role awareness:
//   admin      → sees everything, can assign + upload
//   teamleader → sees own team only, can assign + upload
//   employee   → sees only assigned processes, can upload documents
//
// The page calls:
//   GET  /api/mobile/development-process/project/{projectId}
//   POST /api/mobile/development-process/assign
//   POST /api/mobile/development-process/{projectId}/upload   ← NEW
//   GET  /api/mobile/development-process/file-url?path=…     ← NEW

import 'package:flutter/material.dart';

import '../../../../core/services/api_service.dart';
import '../../../../core/utils/api_exception.dart';
import '../../data/models/dev_process_model.dart';
import '../../data/services/dev_process_upload_service.dart';
import '../widgets/dev_process_document_tile.dart';

class DevProcessProjectPage extends StatefulWidget {
  final int projectId;
  final String projectName;

  const DevProcessProjectPage({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<DevProcessProjectPage> createState() =>
      _DevProcessProjectPageState();
}

class _DevProcessProjectPageState extends State<DevProcessProjectPage>
    with SingleTickerProviderStateMixin {
  // ── Constants ──────────────────────────────────────────────────────────────
  static const Color _accent    = Color(0xFF2563EB);
  static const Color _accentEnd = Color(0xFF1D4ED8);

  static const List<String> _stageTitles = [
    'Stage 0', 'Stage 1', 'Stage 2', 'Stage 3',
  ];

  // ── State ──────────────────────────────────────────────────────────────────
  late TabController _tabController;

  bool    _loading = true;
  String? _error;
  String  _role    = 'employee';

  /// Key: stageNum (0-3)  Value: list of processes for that stage
  final Map<int, List<DevProcessModel>> _stageProcesses = {
    0: [], 1: [], 2: [], 3: [],
  };

  /// Key: process_id   Value: assignment data (includes document_path)
  final Map<int, DevProcessAssignmentModel> _assignments = {};

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error   = null;
    });

    try {
      final data =
          await ApiService.fetchDevProjectProcesses(widget.projectId);

      final role = data['role']?.toString() ?? 'employee';

      // Parse stages array from the response.
      // Shape: { success, project, role, stages: [ { stage, processes, assignments } ] }
      final stagesRaw = data['stages'] as List? ?? [];

      final Map<int, List<DevProcessModel>>         processes   = {};
      final Map<int, DevProcessAssignmentModel>     assignments = {};

      for (final rawStage in stagesRaw) {
        if (rawStage is! Map) continue;
        final stageNum = _parseInt(rawStage['stage']) ?? 0;

        // Processes
        final rawProcesses = rawStage['processes'] as List? ?? [];
        processes[stageNum] = rawProcesses
            .whereType<Map<String, dynamic>>()
            .map(DevProcessModel.fromJson)
            .toList();

        // Assignments keyed by process_id
        final rawAssignments = rawStage['assignments'];
        if (rawAssignments is List) {
          for (final a in rawAssignments) {
            if (a is Map<String, dynamic>) {
              final m = DevProcessAssignmentModel.fromJson(a);
              if (m.processId != null) {
                assignments[m.processId!] = m;
              }
            }
          }
        } else if (rawAssignments is Map) {
          // Sometimes the API returns a map keyed by process_id
          rawAssignments.forEach((key, value) {
            if (value is Map<String, dynamic>) {
              final m = DevProcessAssignmentModel.fromJson(value);
              final pid = _parseInt(key) ?? m.processId;
              if (pid != null) assignments[pid] = m;
            }
          });
        }
      }

      if (mounted) {
        setState(() {
          _role = role;
          _stageProcesses
            ..clear()
            ..addAll(processes);
          _assignments
            ..clear()
            ..addAll(assignments);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error   = e is ApiException ? e.message : e.toString();
          _loading = false;
        });
      }
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  void _onAssignmentUploaded(
      int processId, DevProcessAssignmentModel updated) {
    setState(() => _assignments[processId] = updated);
  }

  void _toast(String msg, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            color: Colors.white, size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ]),
        backgroundColor:
            success ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _accent))
          : _error != null
              ? _buildError()
              : _buildBody(),
    );
  }

  Widget _buildError() {
    return CustomScrollView(
      slivers: [
        _buildAppBar(),
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Color(0xFFEF4444), size: 48),
                  const SizedBox(height: 16),
                  const Text('Failed to load',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
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
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return CustomScrollView(
      slivers: [
        _buildAppBar(),
        SliverToBoxAdapter(child: _buildTabBar()),
        ..._buildStageContent(),
      ],
    );
  }

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 110,
      pinned: true,
      backgroundColor: _accent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: _load,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_accent, _accentEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(56, 12, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    widget.projectName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Development Process · ${_role.toUpperCase()}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: _accent,
        unselectedLabelColor: const Color(0xFF94A3B8),
        indicatorColor: _accent,
        indicatorWeight: 3,
        labelStyle:
            const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        tabs: List.generate(4, (i) {
          final count = _stageProcesses[i]?.length ?? 0;
          return Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_stageTitles[i]),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _accent),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  List<Widget> _buildStageContent() {
    // We render all four stages in a single scroll column, switching via the
    // TabController is handled by the TabBar above; for a true TabBarView the
    // caller can wrap this page inside a DefaultTabController + TabBarView.
    // Here we use a simple animated stage switcher to keep the scroll intact.
    return [
      SliverToBoxAdapter(
        child: TabBarView(
          controller: _tabController,
          children: List.generate(
            4,
            (stageNum) => _buildStageList(stageNum),
          ),
        ),
      ),
    ];
  }

  Widget _buildStageList(int stageNum) {
    final list = _stageProcesses[stageNum] ?? [];

    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_rounded,
                color: Color(0xFFCBD5E1), size: 48),
            const SizedBox(height: 12),
            Text(
              'No processes in ${_stageTitles[stageNum]}',
              style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final p          = list[i];
        final assignment = _assignments[p.processId];
        return _ProcessCard(
          serialNo:    i + 1,
          process:     p,
          assignment:  assignment,
          projectId:   widget.projectId,
          onUploaded:  (updated) =>
              _onAssignmentUploaded(p.processId, updated),
        );
      },
    );
  }
}

// ─── _ProcessCard ─────────────────────────────────────────────────────────────
// Renders one process row with its assignment summary and document tile.

class _ProcessCard extends StatelessWidget {
  final int serialNo;
  final DevProcessModel process;
  final DevProcessAssignmentModel? assignment;
  final int projectId;
  final ValueChanged<DevProcessAssignmentModel> onUploaded;

  static const Color _accent = Color(0xFF2563EB);

  const _ProcessCard({
    required this.serialNo,
    required this.process,
    required this.assignment,
    required this.projectId,
    required this.onUploaded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Accent strip in team colour ────────────────────────────────
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: _hexColor(process.teamColor),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header row ───────────────────────────────────────────
                Row(
                  children: [
                    // Order badge
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${process.orderNo}',
                          style: const TextStyle(
                            color: _accent,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            process.processName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          if (process.teamName != null)
                            Text(
                              process.teamName!,
                              style: TextStyle(
                                fontSize: 11,
                                color: _hexColor(process.teamColor),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Stage chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        process.stageLabel,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _accent,
                        ),
                      ),
                    ),
                  ],
                ),

                // ── Assignment summary ───────────────────────────────────
                if (assignment != null) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 10),
                  _AssignmentSummary(assignment: assignment!),
                ],

                // ── Document tile ────────────────────────────────────────
                const SizedBox(height: 10),
                DevProcessDocumentTile(
                  projectId:  projectId,
                  processId:  process.processId,
                  orderNo:    process.orderNo,
                  assignment: assignment,
                  onUploaded: onUploaded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Color _hexColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      }
    } catch (_) {}
    return const Color(0xFF6366F1);
  }
}

// ─── _AssignmentSummary ───────────────────────────────────────────────────────

class _AssignmentSummary extends StatelessWidget {
  final DevProcessAssignmentModel assignment;

  const _AssignmentSummary({required this.assignment});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        if (assignment.assignedUser != null)
          _Chip(
            icon: Icons.person_outline_rounded,
            label: assignment.assignedUser!,
            color: const Color(0xFF6366F1),
          ),
        if (assignment.deadline != null)
          _Chip(
            icon: Icons.calendar_today_rounded,
            label: assignment.deadline!,
            color: const Color(0xFFF59E0B),
          ),
        if (assignment.status != null)
          _Chip(
            icon: Icons.flag_rounded,
            label: assignment.status!,
            color: _statusColor(assignment.status!),
          ),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFF16A34A);
      case 'in_progress':
      case 'in progress':
        return const Color(0xFF0EA5E9);
      default:
        return const Color(0xFF94A3B8);
    }
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Chip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}