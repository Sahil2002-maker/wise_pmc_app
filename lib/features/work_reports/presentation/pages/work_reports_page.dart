// lib/features/work_reports/presentation/pages/work_reports_page.dart

import 'package:flutter/material.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/auth_storage_service.dart';
import '../../data/models/work_report_calendar_event.dart';
import '../widgets/work_report_calendar_grid.dart';
import '../widgets/work_report_stats_card.dart';
import 'work_report_detail_page.dart';

class WorkReportsPage extends StatefulWidget {
  const WorkReportsPage({super.key});

  @override
  State<WorkReportsPage> createState() => _WorkReportsPageState();
}

class _WorkReportsPageState extends State<WorkReportsPage> {
  bool isLoading    = false;
  bool loadingUsers = false;
  String? errorMessage;

  List<WorkReportCalendarEvent> events = [];
  List<WorkReportUser>          users  = [];

  int?   selectedUserId;
  String selectedUserName = '';
  String currentUserRole  = 'employee';
  int    currentUserId    = 0;
  DateTime currentMonth   = DateTime.now();

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery        = '';
  String _selectedRoleFilter = 'all';
  bool   _selectorExpanded   = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    int? id; String? name; String? role;
    try {
      id   = await AuthStorageService.getUserId();
      name = await AuthStorageService.getUserName();
      role = await AuthStorageService.getUserRole();
    } catch (e) { debugPrint('[WorkReports] auth error: $e'); }

    if (!mounted) return;
    setState(() {
      currentUserId    = id ?? 0;
      selectedUserId   = id ?? 0;
      selectedUserName = name ?? 'Me';
      currentUserRole  = role ?? 'employee';
    });

    if (_canSeeDropdown) await _loadUsers();
    await _loadCalendarData();
  }

  bool get _canSeeDropdown =>
      currentUserRole == 'admin' || currentUserRole == 'teamleader';
  bool get _isAdmin => currentUserRole == 'admin';

  List<WorkReportUser> get _filteredUsers {
    final q = _searchQuery.toLowerCase();
    return users.where((u) {
      final matchSearch = q.isEmpty ||
          u.name.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          u.teamName.toLowerCase().contains(q) ||
          u.role.toLowerCase().contains(q);
      final matchRole = _selectedRoleFilter == 'all' ||
          u.role.toLowerCase() == _selectedRoleFilter;
      return matchSearch && matchRole;
    }).toList();
  }

  List<String> get _availableRoles {
    final roles = users.map((u) => u.role.toLowerCase()).toSet().toList()..sort();
    return roles;
  }

  Future<void> _loadUsers() async {
    setState(() => loadingUsers = true);
    try {
      final result = await ApiService.fetchWorkReportUsers();
      if (!mounted) return;
      setState(() {
        users        = result;
        loadingUsers = false;
        if (users.isNotEmpty && !users.any((u) => u.id == selectedUserId)) {
          final self = users.cast<WorkReportUser?>()
              .firstWhere((u) => u!.id == currentUserId, orElse: () => null);
          if (self != null) {
            selectedUserId   = self.id;
            selectedUserName = self.name;
          }
        }
      });
    } catch (e) {
      debugPrint('[WorkReports] _loadUsers error: $e');
      if (!mounted) return;
      setState(() => loadingUsers = false);
    }
  }

  Future<void> _loadCalendarData() async {
    if (selectedUserId == null || selectedUserId == 0) {
      setState(() {
        errorMessage = 'User not logged in. Please log out and log in again.';
        isLoading    = false;
      });
      return;
    }
    setState(() { isLoading = true; errorMessage = null; });
    try {
      final start = DateTime(currentMonth.year, currentMonth.month, 1);
      final end   = DateTime(currentMonth.year, currentMonth.month + 1, 0);
      final result = await ApiService.fetchWorkReportCalendar(
        userId: selectedUserId!, startDate: _fmt(start), endDate: _fmt(end),
      );
      if (!mounted) return;
      setState(() { events = result; isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString().replaceAll('Exception: ', '');
        isLoading    = false;
      });
    }
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _selectUser(WorkReportUser user) {
    FocusScope.of(context).unfocus();
    setState(() {
      selectedUserId    = user.id;
      selectedUserName  = user.name;
      _selectorExpanded = false;
    });
    _loadCalendarData();
  }

  void _onMonthChanged(DateTime month) {
    setState(() => currentMonth = month);
    _loadCalendarData();
  }

  void _onEventTapped(WorkReportCalendarEvent event) {
    final props = event.extendedProps;
    if (props.isAbsentNoCheckin) {
      _showSnack(
        'Absent${props.leaveTypeName != null ? ' (${props.leaveTypeName})' : ''}'
        ' — no check-in, cannot add work report.',
      );
      return;
    }
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => WorkReportDetailPage(
        event: event, currentUserId: currentUserId,
        currentUserRole: currentUserRole, onSaved: _loadCalendarData,
      ),
    ));
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.blueGrey.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  int get _submittedCount =>
      events.where((e) => e.extendedProps.hasWorkReport).length;
  int get _pendingCount =>
      events.where((e) => e.extendedProps.canAddReport && !e.extendedProps.hasWorkReport).length;

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':      return const Color(0xFFDC3545);
      case 'hr':         return const Color(0xFF4ECDC4);
      case 'teamleader': return const Color(0xFF45B7D1);
      case 'office_boy': return const Color(0xFFFF9F43);
      default:           return const Color(0xFF28C76F);
    }
  }

  IconData _roleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'admin':      return Icons.admin_panel_settings_rounded;
      case 'hr':         return Icons.people_alt_rounded;
      case 'teamleader': return Icons.manage_accounts_rounded;
      case 'office_boy': return Icons.cleaning_services_rounded;
      default:           return Icons.person_rounded;
    }
  }

  String _roleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'admin':      return 'Admin';
      case 'hr':         return 'HR';
      case 'teamleader': return 'Team Leader';
      case 'office_boy': return 'Office Boy';
      default:
        return role.isEmpty ? role : role[0].toUpperCase() + role.substring(1);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    // KEY FIX: resizeToAvoidBottomInset: false prevents the scaffold from
    // shrinking when the keyboard appears, eliminating the yellow overflow line.
    // The keyboard will overlay the content instead of squeezing it.
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Daily Work Reports',
            style: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2D6A4F)),
            onPressed: _loadCalendarData, tooltip: 'Refresh',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE8ECF0), height: 1),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top panel ─────────────────────────────────────────────────
            // Wrapped in SingleChildScrollView so that when the selector
            // expands AND the keyboard is open, this section scrolls instead
            // of overflowing.
            Material(
              color: Colors.white,
              child: AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                child: ConstrainedBox(
                  // Never let the top panel grow beyond 60% of screen height
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.60,
                  ),
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_canSeeDropdown) ...[
                            _buildUserSelectorSection(),
                            const SizedBox(height: 10),
                          ] else
                            _buildSelfInfo(),
                          _buildStatsRow(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),
            _buildLegend(),
            const SizedBox(height: 8),

            // ── Calendar takes ALL remaining space exactly ─────────────
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF2D6A4F)))
                  : errorMessage != null
                      ? _buildError()
                      : WorkReportCalendarGrid(
                          events: events,
                          currentMonth: currentMonth,
                          onMonthChanged: _onMonthChanged,
                          onEventTapped: _onEventTapped,
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: WorkReportStatsCard(label: 'Submitted', count: _submittedCount, color: const Color(0xFF28C76F), icon: Icons.check_circle_outline_rounded)),
        const SizedBox(width: 10),
        Expanded(child: WorkReportStatsCard(label: 'Pending',   count: _pendingCount,   color: const Color(0xFFFF9F43), icon: Icons.pending_actions_rounded)),
        const SizedBox(width: 10),
        Expanded(child: WorkReportStatsCard(label: 'Total Days', count: events.length,  color: const Color(0xFF7367F0), icon: Icons.calendar_month_rounded)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // USER SELECTOR
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildUserSelectorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            _isAdmin ? 'SELECT USER TO VIEW (ADMIN ACCESS)' : 'SELECT USER TO VIEW (TEAM LEADER)',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                color: Color(0xFF888888), letterSpacing: 0.8),
          ),
        ),
        GestureDetector(
          onTap: () => setState(() => _selectorExpanded = !_selectorExpanded),
          child: _buildSelectedUserPill(),
        ),
        // ClipRect prevents animation from overflowing during transition
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: _selectorExpanded ? _buildExpandedSelector() : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedUserPill() {
    final selectedUser = users.isEmpty
        ? null
        : users.cast<WorkReportUser?>()
            .firstWhere((u) => u!.id == selectedUserId, orElse: () => null);
    final roleStr = selectedUser?.role ?? currentUserRole;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _isAdmin ? const Color(0xFFFFD700).withOpacity(0.7) : const Color(0xFF45B7D1).withOpacity(0.6),
          width: 1.2,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: _roleColor(roleStr).withOpacity(0.15), shape: BoxShape.circle),
          child: Icon(_roleIcon(roleStr), size: 16, color: _roleColor(roleStr)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(selectedUser?.name ?? selectedUserName,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1A1A2E)),
                overflow: TextOverflow.ellipsis),
            Text(
              selectedUser?.teamName != null && selectedUser!.teamName != 'No Team'
                  ? '${_roleLabel(roleStr)} · ${selectedUser.teamName}'
                  : _roleLabel(roleStr),
              style: const TextStyle(color: Color(0xFF888888), fontSize: 11),
            ),
          ]),
        ),
        if (users.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: (_isAdmin ? const Color(0xFF856404) : const Color(0xFF45B7D1)).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${users.length} ${_isAdmin ? 'users' : 'members'}',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                    color: _isAdmin ? const Color(0xFF856404) : const Color(0xFF45B7D1))),
          ),
          const SizedBox(width: 6),
        ],
        AnimatedRotation(
          turns: _selectorExpanded ? 0.5 : 0,
          duration: const Duration(milliseconds: 220),
          child: Icon(Icons.keyboard_arrow_down_rounded,
              color: _isAdmin ? const Color(0xFF856404) : const Color(0xFF45B7D1), size: 22),
        ),
      ]),
    );
  }

  Widget _buildExpandedSelector() {
    final filtered = _filteredUsers;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              // Dismiss keyboard on submit so it doesn't push layout
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
              decoration: InputDecoration(
                hintText: 'Search by name, email or team…',
                hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF888888), size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF888888), size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          FocusScope.of(context).unfocus();
                        },
                      )
                    : null,
                filled: true, fillColor: const Color(0xFFF8F9FA),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ),

          // Role filter chips
          if (_availableRoles.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: SizedBox(
                height: 30,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _filterChip('all', 'All', Icons.people_rounded),
                    ..._availableRoles.map((r) => _filterChip(r, _roleLabel(r), _roleIcon(r))),
                  ],
                ),
              ),
            ),

          const Divider(height: 1, color: Color(0xFFEEEEEE)),

          // User list — strictly constrained so it never overflows
          if (loadingUsers)
            const Padding(padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          else if (users.isEmpty)
            _emptyState(Icons.people_outline_rounded, 'No users available')
          else if (filtered.isEmpty)
            _noMatchState()
          else
            ConstrainedBox(
              // Max height = 3 items visible before scroll
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF0F0F0)),
                itemBuilder: (_, i) => _buildUserListItem(filtered[i]),
              ),
            ),

          // Footer
          if (!loadingUsers && users.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: const BoxDecoration(
                color: Color(0xFFF8F9FA),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, size: 12,
                    color: _isAdmin ? const Color(0xFF856404) : const Color(0xFF45B7D1)),
                const SizedBox(width: 4),
                Text(
                  _searchQuery.isNotEmpty || _selectedRoleFilter != 'all'
                      ? 'Showing ${filtered.length} of ${users.length} users'
                      : _isAdmin
                          ? 'All ${users.length} users · Admin Access'
                          : 'Team: ${users.length} members',
                  style: TextStyle(fontSize: 10,
                      color: _isAdmin ? const Color(0xFF856404) : const Color(0xFF45B7D1),
                      fontWeight: FontWeight.w500),
                ),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _emptyState(IconData icon, String text) => Padding(
        padding: const EdgeInsets.all(20),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.grey.shade400, size: 18), const SizedBox(width: 8),
          Text(text, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ]),
      );

  Widget _noMatchState() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_off_rounded, color: Colors.grey.shade400, size: 28),
          const SizedBox(height: 8),
          Text('No users match "$_searchQuery"',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text('Try a different name or clear the search',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () {
              _searchController.clear();
              setState(() { _searchQuery = ''; _selectedRoleFilter = 'all'; });
            },
            icon: const Icon(Icons.clear_rounded, size: 14),
            label: const Text('Clear filters', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF2D6A4F),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
          ),
        ]),
      );

  Widget _buildUserListItem(WorkReportUser user) {
    final isSelected = user.id == selectedUserId;
    final isMe       = user.id == currentUserId;
    return InkWell(
      onTap: () => _selectUser(user),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        color: isSelected ? _roleColor(user.role).withOpacity(0.06) : Colors.transparent,
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _roleColor(user.role).withOpacity(0.12), shape: BoxShape.circle,
              border: isSelected ? Border.all(color: _roleColor(user.role), width: 1.5) : null,
            ),
            child: Icon(_roleIcon(user.role), size: 17, color: _roleColor(user.role)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(user.name,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
                        color: isSelected ? _roleColor(user.role) : const Color(0xFF1A1A2E)),
                    overflow: TextOverflow.ellipsis)),
                if (isMe) ...[const SizedBox(width: 5), _badge('Me', const Color(0xFF2D6A4F))],
              ]),
              const SizedBox(height: 2),
              Row(children: [
                _badge(_roleLabel(user.role), _roleColor(user.role)),
                const SizedBox(width: 5),
                if (user.teamName != 'No Team')
                  Flexible(child: Text('· ${user.teamName}',
                      style: const TextStyle(color: Color(0xFF888888), fontSize: 10),
                      overflow: TextOverflow.ellipsis)),
              ]),
            ]),
          ),
          if (isSelected) Icon(Icons.check_circle_rounded, color: _roleColor(user.role), size: 18),
        ]),
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
        child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
      );

  Widget _filterChip(String value, String label, IconData icon) {
    final isSelected = _selectedRoleFilter == value;
    final chipColor  = value == 'all' ? const Color(0xFF2D6A4F) : _roleColor(value);
    return GestureDetector(
      onTap: () => setState(() => _selectedRoleFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : chipColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? chipColor : chipColor.withOpacity(0.3), width: isSelected ? 1.5 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: isSelected ? Colors.white : chipColor),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : chipColor)),
        ]),
      ),
    );
  }

  Widget _buildSelfInfo() => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFA5D6A7)),
        ),
        child: Row(children: [
          const Icon(Icons.person_outline_rounded, color: Color(0xFF2D6A4F), size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(selectedUserName,
              style: const TextStyle(color: Color(0xFF2D6A4F), fontWeight: FontWeight.w600, fontSize: 14))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFF2D6A4F), borderRadius: BorderRadius.circular(12)),
            child: Text(currentUserRole.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ]),
      );

  Widget _buildLegend() {
    const items = [
      _LI(color: Color(0xFF28C76F), label: 'Present + Submitted'),
      _LI(color: Color(0xFFFF9F43), label: 'Present - No Report'),
      _LI(color: Color(0xFFFFC107), label: 'Half Day'),
      _LI(color: Color(0xFF17A2B8), label: 'Incomplete Shift'),
      _LI(color: Color(0xFFDC3545), label: 'Absent'),
    ];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8ECF0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('LEGEND', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
            color: Color(0xFF888888), letterSpacing: 1)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12, runSpacing: 4,
          children: items.map((item) => Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10,
                decoration: BoxDecoration(color: item.color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 4),
            Text(item.label, style: const TextStyle(fontSize: 11, color: Color(0xFF555555))),
          ])).toList(),
        ),
      ]),
    );
  }

  Widget _buildError() {
    final isConn = errorMessage!.toLowerCase().contains('connection') ||
        errorMessage!.toLowerCase().contains('socket') ||
        errorMessage!.toLowerCase().contains('network') ||
        errorMessage!.toLowerCase().contains('timed out');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(isConn ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
              color: isConn ? Colors.orange : Colors.redAccent, size: 52),
          const SizedBox(height: 12),
          Text(isConn ? 'Cannot reach server' : 'Failed to load reports',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF1A1A2E))),
          const SizedBox(height: 8),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFFE082))),
            child: Text(errorMessage!, textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF856404), fontSize: 13)),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadCalendarData,
            icon: const Icon(Icons.refresh_rounded), label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D6A4F), foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _LI { final Color color; final String label; const _LI({required this.color, required this.label}); }