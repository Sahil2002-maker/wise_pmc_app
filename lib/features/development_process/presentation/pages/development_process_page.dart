// lib/features/development_process/presentation/pages/development_process_page.dart

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/auth_storage_service.dart';
import '../../../../core/utils/api_exception.dart';
import '../../data/models/development_process_model.dart';
import '../../data/services/development_process_api.dart';
import '../widgets/assign_process_sheet.dart';
import 'document_viewer_page.dart';

// ─── Role helpers ─────────────────────────────────────────────────────────────

Future<String> _fetchUserRole() async =>
    (await AuthStorageService.getUserRole() ?? '').trim().toLowerCase();

Future<bool> _checkIsAdmin() async {
  final r = await _fetchUserRole();
  return r == 'admin';
}

Future<bool> _checkIsTeamLeader() async {
  final r = await _fetchUserRole();
  return r == 'teamleader' || r == 'team leader' || r == 'leader';
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class DevelopmentProcessPage extends StatefulWidget {
  final int projectId;
  final String projectName;
  final String projectStatus;

  const DevelopmentProcessPage({
    super.key,
    required this.projectId,
    required this.projectName,
    this.projectStatus = '',
  });

  @override
  State<DevelopmentProcessPage> createState() => _DevelopmentProcessPageState();
}

class _DevelopmentProcessPageState extends State<DevelopmentProcessPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _loading = true;
  String? _error;
  int _currentTab = 0;

  // Role flags
  bool _isAdmin = false;
  bool _isTeamLeader = false;

  // Stage data — always 4 stages (0–3)
  final List<DevelopmentStageData> _stages = List.generate(
    4,
    (i) => DevelopmentStageData(
      stageNumber: i,
      stageLabel: 'Stage $i',
      processes: const [],
    ),
  );

  // Track in-progress actions per orderNo key
  final Set<String> _assigningKeys = {};
  final Set<String> _uploadingKeys = {};
  final Set<String> _viewingKeys = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _currentTab = _tabController.index);
      }
    });
    _init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> _init() async {
    final adminFlag = await _checkIsAdmin();
    final tlFlag = await _checkIsTeamLeader();
    if (mounted) {
      setState(() {
        _isAdmin = adminFlag;
        _isTeamLeader = tlFlag;
      });
    }
    await _loadProcesses();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadProcesses() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await DevelopmentProcessApi.fetchDevelopmentProcesses(
          widget.projectId);

      debugPrint('[DevelopmentProcessPage] raw response keys: ${raw.keys.toList()}');
      debugPrint('[DevelopmentProcessPage] raw response: $raw');

      final newStages = _parseStages(raw);

      if (mounted) {
        setState(() {
          for (int i = 0; i < 4; i++) {
            _stages[i] = i < newStages.length
                ? newStages[i]
                : DevelopmentStageData(
                    stageNumber: i,
                    stageLabel: 'Stage $i',
                    processes: const [],
                  );
          }
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[DevelopmentProcessPage] error: $e');
      if (mounted) {
        setState(() {
          _error = e is ApiException ? e.message : e.toString();
          _loading = false;
        });
      }
    }
  }

  List<DevelopmentStageData> _parseStages(Map<String, dynamic> raw) {
    // ── Strategy 1: "stages" key is a List (primary API format) ──────────
    final stagesList = raw['stages'];
    if (stagesList is List && stagesList.isNotEmpty) {
      debugPrint('[DevelopmentProcessPage] parsing stages as List (${stagesList.length} items)');

      final stageMap = <int, DevelopmentStageData>{};

      for (final item in stagesList) {
        if (item is! Map<String, dynamic>) continue;

        final stageNum = int.tryParse(item['stage']?.toString() ?? '') ?? -1;
        if (stageNum < 0 || stageNum > 3) continue;

        final rawProcesses = item['processes'];
        final rawAssignments = item['assignments'];

        final assignmentsByProcessId = <int, DevelopmentProcessAssignment>{};
        if (rawAssignments is List) {
          for (final a in rawAssignments) {
            if (a is Map<String, dynamic>) {
              final assignment = DevelopmentProcessAssignment.fromJson(a);
              if (assignment.processId != null) {
                assignmentsByProcessId[assignment.processId!] = assignment;
              }
            }
          }
        }

        final processes = <DevelopmentProcessItem>[];
        if (rawProcesses is List) {
          for (final p in rawProcesses) {
            if (p is! Map<String, dynamic>) continue;

            DevelopmentProcessAssignment? assignment;
            final embedded = p['assignment'];
            if (embedded is Map<String, dynamic>) {
              assignment = DevelopmentProcessAssignment.fromJson(embedded);
            } else {
              final pid = int.tryParse(p['process_id']?.toString() ?? '');
              if (pid != null) {
                assignment = assignmentsByProcessId[pid];
              }
            }

            processes.add(DevelopmentProcessItem(
              processId: int.tryParse(p['process_id']?.toString() ?? ''),
              processName: p['process_name']?.toString() ?? '',
              orderNo: int.tryParse(p['order_no']?.toString() ?? ''),
              stage: p['stage']?.toString() ?? 'stage $stageNum',
              teamId: int.tryParse(p['team_id']?.toString() ?? ''),
              teamName: p['team_name']?.toString() ??
                  (p['team'] is Map ? p['team']['team_name']?.toString() : null),
              teamColor: p['team_color']?.toString() ??
                  (p['team'] is Map ? p['team']['team_color']?.toString() : null),
              assignment: assignment,
            ));
          }
        }

        stageMap[stageNum] = DevelopmentStageData(
          stageNumber: stageNum,
          stageLabel: item['stage_label']?.toString() ?? 'Stage $stageNum',
          processes: processes,
        );
      }

      return List.generate(4, (i) {
        return stageMap[i] ??
            DevelopmentStageData(
              stageNumber: i,
              stageLabel: 'Stage $i',
              processes: const [],
            );
      });
    }

    // ── Strategy 2: "stages" key is a Map with "stage0", "stage1"… keys ──
    if (stagesList is Map) {
      debugPrint('[DevelopmentProcessPage] parsing stages as Map');
      return List.generate(4, (i) {
        final key = 'stage$i';
        final list = stagesList[key] as List? ?? [];
        return DevelopmentStageData(
          stageNumber: i,
          stageLabel: 'Stage $i',
          processes: list
              .whereType<Map<String, dynamic>>()
              .map(DevelopmentProcessItem.fromJson)
              .toList(),
        );
      });
    }

    // ── Strategy 3: Flat stage{N}Processes keys at the top level ─────────
    final hasFlat = raw.keys.any((k) => k.startsWith('stage') && k.endsWith('Processes'));
    if (hasFlat) {
      debugPrint('[DevelopmentProcessPage] parsing stages as flat keys');
      return List.generate(4, (i) {
        final key = 'stage${i}Processes';
        final list = (raw[key] as List?) ?? [];
        return DevelopmentStageData(
          stageNumber: i,
          stageLabel: 'Stage $i',
          processes: list
              .whereType<Map<String, dynamic>>()
              .map(DevelopmentProcessItem.fromJson)
              .toList(),
        );
      });
    }

    debugPrint('[DevelopmentProcessPage] WARNING: could not parse stages from response. Keys: ${raw.keys.toList()}');
    return List.generate(
      4,
      (i) => DevelopmentStageData(
        stageNumber: i,
        stageLabel: 'Stage $i',
        processes: const [],
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  bool get _canAssign => _isAdmin || _isTeamLeader;

  Future<void> _openAssignSheet(
      DevelopmentProcessItem process, int stageNum) async {
    // FIX: Pass projectId explicitly so AssignProcessSheet always includes
    // project_id in the API payload — fixes "The project id field is required."
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AssignProcessSheet(
        process: process,
        stageNumber: stageNum,
        projectId: widget.projectId, // ← always explicitly passed
      ),
    );

    if (result != null && mounted) {
      await _loadProcesses();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result['not_applicable'] == true
                      ? 'Marked as Not Applicable.'
                      : 'Process assigned successfully.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ]),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Future<void> _uploadFile(
      DevelopmentProcessItem process, int stageNum) async {
    final key = '${stageNum}_${process.orderNo}';
    if (_uploadingKeys.contains(key)) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (picked == null || picked.files.isEmpty) return;
    final pf = picked.files.first;
    if (pf.path == null) return;

    setState(() => _uploadingKeys.add(key));

    try {
      // FIX: pass projectId explicitly — avoids "project_id is required" error
      await DevelopmentProcessApi.uploadDevelopmentProcessFile(
        projectId: widget.projectId,
        stageNumber: stageNum,
        processId: process.processId ?? 0,
        orderNo: process.orderNo ?? 0,
        file: File(pf.path!),
        fileName: pf.name,
      );
      await _loadProcesses();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.upload_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('File uploaded successfully.',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ]),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is ApiException ? e.message : e.toString()),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingKeys.remove(key));
    }
  }

  Future<void> _viewFile(
    DevelopmentProcessItem process,
    int stageNum,
    String filePath,
  ) async {
    if (filePath.isEmpty) {
      if (mounted) _showErrorSnackBar('No file is attached to this process.');
      return;
    }

    final key = '${stageNum}_${process.orderNo}';
    if (_viewingKeys.contains(key)) return;

    setState(() => _viewingKeys.add(key));

    try {
      final url = await DevelopmentProcessApi.getFileUrl(filePath);

      if (url.isEmpty) {
        throw ApiException('The file URL returned by the server is empty.');
      }

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentViewerPage(
            url: url,
            title: process.processName,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) _showErrorSnackBar(e.message);
    } catch (e) {
      if (mounted) _showErrorSnackBar('Could not open file. Please try again.');
    } finally {
      if (mounted) setState(() => _viewingKeys.remove(key));
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : _error != null
              ? _buildError()
              : _buildBody(),
    );
  }

  Widget _buildError() => CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverFillRemaining(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(36)),
                      child: const Icon(Icons.error_outline_rounded,
                          color: Color(0xFFEF4444), size: 36),
                    ),
                    const SizedBox(height: 20),
                    const Text('Failed to load processes',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B))),
                    const SizedBox(height: 8),
                    Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Color(0xFF64748B), fontSize: 13)),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _loadProcesses,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );

  Widget _buildBody() {
    return CustomScrollView(
      slivers: [
        _buildAppBar(),
        SliverToBoxAdapter(child: _buildTabBar()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          sliver: _buildCurrentStageList(),
        ),
      ],
    );
  }

  // ── App Bar ───────────────────────────────────────────────────────────────

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 130,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF7C3AED),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: _loading ? null : _loadProcesses,
          tooltip: 'Refresh',
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF5B21B6), Color(0xFF7C3AED)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(56, 12, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text('Development Process',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.projectName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusChip(status: widget.projectStatus),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Tab Bar ───────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF7C3AED),
        unselectedLabelColor: const Color(0xFF94A3B8),
        indicatorColor: const Color(0xFF7C3AED),
        indicatorWeight: 3,
        labelStyle:
            const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        tabs: List.generate(4, (i) {
          final count =
              i < _stages.length ? _stages[i].processes.length : 0;
          return Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Stage $i'),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _currentTab == i
                        ? const Color(0xFF7C3AED)
                        : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _currentTab == i
                          ? Colors.white
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── Stage process list ────────────────────────────────────────────────────

  Widget _buildCurrentStageList() {
    if (_currentTab >= _stages.length) {
      return const SliverToBoxAdapter(child: _EmptyStage());
    }
    final stage = _stages[_currentTab];
    if (stage.processes.isEmpty) {
      return const SliverToBoxAdapter(child: _EmptyStage());
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final process = stage.processes[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ProcessCard(
              process: process,
              serialNo: index + 1,
              stageNumber: stage.stageNumber,
              canAssign: _canAssign,
              uploadingKeys: _uploadingKeys,
              viewingKeys: _viewingKeys,
              onAssign: () => _openAssignSheet(process, stage.stageNumber),
              onUpload: () => _uploadFile(process, stage.stageNumber),
              onViewFile: () => _viewFile(
                process,
                stage.stageNumber,
                process.assignment?.filePath ?? '',
              ),
            ),
          );
        },
        childCount: stage.processes.length,
      ),
    );
  }
}

// ─── Status Chip ──────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final started = status.toLowerCase() == 'started';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (started
                ? const Color(0xFF22C55E)
                : const Color(0xFFF59E0B))
            .withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: started
              ? const Color(0xFF22C55E)
              : const Color(0xFFF59E0B),
          width: 1,
        ),
      ),
      child: Text(
        status.isEmpty
            ? 'Pending'
            : '${status[0].toUpperCase()}${status.substring(1).toLowerCase()}',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: started
              ? const Color(0xFF22C55E)
              : const Color(0xFFF59E0B),
        ),
      ),
    );
  }
}

// ─── Empty Stage ──────────────────────────────────────────────────────────────

class _EmptyStage extends StatelessWidget {
  const _EmptyStage();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(36),
            ),
            child: const Icon(Icons.inbox_rounded,
                color: Color(0xFFCBD5E1), size: 36),
          ),
          const SizedBox(height: 16),
          const Text('No processes found',
              style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text(
            'Processes added via the web admin will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─── Process Card ─────────────────────────────────────────────────────────────

class _ProcessCard extends StatelessWidget {
  final DevelopmentProcessItem process;
  final int serialNo;
  final int stageNumber;
  final bool canAssign;
  final Set<String> uploadingKeys;
  final Set<String> viewingKeys;
  final VoidCallback onAssign;
  final VoidCallback onUpload;
  final VoidCallback onViewFile;

  const _ProcessCard({
    required this.process,
    required this.serialNo,
    required this.stageNumber,
    required this.canAssign,
    required this.uploadingKeys,
    required this.viewingKeys,
    required this.onAssign,
    required this.onUpload,
    required this.onViewFile,
  });

  String get _uploadKey => '${stageNumber}_${process.orderNo}';
  String get _viewKey => '${stageNumber}_${process.orderNo}';
  bool get _isUploading => uploadingKeys.contains(_uploadKey);
  bool get _isViewing => viewingKeys.contains(_viewKey);

  @override
  Widget build(BuildContext context) {
    final assign = process.assignment;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            // Colored top accent bar
            Container(
              height: 3,
              decoration: BoxDecoration(color: _stageColor(stageNumber)),
            ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header row ──────────────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Serial number badge
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: _stageColor(stageNumber)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '$serialNo',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _stageColor(stageNumber),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Process name + deadline
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
                            if (assign?.deadline != null) ...[
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded,
                                      size: 11, color: Color(0xFFEF4444)),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Deadline: ${assign!.deadline}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFFEF4444),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Status badge
                      _StatusBadge(assignment: assign),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // ── Team + Assign To row ─────────────────────────────────
                  Row(
                    children: [
                      if (process.teamName != null) ...[
                        _TeamChip(
                          name: process.teamName!,
                          color: process.teamColor,
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (assign != null && !assign.isNA)
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.person_rounded,
                                  size: 13, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  assign.assignedUserName ?? 'Assigned',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF22C55E),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 12),

                  // ── Action buttons ───────────────────────────────────────
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Assign button (admin/team leader)
                      if (canAssign)
                        _ActionButton(
                          label: (assign != null && !assign.isNA)
                              ? 'Re-assign'
                              : 'Assign',
                          icon: Icons.person_add_rounded,
                          color: const Color(0xFF7C3AED),
                          onTap: onAssign,
                        ),

                      // Upload button
                      if (assign != null && !assign.isNA)
                        _ActionButton(
                          label: assign.hasFile ? 'Re-upload' : 'Upload',
                          icon: assign.hasFile
                              ? Icons.replay_rounded
                              : Icons.upload_rounded,
                          color: const Color(0xFFF59E0B),
                          loading: _isUploading,
                          onTap: _isUploading ? null : onUpload,
                        ),

                      // View button
                      if (assign != null && !assign.isNA && assign.hasFile)
                        _ActionButton(
                          label: 'View',
                          icon: Icons.visibility_rounded,
                          color: const Color(0xFF0EA5E9),
                          loading: _isViewing,
                          onTap: _isViewing ? null : onViewFile,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _stageColor(int stage) {
    const colors = [
      Color(0xFF6366F1),
      Color(0xFF3B82F6),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
    ];
    return colors[stage % colors.length];
  }
}

// ─── Status Badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final DevelopmentProcessAssignment? assignment;
  const _StatusBadge({this.assignment});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;

    if (assignment == null) {
      label = 'Pending';
      color = const Color(0xFFF59E0B);
    } else if (assignment!.isNA) {
      label = 'N/A';
      color = const Color(0xFF94A3B8);
    } else if (assignment!.isCompleted) {
      label = 'Completed';
      color = const Color(0xFF22C55E);
    } else if (assignment!.isAssigned) {
      label = 'Assigned';
      color = const Color(0xFF3B82F6);
    } else {
      label = 'Pending';
      color = const Color(0xFFF59E0B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

// ─── Team Chip ────────────────────────────────────────────────────────────────

class _TeamChip extends StatelessWidget {
  final String name;
  final String? color;
  const _TeamChip({required this.name, this.color});

  @override
  Widget build(BuildContext context) {
    Color bgColor = const Color(0xFF6C757D);
    try {
      if (color != null && color!.isNotEmpty) {
        final hex = color!.replaceAll('#', '');
        bgColor = Color(int.parse('FF$hex', radix: 16));
      }
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        name,
        style: const TextStyle(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ─── Action Button ────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool loading;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: loading
          ? const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : Icon(icon, size: 13),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: color.withValues(alpha: 0.5),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}