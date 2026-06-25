// lib/features/development_process/presentation/pages/development_process_page.dart
//
// KEY CHANGES vs previous version
// ─────────────────────────────────────────────────────────────────────────────
//
//  1. _currentUserId field added.
//     Loaded once in _init() via AuthStorageService.getUserId() so every card
//     can decide "am I the assignee?" without a role check.
//
//  2. _ProcessCard now receives `currentUserId` (int?).
//     The Re-upload button visibility is now:
//       • File exists     → only the ASSIGNED USER can re-upload
//                           (i.e. assignment.assignedTo == currentUserId)
//       • No file yet     → the assigned user can do the FIRST upload
//                           (same rule — only the assignee)
//       EXCEPTION: Admin can always re-upload (matches web portal behaviour)
//
//  3. View button logic is unchanged — any role with canViewFiles can view
//     a completed process. This matches the web portal "View" column.
//
//  4. Assign button logic is unchanged — canAssign (admin/TL), hidden once
//     the process has a file (completed).
//
// These four rules now exactly mirror the web DevelopmentProcessController
// and the blade view's button-visibility conditions.

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

import '../../../stage21/presentation/pages/stage21_tab_page.dart';
import '../../../cc_progress/presentation/cc_progress_page.dart';
import '../../../layout_approval/presentation/layout_approval_page.dart';
import '../../../oc_progress/presentation/oc_progress_page.dart';

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

Future<bool> _checkIsTeamMember() async {
  final r = await _fetchUserRole();
  return r == 'employee' || r == 'member' || r == 'teammember' || r == 'team member';
}

// ─── Tab index constants ──────────────────────────────────────────────────────

const int _kStage21        = 3;
const int _kStage3         = 4;
const int _kCcProcess      = 5;
const int _kLayoutApproval = 6;
const int _kOcProgress     = 7;
const int _kTabCount       = 8;

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
  State<DevelopmentProcessPage> createState() =>
      _DevelopmentProcessPageState();
}

class _DevelopmentProcessPageState extends State<DevelopmentProcessPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool    _loading    = true;
  String? _error;
  int     _currentTab = 0;

  bool _isAdmin      = false;
  bool _isTeamLeader = false;
  bool _isTeamMember = false;

  // ── NEW: current logged-in user's numeric ID ──────────────────────────────
  // Used to decide whether the upload button is visible on a given card.
  int? _currentUserId;

  bool get _showProcessTabs => _isAdmin || _isTeamLeader || _isTeamMember;
  int  get _effectiveTabCount =>
      _showProcessTabs ? _kTabCount : _kStage3 + 1;

  // ── Role-based permission flags ───────────────────────────────────────────
  //
  // canAssign   → admin or team leader can assign/re-assign
  // canViewFiles → admin, TL, or member can view a completed document
  // canAdminReUpload → ONLY admin can override and re-upload ANY completed file
  //                    (matches web portal's admin-always-visible Re-upload)
  bool get _canAssign        => _isAdmin || _isTeamLeader;
  bool get _canViewFiles     => _isAdmin || _isTeamLeader || _isTeamMember;
  bool get _canAdminReUpload => _isAdmin;

  final List<DevelopmentStageData> _stages = List.generate(
    4,
    (i) => DevelopmentStageData(
      stageNumber: i,
      stageLabel:  'Stage $i',
      processes:   const [],
    ),
  );

  int _stage21Count = 0;

  final Set<String> _assigningKeys = {};
  final Set<String> _uploadingKeys = {};
  final Set<String> _viewingKeys   = {};

  static const List<String> _tabLabels = [
    'Stage 0', 'Stage 1', 'Stage 2', 'Stage 2.1',
    'Stage 3', 'CC Process', 'Layout Approval', 'OC Progress',
  ];

  static const _ccColor     = Color(0xFF3B82F6);
  static const _layoutColor = Color(0xFF22C55E);
  static const _ocColor     = Color(0xFFF59E0B);
  static const _s21Color    = Color(0xFF7C3AED);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _kTabCount, vsync: this);
    _tabController.addListener(_onTabChanged);
    _init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() => _currentTab = _tabController.index);
    }
  }

  Future<void> _init() async {
    final adminFlag  = await _checkIsAdmin();
    final tlFlag     = await _checkIsTeamLeader();
    final memberFlag = await _checkIsTeamMember();

    // ── Load the current user's ID so card-level upload gating works ─────────
    final userId = await AuthStorageService.getUserId();

    if (mounted) {
      setState(() {
        _isAdmin      = adminFlag;
        _isTeamLeader = tlFlag;
        _isTeamMember = memberFlag;
        _currentUserId = userId;
      });
      _rebuildTabController();
    }
    await _loadProcesses();
  }

  void _rebuildTabController() {
    final newCount = _effectiveTabCount;
    if (_tabController.length == newCount) return;

    final old = _tabController;
    final nc  = TabController(
      length:       newCount,
      vsync:        this,
      initialIndex: _currentTab.clamp(0, newCount - 1),
    );
    nc.addListener(_onTabChanged);
    _tabController = nc;
    old.dispose();
  }

  Future<void> _loadProcesses() async {
    setState(() { _loading = true; _error = null; });
    try {
      final raw      = await DevelopmentProcessApi.fetchDevelopmentProcesses(
          widget.projectId);
      final newStages = _parseStages(raw);

      if (mounted) {
        setState(() {
          for (int i = 0; i < 4; i++) {
            _stages[i] = i < newStages.length
                ? newStages[i]
                : DevelopmentStageData(
                    stageNumber: i, stageLabel: 'Stage $i', processes: const []);
          }
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

  List<DevelopmentStageData> _parseStages(Map<String, dynamic> raw) {
    final stagesList = raw['stages'];
    if (stagesList is List && stagesList.isNotEmpty) {
      final stageMap = <int, DevelopmentStageData>{};
      for (final item in stagesList) {
        if (item is! Map<String, dynamic>) continue;
        final stageNum = int.tryParse(item['stage']?.toString() ?? '') ?? -1;
        if (stageNum < 0 || stageNum > 3) continue;

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

        final rawProcesses = item['processes'];
        final processes    = <DevelopmentProcessItem>[];
        if (rawProcesses is List) {
          for (final p in rawProcesses) {
            if (p is! Map<String, dynamic>) continue;
            final pid = int.tryParse(p['process_id']?.toString() ?? '');
            final assignment =
                pid != null ? assignmentsByProcessId[pid] : null;

            processes.add(DevelopmentProcessItem(
              processId:   pid,
              processName: p['process_name']?.toString() ?? '',
              orderNo:     int.tryParse(p['order_no']?.toString() ?? ''),
              stage:       p['stage']?.toString() ?? 'stage $stageNum',
              teamId:      int.tryParse(p['team_id']?.toString() ?? ''),
              teamName:    p['team_name']?.toString(),
              teamColor:   p['team_color']?.toString(),
              assignment:  assignment,
            ));
          }
        }

        stageMap[stageNum] = DevelopmentStageData(
          stageNumber: stageNum,
          stageLabel:  item['stage_label']?.toString() ?? 'Stage $stageNum',
          processes:   processes,
        );
      }

      return List.generate(4, (i) {
        return stageMap[i] ??
            DevelopmentStageData(
                stageNumber: i, stageLabel: 'Stage $i', processes: const []);
      });
    }

    return List.generate(
        4,
        (i) => DevelopmentStageData(
            stageNumber: i, stageLabel: 'Stage $i', processes: const []));
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _openAssignSheet(
      DevelopmentProcessItem process, int stageNum) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => AssignProcessSheet(
        process:     process,
        stageNumber: stageNum,
        projectId:   widget.projectId,
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
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
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

    final picked = await FilePicker.platform
        .pickFiles(type: FileType.any, allowMultiple: false);
    if (picked == null || picked.files.isEmpty) return;
    final pf = picked.files.first;
    if (pf.path == null) return;

    setState(() => _uploadingKeys.add(key));
    try {
      await DevelopmentProcessApi.uploadDevelopmentProcessFile(
        projectId:   widget.projectId,
        stageNumber: stageNum,
        processId:   process.processId ?? 0,
        orderNo:     process.orderNo ?? 0,
        file:        File(pf.path!),
        fileName:    pf.name,
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
      DevelopmentProcessItem process, int stageNum, String filePath) async {
    if (filePath.isEmpty) {
      _showErrorSnackBar('No file is attached to this process.');
      return;
    }
    final key = '${stageNum}_${process.orderNo}';
    if (_viewingKeys.contains(key)) return;
    setState(() => _viewingKeys.add(key));
    try {
      final url = await DevelopmentProcessApi.getFileUrl(filePath);
      if (url.isEmpty)
        throw ApiException(
            'The file URL returned by the server is empty.');
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              DocumentViewerPage(url: url, title: process.processName),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) _showErrorSnackBar(e.message);
    } catch (_) {
      if (mounted)
        _showErrorSnackBar('Could not open file. Please try again.');
    } finally {
      if (mounted) setState(() => _viewingKeys.remove(key));
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ]),
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
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(36)),
                    child: const Icon(Icons.error_outline_rounded,
                        color: Color(0xFFEF4444), size: 36),
                  ),
                  const SizedBox(height: 20),
                  const Text('Failed to load processes',
                      style: TextStyle(
                          fontSize:   17,
                          fontWeight: FontWeight.w700,
                          color:      Color(0xFF1E293B))),
                  const SizedBox(height: 8),
                  Text(_error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Color(0xFF64748B), fontSize: 13)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _loadProcesses,
                    icon:  const Icon(Icons.refresh_rounded),
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
                ]),
              ),
            ),
          ),
        ],
      );

  Widget _buildBody() => NestedScrollView(
        headerSliverBuilder: (context, _) => [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildTabBar()),
        ],
        body: _buildTabBarView(),
      );

  SliverAppBar _buildAppBar() => SliverAppBar(
        expandedHeight: 130,
        floating:       false,
        pinned:         true,
        elevation:      0,
        backgroundColor: const Color(0xFF7C3AED),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon:    const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loading ? null : _loadProcesses,
            tooltip: 'Refresh',
          ),
        ],
        flexibleSpace: FlexibleSpaceBar(
          background: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin:  Alignment.topLeft,
                end:    Alignment.bottomRight,
                colors: [Color(0xFF5B21B6), Color(0xFF7C3AED)],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(56, 12, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment:  MainAxisAlignment.end,
                  children: [
                    const Text('Development Process',
                        style: TextStyle(
                            color:         Colors.white,
                            fontSize:      22,
                            fontWeight:    FontWeight.w800,
                            letterSpacing: -0.5)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Expanded(
                        child: Text(
                          widget.projectName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color:      Colors.white.withValues(alpha: 0.8),
                              fontSize:   13,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusChip(status: widget.projectStatus),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  Widget _buildTabBar() => Container(
        color: Colors.white,
        child: TabBar(
          controller:           _tabController,
          isScrollable:         true,
          tabAlignment:         TabAlignment.start,
          labelColor:           const Color(0xFF7C3AED),
          unselectedLabelColor: const Color(0xFF94A3B8),
          indicatorColor:       const Color(0xFF7C3AED),
          indicatorWeight:      3,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 12),
          unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500, fontSize: 12),
          tabs: List.generate(_effectiveTabCount, (i) {
            final count      = _badgeCountForTab(i);
            final isSelected = _currentTab == i;

            Color badgeColor;
            if (i == _kCcProcess)           badgeColor = _ccColor;
            else if (i == _kLayoutApproval) badgeColor = _layoutColor;
            else if (i == _kOcProgress)     badgeColor = _ocColor;
            else if (i == _kStage21)        badgeColor = _s21Color;
            else                            badgeColor = const Color(0xFF7C3AED);

            return Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(_tabLabels[i]),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? badgeColor
                        : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize:   10,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ]),
            );
          }),
        ),
      );

  int _badgeCountForTab(int i) {
    if (i == _kStage21)   return _stage21Count;
    if (i >= _kCcProcess) return 0;
    final stageIdx = i < _kStage21 ? i : i - 1;
    return stageIdx < _stages.length
        ? _stages[stageIdx].processes.length
        : 0;
  }

  Widget _buildTabBarView() => TabBarView(
        controller: _tabController,
        physics:    const NeverScrollableScrollPhysics(),
        children:   List.generate(_effectiveTabCount, (i) {
          if (i == _kStage21)        return _buildStage21Tab();
          if (i == _kCcProcess)      return _buildCcProcessTab();
          if (i == _kLayoutApproval) return _buildLayoutApprovalTab();
          if (i == _kOcProgress)     return _buildOcProgressTab();

          final stageIdx = i < _kStage21 ? i : i - 1;
          return _buildStageListView(stageIdx);
        }),
      );

  Widget _buildStageListView(int stageIdx) {
    if (stageIdx >= _stages.length) return const _EmptyStage();
    final stage = _stages[stageIdx];
    if (stage.processes.isEmpty) return const _EmptyStage();

    return ListView.builder(
      padding:   const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: stage.processes.length,
      itemBuilder: (context, index) {
        final process = stage.processes[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ProcessCard(
            process:         process,
            serialNo:        index + 1,
            stageNumber:     stage.stageNumber,
            canAssign:       _canAssign,
            canView:         _canViewFiles,
            canAdminReUpload: _canAdminReUpload,
            currentUserId:   _currentUserId,       // ← NEW
            uploadingKeys:   _uploadingKeys,
            viewingKeys:     _viewingKeys,
            onAssign:        () => _openAssignSheet(process, stage.stageNumber),
            onUpload:        () => _uploadFile(process, stage.stageNumber),
            onViewFile: () => _viewFile(
              process,
              stage.stageNumber,
              process.assignment?.filePath ?? '',
            ),
          ),
        );
      },
    );
  }

  Widget _buildStage21Tab() {
    return Stage21TabPage(
      projectId:   widget.projectId,
      projectName: widget.projectName,
      onCountChanged: (count) {
        if (mounted && _stage21Count != count) {
          setState(() => _stage21Count = count);
        }
      },
    );
  }

  Widget _buildCcProcessTab() => _EmbeddedProcessTab(
        accentColor: _ccColor,
        child: CcProgressPage(
          projectId:   widget.projectId,
          projectName: widget.projectName,
        ),
      );

  Widget _buildLayoutApprovalTab() => _EmbeddedProcessTab(
        accentColor: _layoutColor,
        child: LayoutApprovalPage(
          projectId:   widget.projectId,
          projectName: widget.projectName,
        ),
      );

  Widget _buildOcProgressTab() => _EmbeddedProcessTab(
        accentColor: _ocColor,
        child: OcProgressPage(
          projectId:   widget.projectId,
          projectName: widget.projectName,
        ),
      );
}

// ─── Embedded tab wrapper ─────────────────────────────────────────────────────

class _EmbeddedProcessTab extends StatelessWidget {
  final Color  accentColor;
  final Widget child;
  const _EmbeddedProcessTab(
      {required this.accentColor, required this.child});

  @override
  Widget build(BuildContext context) =>
      Container(color: const Color(0xFFF8FAFC), child: child);
}

// ─── Empty stage placeholder ──────────────────────────────────────────────────

class _EmptyStage extends StatelessWidget {
  final String message;
  final String subMessage;
  const _EmptyStage({
    this.message    = 'No processes found',
    this.subMessage = 'Processes added via the web admin will appear here.',
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color:        const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(36),
              ),
              child: const Icon(Icons.inbox_rounded,
                  color: Color(0xFFCBD5E1), size: 36),
            ),
            const SizedBox(height: 16),
            Text(message,
                style: const TextStyle(
                    color:      Color(0xFF94A3B8),
                    fontSize:   15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(subMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFFCBD5E1), fontSize: 12)),
          ]),
        ),
      );
}

// ─── Status chip ──────────────────────────────────────────────────────────────

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
        ),
      ),
      child: Text(
        status.isEmpty
            ? 'Pending'
            : '${status[0].toUpperCase()}${status.substring(1).toLowerCase()}',
        style: TextStyle(
          fontSize:   10,
          fontWeight: FontWeight.w700,
          color: started
              ? const Color(0xFF22C55E)
              : const Color(0xFFF59E0B),
        ),
      ),
    );
  }
}

// ─── Process Card ─────────────────────────────────────────────────────────────
//
// ┌──────────────────────────────────────────────────────────────────────────┐
// │  BUTTON VISIBILITY MATRIX  (mirrors web DevelopmentProcessController)   │
// ├────────────┬──────────────────┬─────────────────────┬────────────────── │
// │  State     │  Assign/Re-assign│  Upload / Re-upload │  View             │
// ├────────────┼──────────────────┼─────────────────────┼────────────────── │
// │  Pending   │  canAssign ✓     │  ✗                  │  ✗                │
// │  Assigned  │  canAssign ✓     │  assignee only ✓    │  ✗                │
// │  Completed │  ✗ (frozen)      │  assignee OR admin  │  canViewFiles ✓   │
// │  N/A       │  canAssign ✓     │  ✗                  │  ✗                │
// └────────────┴──────────────────┴─────────────────────┴────────────────── │
//
// KEY RULE for Upload/Re-upload:
//   The button is shown when:
//     a) The process is assigned (not N/A, not pending).
//     b) AND the current user is either:
//         • The assigned user   (assignedTo == currentUserId), OR
//         • An Admin            (canAdminReUpload == true)
//
// This matches the web portal exactly:
//   - The assigned team member sees "Upload" (first upload) or "Re-upload".
//   - The admin always sees "Re-upload" on completed processes.
//   - Team leaders who are NOT the assignee do NOT see the upload button.

class _ProcessCard extends StatelessWidget {
  final DevelopmentProcessItem process;
  final int                    serialNo;
  final int                    stageNumber;
  final bool                   canAssign;
  final bool                   canView;
  final bool                   canAdminReUpload; // admin can always re-upload
  final int?                   currentUserId;   // logged-in user's ID
  final Set<String>            uploadingKeys;
  final Set<String>            viewingKeys;
  final VoidCallback           onAssign;
  final VoidCallback           onUpload;
  final VoidCallback           onViewFile;

  const _ProcessCard({
    required this.process,
    required this.serialNo,
    required this.stageNumber,
    required this.canAssign,
    required this.canView,
    required this.canAdminReUpload,
    required this.currentUserId,
    required this.uploadingKeys,
    required this.viewingKeys,
    required this.onAssign,
    required this.onUpload,
    required this.onViewFile,
  });

  String get _uploadKey   => '${stageNumber}_${process.orderNo}';
  bool   get _isUploading => uploadingKeys.contains(_uploadKey);
  bool   get _isViewing   => viewingKeys.contains(_uploadKey);

  @override
  Widget build(BuildContext context) {
    final assign = process.assignment;

    // ── Derive states ────────────────────────────────────────────────────────
    final bool isNA       = assign?.isNA       ?? false;
    final bool isAssigned = assign?.isAssigned ?? false;

    // hasFile: true when the server has a document for this process.
    // Triple-check mirrors the previous defensive logic.
    final bool hasFile = assign != null &&
        ((assign.hasFile) ||
         (assign.filePath != null && assign.filePath!.isNotEmpty) ||
         (assign.isCompleted));

    final bool isCompleted = hasFile;

    // ── Is the current user the one assigned to this process? ──────────────
    final bool isCurrentUserAssignee =
        currentUserId != null &&
        assign != null &&
        assign.assignedToUserId != null &&
        assign.assignedToUserId == currentUserId;

    // ── Button visibility ────────────────────────────────────────────────────

    // ASSIGN: admin/TL can assign, but once a file exists (completed) the
    // process is frozen — no reassignment (matches web "Assign" column).
    final bool showAssignBtn = canAssign && !isCompleted && !isNA;

    // UPLOAD / RE-UPLOAD:
    //   • Process must be assigned (someone is responsible).
    //   • Current user must be either the assignee OR an admin.
    //   • N/A processes never show upload.
    final bool isUploadEligible =
        isCurrentUserAssignee || canAdminReUpload;

    final bool showUploadBtn = !isNA && isAssigned && isUploadEligible;

    // VIEW: shown when completed and role can read documents.
    final bool showViewBtn = isCompleted && canView;

    return Container(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color:     Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset:    const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(children: [
          // Coloured top accent bar
          Container(height: 3, color: _stageColor(stageNumber)),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ────────────────────────────────────────────────────
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: _stageColor(stageNumber).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text('$serialNo',
                          style: TextStyle(
                              fontSize:   12,
                              fontWeight: FontWeight.w800,
                              color:      _stageColor(stageNumber))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(process.processName,
                          style: const TextStyle(
                              fontSize:   14,
                              fontWeight: FontWeight.w700,
                              color:      Color(0xFF1E293B))),
                      if (assign?.deadline != null) ...[
                        const SizedBox(height: 3),
                        Row(children: [
                          const Icon(Icons.calendar_today_rounded,
                              size: 11, color: Color(0xFFEF4444)),
                          const SizedBox(width: 3),
                          Text('Deadline: ${assign!.deadline}',
                              style: const TextStyle(
                                  fontSize:   11,
                                  color:      Color(0xFFEF4444),
                                  fontWeight: FontWeight.w500)),
                        ]),
                      ],
                    ]),
                  ),
                  _StatusBadge(assignment: assign, hasFile: hasFile),
                ]),

                const SizedBox(height: 10),

                // ── Team + assignee row ───────────────────────────────────────
                Row(children: [
                  if (process.teamName != null) ...[
                    _TeamChip(
                        name:  process.teamName!,
                        color: process.teamColor),
                    const SizedBox(width: 8),
                  ],
                  if (assign != null && !assign.isNA)
                    Expanded(
                      child: Row(children: [
                        Icon(
                          assign.isAssignedToTeamLeader
                              ? Icons.star_rounded
                              : Icons.person_rounded,
                          size: 13,
                          color: assign.isAssignedToTeamLeader
                              ? const Color(0xFF7C3AED)
                              : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text.rich(
                            TextSpan(children: [
                              const TextSpan(
                                text: 'Assigned to: ',
                                style: TextStyle(
                                    fontSize:   12,
                                    color:      Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w500),
                              ),
                              TextSpan(
                                text: (assign.assignedUserName
                                            ?.isNotEmpty ==
                                        true)
                                    ? assign.assignedUserName!
                                    : 'Assigned',
                                style: TextStyle(
                                    fontSize:   12,
                                    color: assign.isAssignedToTeamLeader
                                        ? const Color(0xFF7C3AED)
                                        : const Color(0xFF22C55E),
                                    fontWeight: FontWeight.w700),
                              ),
                              TextSpan(
                                text: assign.isAssignedToTeamLeader
                                    ? '  (Team Leader)'
                                    : '  (Team Member)',
                                style: TextStyle(
                                    fontSize:   11,
                                    color: assign.isAssignedToTeamLeader
                                        ? const Color(0xFF7C3AED)
                                        : const Color(0xFF64748B),
                                    fontWeight: FontWeight.w600),
                              ),
                            ]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                    ),
                ]),

                // ── Attached file chip ────────────────────────────────────────
                if (isCompleted &&
                    assign?.fileName != null &&
                    assign!.fileName!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.attach_file_rounded,
                        size: 13, color: Color(0xFF22C55E)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        assign.fileName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize:   11,
                            color:      Color(0xFF22C55E),
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ]),
                ],

                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 12),

                // ── Action buttons ────────────────────────────────────────────
                Wrap(spacing: 8, runSpacing: 8, children: [

                  // Assign / Re-assign
                  if (showAssignBtn)
                    _ActionButton(
                      label: (assign != null && !assign.isNA)
                          ? 'Re-assign'
                          : 'Assign',
                      icon:  Icons.person_add_rounded,
                      color: const Color(0xFF7C3AED),
                      onTap: onAssign,
                    ),

                  // Upload / Re-upload  ← FIXED
                  if (showUploadBtn)
                    _ActionButton(
                      label:   hasFile ? 'Re-upload' : 'Upload',
                      icon:    hasFile
                          ? Icons.replay_rounded
                          : Icons.upload_rounded,
                      color:   const Color(0xFFF59E0B),
                      loading: _isUploading,
                      onTap:   _isUploading ? null : onUpload,
                    ),

                  // View
                  if (showViewBtn)
                    _ActionButton(
                      label:   'View',
                      icon:    Icons.visibility_rounded,
                      color:   const Color(0xFF0EA5E9),
                      loading: _isViewing,
                      onTap:   _isViewing ? null : onViewFile,
                    ),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Color _stageColor(int stage) {
    const colors = [
      Color(0xFF6366F1), Color(0xFF3B82F6),
      Color(0xFF10B981), Color(0xFFF59E0B),
    ];
    return colors[stage % colors.length];
  }
}

// ─── Status badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final DevelopmentProcessAssignment? assignment;
  final bool hasFile;
  const _StatusBadge({this.assignment, this.hasFile = false});

  @override
  Widget build(BuildContext context) {
    String label;
    Color  color;

    if (assignment == null) {
      label = 'Pending';
      color = const Color(0xFFF59E0B);
    } else if (assignment!.isNA) {
      label = 'N/A';
      color = const Color(0xFF94A3B8);
    } else if (hasFile || assignment!.isCompleted) {
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
        color:        color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width:  6,
            height: 6,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize:   10,
                fontWeight: FontWeight.w700,
                color:      color)),
      ]),
    );
  }
}

// ─── Team chip ────────────────────────────────────────────────────────────────

class _TeamChip extends StatelessWidget {
  final String  name;
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
          color:        bgColor,
          borderRadius: BorderRadius.circular(8)),
      child: Text(name,
          style: const TextStyle(
              color:      Colors.white,
              fontSize:   10,
              fontWeight: FontWeight.w700)),
    );
  }
}

// ─── Action button ────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String        label;
  final IconData      icon;
  final Color         color;
  final VoidCallback? onTap;
  final bool          loading;

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
              width:  12,
              height: 12,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : Icon(icon, size: 13),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor:         color,
        foregroundColor:         Colors.white,
        disabledBackgroundColor: color.withValues(alpha: 0.5),
        elevation:               0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize:   Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}