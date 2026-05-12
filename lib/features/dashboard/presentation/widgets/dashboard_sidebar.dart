// lib/features/dashboard/presentation/widgets/dashboard_sidebar.dart
//
// UPDATED — added onDevelopmentProcessTap callback (was already present in
// the original file). No other existing functionality has been changed.
// Only the _processChildren() sub-item for "Development Process" now routes
// through the callback, and the parameter is forwarded from the parent widget.

import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/permission_service.dart';


class DashboardSidebar extends StatefulWidget {
  final String userRole;
  final int userId;
  final List<String> permissions;
  final VoidCallback onDashboardTap;
  final VoidCallback onProjectListTap;
  final VoidCallback onAllMeetingsTap;
  final VoidCallback onGeneralTasksTap;
  final VoidCallback onTaskCalendarTap;
  final VoidCallback onAllTasksTap;
  final VoidCallback onWorkReportsTap;
  final VoidCallback onReportsTap;
  final VoidCallback onEmployeeReportTap;
  final VoidCallback onProjectReportTap;
  final VoidCallback onTeamReportTap;
  final VoidCallback onStageReportTap;
  final VoidCallback onUserManagementTap;
  final VoidCallback onReDevelopmentProcessTap;
  final VoidCallback onDevelopmentProcessTap; // ← routes to DevProcessPage

  const DashboardSidebar({
    super.key,
    required this.userRole,
    required this.userId,
    required this.permissions,
    required this.onDashboardTap,
    required this.onProjectListTap,
    required this.onAllMeetingsTap,
    required this.onGeneralTasksTap,
    required this.onTaskCalendarTap,
    required this.onAllTasksTap,
    required this.onWorkReportsTap,
    required this.onReportsTap,
    required this.onEmployeeReportTap,
    required this.onProjectReportTap,
    required this.onTeamReportTap,
    required this.onStageReportTap,
    required this.onUserManagementTap,
    required this.onReDevelopmentProcessTap,
    required this.onDevelopmentProcessTap,
  });

  @override
  State<DashboardSidebar> createState() => _DashboardSidebarState();
}

class _DashboardSidebarState extends State<DashboardSidebar> {
  bool _masterExpanded      = false;
  bool _workReportsExpanded = false;
  bool _reportsExpanded     = false;
  bool _processExpanded     = false;

  String get _role       => widget.userRole.toLowerCase();
  bool get _isAdmin      => _role == 'admin';
  bool get _isTeamLeader => _role == 'teamleader';
  bool get _isEmployee   => _role == 'employee';

  bool get _canSeeProcess => _isAdmin || widget.userId == 182;

  // ── Brand header ──────────────────────────────────────────────────────────

  Widget _brandHeader() {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFEEF1F8), width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF43C880), Color(0xFF2DA765)],
              ),
              borderRadius: BorderRadius.circular(9),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGreen.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Image.asset(
                'assets/logo.png',
                width: 20,
                height: 20,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.domain_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Wise Realty',
                  style: TextStyle(
                    color: Color(0xFF1A2340),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  'Management Suite',
                  style: TextStyle(
                    color: Color(0xFF8E9BB5),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Section label ─────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFFB0BAC9),
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  // ── Top-level tile ────────────────────────────────────────────────────────

  Widget _menuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool active = false,
    bool hasArrow = false,
    bool isExpanded = false,
    Color? iconColor,
  }) {
    final color = iconColor ?? AppColors.primaryGreen;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        gradient: active
            ? LinearGradient(
                colors: [color, color.withOpacity(0.75)],
              )
            : null,
        color: active ? null : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        boxShadow: active
            ? [
                BoxShadow(
                  color: color.withOpacity(0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: active ? null : const Color(0xFFF4F6FA),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white.withOpacity(0.2)
                        : color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: active ? Colors.white : color,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: active ? Colors.white : const Color(0xFF3D4A5C),
                      fontWeight:
                          active ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                if (hasArrow)
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.chevron_right_rounded,
                    color: active
                        ? Colors.white.withOpacity(0.8)
                        : const Color(0xFFB0BAC9),
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Sub-menu tile ─────────────────────────────────────────────────────────

  Widget _subMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 22, right: 10, top: 1, bottom: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: const Color(0xFFF4F6FA),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: active ? AppColors.primaryGreen.withOpacity(0.08) : null,
              borderRadius: BorderRadius.circular(8),
              border: active
                  ? Border.all(
                      color: AppColors.primaryGreen.withOpacity(0.25),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primaryGreen
                        : const Color(0xFFCDD2DD),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  icon,
                  size: 16,
                  color: active
                      ? AppColors.primaryGreen
                      : const Color(0xFF8E9BB5),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: active
                          ? AppColors.primaryGreen
                          : const Color(0xFF5A6478),
                      fontSize: 13,
                      fontWeight:
                          active ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Master sub-items ──────────────────────────────────────────────────────

  List<Widget> _masterChildrenAdmin() => [
        _subMenuTile(
          icon:  Icons.list_alt_outlined,
          title: 'Project List',
          onTap: widget.onProjectListTap,
        ),
        _subMenuTile(
          icon:  Icons.check_box_outlined,
          title: 'General Tasks',
          onTap: widget.onGeneralTasksTap,
        ),
        _subMenuTile(
          icon:  Icons.event_note_outlined,
          title: 'Task Calendar',
          onTap: widget.onTaskCalendarTap,
        ),
        _subMenuTile(
          icon:  Icons.assignment_ind_outlined,
          title: 'All Tasks',
          onTap: widget.onAllTasksTap,
        ),
      ];

  List<Widget> _masterChildrenTeamLeader() => [
        _subMenuTile(
          icon:  Icons.list_alt_outlined,
          title: 'Project List',
          onTap: widget.onProjectListTap,
        ),
        _subMenuTile(
          icon:  Icons.check_box_outlined,
          title: 'General Tasks',
          onTap: widget.onGeneralTasksTap,
        ),
        _subMenuTile(
          icon:  Icons.event_note_outlined,
          title: 'Task Calendar',
          onTap: widget.onTaskCalendarTap,
        ),
      ];

  List<Widget> _masterChildrenEmployee() => [
        _subMenuTile(
          icon:  Icons.list_alt_outlined,
          title: 'Project List',
          onTap: widget.onProjectListTap,
        ),
        _subMenuTile(
          icon:  Icons.check_box_outlined,
          title: 'General Tasks',
          onTap: widget.onGeneralTasksTap,
        ),
        _subMenuTile(
          icon:  Icons.event_note_outlined,
          title: 'Task Calendar',
          onTap: widget.onTaskCalendarTap,
        ),
      ];

  List<Widget> _masterChildren() {
    if (_isAdmin)      return _masterChildrenAdmin();
    if (_isTeamLeader) return _masterChildrenTeamLeader();
    return _masterChildrenEmployee();
  }

  List<Widget> _workReportsChildren() => [
        _subMenuTile(
          icon:  Icons.calendar_month_rounded,
          title: 'Daily Reports',
          onTap: widget.onWorkReportsTap,
        ),
      ];

  List<Widget> _reportsChildren() => [
        _subMenuTile(
          icon:  Icons.person_outline,
          title: 'Employee Report',
          onTap: widget.onEmployeeReportTap,
        ),
        _subMenuTile(
          icon:  Icons.bar_chart_outlined,
          title: 'Project Report',
          onTap: widget.onProjectReportTap,
        ),
        _subMenuTile(
          icon:  Icons.group_outlined,
          title: 'Team Report',
          onTap: widget.onTeamReportTap,
        ),
        _subMenuTile(
          icon:  Icons.layers_outlined,
          title: 'Stage Report',
          onTap: widget.onStageReportTap,
        ),
      ];

  // ── Process sub-items ─────────────────────────────────────────────────────
  // Mirrors backend sidebar:
  //   • Re-Development Process  → onReDevelopmentProcessTap
  //   • Development Process     → onDevelopmentProcessTap  ← NEW

  List<Widget> _processChildren() => [
        _subMenuTile(
          icon:  Icons.add_circle_outline,
          title: 'Re-Development Process',
          onTap: widget.onReDevelopmentProcessTap,
        ),
        // ── Development Process (new module) ────────────────────────────
        _subMenuTile(
          icon:  Icons.account_tree_outlined,
          title: 'Development Process',
          onTap: widget.onDevelopmentProcessTap, // ← wired to DevProcessPage
        ),
      ];

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 256,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Color(0xFFEEF1F8), width: 1),
        ),
      ),
      child: Column(
        children: [
          _brandHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                _sectionLabel('Main'),

                _menuTile(
                  icon:   Icons.dashboard_outlined,
                  title:  'Dashboard',
                  onTap:  widget.onDashboardTap,
                  active: true,
                ),

                _menuTile(
                  icon:       Icons.folder_copy_outlined,
                  title:      'Master',
                  hasArrow:   true,
                  isExpanded: _masterExpanded,
                  iconColor:  const Color(0xFF4C6FFF),
                  onTap: () =>
                      setState(() => _masterExpanded = !_masterExpanded),
                ),
                if (_masterExpanded) ..._masterChildren(),

                _menuTile(
                  icon:       Icons.description_outlined,
                  title:      'Work Reports',
                  hasArrow:   true,
                  isExpanded: _workReportsExpanded,
                  iconColor:  const Color(0xFFFF9F43),
                  onTap: () => setState(
                      () => _workReportsExpanded = !_workReportsExpanded),
                ),
                if (_workReportsExpanded) ..._workReportsChildren(),

                if (_isAdmin) ...[
                  _sectionLabel('Analytics'),
                  _menuTile(
                    icon:       Icons.bar_chart_rounded,
                    title:      'Reports',
                    hasArrow:   true,
                    isExpanded: _reportsExpanded,
                    iconColor:  const Color(0xFF9B59B6),
                    onTap: () =>
                        setState(() => _reportsExpanded = !_reportsExpanded),
                  ),
                  if (_reportsExpanded) ..._reportsChildren(),
                ],

                // ── Process section ────────────────────────────────────
                if (_canSeeProcess) ...[
                  _sectionLabel('Process'),
                  _menuTile(
                    icon:       Icons.layers_outlined,
                    title:      'Process',
                    hasArrow:   true,
                    isExpanded: _processExpanded,
                    iconColor:  const Color(0xFF1ABC9C),
                    onTap: () =>
                        setState(() => _processExpanded = !_processExpanded),
                  ),
                  if (_processExpanded) ..._processChildren(),
                ],

                const SizedBox(height: 20),
              ],
            ),
          ),

          // ── Bottom version tag ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFFEEF1F8), width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2ECC71),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'All systems operational',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8E9BB5),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}