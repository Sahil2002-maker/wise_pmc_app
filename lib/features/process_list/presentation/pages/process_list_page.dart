import 'dart:convert';
import 'dart:io';
 
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
 
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/auth_storage_service.dart';
import '../../../../core/utils/api_exception.dart';
import '../../data/models/process_list_item_model.dart';
import '../../data/models/process_stage_model.dart';
import '../../data/models/team_member_model.dart';
import 'file_viewer_page.dart';
import '../../../re_execution/presentation/re_execution_list_page.dart';
import '../../../cement_checklist/presentation/cement_checklist_page.dart';
import '../../../steel_checklist/presentation/steel_checklist_page.dart';
import '../../../excavation_checklist/presentation/excavation_checklist_page.dart';
import '../../../shuttering_checklist/presentation/shuttering_checklist_page.dart';
import '../../../concreting_checklist/presentation/concreting_checklist_page.dart';
import '../../../site_instruction/presentation/site_instruction_page.dart';
import '../../../reinforcement_checklist/presentation/reinforcement_checklist_page.dart';
import '../../../concrete_cube_results/presentation/concrete_cube_results_page.dart';
import '../../../approval_form/presentation/approval_form_page.dart';
import '../../../architecture_checklist/presentation/architecture_checklist_page.dart';
import '../../../concrete_pour_card/presentation/concrete_pour_card_page.dart';
import '../../../minutes_of_meeting/presentation/minutes_of_meeting_page.dart';
import '../../../cc_progress/presentation/cc_progress_page.dart';
import '../../../layout_approval/presentation/layout_approval_page.dart';
import '../../../oc_progress/presentation/oc_progress_page.dart';
 
// ─────────────────────────────────────────────────────────────────────────────
// Stage 0 sub-tab keys
// ─────────────────────────────────────────────────────────────────────────────
enum Stage0SubTab { projectInfo, pmcApplication, pmcAppointment }
 
// ─────────────────────────────────────────────────────────────────────────────
// Stage 3 sub-tab keys
// ─────────────────────────────────────────────────────────────────────────────
enum Stage3SubTab {
  dailyProgress,
  cementChecklist,
  steelChecklist,
  excavationChecklist,
  shutteringChecklist,
  concretingChecklist,
  siteInstruction,
  reinforcementChecklist,
  concreteCubeResults,
  approvalForm,
  architectureChecklist,
  concretePourCard,
}
 
// ─────────────────────────────────────────────────────────────────────────────
// Role constants — mirrors backend role names exactly
// ─────────────────────────────────────────────────────────────────────────────
class _Roles {
  static const admin       = 'admin';
  static const teamLeader  = 'teamleader';
  static const leader      = 'leader';
  static const teamLeader2 = 'team leader';
}
 
class ProcessListPage extends StatefulWidget {
  final int projectId;
  final String projectName;
 
  const ProcessListPage({
    super.key,
    required this.projectId,
    required this.projectName,
  });
 
  @override
  State<ProcessListPage> createState() => _ProcessListPageState();
}
 
class _ProcessListPageState extends State<ProcessListPage>
    with TickerProviderStateMixin {
  TabController? _tabController;
  TabController? _stage0SubTabController;
  TabController? _stage3SubTabController;
 
  List<ProcessStageModel> _stages = [];
  bool _isLoading    = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  int _currentTabIndex = 0;
  Stage0SubTab _currentStage0SubTab = Stage0SubTab.pmcApplication;
  Stage3SubTab _currentStage3SubTab = Stage3SubTab.dailyProgress;
 
  bool _isAdmin              = false;
  bool _isTeamLeader         = false;
  bool _isMunicipalOrLiaisonTeam = false;
 
  List<int> _leaderOwnedTeamIds = [];
  List<int> _memberTeamIds      = [];
  int? _currentUserId;
 
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
 
  static const _stageOrder = [
    'pmc_application',
    'stage1',
    'stage2',
    'stage3',
    'stage3_1',
    'stage3_2',
  ];
 
  static const _stageLabels = {
    'pmc_application': 'Stage 0',
    'stage1'         : 'Stage 1',
    'stage2'         : 'Stage 2',
    'stage3'         : 'Stage 3',
    'stage3_1'       : 'Stage 3.1',
    'stage3_2'       : 'Stage 3.2',
  };

  static const _stageIcons = {
    'pmc_application': Icons.description_outlined,
    'stage1': Icons.looks_one_outlined,
    'stage2': Icons.looks_two_outlined,
    'stage3': Icons.construction_outlined,
    'stage3_1': Icons.draw_outlined,
    'stage3_2': Icons.assignment_outlined,
  };

  static const _stageAccentColors = {
    'pmc_application': Color(0xFF0EA5E9),
    'stage1': Color(0xFF3B82F6),
    'stage2': Color(0xFFF59E0B),
    'stage3': Color(0xFF22C55E),
    'stage3_1': Color(0xFF8B5CF6),
    'stage3_2': Color(0xFFEF4444),
  };
 
  List<_ExtraTab> _extraTabs = [];
 
  bool _roleIsAdmin(String role) => role == _Roles.admin;
 
  bool _roleIsTeamLeader(String role) =>
      role == _Roles.teamLeader ||
      role == _Roles.leader     ||
      role == _Roles.teamLeader2;

  Color _accentColorForStage(String stageKey) =>
      _stageAccentColors[stageKey] ?? AppColors.primaryGreen;

  IconData _iconForStage(String stageKey) =>
      _stageIcons[stageKey] ?? Icons.layers_outlined;
 
  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────
 
  @override
  void initState() {
    super.initState();
    _initStage0SubTabController();
    _initStage3SubTabController();
    _loadProcesses(initial: true);
  }
 
  @override
  void dispose() {
    _tabController?.dispose();
    _stage0SubTabController?.dispose();
    _stage3SubTabController?.dispose();
    _searchController.dispose();
    super.dispose();
  }
 
  void _initStage0SubTabController() {
    _stage0SubTabController?.dispose();
    _stage0SubTabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: _currentStage0SubTab.index,
    );
    _stage0SubTabController!.addListener(() {
      if (!_stage0SubTabController!.indexIsChanging && mounted) {
        setState(() => _currentStage0SubTab =
            Stage0SubTab.values[_stage0SubTabController!.index]);
      }
    });
  }
 
  void _initStage3SubTabController() {
    _stage3SubTabController?.dispose();
    _stage3SubTabController = TabController(
      length: Stage3SubTab.values.length,
      vsync: this,
      initialIndex: _currentStage3SubTab.index,
    );
    _stage3SubTabController!.addListener(() {
      if (!_stage3SubTabController!.indexIsChanging && mounted) {
        setState(() => _currentStage3SubTab =
            Stage3SubTab.values[_stage3SubTabController!.index]);
      }
    });
  }
 
  void _rebuildTabControllerIfNeeded(int totalTabCount) {
    final len = totalTabCount < 1 ? 1 : totalTabCount;
    if (_tabController != null && _tabController!.length == len) {
      final clamped = _currentTabIndex.clamp(0, len - 1);
      if (_tabController!.index != clamped) _tabController!.animateTo(clamped);
      return;
    }
    final old = _tabController;
    final nc = TabController(
      length: len,
      vsync: this,
      initialIndex: _currentTabIndex.clamp(0, len - 1),
    );
    nc.addListener(() {
      if (!nc.indexIsChanging && mounted) {
        setState(() => _currentTabIndex = nc.index);
      }
    });
    _tabController = nc;
    old?.dispose();
  }
 
  // ─────────────────────────────────────────────────────────────────────────
  // Core data-load
  // ─────────────────────────────────────────────────────────────────────────
 
  Future<void> _loadProcesses({bool initial = false, bool silent = false}) async {
    if (!mounted) return;
    if (silent) {
      setState(() => _isRefreshing = true);
    } else {
      setState(() { _isLoading = true; _errorMessage = null; });
    }
 
    try {
      final rawRole = (await AuthStorageService.getUserRole() ?? '').trim().toLowerCase();
      final isAdmin      = _roleIsAdmin(rawRole);
      final isTeamLeader = !isAdmin && _roleIsTeamLeader(rawRole);
      final isRegular    = !isAdmin && !isTeamLeader;
 
      final currentUserId = await AuthStorageService.getUserId();
 
      List<Map<String, dynamic>> allTeams = [];
      try {
        allTeams = await ApiService.fetchTeamsAndMembers();
      } catch (_) {}
 
      List<int> leaderOwnedTeamIds = [];
      if (isTeamLeader && currentUserId != null) {
        try {
          leaderOwnedTeamIds = await ApiService.fetchLeaderOwnedTeamIds();
        } catch (_) {}
 
        if (leaderOwnedTeamIds.isEmpty && allTeams.isNotEmpty) {
          for (final team in allTeams) {
            final teamId = int.tryParse(team['id']?.toString() ?? '');
            if (teamId == null) continue;
 
            final rawLeaderId = team['team_leader_id'];
            final leaderIds = _parseIdList(rawLeaderId);
            if (leaderIds.contains(currentUserId)) {
              leaderOwnedTeamIds.add(teamId);
              continue;
            }
 
            final members = team['members'];
            if (members is List) {
              final isInTeam = members.any((m) {
                if (m is! Map) return false;
                final mid = int.tryParse(
                    m['id']?.toString() ?? m['user_id']?.toString() ?? '');
                return mid == currentUserId;
              });
              if (isInTeam) leaderOwnedTeamIds.add(teamId);
            }
          }
        }
 
        debugPrint('LEADER teamIds=$leaderOwnedTeamIds userId=$currentUserId');
      }
 
      List<int> memberTeamIds = [];
      if (isRegular && currentUserId != null) {
        for (final team in allTeams) {
          final teamId = int.tryParse(team['id']?.toString() ?? '');
          if (teamId == null) continue;
 
          final rawMemberIds = team['member_ids'] ?? team['members'];
          if (rawMemberIds is List) {
            final isMember = rawMemberIds.any((m) {
              if (m is Map) {
                final mid = int.tryParse(
                    m['id']?.toString() ?? m['user_id']?.toString() ?? '');
                return mid == currentUserId;
              }
              return int.tryParse(m.toString()) == currentUserId;
            });
            if (isMember) memberTeamIds.add(teamId);
          }
        }
        debugPrint('MEMBER teamIds=$memberTeamIds userId=$currentUserId');
      }
 
      final raw = await ApiService.fetchProjectProcesses(widget.projectId);
      if (!mounted) return;
 
      final allProcesses =
          raw.map((item) => ProcessListItemModel.fromJson(item)).toList();
 
      for (final p in allProcesses) {
        debugPrint('PROCESS => stage=${p.stage}, '
            'name=${p.processName}, teamId=${p.workingTeamId}, '
            'assignUser=${p.assignUser}, status=${p.status}');
      }
 
      // ── Role-based process visibility ──────────────────────────────────
      List<ProcessListItemModel> visibleProcesses;
 
      if (isAdmin) {
        visibleProcesses = allProcesses;
 
      } else if (isTeamLeader) {
        if (leaderOwnedTeamIds.isEmpty) {
          debugPrint('LEADER: no team IDs resolved → showing all processes');
          visibleProcesses = allProcesses;
        } else {
          visibleProcesses = allProcesses.where((p) {
            final teamId = p.workingTeamId;
            return teamId == null || leaderOwnedTeamIds.contains(teamId);
          }).toList();
        }
 
      } else {
        if (currentUserId != null) {
          visibleProcesses = allProcesses.where((p) {
            if (p.isAssignedToCurrentUser(currentUserId)) return true;
            final teamId = p.workingTeamId;
            if (teamId != null && memberTeamIds.contains(teamId)) return true;
            return false;
          }).toList();
 
          debugPrint('MEMBER: visible=${visibleProcesses.length} '
              'of ${allProcesses.length} total');
        } else {
          visibleProcesses = [];
        }
      }
 
      // ── Group by stage ─────────────────────────────────────────────────
      final Map<String, List<ProcessListItemModel>> grouped = {};
      for (final process in visibleProcesses) {
        grouped.putIfAbsent(process.stage, () => []).add(process);
      }
 
      // ── Stage-tab visibility ───────────────────────────────────────────
      final stages = <ProcessStageModel>[];
 
      for (final key in _stageOrder) {
        final list = grouped[key] ?? <ProcessListItemModel>[];
 
        final alwaysShow =
            key == 'pmc_application' ||
            key == 'stage1'          ||
            key == 'stage2'          ||
            key == 'stage3_1'        ||
            key == 'stage3_2';
 
        final isStage3AdminOnly = key == 'stage3';
 
        bool shouldShow;
        if (isAdmin) {
          shouldShow = true;
        } else if (isStage3AdminOnly) {
          shouldShow = false;
        } else if (alwaysShow) {
          shouldShow = true;
        } else {
          shouldShow = list.isNotEmpty;
        }
 
        if (shouldShow) {
          stages.add(ProcessStageModel(
            stageKey  : key,
            stageLabel: _stageLabels[key] ?? key,
            processes : list,
          ));
        }
      }
 
      // ── Extra tabs ────────────────────────────────────────────────────
      // CHANGE: Minutes of Meeting is visible to ALL roles.
      //         CC Progress, Layout Approval, OC Progress are ADMIN ONLY.
      //         Team leaders and regular members can NO LONGER see those tabs.
      final extraTabs = <_ExtraTab>[
        _ExtraTab(
          key  : 'mom',
          label: 'Minutes of Meeting',
          icon : Icons.calendar_today_outlined,
        ),
      ];
 
      // Only admins see CC Progress, Layout Approval, OC Progress
      if (isAdmin) {
        extraTabs.addAll([
          _ExtraTab(
            key  : 'cc_progress',
            label: 'CC Progress',
            icon : Icons.construction_outlined,
          ),
          _ExtraTab(
            key  : 'layout_approval',
            label: 'Layout Approval',
            icon : Icons.layers_outlined,
          ),
          _ExtraTab(
            key  : 'oc_progress',
            label: 'OC Progress',
            icon : Icons.check_circle_outline,
          ),
        ]);
      }
 
      if (!mounted) return;
 
      final totalTabs = stages.length + extraTabs.length;
      if (_currentTabIndex >= totalTabs && totalTabs > 0) {
        _currentTabIndex = 0;
      }
      _rebuildTabControllerIfNeeded(totalTabs);
 
      setState(() {
        _isAdmin                   = isAdmin;
        _isTeamLeader              = isTeamLeader;
        _isMunicipalOrLiaisonTeam  = isAdmin || isTeamLeader;
        _leaderOwnedTeamIds        = leaderOwnedTeamIds;
        _memberTeamIds             = memberTeamIds;
        _currentUserId             = currentUserId;
        _stages                    = stages;
        _extraTabs                 = extraTabs;
        _isLoading                 = false;
        _isRefreshing              = false;
        _errorMessage              = null;
      });
 
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (!silent) {
          _errorMessage = e is ApiException ? e.message : e.toString();
        }
        _isLoading    = false;
        _isRefreshing = false;
      });
    }
  }
 
  List<int> _parseIdList(dynamic raw) {
    if (raw == null) return [];
    if (raw is int) return [raw];
    if (raw is List) {
      return raw
          .map((e) => int.tryParse(e.toString()))
          .whereType<int>()
          .toList();
    }
    if (raw is String) {
      if (raw.trim().startsWith('[')) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            return decoded
                .map((e) => int.tryParse(e.toString()))
                .whereType<int>()
                .toList();
          }
        } catch (_) {}
      }
      final single = int.tryParse(raw.trim());
      return single != null ? [single] : [];
    }
    return [];
  }
 
  Future<void> _onActionComplete() async => _loadProcesses(silent: true);
 
  // ── Colour helpers ─────────────────────────────────────────────────────────
 
  Color _resolveTeamColor(String? teamName, String? teamColor) {
    if (teamColor != null && teamColor.isNotEmpty) {
      try {
        final hex = teamColor.replaceAll('#', '');
        if (hex.length == 6) return Color(int.parse('FF$hex', radix: 16));
        if (hex.length == 8) return Color(int.parse(hex, radix: 16));
      } catch (_) {}
    }
    if (teamName == null || teamName.isEmpty) return const Color(0xFF94A3B8);
    final n = teamName.toLowerCase();
    if (n.contains('legal'))                               return const Color(0xFF22C55E);
    if (n.contains('liaison') || n.contains('liasoning')) return const Color(0xFFEF4444);
    if (n.contains('construction'))                        return const Color(0xFFF59E0B);
    const colors = [
      Color(0xFF3B82F6), Color(0xFF8B5CF6), Color(0xFFEC4899),
      Color(0xFF14B8A6), Color(0xFFF97316), Color(0xFF06B6D4),
    ];
    return colors[teamName.hashCode.abs() % colors.length];
  }
 
  // ── Badge / chip widgets ───────────────────────────────────────────────────
 
  Widget _buildTeamPill(String teamName, String? teamColor) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _resolveTeamColor(teamName, teamColor),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          teamName.toUpperCase(),
          style: const TextStyle(
              color: Colors.white, fontSize: 11,
              fontWeight: FontWeight.w700, letterSpacing: 0.4),
        ),
      );
 
  Widget _deadlineBadge(ProcessListItemModel p) {
    if (p.isNotApplicable) return _chip('N/A', const Color(0xFF94A3B8));
    if (!p.isAssigned)     return _chip('—',   const Color(0xFFCBD5E1));
    final d = p.deadlineDays;
    if (d == null)  return _chip('No Deadline',          const Color(0xFF94A3B8));
    if (d > 0)      return _chip('$d days left',         const Color(0xFFF59E0B));
    if (d == 0)     return _chip('Due Today',            const Color(0xFFEF4444));
    return              _chip('${d.abs()} days overdue', const Color(0xFFDC2626));
  }
 
  Widget _statusBadge(ProcessListItemModel p) {
    if (p.isNotApplicable) return _chip('Not Applicable', const Color(0xFF94A3B8));
    final color = switch (p.status) {
      'completed'      => const Color(0xFF22C55E),
      'assigned'       => const Color(0xFFF59E0B),
      'not_started'    => const Color(0xFF94A3B8),
      'not_applicable' => const Color(0xFF94A3B8),
      _                => const Color(0xFFEF4444),
    };
    return _chip(p.statusLabel, color);
  }
 
  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 10,
                fontWeight: FontWeight.w600, letterSpacing: 0.2)),
      );
 
  // ── Assign button ──────────────────────────────────────────────────────────
 
  Widget _assignButton(ProcessListItemModel p) {
    if (p.isNotApplicable) return _chip('N/A', const Color(0xFF94A3B8));
    if (p.isAssigned && (p.assignUserName?.isNotEmpty ?? false)) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.person_outline, size: 13, color: Color(0xFF64748B)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(p.assignUserName!,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF1E293B),
                  fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis),
        ),
      ]);
    }
 
    final canAssign = _isAdmin ||
        (_isTeamLeader &&
            (p.workingTeamId == null ||
                _leaderOwnedTeamIds.contains(p.workingTeamId)));
 
    if (!canAssign) {
      return const Text('—',
          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)));
    }
 
    return GestureDetector(
      onTap: () => _showAssignDialog(p),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
            color: AppColors.primaryGreen,
            borderRadius: BorderRadius.circular(5)),
        child: const Text('Assign',
            style: TextStyle(
                color: Colors.white, fontSize: 12,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
 
  // ── Action buttons ─────────────────────────────────────────────────────────
 
  Widget _actionButtons(ProcessListItemModel p) {
    if (p.isNotApplicable) return _chip('N/A', const Color(0xFF94A3B8));
 
    final int? uid = _currentUserId;
    final bool isAssignedUser =
        uid != null && p.isAssignedToCurrentUser(uid);
    final bool canViewFile = p.hasFile && (_isAdmin || _isTeamLeader || isAssignedUser);
 
    final btns = <Widget>[];
 
    if (isAssignedUser) {
      if (p.hasFile) {
        btns.add(_actionBtn(
          label: 'Reupload',
          color: const Color(0xFFF59E0B),
          icon: Icons.upload_rounded,
          onTap: () => _showUploadDialog(p),
        ));
      } else {
        btns.add(_actionBtn(
          label: 'Upload',
          color: const Color(0xFF3B82F6),
          icon: Icons.upload_file_outlined,
          onTap: () => _showUploadDialog(p),
        ));
      }
    }
 
    if (canViewFile) {
      btns.add(_actionBtn(
        label: 'View File',
        color: const Color(0xFF22C55E),
        icon: Icons.insert_drive_file_outlined,
        onTap: () => _openFile(p),
      ));
    }
 
    if (_isAdmin || _isTeamLeader) {
      btns.add(_actionBtn(
        label: 'Email',
        color: const Color(0xFF1E293B),
        icon: Icons.email_outlined,
        onTap: () => _showEmailDialog(p),
      ));
    }
 
    if (btns.isEmpty) {
      if (!p.isAssigned) {
        return const Text('Not yet assigned',
            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8),
                fontStyle: FontStyle.italic));
      }
      return const Text('—',
          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)));
    }
 
    return Wrap(spacing: 6, runSpacing: 6, children: btns);
  }
 
  Widget _actionBtn({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(4)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 12, color: Colors.white),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  Color _statusColor(ProcessListItemModel p) {
    if (p.isNotApplicable) return const Color(0xFF94A3B8);
    return switch (p.status) {
      'completed' => const Color(0xFF22C55E),
      'assigned' => const Color(0xFFF59E0B),
      'not_started' => const Color(0xFF94A3B8),
      'not_applicable' => const Color(0xFF94A3B8),
      _ => const Color(0xFFEF4444),
    };
  }

  Widget _processCard(ProcessListItemModel p, int index) {
    final hasTeam = p.teamName != null && p.teamName!.isNotEmpty;
    final uid = _currentUserId;
    final isMyTask = uid != null && p.isAssignedToCurrentUser(uid);
    final statusColor = _statusColor(p);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMyTask && !_isAdmin && !_isTeamLeader
              ? AppColors.primaryGreen.withValues(alpha: 0.35)
              : statusColor.withValues(alpha: 0.14),
          width: isMyTask && !_isAdmin && !_isTeamLeader ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(14),
            ),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: statusColor.withValues(alpha: 0.2)),
              ),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF334155),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.processName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _statusBadge(p),
                      if (isMyTask && !_isAdmin && !_isTeamLeader)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'My Task',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _labeledSection(
              label: 'Team Name',
              child: hasTeam
                  ? _buildTeamPill(p.teamName!, p.teamColor)
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Not assigned',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ]),
            ),
            const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: _labeledSection(
                  label: 'Assign To',
                  child: _assignButton(p),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _labeledSection(
                  label: 'Deadline',
                  child: _deadlineBadge(p),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            _labeledSection(label: 'Actions', child: _actionButtons(p)),
          ]),
        ),
      ]),
    );
  }

  Widget _labeledSection({required String label, required Widget child}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF94A3B8),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ]);

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.folder_open_outlined,
              color: AppColors.primaryGreen,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
                letterSpacing: 0.2,
              ),
            ),
          ),
        ]),
      );

  Widget _stageProgressHeader(ProcessStageModel stage) => Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _accentColorForStage(stage.stageKey).withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color:
                    _accentColorForStage(stage.stageKey).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _iconForStage(stage.stageKey),
                size: 18,
                color: _accentColorForStage(stage.stageKey),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${stage.stageLabel} Overview',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _accentColorForStage(stage.stageKey),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${stage.completedCount} of ${stage.totalCount} processes completed',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${(stage.progress * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _accentColorForStage(stage.stageKey),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: _overviewStatChip(
                label: 'Completed',
                value: stage.completedCount,
                color: const Color(0xFF22C55E),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _overviewStatChip(
                label: 'Remaining',
                value: stage.totalCount - stage.completedCount,
                color: const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _overviewStatChip(
                label: 'Total',
                value: stage.totalCount,
                color: _accentColorForStage(stage.stageKey),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: stage.progress,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                _accentColorForStage(stage.stageKey),
              ),
              minHeight: 6,
            ),
          ),
        ]),
      );

  Widget _overviewStatChip({
    required String label,
    required int value,
    required Color color,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ]),
      );
 
  Widget _buildProcessCards(List<ProcessListItemModel> processes) {
    if (processes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.search_off_rounded,
                size: 40,
                color: AppColors.primaryGreen.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isEmpty
                  ? 'No processes found'
                  : 'No results for "$_searchQuery"',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            ),
          ]),
        ),
      );
    }
    final children = <Widget>[];
    String? lastGroup;
    int idx = 0;
    for (final p in processes) {
      final g = p.groupName;
      if (g != null && g != lastGroup) {
        children.add(_sectionHeader(g));
        lastGroup = g;
        idx = 0;
      } else if (g == null && lastGroup != null) {
        lastGroup = null;
      }
      children.add(_processCard(p, idx++));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
 
  // ─────────────────────────────────────────────────────────────────────────
  // Stage 0
  // ─────────────────────────────────────────────────────────────────────────
 
  ProcessStageModel? get _stage0 {
    try {
      return _stages.firstWhere((s) => s.stageKey == 'pmc_application');
    } catch (_) { return null; }
  }
 
  Widget _buildStage0Tab() {
    final ctrl = _stage0SubTabController;
    if (ctrl == null) return const SizedBox.shrink();
    return Column(children: [
      Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: TabBar(
          controller: ctrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.primaryGreen,
          unselectedLabelColor: const Color(0xFF94A3B8),
          indicatorColor: AppColors.primaryGreen,
          indicatorWeight: 2,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          tabs: const [
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.info_outline, size: 14), SizedBox(width: 5),
              Text('Project Info'),
            ])),
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.description_outlined, size: 14), SizedBox(width: 5),
              Text('PMC Application'),
            ])),
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.person_pin_outlined, size: 14), SizedBox(width: 5),
              Text('PMC Appointment'),
            ])),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(controller: ctrl, children: [
          _buildProjectInfoSubTab(),
          _buildPmcApplicationSubTab(),
          _buildPmcAppointmentSubTab(),
        ]),
      ),
    ]);
  }
 
  Widget _buildProjectInfoSubTab() => _ProjectInfoForm(
        projectId: widget.projectId,
        isAdmin: _isAdmin,
        onSaved: _onActionComplete,
      );
 
  Widget _buildPmcApplicationSubTab() {
    final stage = _stage0;
    if (stage == null) return _emptyProcessState('No PMC Application processes found.');
    final filtered = _searchQuery.isEmpty
        ? stage.processes
        : stage.processes
            .where((p) => p.processName
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()))
            .toList();
    return RefreshIndicator(
      onRefresh: () => _loadProcesses(silent: false),
      color: AppColors.primaryGreen,
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: _stageProgressHeader(stage)),
        SliverToBoxAdapter(child: _buildProcessCards(filtered)),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ]),
    );
  }
 
  Widget _buildPmcAppointmentSubTab() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.person_add_alt_outlined,
                size: 52,
                color: AppColors.primaryGreen.withValues(alpha: 0.35)),
            const SizedBox(height: 16),
            const Text('PMC Appointment',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            const Text(
              'PMC Appointment content will appear here once available.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
          ]),
        ),
      );
 
  // ─────────────────────────────────────────────────────────────────────────
  // Stage 3
  // ─────────────────────────────────────────────────────────────────────────
 
  static const _stage3SubTabDefs = [
    _Stage3SubTabDef(key: Stage3SubTab.dailyProgress,         label: 'Daily Progress Report',    icon: Icons.insert_drive_file_outlined),
    _Stage3SubTabDef(key: Stage3SubTab.cementChecklist,       label: 'Cement Checklist',         icon: Icons.assignment_outlined),
    _Stage3SubTabDef(key: Stage3SubTab.steelChecklist,        label: 'Steel Checklist',          icon: Icons.assignment_outlined),
    _Stage3SubTabDef(key: Stage3SubTab.excavationChecklist,   label: 'Excavation Checklist',     icon: Icons.assignment_outlined),
    _Stage3SubTabDef(key: Stage3SubTab.shutteringChecklist,   label: 'Shuttering Checklist',     icon: Icons.assignment_outlined),
    _Stage3SubTabDef(key: Stage3SubTab.concretingChecklist,   label: 'Concreting Checklist',     icon: Icons.assignment_outlined),
    _Stage3SubTabDef(key: Stage3SubTab.siteInstruction,       label: 'Site Instruction',         icon: Icons.menu_book_outlined),
    _Stage3SubTabDef(key: Stage3SubTab.reinforcementChecklist,label: 'Reinforcement Checklist',  icon: Icons.settings_outlined),
    _Stage3SubTabDef(key: Stage3SubTab.concreteCubeResults,   label: 'Concrete Cube Results',    icon: Icons.bar_chart_outlined),
    _Stage3SubTabDef(key: Stage3SubTab.approvalForm,          label: 'Approval Form',            icon: Icons.fact_check_outlined),
    _Stage3SubTabDef(key: Stage3SubTab.architectureChecklist, label: 'Architecture Checklist',   icon: Icons.apartment_outlined),
    _Stage3SubTabDef(key: Stage3SubTab.concretePourCard,      label: 'Concrete Pour Card',       icon: Icons.credit_card_outlined),
  ];
 
  Widget _buildStage3Tab() {
    final ctrl = _stage3SubTabController;
    if (ctrl == null) return const SizedBox.shrink();
    return Column(children: [
      Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: TabBar(
          controller: ctrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.primaryGreen,
          unselectedLabelColor: const Color(0xFF94A3B8),
          indicatorColor: AppColors.primaryGreen,
          indicatorWeight: 2,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          tabs: _stage3SubTabDefs
              .map((d) => Tab(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(d.icon, size: 13),
                      const SizedBox(width: 5),
                      Text(d.label),
                    ]),
                  ))
              .toList(),
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: ctrl,
          children: _stage3SubTabDefs
              .map((d) => _buildStage3SubTabContent(d.key))
              .toList(),
        ),
      ),
    ]);
  }
 
  Widget _buildStage3SubTabContent(Stage3SubTab tab) {
    switch (tab) {
      case Stage3SubTab.dailyProgress:
        return _buildDailyProgressContent();
      case Stage3SubTab.cementChecklist:
        return CementChecklistPage(
            projectId: widget.projectId, projectName: widget.projectName);
      case Stage3SubTab.steelChecklist:
        return SteelChecklistPage(
            projectId: widget.projectId, projectName: widget.projectName);
      case Stage3SubTab.excavationChecklist:
        return ExcavationChecklistPage(
            projectId: widget.projectId, projectName: widget.projectName);
      case Stage3SubTab.shutteringChecklist:
        return ShutteringChecklistPage(
            projectId: widget.projectId, projectName: widget.projectName);
      case Stage3SubTab.concretingChecklist:
        return ConcretingChecklistPage(
            projectId: widget.projectId, projectName: widget.projectName);
      case Stage3SubTab.siteInstruction:
        return SiteInstructionPage(
            projectId: widget.projectId, projectName: widget.projectName);
      case Stage3SubTab.reinforcementChecklist:
        return ReinforcementChecklistPage(
            projectId: widget.projectId, projectName: widget.projectName);
      case Stage3SubTab.concreteCubeResults:
        return ConcreteCubeResultsPage(
            projectId: widget.projectId, projectName: widget.projectName);
      case Stage3SubTab.approvalForm:
        return ApprovalFormPage(
            projectId: widget.projectId, projectName: widget.projectName);
      case Stage3SubTab.architectureChecklist:
        return ArchitectureChecklistPage(
            projectId: widget.projectId, projectName: widget.projectName);
      case Stage3SubTab.concretePourCard:
        return ConcretePourCardPage(
            projectId: widget.projectId, projectName: widget.projectName);
    }
  }
 
  Widget _buildDailyProgressContent() => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.primaryGreen.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6, offset: const Offset(0, 2))
              ],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.insert_drive_file_outlined,
                    size: 18, color: AppColors.primaryGreen),
                const SizedBox(width: 8),
                Text('Re-Execution Process',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700,
                        color: AppColors.primaryGreen)),
              ]),
              const SizedBox(height: 12),
              const Text('Daily Progress Report',
                  style: TextStyle(
                      fontSize: 13, color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                      builder: (_) => ReExecutionListPage(
                          projectId: widget.projectId,
                          projectName: widget.projectName),
                    )),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.open_in_new, size: 14, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Open Daily Progress Reports',
                        style: TextStyle(
                            color: Colors.white, fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      );
 
  // ─────────────────────────────────────────────────────────────────────────
  // Stage 3.1 — Drawing Requests
  // ─────────────────────────────────────────────────────────────────────────
 
  Widget _buildStage3_1Tab() => _DrawingRequestsTab(
        projectId: widget.projectId,
        isAdmin: _isAdmin,
        isTeamLeader: _isTeamLeader,
      );
 
  // ─────────────────────────────────────────────────────────────────────────
  // Stage 3.2 — Report Tasks
  // ─────────────────────────────────────────────────────────────────────────
 
  Widget _buildStage3_2Tab() {
    ProcessStageModel? stage32;
    try {
      stage32 = _stages.firstWhere((s) => s.stageKey == 'stage3_2');
    } catch (_) { stage32 = null; }
 
    if (!_isAdmin && !_isTeamLeader) {
      return _buildMemberStage32View(stage32);
    }
 
    if (stage32 == null) {
      return _emptyProcessState('No Stage 3.2 processes found.');
    }
 
    final filtered = _searchQuery.isEmpty
        ? stage32.processes
        : stage32.processes
            .where((p) => p.processName
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()))
            .toList();
 
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 700;
      return RefreshIndicator(
        onRefresh: () => _loadProcesses(silent: false),
        color: AppColors.primaryGreen,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(children: [
                if (_isAdmin || _isTeamLeader)
                  GestureDetector(
                    onTap: () => _showCreateReportTaskDialog(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                          color: AppColors.primaryGreen,
                          borderRadius: BorderRadius.circular(8)),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.add, size: 16, color: Colors.white),
                        SizedBox(width: 6),
                        Text('Create Report Task',
                            style: TextStyle(
                                color: Colors.white, fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
              ]),
            ),
          ),
          if (filtered.isEmpty)
            SliverToBoxAdapter(
                child: _emptyProcessState('No Stage 3.2 processes found.'))
          else if (isMobile)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _buildStage32MobileCard(filtered[i], i),
                childCount: filtered.length,
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _buildStage32Row(filtered[i], i),
                childCount: filtered.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ]),
      );
    });
  }
 
  Widget _buildMemberStage32View(ProcessStageModel? stage32) {
    final uid = _currentUserId;
    final myTasks = stage32?.processes.where((p) {
      return uid != null && p.isAssignedToCurrentUser(uid);
    }).toList() ?? [];
 
    return RefreshIndicator(
      onRefresh: () => _loadProcesses(silent: false),
      color: AppColors.primaryGreen,
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.primaryGreen.withValues(alpha: 0.25)),
            ),
            child: Row(children: [
              Icon(Icons.assignment_ind_outlined,
                  color: AppColors.primaryGreen, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('My Assigned Tasks',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: AppColors.primaryGreen)),
                  const SizedBox(height: 2),
                  Text(
                    myTasks.isEmpty
                        ? 'No tasks have been assigned to you yet.'
                        : '${myTasks.length} task${myTasks.length == 1 ? '' : 's'} assigned to you',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF475569)),
                  ),
                ]),
              ),
            ]),
          ),
        ),
 
        if (myTasks.isEmpty)
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.inbox_outlined,
                      size: 52,
                      color: AppColors.primaryGreen.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  const Text(
                    'No tasks assigned to you yet.\nYour team leader will assign tasks here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  ),
                ]),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _buildMemberTaskCard(myTasks[i], i),
              childCount: myTasks.length,
            ),
          ),
 
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ]),
    );
  }
 
  Widget _buildMemberTaskCard(ProcessListItemModel p, int index) {
    final isCompleted = p.isCompleted;
    final hasFile = p.hasFile;
 
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFF22C55E)
              : AppColors.primaryGreen.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: isCompleted
                ? const Color(0xFFF0FDF4)
                : AppColors.primaryGreen.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: isCompleted
                    ? const Color(0xFF22C55E)
                    : AppColors.primaryGreen,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(
                isCompleted ? Icons.check_rounded : Icons.assignment_outlined,
                color: Colors.white, size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(p.processName,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B))),
            ),
            _statusBadge(p),
          ]),
        ),
 
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (p.deadline != null || p.deadlineDays != null) ...[
              Row(children: [
                const Icon(Icons.schedule_outlined,
                    size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                _deadlineBadge(p),
              ]),
              const SizedBox(height: 12),
            ],
 
            if (isCompleted) ...[
              Row(children: [
                const Icon(Icons.check_circle_outline,
                    size: 16, color: Color(0xFF22C55E)),
                const SizedBox(width: 6),
                const Text('Task completed',
                    style: TextStyle(
                        fontSize: 13, color: Color(0xFF22C55E),
                        fontWeight: FontWeight.w600)),
              ]),
              if (hasFile) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openFile(p),
                      icon: const Icon(Icons.open_in_new, size: 14),
                      label: const Text('View Uploaded File'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryGreen,
                        side: BorderSide(color: AppColors.primaryGreen),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showUploadDialog(p),
                      icon: const Icon(Icons.upload_rounded, size: 14),
                      label: const Text('Reupload'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ]),
              ],
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline,
                      size: 14, color: Color(0xFFF97316)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Upload your completed work to mark this task done.',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFF92400E)),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showUploadDialog(p),
                  icon: const Icon(Icons.upload_file_outlined, size: 16),
                  label: const Text('Upload Completed Work',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
 
  Widget _buildStage32MobileCard(ProcessListItemModel p, int index) {
    final hasTeam = p.teamName != null && p.teamName!.isNotEmpty;
    final canAssign = _isAdmin ||
        (_isTeamLeader &&
            (p.workingTeamId == null ||
                _leaderOwnedTeamIds.contains(p.workingTeamId)));
 
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6)),
            alignment: Alignment.center,
            child: Text('${index + 1}',
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B))),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(p.processName,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B)))),
        ]),
        const SizedBox(height: 12),
        if (hasTeam) ...[
          const Text('TEAM', style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: Color(0xFF94A3B8), letterSpacing: 0.5)),
          const SizedBox(height: 5),
          _buildCompactTeamPill(p.teamName!, p.teamColor),
          const SizedBox(height: 12),
        ],
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: _mobileInfoBlock(
              'ASSIGN TO',
              p.isAssigned && (p.assignUserName?.isNotEmpty ?? false)
                  ? Text(p.assignUserName!,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF1E293B),
                          fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis)
                  : canAssign
                      ? GestureDetector(
                          onTap: () => _showAssignDialog(p),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                                color: AppColors.primaryGreen,
                                borderRadius: BorderRadius.circular(6)),
                            child: const Text('Assign',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          ))
                      : const Text('—',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF94A3B8))),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _mobileInfoBlock('STATUS', _statusBadge(p))),
        ]),
        const SizedBox(height: 14),
        const Text('ACTIONS', style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700,
            color: Color(0xFF94A3B8), letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (p.hasFile) ...[
            _mobileActionBtn(label: 'Reupload',
                color: const Color(0xFFF59E0B),
                icon: Icons.upload_rounded,
                onTap: () => _showUploadDialog(p)),
            _mobileActionBtn(label: 'View',
                color: const Color(0xFF3B82F6),
                icon: Icons.insert_drive_file_outlined,
                onTap: () => _openFile(p)),
          ] else
            _mobileActionBtn(label: 'Upload',
                color: const Color(0xFF3B82F6),
                icon: Icons.upload_file_outlined,
                onTap: () => _showUploadDialog(p)),
          _mobileActionBtn(label: 'Email',
              color: const Color(0xFF1E293B),
              icon: Icons.email_outlined,
              onTap: () => _showEmailDialog(p)),
        ]),
      ]),
    );
  }
 
  Widget _mobileInfoBlock(String label, Widget child) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700,
            color: Color(0xFF94A3B8), letterSpacing: 0.5)),
        const SizedBox(height: 6),
        child,
      ]);
 
  Widget _buildCompactTeamPill(String teamName, String? teamColor) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: _resolveTeamColor(teamName, teamColor),
            borderRadius: BorderRadius.circular(20)),
        child: Text(teamName.toUpperCase(),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontSize: 10,
                fontWeight: FontWeight.w700)),
      );
 
  Widget _mobileActionBtn({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(6)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(
                color: Colors.white, fontSize: 11,
                fontWeight: FontWeight.w600)),
          ]),
        ),
      );
 
  Widget _buildStage32Row(ProcessListItemModel p, int index) {
    final hasTeam = p.teamName != null && p.teamName!.isNotEmpty;
    final canAssign = _isAdmin ||
        (_isTeamLeader &&
            (p.workingTeamId == null ||
                _leaderOwnedTeamIds.contains(p.workingTeamId)));
 
    final statusColor = switch (p.status) {
      'completed'      => const Color(0xFF22C55E),
      'assigned'       => const Color(0xFFF59E0B),
      'not_applicable' => const Color(0xFF94A3B8),
      _                => const Color(0xFF94A3B8),
    };
 
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(width: 40,
            child: Text('${index + 1}',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600))),
        Expanded(flex: 3,
            child: Text(p.processName,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B)),
                overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        Expanded(flex: 3,
            child: hasTeam
                ? _buildCompactTeamPill(p.teamName!, p.teamColor)
                : const Text('—',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12))),
        const SizedBox(width: 8),
        Expanded(flex: 2,
            child: p.isAssigned && p.assignUserName != null
                ? Text(p.assignUserName!,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF1E293B)),
                    overflow: TextOverflow.ellipsis)
                : canAssign
                    ? GestureDetector(
                        onTap: () => _showAssignDialog(p),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                              color: AppColors.primaryGreen,
                              borderRadius: BorderRadius.circular(4)),
                          child: const Text('Assign',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white, fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ))
                    : const Text('—',
                        style: TextStyle(
                            fontSize: 11, color: Color(0xFF94A3B8)))),
        const SizedBox(width: 8),
        Expanded(flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(4)),
              child: Text(p.statusLabel,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 10,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
            )),
        const SizedBox(width: 8),
        Expanded(flex: 2,
            child: Wrap(spacing: 4, runSpacing: 4, children: [
              if (p.hasFile) ...[
                _actionBtn(label: 'Reupload',
                    color: const Color(0xFFF59E0B),
                    icon: Icons.upload_rounded,
                    onTap: () => _showUploadDialog(p)),
                _actionBtn(label: 'View',
                    color: const Color(0xFF3B82F6),
                    icon: Icons.insert_drive_file_outlined,
                    onTap: () => _openFile(p)),
              ] else
                _actionBtn(label: 'Upload',
                    color: const Color(0xFF3B82F6),
                    icon: Icons.upload_file_outlined,
                    onTap: () => _showUploadDialog(p)),
              _actionBtn(label: 'Email',
                  color: const Color(0xFF1E293B),
                  icon: Icons.email_outlined,
                  onTap: () => _showEmailDialog(p)),
            ])),
      ]),
    );
  }
 
  void _showCreateReportTaskDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateReportTaskDialog(
          projectId: widget.projectId, onCreated: _onActionComplete),
    );
  }
 
  // ─────────────────────────────────────────────────────────────────────────
  // Extra tabs
  // ─────────────────────────────────────────────────────────────────────────
 
  Widget _buildExtraTabContent(String tabKey) {
    switch (tabKey) {
      case 'mom':             return _buildMinutesOfMeetingTab();
      case 'cc_progress':     return _buildCCProgressTab();
      case 'layout_approval': return _buildLayoutApprovalTab();
      case 'oc_progress':     return _buildOCProgressTab();
      default:                return _emptyProcessState('Content not available.');
    }
  }
 
  Widget _buildMinutesOfMeetingTab() => MinutesOfMeetingPage(
    projectId: widget.projectId,
    projectName: widget.projectName,
    isAdmin: _isAdmin,
  );
 
  Widget _buildCCProgressTab() => CcProgressPage(
    projectId: widget.projectId,
    projectName: widget.projectName,
  );
 
  Widget _buildLayoutApprovalTab() => LayoutApprovalPage(
        projectId:   widget.projectId,
        projectName: widget.projectName,
      );
 
  Widget _buildOCProgressTab() => OcProgressPage(
        projectId:   widget.projectId,
        projectName: widget.projectName,
      );
 
  // ─────────────────────────────────────────────────────────────────────────
  // Generic stage tab
  // ─────────────────────────────────────────────────────────────────────────
 
  Widget _buildGenericStageTab(ProcessStageModel stage) {
    final filtered = _searchQuery.isEmpty
        ? stage.processes
        : stage.processes
            .where((p) => p.processName
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()))
            .toList();
 
    final emptyMessage = _searchQuery.isEmpty
        ? (_isAdmin
            ? 'No processes found for this stage.'
            : 'No processes assigned to you in this stage.')
        : 'No results for "$_searchQuery"';
 
    return RefreshIndicator(
      onRefresh: () => _loadProcesses(silent: false),
      color: AppColors.primaryGreen,
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: _stageProgressHeader(stage)),
        SliverToBoxAdapter(
          child: filtered.isEmpty
              ? _emptyProcessState(emptyMessage)
              : _buildProcessCards(filtered),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ]),
    );
  }
 
  Widget _emptyProcessState(String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.assignment_outlined,
                size: 48,
                color: AppColors.primaryGreen.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
          ]),
        ),
      );
 
  // ── Dialog handlers ────────────────────────────────────────────────────────
 
  void _showAssignDialog(ProcessListItemModel p) {
    if (_isTeamLeader) {
      final teamId = p.workingTeamId;
      if (teamId != null && !_leaderOwnedTeamIds.contains(teamId)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'You can assign tasks only to members of your own team.'),
          backgroundColor: Color(0xFFEF4444),
        ));
        return;
      }
    }
    if (!_isAdmin && !_isTeamLeader) return;
 
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AssignDialog(
        process: p,
        projectId: widget.projectId,
        teamId: p.workingTeamId,
        teamName: p.teamName,
        teamColor: p.teamColor,
        onAssigned: _onActionComplete,
      ),
    );
  }
 
  void _showUploadDialog(ProcessListItemModel p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UploadDialog(
        process: p,
        projectId: widget.projectId,
        currentUserId: _currentUserId ?? 0,
        onUploaded: _onActionComplete,
      ),
    );
  }
 
  void _openFile(ProcessListItemModel p) {
    final path = p.filePath;
    if (path == null || path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No file path available'),
        backgroundColor: Color(0xFFEF4444),
      ));
      return;
    }
    String fullUrl = path.trim();
    if (!fullUrl.startsWith('http://') && !fullUrl.startsWith('https://')) {
      final base = ApiConstants.baseUrl.replaceAll(RegExp(r'/$'), '');
      final rel = fullUrl.startsWith('/') ? fullUrl : '/$fullUrl';
      fullUrl = '$base$rel';
    }
    Navigator.push(context,
        MaterialPageRoute(
          builder: (_) => FileViewerPage(url: fullUrl, title: p.processName),
        ));
  }
 
  void _showEmailDialog(ProcessListItemModel p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EmailDialog(process: p, projectId: widget.projectId),
    );
  }
 
  // ── AppBar ─────────────────────────────────────────────────────────────────
 
  AppBar _buildAppBar() {
    final ctrl = _tabController;
    final totalTabs = _stages.length + _extraTabs.length;
    final showTabs = !_isLoading && totalTabs > 0 && ctrl != null;

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.projectName,
            style: const TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w700, fontSize: 16)),
        const Text('Process List',
            style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12, fontWeight: FontWeight.w400)),
      ]),
      actions: [
        if (_isRefreshing)
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: AppColors.primaryGreen),
            ),
          )
        else
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
            onPressed: _isLoading ? null : () => _loadProcesses(silent: false),
            tooltip: 'Refresh',
          ),
      ],
      bottom: showTabs
          ? PreferredSize(
              preferredSize: const Size.fromHeight(50),
              child: Container(
                decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                        bottom: BorderSide(color: Color(0xFFE2E8F0)))),
                child: TabBar(
                  controller: ctrl,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: AppColors.primaryGreen,
                  unselectedLabelColor: const Color(0xFF94A3B8),
                  indicatorColor: AppColors.primaryGreen,
                  indicatorWeight: 2.5,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13),
                  tabs: [
                    ..._stages.asMap().entries.map((e) {
                      final i = e.key;
                      final s = e.value;
                      final showCount = s.stageKey != 'stage3';
                      final accentColor = _accentColorForStage(s.stageKey);
                      return Tab(
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(_iconForStage(s.stageKey), size: 13),
                          const SizedBox(width: 5),
                          Text(s.stageLabel),
                          if (showCount) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: _currentTabIndex == i
                                    ? accentColor
                                    : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('${s.totalCount}',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: _currentTabIndex == i
                                          ? Colors.white
                                          : const Color(0xFF64748B))),
                            ),
                          ],
                        ]),
                      );
                    }),
                    ..._extraTabs.asMap().entries.map((e) {
                      final t = e.value;
                      return Tab(
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(t.icon, size: 13),
                          const SizedBox(width: 5),
                          Text(t.label),
                        ]),
                      );
                    }),
                  ],
                ),
              ),
            )
          : null,
    );
  }
 
  Widget _buildSearchBar() => Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.search_rounded,
              color: AppColors.primaryGreen,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
              decoration: const InputDecoration(
                hintText: 'Search process name',
                hintStyle: TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              child: Container(
                margin: const EdgeInsets.only(left: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE2E8F0))),
                child: const Row(children: [
                  Icon(Icons.close_rounded, size: 14, color: Color(0xFF64748B)),
                  SizedBox(width: 4),
                  Text('Clear',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ]),
              ),
            ),
        ]),
      );
 
  // ── Build body ─────────────────────────────────────────────────────────────
 
  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: AppColors.primaryGreen),
          const SizedBox(height: 16),
          const Text('Loading processes...',
              style: TextStyle(color: Color(0xFF64748B))),
        ]),
      );
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
            const SizedBox(height: 12),
            Text(_errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF1E293B))),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _loadProcesses(initial: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white),
            ),
          ]),
        ),
      );
    }
 
    final totalTabs = _stages.length + _extraTabs.length;
    if (totalTabs == 0) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.assignment_outlined,
              size: 56,
              color: AppColors.primaryGreen.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          const Text('No processes found',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 16)),
        ]),
      );
    }
 
    final ctrl = _tabController;
    if (ctrl == null || ctrl.length != totalTabs) {
      return Column(children: [
        _buildSearchBar(),
        Expanded(child: Center(
            child: CircularProgressIndicator(color: AppColors.primaryGreen))),
      ]);
    }
 
    final tabViews = <Widget>[
      ..._stages.map((stage) {
        switch (stage.stageKey) {
          case 'pmc_application': return _buildStage0Tab();
          case 'stage3':          return _buildStage3Tab();
          case 'stage3_1':        return _buildStage3_1Tab();
          case 'stage3_2':        return _buildStage3_2Tab();
          default:                return _buildGenericStageTab(stage);
        }
      }),
      ..._extraTabs.map((t) => _buildExtraTabContent(t.key)),
    ];
 
    final currentIsStageTab = _currentTabIndex < _stages.length;
 
    return Column(children: [
      if (currentIsStageTab) _buildSearchBar(),
      Expanded(child: TabBarView(controller: ctrl, children: tabViews)),
    ]);
  }
 
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: _buildAppBar(),
        body: _buildBody(),
      );
}
 
// ═══════════════════════════════════════════════════════════════════════════
// Helper data classes
// ═══════════════════════════════════════════════════════════════════════════
 
class _ExtraTab {
  final String key;
  final String label;
  final IconData icon;
  const _ExtraTab({required this.key, required this.label, required this.icon});
}
 
class _Stage3SubTabDef {
  final Stage3SubTab key;
  final String label;
  final IconData icon;
  const _Stage3SubTabDef(
      {required this.key, required this.label, required this.icon});
}
 
// ═══════════════════════════════════════════════════════════════════════════
// All remaining widget classes are unchanged from the original file.
// ═══════════════════════════════════════════════════════════════════════════
 
class _MinutesOfMeetingTab extends StatefulWidget {
  final int projectId;
  final bool isAdmin;
  const _MinutesOfMeetingTab({required this.projectId, required this.isAdmin});
  @override
  State<_MinutesOfMeetingTab> createState() => _MinutesOfMeetingTabState();
}
 
class _MinutesOfMeetingTabState extends State<_MinutesOfMeetingTab> {
  List<Map<String, dynamic>> _meetings = [];
  bool _isLoading = true;
  String? _error;
 
  @override
  void initState() { super.initState(); _loadMeetings(); }
 
  Future<void> _loadMeetings() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      final token = await AuthStorageService.getToken();
      if (token == null) throw Exception('Session expired');
      final url = Uri.parse(
          '${ApiConstants.baseUrl}/api/mobile/projects/${widget.projectId}/meetings');
      final response = await http.get(url, headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body);
        final data = body['data'] ?? body['meetings'] ?? [];
        setState(() {
          _meetings = List<Map<String, dynamic>>.from(
              (data as List).map((e) => Map<String, dynamic>.from(e)));
          _isLoading = false;
        });
      } else {
        setState(() { _meetings = []; _isLoading = false; });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }
 
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
    return RefreshIndicator(
      onRefresh: _loadMeetings,
      color: AppColors.primaryGreen,
      child: _meetings.isEmpty
          ? ListView(children: [_emptyState('No meetings recorded yet.', Icons.calendar_today_outlined, const Color(0xFF3B82F6))])
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _meetings.length,
              itemBuilder: (_, i) {
                final m = _meetings[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1))]),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.calendar_today, size: 14, color: Color(0xFF3B82F6)),
                      const SizedBox(width: 6),
                      Text(m['meeting_date']?.toString() ?? m['date']?.toString() ?? 'N/A',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 8),
                    Text(m['title']?.toString() ?? m['meeting_title']?.toString() ?? 'Meeting',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                    if (m['description'] != null) ...[
                      const SizedBox(height: 6),
                      Text(m['description'].toString(),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ]),
                );
              },
            ),
    );
  }
 
  Widget _emptyState(String msg, IconData icon, Color color) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 52, color: color.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(msg, textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
          ]),
        ),
      );
}
 
class _CCProgressTab extends StatefulWidget {
  final int projectId;
  final bool isAdmin;
  const _CCProgressTab({required this.projectId, required this.isAdmin});
  @override
  State<_CCProgressTab> createState() => _CCProgressTabState();
}
 
class _CCProgressTabState extends State<_CCProgressTab> with TickerProviderStateMixin {
  TabController? _subCtrl;
  static const _subTabs = [
    _CCSubTab(key: 'cc_application', label: 'CC Application'),
    _CCSubTab(key: 'cc_scrutiny',    label: 'Scrutiny'),
    _CCSubTab(key: 'cc_approval',    label: 'Approval'),
    _CCSubTab(key: 'cc_documents',   label: 'Documents'),
  ];
  List<ProcessListItemModel> _processes = [];
  bool _isLoading = true;
 
  @override
  void initState() { super.initState(); _subCtrl = TabController(length: _subTabs.length, vsync: this); _loadData(); }
  @override
  void dispose() { _subCtrl?.dispose(); super.dispose(); }
 
  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });
    try {
      final token = await AuthStorageService.getToken();
      if (token == null) return;
      final url = Uri.parse('${ApiConstants.baseUrl}/api/mobile/projects/${widget.projectId}/cc-processes');
      final response = await http.get(url, headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body);
        final raw = body['data'] ?? body['processes'] ?? [];
        setState(() { _processes = (raw as List).map((e) => ProcessListItemModel.fromJson(e)).toList(); });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }
 
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
    final ctrl = _subCtrl;
    if (ctrl == null) return const SizedBox.shrink();
    return Column(children: [
      Container(color: Colors.white,
          child: TabBar(controller: ctrl, isScrollable: true, tabAlignment: TabAlignment.start,
              labelColor: AppColors.primaryGreen, unselectedLabelColor: const Color(0xFF94A3B8),
              indicatorColor: AppColors.primaryGreen, indicatorWeight: 2,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
              tabs: _subTabs.map((t) => Tab(text: t.label)).toList())),
      Expanded(child: TabBarView(controller: ctrl, children: _subTabs.map((t) => _buildSubContent(t.key)).toList())),
    ]);
  }
 
  Widget _buildSubContent(String key) {
    final filtered = _processes.where((p) => (p.subStage ?? p.stage) == key).toList();
    if (filtered.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.construction_outlined, size: 48, color: AppColors.primaryGreen.withValues(alpha: 0.3)),
      const SizedBox(height: 12),
      const Text('No CC processes found', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
    ]));
    return ListView.builder(padding: const EdgeInsets.all(16), itemCount: filtered.length,
        itemBuilder: (_, i) => _CCProcessCard(process: filtered[i]));
  }
}
 
class _CCSubTab { final String key, label; const _CCSubTab({required this.key, required this.label}); }
 
class _CCProcessCard extends StatelessWidget {
  final ProcessListItemModel process;
  const _CCProcessCard({required this.process});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Row(children: [
          Expanded(child: Text(process.processName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)))),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: process.status == 'completed' ? const Color(0xFF22C55E) : process.status == 'assigned' ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                borderRadius: BorderRadius.circular(4)),
            child: Text(process.statusLabel, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
        ]),
      );
}
 
class _LayoutApprovalTab extends StatefulWidget {
  final int projectId;
  final bool isAdmin;
  const _LayoutApprovalTab({required this.projectId, required this.isAdmin});
  @override
  State<_LayoutApprovalTab> createState() => _LayoutApprovalTabState();
}
 
class _LayoutApprovalTabState extends State<_LayoutApprovalTab> with TickerProviderStateMixin {
  TabController? _subCtrl;
  static const _subTabs = [
    _LayoutSubTab(key: 'layout_application', label: 'Application'),
    _LayoutSubTab(key: 'layout_scrutiny',    label: 'Scrutiny'),
    _LayoutSubTab(key: 'layout_approval',    label: 'Approval'),
    _LayoutSubTab(key: 'layout_documents',   label: 'Documents'),
  ];
  List<ProcessListItemModel> _processes = [];
  bool _isLoading = true;
 
  @override
  void initState() { super.initState(); _subCtrl = TabController(length: _subTabs.length, vsync: this); _loadData(); }
  @override
  void dispose() { _subCtrl?.dispose(); super.dispose(); }
 
  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final token = await AuthStorageService.getToken();
      if (token == null) return;
      final url = Uri.parse('${ApiConstants.baseUrl}/api/mobile/projects/${widget.projectId}/layout-processes');
      final response = await http.get(url, headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body);
        final raw = body['data'] ?? body['processes'] ?? [];
        setState(() { _processes = (raw as List).map((e) => ProcessListItemModel.fromJson(e)).toList(); });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }
 
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
    final ctrl = _subCtrl;
    if (ctrl == null) return const SizedBox.shrink();
    return Column(children: [
      Container(color: Colors.white, child: TabBar(controller: ctrl, isScrollable: true, tabAlignment: TabAlignment.start,
          labelColor: AppColors.primaryGreen, unselectedLabelColor: const Color(0xFF94A3B8),
          indicatorColor: AppColors.primaryGreen, indicatorWeight: 2,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          tabs: _subTabs.map((t) => Tab(text: t.label)).toList())),
      Expanded(child: TabBarView(controller: ctrl, children: _subTabs.map((t) => _buildSubContent(t.key)).toList())),
    ]);
  }
 
  Widget _buildSubContent(String key) {
    final filtered = _processes.where((p) => (p.subStage ?? p.stage) == key).toList();
    if (filtered.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.layers_outlined, size: 48, color: AppColors.primaryGreen.withValues(alpha: 0.3)),
      const SizedBox(height: 12),
      const Text('No layout approval processes found', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
    ]));
    return ListView.builder(padding: const EdgeInsets.all(16), itemCount: filtered.length, itemBuilder: (_, i) => _CCProcessCard(process: filtered[i]));
  }
}
 
class _LayoutSubTab { final String key, label; const _LayoutSubTab({required this.key, required this.label}); }
 
class _OCProgressTab extends StatefulWidget {
  final int projectId;
  final bool isAdmin;
  const _OCProgressTab({required this.projectId, required this.isAdmin});
  @override
  State<_OCProgressTab> createState() => _OCProgressTabState();
}
 
class _OCProgressTabState extends State<_OCProgressTab> with TickerProviderStateMixin {
  TabController? _subCtrl;
  static const _subTabs = [
    _OCSubTab(key: 'oc_application', label: 'Application'),
    _OCSubTab(key: 'oc_scrutiny',    label: 'Scrutiny'),
    _OCSubTab(key: 'oc_completion',  label: 'Completion Certificate'),
    _OCSubTab(key: 'oc_documents',   label: 'Documents'),
  ];
  List<ProcessListItemModel> _processes = [];
  bool _isLoading = true;
 
  @override
  void initState() { super.initState(); _subCtrl = TabController(length: _subTabs.length, vsync: this); _loadData(); }
  @override
  void dispose() { _subCtrl?.dispose(); super.dispose(); }
 
  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final token = await AuthStorageService.getToken();
      if (token == null) return;
      final url = Uri.parse('${ApiConstants.baseUrl}/api/mobile/projects/${widget.projectId}/oc-processes');
      final response = await http.get(url, headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body);
        final raw = body['data'] ?? body['processes'] ?? [];
        setState(() { _processes = (raw as List).map((e) => ProcessListItemModel.fromJson(e)).toList(); });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }
 
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
    final ctrl = _subCtrl;
    if (ctrl == null) return const SizedBox.shrink();
    return Column(children: [
      Container(color: Colors.white, child: TabBar(controller: ctrl, isScrollable: true, tabAlignment: TabAlignment.start,
          labelColor: AppColors.primaryGreen, unselectedLabelColor: const Color(0xFF94A3B8),
          indicatorColor: AppColors.primaryGreen, indicatorWeight: 2,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          tabs: _subTabs.map((t) => Tab(text: t.label)).toList())),
      Expanded(child: TabBarView(controller: ctrl, children: _subTabs.map((t) => _buildSubContent(t.key)).toList())),
    ]);
  }
 
  Widget _buildSubContent(String key) {
    final filtered = _processes.where((p) => (p.subStage ?? p.stage) == key).toList();
    if (filtered.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.check_circle_outline, size: 48, color: AppColors.primaryGreen.withValues(alpha: 0.3)),
      const SizedBox(height: 12),
      const Text('No OC progress processes found', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
    ]));
    return ListView.builder(padding: const EdgeInsets.all(16), itemCount: filtered.length, itemBuilder: (_, i) => _CCProcessCard(process: filtered[i]));
  }
}
 
class _OCSubTab { final String key, label; const _OCSubTab({required this.key, required this.label}); }
 
// ═══════════════════════════════════════════════════════════════════════════
// Drawing Requests Tab
// ═══════════════════════════════════════════════════════════════════════════
 
class _DrawingRequestsTab extends StatefulWidget {
  final int projectId;
  final bool isAdmin;
  final bool isTeamLeader;
 
  const _DrawingRequestsTab({
    required this.projectId,
    required this.isAdmin,
    required this.isTeamLeader,
  });
 
  @override
  State<_DrawingRequestsTab> createState() => _DrawingRequestsTabState();
}
 
class _DrawingRequestsTabState extends State<_DrawingRequestsTab> {
  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = true;
  String? _error;
 
  @override
  void initState() {
    super.initState();
    _loadTasks();
  }
 
  Future<void> _loadTasks() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; });
 
    try {
      final token = await AuthStorageService.getToken();
      if (token == null) throw Exception('Session expired');
 
      final url = Uri.parse(
        '${ApiConstants.baseUrl}/api/mobile/projects/${widget.projectId}/drawing-tasks',
      );
 
      final response = await http.get(url, headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 20));
 
      if (!mounted) return;
 
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body);
        final raw = body['data'] ?? body['tasks'] ?? [];
 
        final tasks = List<Map<String, dynamic>>.from(
          (raw as List).map((e) => Map<String, dynamic>.from(e)),
        );
 
        for (final task in tasks) {
          final filePath = task['file_path']?.toString();
          if (filePath != null &&
              filePath.isNotEmpty &&
              !filePath.startsWith('http://') &&
              !filePath.startsWith('https://')) {
            final base = ApiConstants.baseUrl.replaceAll(RegExp(r'/$'), '');
            final rel = filePath.startsWith('/') ? filePath : '/$filePath';
            task['file_path'] = '$base$rel';
          }
        }
 
        setState(() { _tasks = tasks; _isLoading = false; });
      } else {
        setState(() { _tasks = []; _isLoading = false; });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _tasks = []; _isLoading = false; _error = e.toString(); });
    }
  }
 
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('Drawing Requests',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primaryGreen)),
        ),
      ),
      if (widget.isAdmin || widget.isTeamLeader)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: _showCreateDrawingDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: AppColors.primaryGreen, borderRadius: BorderRadius.circular(8)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add, size: 15, color: Colors.white),
                  SizedBox(width: 6),
                  Text('Create Drawing Task', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
        ),
      if (_isLoading)
        Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)))
      else
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadTasks,
            color: AppColors.primaryGreen,
            child: _tasks.isEmpty
                ? ListView(children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.draw_outlined, size: 52, color: AppColors.primaryGreen.withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          const Text('No drawing tasks yet', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
                        ]),
                      ),
                    ),
                  ])
                : Column(children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: const Row(children: [
                        Expanded(flex: 3, child: Text('DRAWING NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                        Expanded(flex: 3, child: Text('DESCRIPTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                        Expanded(flex: 2, child: Text('DEADLINE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                        Expanded(flex: 2, child: Text('ASSIGNED USER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                        Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                        Expanded(flex: 2, child: Text('ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                      ]),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _tasks.length,
                        itemBuilder: (_, i) => _buildDrawingRow(_tasks[i], i),
                      ),
                    ),
                  ]),
          ),
        ),
    ]);
  }
 
  Widget _buildDrawingRow(Map<String, dynamic> task, int index) {
    final name = (task['task_name']?.toString() ?? '').replaceFirst('Drawing: ', '').trim();
    final status = task['status']?.toString() ?? 'pending';
    final deadline = task['task_deadline']?.toString() ?? '-';
    final description = task['task_description']?.toString() ?? '-';
    final assignedUsers = task['assigned_users_names']?.toString() ?? '';
    final filePath = task['file_path']?.toString();
 
    Color statusColor = status == 'completed' ? const Color(0xFF22C55E) : status == 'in_progress' ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);
 
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(flex: 3, child: Text(name.isEmpty ? '—' : name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)), overflow: TextOverflow.ellipsis)),
        Expanded(flex: 3, child: Text(description, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), maxLines: 2, overflow: TextOverflow.ellipsis)),
        Expanded(flex: 2, child: Text(deadline, style: const TextStyle(fontSize: 11, color: Color(0xFF334155)), overflow: TextOverflow.ellipsis)),
        Expanded(flex: 2, child: assignedUsers.isNotEmpty
            ? Row(children: [
                const Icon(Icons.person_outline, size: 13, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Expanded(child: Text(assignedUsers, style: const TextStyle(fontSize: 11, color: Color(0xFF1E293B), fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
              ])
            : const Text('—', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
        Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(6)),
          child: Text(status.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
        ))),
        Expanded(flex: 2, child: filePath != null && filePath.isNotEmpty
            ? GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FileViewerPage(url: filePath, title: name))),
                child: const Text('View File', style: TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.w600)),
              )
            : const Text('Not Uploaded', style: TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.w500))),
      ]),
    );
  }
 
  void _showCreateDrawingDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateDrawingDialog(projectId: widget.projectId, onCreated: _loadTasks),
    );
  }
}
 
// ═══════════════════════════════════════════════════════════════════════════
// Create Drawing Task Dialog
// ═══════════════════════════════════════════════════════════════════════════
 
class _CreateDrawingDialog extends StatefulWidget {
  final int projectId;
  final Future<void> Function() onCreated;
  const _CreateDrawingDialog({required this.projectId, required this.onCreated});
  @override
  State<_CreateDrawingDialog> createState() => _CreateDrawingDialogState();
}
 
class _CreateDrawingDialogState extends State<_CreateDrawingDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime? _deadline;
  bool _isSaving = false;
 
  @override
  void dispose() { _nameCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }
 
  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.light(primary: AppColors.primaryGreen)), child: child!),
    );
    if (picked != null && mounted) setState(() => _deadline = picked);
  }
 
  String get _fmtDeadline => _deadline == null ? 'Select deadline' : '${_deadline!.day.toString().padLeft(2, '0')}/${_deadline!.month.toString().padLeft(2, '0')}/${_deadline!.year}';
 
  Future<void> _submit() async {
    if (_isSaving) return;
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a drawing name'), backgroundColor: Color(0xFFEF4444)));
      return;
    }
    if (_deadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a deadline'), backgroundColor: Color(0xFFEF4444)));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final token = await AuthStorageService.getToken();
      if (token == null) throw Exception('Session expired');
      final dl = '${_deadline!.year}-${_deadline!.month.toString().padLeft(2, '0')}-${_deadline!.day.toString().padLeft(2, '0')}';
      final payload = {
        'project_id': widget.projectId, 'task_type': 'drawing',
        'task_name': 'Drawing: ${_nameCtrl.text.trim()}', 'task_description': _descCtrl.text.trim(),
        'task_deadline': dl, 'drawing_name': _nameCtrl.text.trim(),
        'drawing_description': _descCtrl.text.trim(), 'drawing_deadline': dl,
      };
      final candidateUrls = [
        '${ApiConstants.baseUrl}/api/mobile/general-tasks',
        '${ApiConstants.baseUrl}/general-tasks',
        '${ApiConstants.baseUrl}/general-tasks/store',
      ];
      http.Response? lastResponse;
      dynamic lastDecoded;
      for (final rawUrl in candidateUrls) {
        final response = await http.post(Uri.parse(rawUrl), headers: {'Accept': 'application/json', 'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}, body: jsonEncode(payload)).timeout(const Duration(seconds: 30));
        dynamic decoded;
        try { decoded = jsonDecode(response.body); } catch (_) { decoded = {'message': response.body}; }
        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (!mounted) return;
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text((decoded is Map ? decoded['message']?.toString() : null) ?? 'Drawing task created successfully'), backgroundColor: AppColors.primaryGreen));
          await widget.onCreated();
          return;
        }
        lastResponse = response;
        lastDecoded = decoded;
      }
      throw Exception((lastDecoded is Map ? lastDecoded['message']?.toString() : null) ?? 'Failed to create drawing task (${lastResponse?.statusCode ?? ''})');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
 
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(color: AppColors.primaryGreen, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
            child: Row(children: [
              const Expanded(child: Text('Create Drawing Task', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700))),
              GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.close, color: Colors.white, size: 18))),
            ]),
          ),
          Flexible(child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Drawing Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
              const SizedBox(height: 6),
              TextField(controller: _nameCtrl, decoration: _inputDeco(hint: 'Enter drawing name'), style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B))),
              const SizedBox(height: 14),
              const Text('Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
              const SizedBox(height: 6),
              TextField(controller: _descCtrl, maxLines: 3, decoration: _inputDeco(hint: 'Enter description'), style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B))),
              const SizedBox(height: 14),
              const Text('Deadline', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _pickDeadline,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD1D5DB)), borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Expanded(child: Text(_fmtDeadline, style: TextStyle(fontSize: 14, color: _deadline == null ? const Color(0xFF9CA3AF) : const Color(0xFF1E293B)))),
                    const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF6B7280)),
                  ]),
                ),
              ),
            ]),
          )),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Row(children: [
              Expanded(child: OutlinedButton(onPressed: _isSaving ? null : () => Navigator.pop(context), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF374151), side: const BorderSide(color: Color(0xFFD1D5DB)), padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('Cancel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)))),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(onPressed: _isSaving ? null : _submit, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Create', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)))),
            ]),
          ),
        ]),
      );
 
  InputDecoration _inputDeco({String? hint}) => InputDecoration(
        hintText: hint, hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.primaryGreen, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      );
}
 
// ═══════════════════════════════════════════════════════════════════════════
// Create Report Task Dialog
// ═══════════════════════════════════════════════════════════════════════════
 
class _CreateReportTaskDialog extends StatefulWidget {
  final int projectId;
  final Future<void> Function() onCreated;
  const _CreateReportTaskDialog({required this.projectId, required this.onCreated});
  @override
  State<_CreateReportTaskDialog> createState() => _CreateReportTaskDialogState();
}
 
class _CreateReportTaskDialogState extends State<_CreateReportTaskDialog> {
  final _nameCtrl = TextEditingController();
  List<Map<String, dynamic>> _teams = [];
  int? _selectedWorkingTeam;
  int? _selectedReviewTeam;
  bool _isLoading = true;
  bool _isSaving = false;
 
  @override
  void initState() { super.initState(); _loadTeams(); }
  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }
 
  Future<void> _loadTeams() async {
    try {
      final token = await AuthStorageService.getToken();
      if (token == null) return;
      final url = Uri.parse('${ApiConstants.baseUrl}/api/mobile/teams');
      final response = await http.get(url, headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body);
        final raw = body['data'] ?? body['teams'] ?? [];
        setState(() { _teams = List<Map<String, dynamic>>.from((raw as List).map((e) => Map<String, dynamic>.from(e))); });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }
 
  Future<void> _submit() async {
    if (_isSaving) return;
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a report name'), backgroundColor: Color(0xFFEF4444)));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final token = await AuthStorageService.getToken();
      if (token == null) throw Exception('Session expired');
      final url = Uri.parse('${ApiConstants.baseUrl}/process/create');
      final body = <String, dynamic>{'project_id': widget.projectId, 'process_name': _nameCtrl.text.trim(), 'stage': 'stage3_2'};
      if (_selectedWorkingTeam != null) body['working_team'] = _selectedWorkingTeam;
      if (_selectedReviewTeam != null) body['review_team'] = _selectedReviewTeam;
      final response = await http.post(url, headers: {'Accept': 'application/json', 'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}, body: jsonEncode(body)).timeout(const Duration(seconds: 30));
      if (!mounted) return;
      dynamic decoded;
      try { decoded = jsonDecode(response.body); } catch (_) { decoded = {'message': response.body}; }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text((decoded is Map ? decoded['message']?.toString() : null) ?? 'Report task created successfully'), backgroundColor: AppColors.primaryGreen));
        await widget.onCreated();
      } else {
        final msg = (decoded is Map ? decoded['message']?.toString() : null) ?? 'Failed to create report task';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: const Color(0xFFEF4444)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
 
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(color: AppColors.primaryGreen, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
            child: Row(children: [
              const Expanded(child: Text('Create Report Task', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700))),
              GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.close, color: Colors.white, size: 18))),
            ]),
          ),
          if (_isLoading)
            const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())
          else
            Flexible(child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Report Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                const SizedBox(height: 6),
                TextField(controller: _nameCtrl, decoration: _inputDeco(hint: 'Enter report name'), style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B))),
                const SizedBox(height: 14),
                const Text('Working Team', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                const SizedBox(height: 6),
                _teamDropdown(value: _selectedWorkingTeam, hint: 'Select team', onChanged: (v) => setState(() => _selectedWorkingTeam = v)),
                const SizedBox(height: 14),
                const Text('Review Team (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                const SizedBox(height: 6),
                _teamDropdown(value: _selectedReviewTeam, hint: 'Select review team (optional)', onChanged: (v) => setState(() => _selectedReviewTeam = v)),
              ]),
            )),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Row(children: [
              Expanded(child: OutlinedButton(onPressed: _isSaving ? null : () => Navigator.pop(context), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF374151), side: const BorderSide(color: Color(0xFFD1D5DB)), padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('Cancel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)))),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(onPressed: _isSaving ? null : _submit, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Create Report', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)))),
            ]),
          ),
        ]),
      );
 
  Widget _teamDropdown({required int? value, required String hint, required ValueChanged<int?> onChanged}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD1D5DB)), borderRadius: BorderRadius.circular(8)),
        child: DropdownButtonHideUnderline(child: DropdownButton<int>(
          isExpanded: true, value: value,
          hint: Text(hint, style: const TextStyle(color: Color(0xFF9CA3AF))),
          items: [
            const DropdownMenuItem<int>(value: null, child: Text('None', style: TextStyle(color: Color(0xFF6B7280)))),
            ..._teams.map((t) => DropdownMenuItem<int>(value: t['id'] as int?, child: Text(t['team_name']?.toString() ?? 'Team', style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B))))),
          ],
          onChanged: onChanged,
        )),
      );
 
  InputDecoration _inputDeco({String? hint}) => InputDecoration(
        hintText: hint, hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.primaryGreen, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// _ProjectInfoForm  — Fully editable Project Info form
// ═══════════════════════════════════════════════════════════════════════════

class _ProjectInfoForm extends StatefulWidget {
  final int projectId;
  final bool isAdmin;
  final Future<void> Function() onSaved;

  const _ProjectInfoForm({
    required this.projectId,
    required this.isAdmin,
    required this.onSaved,
  });

  @override
  State<_ProjectInfoForm> createState() => _ProjectInfoFormState();
}

class _ProjectInfoFormState extends State<_ProjectInfoForm> {
  final _formKey = GlobalKey<FormState>();

  final _plotAreaCtrl = TextEditingController();
  final _surveyNoCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  String _ownershipType = 'freehold';
  final _deductionCtrl = TextEditingController();
  final _deductionCommentCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _locationLinkCtrl = TextEditingController();
  final _fsiAvailableCtrl = TextEditingController();
  final _fsiCommentCtrl = TextEditingController();
  String _existingInfo = 'regular';
  final _totalMembersCtrl = TextEditingController();

  final List<Map<String, TextEditingController>> _unitTypeRows = [];

  final List<PlatformFile> _ownershipFiles = [];
  final List<PlatformFile> _surveyDrawingFiles = [];
  final List<PlatformFile> _titleSurveyFiles = [];

  List<Map<String, dynamic>> _existingOwnershipDocs = [];
  List<Map<String, dynamic>> _existingSurveyDrawings = [];
  List<Map<String, dynamic>> _existingTitleSurveys = [];

  bool _isLoadingInfo = true;
  bool _isSaving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _addUnitTypeRow();
    _loadProjectInfo();
  }

  @override
  void dispose() {
    _plotAreaCtrl.dispose();
    _surveyNoCtrl.dispose();
    _ownerNameCtrl.dispose();
    _deductionCtrl.dispose();
    _deductionCommentCtrl.dispose();
    _locationCtrl.dispose();
    _locationLinkCtrl.dispose();
    _fsiAvailableCtrl.dispose();
    _fsiCommentCtrl.dispose();
    _totalMembersCtrl.dispose();
    for (final row in _unitTypeRows) {
      row['type']!.dispose();
      row['number_of_units']!.dispose();
      row['carpet_area']!.dispose();
      row['__id']!.dispose();
    }
    super.dispose();
  }

  void _addUnitTypeRow(
      {String? id, String? type, String? units, String? area}) {
    _unitTypeRows.add({
      '__id': TextEditingController(text: id ?? ''),
      'type': TextEditingController(text: type ?? ''),
      'number_of_units': TextEditingController(text: units ?? ''),
      'carpet_area': TextEditingController(text: area ?? ''),
    });
  }

  Future<void> _loadProjectInfo() async {
    setState(() {
      _isLoadingInfo = true;
      _loadError = null;
    });
    try {
      final token = await AuthStorageService.getToken();
      if (token == null || token.isEmpty) throw Exception('Session expired.');
      final url = Uri.parse(
          '${ApiConstants.baseUrl}/api/mobile/projects/${widget.projectId}');
      final response = await http.get(url, headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body);
        final raw = body['project'] ?? body['data'] ?? body;
        final info =
            raw['project_info'] ?? raw['projectInfo'] ?? {};
        _plotAreaCtrl.text = info['plot_area']?.toString() ?? '';
        _surveyNoCtrl.text = info['survey_no']?.toString() ?? '';
        _ownerNameCtrl.text = info['owner_name']?.toString() ?? '';
        _ownershipType =
            info['ownership_type']?.toString() ?? 'freehold';
        _deductionCtrl.text = info['deduction']?.toString() ?? '';
        _deductionCommentCtrl.text =
            info['deduction_comment']?.toString() ?? '';
        _locationCtrl.text = info['location']?.toString() ?? '';
        _locationLinkCtrl.text =
            info['location_link']?.toString() ?? '';
        _fsiAvailableCtrl.text =
            info['fsi_available']?.toString() ?? '';
        _fsiCommentCtrl.text = info['fsi_comment']?.toString() ?? '';
        _existingInfo =
            info['existing_info']?.toString() ?? 'regular';
        _totalMembersCtrl.text =
            info['total_members']?.toString() ?? '';
        _existingOwnershipDocs = _parseDocs(info['ownership_documents']);
        _existingSurveyDrawings = _parseDocs(info['survey_drawings']);
        _existingTitleSurveys = _parseDocs(info['title_surveys']);
        final unitTypes =
            info['unit_types'] ?? info['unitTypes'] ?? [];
        if (unitTypes is List && unitTypes.isNotEmpty) {
          for (final row in _unitTypeRows) {
            row['type']!.dispose();
            row['number_of_units']!.dispose();
            row['carpet_area']!.dispose();
            row['__id']!.dispose();
          }
          _unitTypeRows.clear();
          for (final ut in unitTypes) {
            if (ut is Map) {
              _addUnitTypeRow(
                id: ut['id']?.toString(),
                type: ut['type']?.toString(),
                units: ut['number_of_units']?.toString(),
                area: ut['carpet_area']?.toString(),
              );
            }
          }
          if (_unitTypeRows.isEmpty) _addUnitTypeRow();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _loadError = 'Could not load project info: $e');
    } finally {
      if (mounted) setState(() => _isLoadingInfo = false);
    }
  }

  List<Map<String, dynamic>> _parseDocs(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  Future<void> _pickFiles(List<PlatformFile> target) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      allowMultiple: true,
      withData: false,
    );
    if (result != null && result.files.isNotEmpty && mounted) {
      setState(() => target.addAll(result.files));
    }
  }

  Future<void> _removeExistingDoc(
      List<Map<String, dynamic>> list, int index, String type) async {
    final token = await AuthStorageService.getToken();
    if (token == null) return;
    try {
      final url = Uri.parse(
          '${ApiConstants.baseUrl}/api/mobile/projects/${widget.projectId}/project-info/$type/$index');
      final res = await http.delete(url, headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 20));
      if (res.statusCode >= 200 && res.statusCode < 300 && mounted) {
        setState(() => list.removeAt(index));
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    try {
      final token = await AuthStorageService.getToken();
      if (token == null || token.isEmpty) throw Exception('Session expired.');
      final uri = Uri.parse(
          '${ApiConstants.baseUrl}/api/mobile/projects/${widget.projectId}/project-info');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Accept'] = 'application/json'
        ..headers['Authorization'] = 'Bearer $token';
      void addField(String key, String value) {
        if (value.trim().isNotEmpty) request.fields[key] = value.trim();
      }

      addField('plot_area', _plotAreaCtrl.text);
      addField('survey_no', _surveyNoCtrl.text);
      addField('owner_name', _ownerNameCtrl.text);
      addField('deduction', _deductionCtrl.text);
      addField('deduction_comment', _deductionCommentCtrl.text);
      addField('location', _locationCtrl.text);
      addField('location_link', _locationLinkCtrl.text);
      addField('fsi_available', _fsiAvailableCtrl.text);
      addField('fsi_comment', _fsiCommentCtrl.text);
      addField('total_members', _totalMembersCtrl.text);
      request.fields['ownership_type'] = _ownershipType;
      request.fields['existing_info'] = _existingInfo;
      int unitIdx = 0;
      for (final row in _unitTypeRows) {
        final type = row['type']!.text.trim();
        if (type.isEmpty) continue;
        final id = row['__id']!.text.trim();
        if (id.isNotEmpty) {
          request.fields['unit_types[$unitIdx][id]'] = id;
        }
        request.fields['unit_types[$unitIdx][type]'] = type;
        request.fields['unit_types[$unitIdx][number_of_units]'] =
            row['number_of_units']!.text.trim().isEmpty
                ? '0'
                : row['number_of_units']!.text.trim();
        request.fields['unit_types[$unitIdx][carpet_area]'] =
            row['carpet_area']!.text.trim().isEmpty
                ? '0'
                : row['carpet_area']!.text.trim();
        unitIdx++;
      }

      Future<void> addFiles(
          String fieldName, List<PlatformFile> files) async {
        for (final f in files) {
          if (f.path == null) continue;
          final mime =
              lookupMimeType(f.path!) ?? 'application/octet-stream';
          final parts = mime.split('/');
          request.files.add(await http.MultipartFile.fromPath(
            '$fieldName[]',
            f.path!,
            filename: f.name,
            contentType: MediaType(parts[0], parts[1]),
          ));
        }
      }

      await addFiles('ownership_documents', _ownershipFiles);
      await addFiles('survey_drawings', _surveyDrawingFiles);
      await addFiles('title_surveys', _titleSurveyFiles);
      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);
      if (!mounted) return;
      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = {};
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(decoded['message']?.toString() ??
              'Project information saved successfully.'),
          backgroundColor: AppColors.primaryGreen,
        ));
        setState(() {
          _ownershipFiles.clear();
          _surveyDrawingFiles.clear();
          _titleSurveyFiles.clear();
        });
        await widget.onSaved();
        await _loadProjectInfo();
      } else {
        String msg =
            decoded['message']?.toString() ?? 'Failed to save';
        if (decoded is Map && decoded['errors'] is Map) {
          final errs = decoded['errors'] as Map;
          msg = errs.values.first is List
              ? (errs.values.first as List).first.toString()
              : msg;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: const Color(0xFFEF4444),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _sectionCard(
          {required String title,
          required IconData icon,
          required List<Widget> children}) =>
      Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: AppColors.primaryGreen.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(children: [
              Icon(icon, size: 16, color: AppColors.primaryGreen),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryGreen)),
            ]),
          ),
          Divider(
              height: 1,
              color: AppColors.primaryGreen.withValues(alpha: 0.15)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children),
          ),
        ]),
      );

  Widget _fieldLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151))),
      );

  InputDecoration _inputDecoration({String? hint, Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
        suffixIcon: suffix,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: Color(0xFFD1D5DB))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: Color(0xFFD1D5DB))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
                color: AppColors.primaryGreen, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      );

  Widget _textField(TextEditingController ctrl,
          {String? label,
          String? hint,
          TextInputType? type,
          int maxLines = 1,
          String? Function(String?)? validator}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (label != null) _fieldLabel(label),
        TextFormField(
          controller: ctrl,
          keyboardType: type,
          maxLines: maxLines,
          validator: validator,
          style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
          decoration: _inputDecoration(hint: hint),
        ),
      ]);

  Widget _docList(
      String title, List<Map<String, dynamic>> docs, String type) {
    if (docs.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 8),
      Text('Uploaded $title:',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryGreen)),
      const SizedBox(height: 6),
      ...docs.asMap().entries.map((e) {
        final idx = e.key;
        final doc = e.value;
        final name =
            doc['name']?.toString() ?? 'Document ${idx + 1}';
        final url = doc['url']?.toString() ?? '';
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(children: [
            const Icon(Icons.insert_drive_file_outlined,
                size: 16, color: Color(0xFF64748B)),
            const SizedBox(width: 8),
            Expanded(
                child: Text(name,
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
                    overflow: TextOverflow.ellipsis)),
            if (url.isNotEmpty)
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        FileViewerPage(url: url, title: name),
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.open_in_new,
                      size: 15, color: Color(0xFF3B82F6)),
                ),
              ),
            GestureDetector(
              onTap: () => _removeExistingDoc(docs, idx, type),
              child: const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.delete_outline,
                    size: 16, color: Color(0xFFEF4444)),
              ),
            ),
          ]),
        );
      }),
    ]);
  }

  Widget _pickedFilesList(List<PlatformFile> files) {
    if (files.isEmpty) return const SizedBox.shrink();
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: files.asMap().entries.map((e) {
          final idx = e.key;
          final f = e.value;
          return Container(
            margin: const EdgeInsets.only(top: 6),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: AppColors.primaryGreen.withValues(alpha: 0.25)),
            ),
            child: Row(children: [
              Icon(Icons.attach_file_rounded,
                  size: 15, color: AppColors.primaryGreen),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(f.name,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF1E293B)),
                      overflow: TextOverflow.ellipsis)),
              GestureDetector(
                onTap: () =>
                    setState(() => files.removeAt(idx)),
                child: const Icon(Icons.close,
                    size: 14, color: Color(0xFF94A3B8)),
              ),
            ]),
          );
        }).toList());
  }

  Widget _filePickerSection(
          {required String label,
          required List<PlatformFile> files,
          required List<Map<String, dynamic>> existing,
          required String type,
          required VoidCallback onPick}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _fieldLabel(label),
        GestureDetector(
          onTap: onPick,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              border: Border.all(
                  color: AppColors.primaryGreen.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(8),
              color: AppColors.primaryGreen.withValues(alpha: 0.04),
            ),
            child: Row(children: [
              Icon(Icons.upload_file_outlined,
                  size: 16, color: AppColors.primaryGreen),
              const SizedBox(width: 8),
              Text('Choose files',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w500)),
              const Spacer(),
              if (files.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${files.length} new',
                      style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w700)),
                ),
            ]),
          ),
        ),
        _pickedFilesList(files),
        _docList(label, existing, type),
      ]);

  Widget _unitTypesSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._unitTypeRows.asMap().entries.map((e) {
            final idx = e.key;
            final row = e.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Text('Unit Type ${idx + 1}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryGreen)),
                  const Spacer(),
                  if (_unitTypeRows.length > 1)
                    GestureDetector(
                      onTap: () => setState(() {
                        row['type']!.dispose();
                        row['number_of_units']!.dispose();
                        row['carpet_area']!.dispose();
                        row['__id']!.dispose();
                        _unitTypeRows.removeAt(idx);
                      }),
                      child: const Icon(Icons.delete_outline,
                          size: 16, color: Color(0xFFEF4444)),
                    ),
                ]),
                const SizedBox(height: 8),
                TextFormField(
                  controller: row['type'],
                  decoration:
                      _inputDecoration(hint: 'Type (e.g. 1BHK, 2BHK)'),
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: row['number_of_units'],
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration(hint: 'No. of units'),
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF1E293B)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: row['carpet_area'],
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration:
                          _inputDecoration(hint: 'Carpet area (sq.m)'),
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF1E293B)),
                    ),
                  ),
                ]),
              ]),
            );
          }),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => setState(() => _addUnitTypeRow()),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(
                    color:
                        AppColors.primaryGreen.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_circle_outline,
                    size: 16, color: AppColors.primaryGreen),
                const SizedBox(width: 6),
                Text('Add Unit Type',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ],
      );

  double? get _netArea {
    final plot = double.tryParse(_plotAreaCtrl.text);
    final ded = double.tryParse(_deductionCtrl.text);
    if (plot == null) return null;
    return plot - (ded ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingInfo) {
      return Center(
          child: CircularProgressIndicator(
              color: AppColors.primaryGreen));
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined,
                size: 40, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            Text(_loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF64748B), fontSize: 13)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadProjectInfo,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white),
              child: const Text('Retry'),
            ),
          ]),
        ),
      );
    }
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          _sectionCard(
            title: 'Property Details',
            icon: Icons.home_outlined,
            children: [
              Row(children: [
                Expanded(
                    child: _textField(_plotAreaCtrl,
                        label: 'Plot Area (sq. meters)',
                        hint: '0.00',
                        type: const TextInputType.numberWithOptions(
                            decimal: true))),
                const SizedBox(width: 10),
                Expanded(
                    child: _textField(_surveyNoCtrl,
                        label: 'Survey No.',
                        hint: 'Survey number')),
              ]),
              const SizedBox(height: 12),
              _textField(_ownerNameCtrl,
                  label: 'Owner Name', hint: 'Owner name'),
              const SizedBox(height: 12),
              _fieldLabel('Ownership Type'),
              Row(children: [
                Expanded(
                  child: RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Leasehold',
                        style: TextStyle(fontSize: 13)),
                    value: 'leasehold',
                    groupValue: _ownershipType,
                    activeColor: AppColors.primaryGreen,
                    onChanged: (v) =>
                        setState(() => _ownershipType = v!),
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Freehold',
                        style: TextStyle(fontSize: 13)),
                    value: 'freehold',
                    groupValue: _ownershipType,
                    activeColor: AppColors.primaryGreen,
                    onChanged: (v) =>
                        setState(() => _ownershipType = v!),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: _textField(_deductionCtrl,
                      label: 'Deduction (sq. meters)',
                      hint: '0.00',
                      type: const TextInputType.numberWithOptions(
                          decimal: true)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _textField(_deductionCommentCtrl,
                      label: 'Deduction Comment',
                      hint: 'Comment',
                      maxLines: 2),
                ),
              ]),
              if (_netArea != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(children: [
                    Icon(Icons.calculate_outlined,
                        size: 14, color: AppColors.primaryGreen),
                    const SizedBox(width: 6),
                    Text(
                      'Net Area: ${_netArea!.toStringAsFixed(2)} sq. meters',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w600),
                    ),
                  ]),
                ),
              ],
            ],
          ),
          _sectionCard(
            title: 'Location Details',
            icon: Icons.location_on_outlined,
            children: [
              _textField(_locationCtrl,
                  label: 'Location', hint: 'Enter location'),
              const SizedBox(height: 12),
              _fieldLabel('Google Maps Link'),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _locationLinkCtrl,
                    keyboardType: TextInputType.url,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF1E293B)),
                    decoration: _inputDecoration(
                        hint: 'https://maps.google.com/...'),
                  ),
                ),
              ]),
            ],
          ),
          _sectionCard(
            title: 'Documents',
            icon: Icons.folder_outlined,
            children: [
              _filePickerSection(
                label: 'Ownership Documents',
                files: _ownershipFiles,
                existing: _existingOwnershipDocs,
                type: 'ownership_documents',
                onPick: () => _pickFiles(_ownershipFiles),
              ),
              const SizedBox(height: 14),
              _filePickerSection(
                label: 'Survey Drawings',
                files: _surveyDrawingFiles,
                existing: _existingSurveyDrawings,
                type: 'survey_drawings',
                onPick: () => _pickFiles(_surveyDrawingFiles),
              ),
              const SizedBox(height: 14),
              _filePickerSection(
                label: 'Title Surveys',
                files: _titleSurveyFiles,
                existing: _existingTitleSurveys,
                type: 'title_surveys',
                onPick: () => _pickFiles(_titleSurveyFiles),
              ),
            ],
          ),
          _sectionCard(
            title: 'FSI Details',
            icon: Icons.bar_chart_outlined,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: _textField(_fsiAvailableCtrl,
                      label: 'FSI Available',
                      hint: '0.00',
                      type: const TextInputType.numberWithOptions(
                          decimal: true)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _textField(_fsiCommentCtrl,
                      label: 'FSI Comment',
                      hint: 'Comment',
                      maxLines: 2),
                ),
              ]),
            ],
          ),
          _sectionCard(
            title: 'Existing Information',
            icon: Icons.info_outline,
            children: [
              _fieldLabel('Existing Info'),
              Row(children: [
                Expanded(
                  child: RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Regular',
                        style: TextStyle(fontSize: 13)),
                    value: 'regular',
                    groupValue: _existingInfo,
                    activeColor: AppColors.primaryGreen,
                    onChanged: (v) =>
                        setState(() => _existingInfo = v!),
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Redevelopment',
                        style: TextStyle(fontSize: 13)),
                    value: 'redevelopment',
                    groupValue: _existingInfo,
                    activeColor: AppColors.primaryGreen,
                    onChanged: (v) =>
                        setState(() => _existingInfo = v!),
                  ),
                ),
              ]),
              if (_existingInfo == 'redevelopment') ...[
                const SizedBox(height: 12),
                _textField(_totalMembersCtrl,
                    label: 'Total Members',
                    hint: 'Enter total members',
                    type: TextInputType.number),
              ],
            ],
          ),
          _sectionCard(
            title: 'Unit Types',
            icon: Icons.apartment_outlined,
            children: [_unitTypesSection()],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : const Text('Save Project Information',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _AssignDialog
// ═══════════════════════════════════════════════════════════════════════════

class _AssignDialog extends StatefulWidget {
  final ProcessListItemModel process;
  final int projectId;
  final int? teamId;
  final String? teamName;
  final String? teamColor;
  final Future<void> Function() onAssigned;

  const _AssignDialog({
    required this.process,
    required this.projectId,
    required this.teamId,
    required this.teamName,
    required this.teamColor,
    required this.onAssigned,
  });

  @override
  State<_AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends State<_AssignDialog> {
  List<TeamMemberModel> _members = [];
  bool _loadingMembers = false;
  String? _membersError;
  TeamMemberModel? _selectedMember;
  DateTime? _selectedDeadline;
  bool _isNotApplicable = false;
  bool _isSaving = false;
  final _deadlineCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.teamId != null && widget.teamId! > 0) {
      _fetchMembers(widget.teamId!);
    }
  }

  @override
  void dispose() {
    _deadlineCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchMembers(int teamId) async {
    if (!mounted) return;
    setState(() {
      _loadingMembers = true;
      _membersError = null;
      _members = [];
      _selectedMember = null;
    });
    try {
      final members = await ApiService.fetchTeamMembersForAssign(teamId,
          excludeLeaders: true);
      if (!mounted) return;
      setState(() {
        _members = members;
        _loadingMembers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _membersError =
            e is ApiException ? e.message : 'Failed to load members';
        _loadingMembers = false;
      });
    }
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline ??
          DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme:
                ColorScheme.light(primary: AppColors.primaryGreen)),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDeadline = picked;
        _deadlineCtrl.text =
            '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      });
    }
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (!_isNotApplicable && _selectedMember == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select a team member'),
          backgroundColor: Color(0xFFEF4444)));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final token = await AuthStorageService.getToken();
      if (token == null || token.isEmpty) throw Exception('Session expired.');
      final url = Uri.parse(
          '${ApiConstants.baseUrl}/api/mobile/process-tasks/assign');
      final body = <String, dynamic>{
        'project_id': widget.projectId,
        'process_id': widget.process.processId,
      };
      if (_isNotApplicable) {
        body['not_applicable'] = '1';
      } else {
        body['assign_user'] = _selectedMember!.id;
        if (_selectedDeadline != null) {
          body['deadline'] =
              '${_selectedDeadline!.year}-${_selectedDeadline!.month.toString().padLeft(2, '0')}-${_selectedDeadline!.day.toString().padLeft(2, '0')}';
        }
      }
      final response = await http
          .post(url,
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode(body))
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isNotApplicable
              ? 'Marked as Not Applicable'
              : 'Assigned to ${_selectedMember!.name}'),
          backgroundColor: AppColors.primaryGreen,
        ));
        await widget.onAssigned();
      } else {
        dynamic decoded;
        try {
          decoded = jsonDecode(response.body);
        } catch (_) {
          decoded = {'message': response.body};
        }
        final msg =
            (decoded is Map ? decoded['message']?.toString() : null) ??
                'Failed to assign (${response.statusCode})';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(msg),
              backgroundColor: const Color(0xFFEF4444)));
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFEF4444)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Color _pillColor() {
    final tc = widget.teamColor;
    if (tc != null && tc.isNotEmpty) {
      try {
        final hex = tc.replaceAll('#', '');
        if (hex.length == 6) return Color(int.parse('FF$hex', radix: 16));
        if (hex.length == 8) return Color(int.parse(hex, radix: 16));
      } catch (_) {}
    }
    final n = widget.teamName?.toLowerCase() ?? '';
    if (n.contains('legal')) return const Color(0xFF22C55E);
    if (n.contains('liaison') || n.contains('liasoning')) {
      return const Color(0xFFEF4444);
    }
    if (n.contains('construction')) return const Color(0xFFF59E0B);
    const colors = [
      Color(0xFF3B82F6),
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
      Color(0xFF14B8A6),
      Color(0xFFF97316)
    ];
    return colors[(widget.teamName ?? '').hashCode.abs() % colors.length];
  }

  Widget _teamPill() {
    if (widget.teamName == null || widget.teamName!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: _pillColor(), borderRadius: BorderRadius.circular(20)),
      child: Text(widget.teamName!.toUpperCase(),
          style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4)),
    );
  }

  Widget _memberDropdown() {
    if (_loadingMembers) {
      return _stateShell(
          color: const Color(0xFFD1FAE5),
          child: Row(children: [
            SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primaryGreen)),
            const SizedBox(width: 12),
            const Expanded(
                child: Text('Loading team members…',
                    style: TextStyle(
                        fontSize: 14, color: Color(0xFF6B7280)))),
          ]));
    }
    if (_membersError != null) {
      return _stateShell(
          color: const Color(0xFFFFE4E6),
          borderColor: const Color(0xFFEF4444),
          child: Row(children: [
            const Icon(Icons.error_outline,
                size: 16, color: Color(0xFFEF4444)),
            const SizedBox(width: 8),
            Expanded(
                child: Text(_membersError!,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFFEF4444)))),
            GestureDetector(
              onTap: () {
                if (widget.teamId != null && widget.teamId! > 0) {
                  _fetchMembers(widget.teamId!);
                }
              },
              child: const Text('Retry',
                  style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF3B82F6),
                      fontWeight: FontWeight.w600)),
            ),
          ]));
    }
    if (widget.teamId == null || widget.teamId! <= 0) {
      return _stateShell(
          color: const Color(0xFFF9FAFB),
          child: const Row(children: [
            Icon(Icons.group_off_outlined,
                size: 16, color: Color(0xFF9CA3AF)),
            SizedBox(width: 8),
            Text('No team assigned to this process',
                style: TextStyle(
                    fontSize: 14, color: Color(0xFF9CA3AF))),
          ]));
    }
    if (_members.isEmpty) {
      return _stateShell(
          color: const Color(0xFFF9FAFB),
          child: const Row(children: [
            Icon(Icons.person_off_outlined,
                size: 16, color: Color(0xFF9CA3AF)),
            SizedBox(width: 8),
            Expanded(
                child: Text('No assignable team members found',
                    style: TextStyle(
                        fontSize: 14, color: Color(0xFF9CA3AF)))),
          ]));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(
            color: _isNotApplicable
                ? const Color(0xFFD1D5DB)
                : AppColors.primaryGreen,
            width: 1.5),
        borderRadius: BorderRadius.circular(8),
        color:
            _isNotApplicable ? const Color(0xFFF9FAFB) : Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<TeamMemberModel>(
          isExpanded: true,
          value: _selectedMember,
          hint: Text('Select a team member',
              style: TextStyle(
                  fontSize: 14,
                  color: _isNotApplicable
                      ? const Color(0xFFD1D5DB)
                      : const Color(0xFF374151))),
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: _isNotApplicable
                  ? const Color(0xFFD1D5DB)
                  : AppColors.primaryGreen),
          items: _isNotApplicable
              ? null
              : _members.map((m) {
                  return DropdownMenuItem<TeamMemberModel>(
                    value: m,
                    child: Row(children: [
                      const Icon(Icons.person_outline_rounded,
                          size: 16, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(m.name,
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF1E293B),
                                  fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis)),
                    ]),
                  );
                }).toList(),
          onChanged: _isNotApplicable
              ? null
              : (v) => setState(() => _selectedMember = v),
        ),
      ),
    );
  }

  Widget _stateShell(
          {required Color color,
          Color? borderColor,
          required Widget child}) =>
      Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(
              color: borderColor ?? const Color(0xFFE5E7EB),
              width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20))),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
              const Text('Assign Process',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(widget.process.processName,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ])),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(4),
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const Text('Deadline Date',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151))),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _isNotApplicable ? null : _pickDeadline,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 13),
                  decoration: BoxDecoration(
                      border: Border.all(
                          color: const Color(0xFFD1D5DB)),
                      borderRadius: BorderRadius.circular(8),
                      color: _isNotApplicable
                          ? const Color(0xFFF9FAFB)
                          : Colors.white),
                  child: Row(children: [
                    Expanded(
                        child: Text(
                      _deadlineCtrl.text.isEmpty
                          ? 'dd/mm/yyyy'
                          : _deadlineCtrl.text,
                      style: TextStyle(
                          fontSize: 14,
                          color: _deadlineCtrl.text.isEmpty
                              ? const Color(0xFF9CA3AF)
                              : const Color(0xFF1E293B)),
                    )),
                    Icon(Icons.calendar_today_outlined,
                        size: 18,
                        color: _isNotApplicable
                            ? const Color(0xFFD1D5DB)
                            : const Color(0xFF6B7280)),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                const Text('Assign To',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151))),
                if (_members.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                        color: AppColors.primaryGreen
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(
                        '${_members.length} member${_members.length == 1 ? '' : 's'}',
                        style: TextStyle(
                            fontSize: 10,
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ]),
              const SizedBox(height: 8),
              _memberDropdown(),
              const SizedBox(height: 16),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _isNotApplicable,
                    onChanged: (v) => setState(() {
                      _isNotApplicable = v ?? false;
                      if (_isNotApplicable) _selectedMember = null;
                    }),
                    activeColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                  Text('Not Applicable',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF374151))),
                  SizedBox(height: 2),
                  Text(
                      'Check this if this process is not applicable for this project.',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9CA3AF))),
                ])),
              ]),
              const SizedBox(height: 16),
              if (widget.teamName != null &&
                  widget.teamName!.isNotEmpty) ...[
                Row(children: [
                  const Text('Working team: ',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280))),
                  _teamPill(),
                ]),
                const SizedBox(height: 16),
              ],
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed:
                    _isSaving ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF374151),
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    padding:
                        const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
                child: const Text('Cancel',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: 13),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Assign',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _UploadDialog
// ═══════════════════════════════════════════════════════════════════════════

class _UploadDialog extends StatefulWidget {
  final ProcessListItemModel process;
  final int projectId;
  final int currentUserId;
  final Future<void> Function() onUploaded;
 
  const _UploadDialog({
    required this.process,
    required this.projectId,
    required this.currentUserId,
    required this.onUploaded,
  });
 
  @override
  State<_UploadDialog> createState() => _UploadDialogState();
}
 
class _UploadDialogState extends State<_UploadDialog> {
  String _uploadType = 'drive_link';
  final _driveLinkCtrl = TextEditingController();
  DateTime _uploadedDate = DateTime.now();
  bool _isSaving = false;
  PlatformFile? _pickedFile;
  bool _isPickingFile = false;
 
  @override
  void dispose() {
    _driveLinkCtrl.dispose();
    super.dispose();
  }
 
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _uploadedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.light(primary: AppColors.primaryGreen)),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _uploadedDate = picked);
  }
 
  Future<void> _pickFile() async {
    if (_isPickingFile) return;
    setState(() => _isPickingFile = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'xls', 'xlsx'],
        withData: false,
      );
      if (!mounted) return;
      if (result != null && result.files.isNotEmpty) {
        setState(() => _pickedFile = result.files.first);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not open file picker: $e'),
          backgroundColor: const Color(0xFFEF4444)));
    } finally {
      if (mounted) setState(() => _isPickingFile = false);
    }
  }
 
  String get _formattedDate =>
      '${_uploadedDate.day.toString().padLeft(2, '0')}/${_uploadedDate.month.toString().padLeft(2, '0')}/${_uploadedDate.year}';
 
  String get _isoDate =>
      '${_uploadedDate.year}-${_uploadedDate.month.toString().padLeft(2, '0')}-${_uploadedDate.day.toString().padLeft(2, '0')}';
 
  // ── Submit ──────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_isSaving) return;
 
    if (_uploadType == 'drive_link' && _driveLinkCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please enter a Google Drive link'),
          backgroundColor: Color(0xFFEF4444)));
      return;
    }
    if (_uploadType == 'file' && _pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select a file to upload'),
          backgroundColor: Color(0xFFEF4444)));
      return;
    }
 
    setState(() => _isSaving = true);
 
    try {
      final token = await AuthStorageService.getToken();
      if (token == null || token.isEmpty) throw Exception('Session expired.');
 
      // ── Mobile upload endpoint (/api/mobile/process-tasks/upload) ─────
      final uploadUrl = '${ApiConstants.baseUrl}/api/mobile/process-tasks/upload';
 
      http.Response response;
 
      if (_uploadType == 'drive_link') {
        response = await http
            .post(
              Uri.parse(uploadUrl),
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({
                'project_id':    widget.projectId,
                'process_id':    widget.process.processId,
                'upload_type':   'drive_link',
                'uploaded_date': _isoDate,
                'drive_link':    _driveLinkCtrl.text.trim(),
              }),
            )
            .timeout(const Duration(seconds: 30));
      } else {
        final filePath = _pickedFile!.path;
        if (filePath == null) throw Exception('File path is null');
 
        final mimeType  = lookupMimeType(filePath) ?? 'application/octet-stream';
        final mimeParts = mimeType.split('/');
 
        final request = http.MultipartRequest('POST', Uri.parse(uploadUrl))
          ..headers['Authorization'] = 'Bearer $token'
          ..headers['Accept'] = 'application/json'
          ..fields['project_id']    = widget.projectId.toString()
          ..fields['process_id']    = widget.process.processId.toString()
          ..fields['upload_type']   = 'file'
          ..fields['uploaded_date'] = _isoDate
          ..files.add(await http.MultipartFile.fromPath(
            'file',
            filePath,
            contentType: MediaType(mimeParts[0], mimeParts[1]),
          ));
 
        final streamed = await request.send().timeout(const Duration(seconds: 60));
        response = await http.Response.fromStream(streamed);
      }
 
      if (!mounted) return;
      await _handleResponse(response);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFEF4444)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
 
  Future<void> _handleResponse(http.Response response) async {
    dynamic decoded;
    try { decoded = jsonDecode(response.body); } catch (_) { decoded = {}; }
 
    final success = (response.statusCode >= 200 && response.statusCode < 300) &&
        (decoded is Map ? (decoded['status'] == true || decoded['success'] == true) : true);
 
    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_uploadType == 'drive_link'
            ? 'Drive link saved. The team leader has been notified.'
            : 'File uploaded. The team leader has been notified.'),
        backgroundColor: AppColors.primaryGreen,
        duration: const Duration(seconds: 4),
      ));
      await widget.onUploaded();
    } else {
      final msg = (decoded is Map ? decoded['message']?.toString() : null) ??
          'Upload failed (${response.statusCode})';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg), backgroundColor: const Color(0xFFEF4444)));
    }
  }
 
  // ── Helpers ─────────────────────────────────────────────────────────────
  IconData _fileIcon(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'pdf':  return Icons.picture_as_pdf_outlined;
      case 'doc':
      case 'docx': return Icons.description_outlined;
      case 'xls':
      case 'xlsx': return Icons.table_chart_outlined;
      case 'jpg':
      case 'jpeg':
      case 'png':  return Icons.image_outlined;
      default:     return Icons.insert_drive_file_outlined;
    }
  }
 
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
 
  Widget _typeChip({
    required String label,
    required IconData icon,
    required String value,
  }) {
    final selected = _uploadType == value;
    return GestureDetector(
      onTap: () => setState(() {
        _uploadType = value;
        if (value == 'drive_link') _pickedFile = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color:  selected ? AppColors.primaryGreen : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? AppColors.primaryGreen : const Color(0xFFE2E8F0)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14,
              color: selected ? Colors.white : const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFF374151))),
        ]),
      ),
    );
  }
 
  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // ── Header ────────────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Row(children: [
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.process.hasFile ? 'Reupload Document' : 'Upload Document',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(widget.process.processName,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ]),
        ),
 
        // ── Body ──────────────────────────────────────────────────────────
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
 
              // Info banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE))),
                child: const Row(children: [
                  Icon(Icons.info_outline, size: 15, color: Color(0xFF2563EB)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'After upload, your team leader will be notified automatically.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF1D4ED8)),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
 
              // Upload type chips
              const Text('Upload Type',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
              const SizedBox(height: 8),
              Row(children: [
                _typeChip(label: 'Drive Link', icon: Icons.link_rounded,       value: 'drive_link'),
                const SizedBox(width: 10),
                _typeChip(label: 'Upload File', icon: Icons.upload_file_outlined, value: 'file'),
              ]),
              const SizedBox(height: 16),
 
              // Drive link field
              if (_uploadType == 'drive_link') ...[
                const Text('Google Drive Link',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                const SizedBox(height: 6),
                TextField(
                  controller: _driveLinkCtrl,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    hintText: 'https://drive.google.com/file/d/...',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.primaryGreen, width: 1.5)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    prefixIcon: const Icon(Icons.link_rounded, size: 18, color: Color(0xFF94A3B8)),
                  ),
                  style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                ),
              ] else ...[
                // File picker
                const Text('Select File',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _isPickingFile ? null : _pickFile,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: _pickedFile != null
                              ? AppColors.primaryGreen
                              : AppColors.primaryGreen.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(8),
                      color: _pickedFile != null
                          ? AppColors.primaryGreen.withValues(alpha: 0.06)
                          : AppColors.primaryGreen.withValues(alpha: 0.04),
                    ),
                    child: _isPickingFile
                        ? Center(
                            child: SizedBox(
                                width: 24, height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.primaryGreen)))
                        : _pickedFile != null
                            ? Row(children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      color: AppColors.primaryGreen.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6)),
                                  child: Icon(_fileIcon(_pickedFile!.extension),
                                      color: AppColors.primaryGreen, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                  Text(_pickedFile!.name,
                                      style: const TextStyle(
                                          fontSize: 13, fontWeight: FontWeight.w600,
                                          color: Color(0xFF1E293B)),
                                      overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 2),
                                  Text(_formatFileSize(_pickedFile!.size),
                                      style: const TextStyle(
                                          fontSize: 11, color: Color(0xFF94A3B8))),
                                ])),
                                GestureDetector(
                                  onTap: () => setState(() => _pickedFile = null),
                                  child: const Icon(Icons.close, size: 18, color: Color(0xFF94A3B8)),
                                ),
                              ])
                            : Column(children: [
                                Icon(Icons.cloud_upload_outlined,
                                    size: 36, color: AppColors.primaryGreen),
                                const SizedBox(height: 8),
                                Text('Tap to select file',
                                    style: TextStyle(
                                        color: AppColors.primaryGreen,
                                        fontWeight: FontWeight.w600, fontSize: 13)),
                                const SizedBox(height: 4),
                                const Text('PDF, DOC, DOCX, XLS, XLSX, JPG, PNG',
                                    style: TextStyle(color: Color(0xFF94A3AF), fontSize: 11)),
                              ]),
                  ),
                ),
              ],
 
              const SizedBox(height: 16),
 
              // Date picker
              const Text('Upload Date',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                  decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFD1D5DB)),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white),
                  child: Row(children: [
                    Expanded(
                        child: Text(_formattedDate,
                            style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)))),
                    const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF6B7280)),
                  ]),
                ),
              ),
              const SizedBox(height: 20),
            ]),
          ),
        ),
 
        // ── Footer buttons ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF374151),
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: const Text('Cancel',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _submit,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.upload_rounded, size: 16),
                label: Text(_isSaving ? 'Uploading…' : 'Submit',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _EmailDialog
// ═══════════════════════════════════════════════════════════════════════════

class _EmailDialog extends StatefulWidget {
  final ProcessListItemModel process;
  final int projectId;

  const _EmailDialog(
      {required this.process, required this.projectId});

  @override
  State<_EmailDialog> createState() => _EmailDialogState();
}

class _EmailDialogState extends State<_EmailDialog> {
  final _noteCtrl = TextEditingController();
  final Set<String> _selectedRecipients = {};
  bool _isSending = false;

  static const _recipientOptions = [
    {'value': 'team_leader', 'label': 'Team Leader'},
    {'value': 'society', 'label': 'Society'},
    {'value': 'review_team', 'label': 'Review Team'},
    {'value': 'uploaded_person', 'label': 'Uploaded Person'},
  ];

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
  if (_isSending) return;

  if (_selectedRecipients.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Please select at least one recipient'),
      backgroundColor: Color(0xFFEF4444),
    ));
    return;
  }

  if (widget.process.filePath == null || widget.process.filePath!.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('No file uploaded for this process yet'),
      backgroundColor: Color(0xFFEF4444),
    ));
    return;
  }

  setState(() => _isSending = true);

  try {
    final token = await AuthStorageService.getToken();
    if (token == null || token.isEmpty) throw Exception('Session expired.');

    final url = Uri.parse('${ApiConstants.baseUrl}/send-email');

    final response = await http
        .post(
          url,
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'project_id': widget.projectId,
            'process_id': widget.process.processId,
            'file_path': widget.process.filePath,
            'recipients': _selectedRecipients.toList(),
            'note': _noteCtrl.text.trim(),
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (!mounted) return;

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = {'message': response.body};
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final success = decoded is Map ? (decoded['success'] == true) : true;

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          (decoded is Map ? decoded['text']?.toString() : null) ??
              (success ? 'Email sent successfully' : 'Email failed'),
        ),
        backgroundColor:
            success ? AppColors.primaryGreen : const Color(0xFFEF4444),
      ));
    } else {
      final msg =
          (decoded is Map ? decoded['text']?.toString() : null) ??
              (decoded is Map ? decoded['message']?.toString() : null) ??
              'Failed to send email (${response.statusCode})';

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFEF4444),
      ));
    }
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Error: $e'),
      backgroundColor: const Color(0xFFEF4444),
    ));
  } finally {
    if (mounted) setState(() => _isSending = false);
  }
}

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20))),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
              const Text('Send Mail',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(widget.process.processName,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ])),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
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
              if (widget.process.filePath != null &&
                  widget.process.filePath!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFFBBF7D0))),
                  child: Row(children: [
                    const Icon(Icons.insert_drive_file_outlined,
                        size: 16, color: Color(0xFF22C55E)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(widget.process.filePath!,
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF166534)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis)),
                  ]),
                ),
                const SizedBox(height: 16),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFFFED7AA))),
                  child: const Row(children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 16, color: Color(0xFFF97316)),
                    SizedBox(width: 8),
                    Expanded(
                        child: Text(
                            'No file uploaded yet.',
                            style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF9A3412)))),
                  ]),
                ),
                const SizedBox(height: 16),
              ],
              const Text('Recipients',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151))),
              const SizedBox(height: 4),
              const Text('Select who should receive this email',
                  style: TextStyle(
                      fontSize: 11, color: Color(0xFF9CA3AF))),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _recipientOptions.map((opt) {
                  final val = opt['value']!;
                  final selected =
                      _selectedRecipients.contains(val);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (selected) {
                        _selectedRecipients.remove(val);
                      } else {
                        _selectedRecipients.add(val);
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: selected
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                        Icon(
                            selected
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked,
                            size: 14,
                            color: selected
                                ? Colors.white
                                : const Color(0xFF94A3B8)),
                        const SizedBox(width: 6),
                        Text(opt['label']!,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF374151))),
                      ]),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('Note (optional)',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151))),
              const SizedBox(height: 6),
              TextField(
                controller: _noteCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Add an optional note…',
                  hintStyle: const TextStyle(
                      fontSize: 13, color: Color(0xFFCBD5E1)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: Color(0xFF1E293B), width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 20),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed:
                    _isSending ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF374151),
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    padding:
                        const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
                child: const Text('Cancel',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isSending ? null : _send,
                icon: _isSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 16),
                label: Text(_isSending ? 'Sending…' : 'Send',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: 13),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
