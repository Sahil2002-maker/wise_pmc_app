// lib/features/work_reports/presentation/widgets/work_report_user_selector.dart

import 'package:flutter/material.dart';
import '../../data/models/work_report_calendar_event.dart';

class WorkReportUserSelector extends StatefulWidget {
  final List<WorkReportUser> users;
  final int? selectedUserId;
  final bool isLoading;
  final int currentUserId;
  final String currentUserRole;
  final ValueChanged<WorkReportUser> onUserChanged;

  const WorkReportUserSelector({
    super.key,
    required this.users,
    required this.selectedUserId,
    required this.isLoading,
    required this.currentUserId,
    required this.currentUserRole,
    required this.onUserChanged,
  });

  @override
  State<WorkReportUserSelector> createState() => _WorkReportUserSelectorState();
}

class _WorkReportUserSelectorState extends State<WorkReportUserSelector> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedRoleFilter = 'all';

  // ── Role helpers ──────────────────────────────────────────────────────────

  bool get _isAdmin => widget.currentUserRole.toLowerCase() == 'admin';
  bool get _isTeamLeader =>
      widget.currentUserRole.toLowerCase() == 'teamleader';
  bool get _isHR => widget.currentUserRole.toLowerCase() == 'hr';

  /// Roles that get the full search+filter panel
  bool get _showSearchPanel => _isAdmin || _isTeamLeader || _isHR;

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return const Color(0xFFDC3545);
      case 'hr':
        return const Color(0xFF4ECDC4);
      case 'teamleader':
        return const Color(0xFF45B7D1);
      case 'office_boy':
        return const Color(0xFFFF9F43);
      default:
        return const Color(0xFF28C76F);
    }
  }

  IconData _roleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Icons.admin_panel_settings_rounded;
      case 'hr':
        return Icons.people_alt_rounded;
      case 'teamleader':
        return Icons.manage_accounts_rounded;
      case 'office_boy':
        return Icons.cleaning_services_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  String _roleDisplayLabel(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Admin';
      case 'hr':
        return 'HR';
      case 'teamleader':
        return 'Team Leader';
      case 'office_boy':
        return 'Office Boy';
      default:
        return role.isEmpty
            ? role
            : role[0].toUpperCase() + role.substring(1);
    }
  }

  // ── Filter logic ──────────────────────────────────────────────────────────

  /// Returns distinct roles available in the user list, sorted for display.
  List<String> get _availableRoles {
    final roles = widget.users.map((u) => u.role.toLowerCase()).toSet().toList();
    roles.sort();
    return roles;
  }

  /// Filtered user list respecting search query + role filter.
  List<WorkReportUser> get _filteredUsers {
    return widget.users.where((user) {
      final matchesSearch = _searchQuery.isEmpty ||
          user.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          user.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          user.teamName.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesRole = _selectedRoleFilter == 'all' ||
          user.role.toLowerCase() == _selectedRoleFilter;
      return matchesSearch && matchesRole;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Header accent color based on role ─────────────────────────────────────

  Color get _accentColor {
    if (_isAdmin) return const Color(0xFF856404);
    if (_isTeamLeader) return const Color(0xFF45B7D1);
    if (_isHR) return const Color(0xFF4ECDC4);
    return const Color(0xFF2D6A4F);
  }

  Color get _accentBg {
    if (_isAdmin) return const Color(0xFFFFF8E1);
    if (_isTeamLeader) return const Color(0xFFE3F6FB);
    if (_isHR) return const Color(0xFFE8FAFA);
    return const Color(0xFFE8F5E9);
  }

  Color get _borderColor {
    if (_isAdmin) return const Color(0xFFFFD700).withValues(alpha: 0.6);
    if (_isTeamLeader) return const Color(0xFF45B7D1).withValues(alpha: 0.5);
    if (_isHR) return const Color(0xFF4ECDC4).withValues(alpha: 0.5);
    return const Color(0xFFE0E0E0);
  }

  String get _roleLabel {
    if (_isAdmin) return 'Admin Access';
    if (_isTeamLeader) return 'Team Leader Access';
    if (_isHR) return 'HR Access';
    return '';
  }

  IconData get _roleHeaderIcon {
    if (_isAdmin) return Icons.admin_panel_settings_rounded;
    if (_isTeamLeader) return Icons.manage_accounts_rounded;
    if (_isHR) return Icons.people_alt_rounded;
    return Icons.person_rounded;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return _buildLoadingState();
    }

    if (widget.users.isEmpty) {
      return const SizedBox.shrink();
    }

    // Employee: just show their own name, no selector needed
    if (!_showSearchPanel) {
      return _buildSelfOnlyView();
    }

    return _buildFullSelector();
  }

  // ── Loading placeholder ───────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Text('Loading users...', style: TextStyle(color: Color(0xFF888888))),
        ],
      ),
    );
  }

  // ── Employee self-only view ───────────────────────────────────────────────

  Widget _buildSelfOnlyView() {
    final self = widget.users.firstWhere(
      (u) => u.id == widget.currentUserId,
      orElse: () => widget.users.first,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF2D6A4F).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded,
                size: 16, color: Color(0xFF2D6A4F)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  self.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                Text(
                  'My Work Reports',
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF2D6A4F).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'You',
              style: TextStyle(
                color: Color(0xFF2D6A4F),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Full admin/TL/HR selector ─────────────────────────────────────────────

  Widget _buildFullSelector() {
    final filtered = _filteredUsers;
    final selectedUser = widget.users.firstWhere(
      (u) => u.id == widget.selectedUserId,
      orElse: () => widget.users.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Role badge header ────────────────────────────────────────────
        _buildRoleHeader(),
        const SizedBox(height: 10),

        // ── Search bar ───────────────────────────────────────────────────
        _buildSearchBar(),
        const SizedBox(height: 8),

        // ── Role filter chips ────────────────────────────────────────────
        _buildRoleFilterChips(),
        const SizedBox(height: 10),

        // ── Dropdown ─────────────────────────────────────────────────────
        _buildDropdown(filtered, selectedUser),
        const SizedBox(height: 6),

        // ── Viewing subtitle ─────────────────────────────────────────────
        _buildViewingSubtitle(selectedUser, filtered.length),
      ],
    );
  }

  Widget _buildRoleHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _accentBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Icon(_roleHeaderIcon, size: 15, color: _accentColor),
          const SizedBox(width: 6),
          Text(
            _roleLabel,
            style: TextStyle(
              color: _accentColor,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Text(
            '${widget.users.length} users',
            style: TextStyle(
              color: _accentColor.withValues(alpha: 0.75),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _searchQuery = v),
      style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
      decoration: InputDecoration(
        hintText: 'Search by name, email or team...',
        hintStyle:
            const TextStyle(color: Color(0xFFBBBBBB), fontSize: 13),
        prefixIcon: const Icon(Icons.search_rounded,
            color: Color(0xFF888888), size: 20),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: Color(0xFF888888), size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _accentColor, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildRoleFilterChips() {
    final roles = _availableRoles;
    if (roles.length <= 1) return const SizedBox.shrink();

    return SizedBox(
      height: 30,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _filterChip('all', 'All Roles', Icons.people_rounded),
          ...roles.map((role) => _filterChip(
                role,
                _roleDisplayLabel(role),
                _roleIcon(role),
              )),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label, IconData icon) {
    final isSelected = _selectedRoleFilter == value;
    final chipColor =
        value == 'all' ? const Color(0xFF2D6A4F) : _roleColor(value);

    return GestureDetector(
      onTap: () => setState(() => _selectedRoleFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? chipColor
              : chipColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? chipColor
                : chipColor.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 11,
              color: isSelected ? Colors.white : chipColor,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : chipColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(
      List<WorkReportUser> filtered, WorkReportUser selectedUser) {
    // If selected user is filtered out, show a message instead of dropdown
    final selectedInFiltered =
        filtered.any((u) => u.id == widget.selectedUserId);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: filtered.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.search_off_rounded,
                      color: Colors.grey.shade400, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'No users match your search',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 13),
                  ),
                ],
              ),
            )
          : DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: selectedInFiltered ? widget.selectedUserId : null,
                isExpanded: true,
                hint: Text(
                  selectedInFiltered
                      ? selectedUser.name
                      : 'Select a user...',
                  style: const TextStyle(
                      fontSize: 14, color: Color(0xFF1A1A2E)),
                ),
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _accentColor,
                ),
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF1A1A2E)),
                selectedItemBuilder: (context) {
                  return filtered.map((user) {
                    final isMe = user.id == widget.currentUserId;
                    return Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: _roleColor(user.role)
                                .withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_roleIcon(user.role),
                              size: 13, color: _roleColor(user.role)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            user.name + (isMe ? ' (Me)' : ''),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Color(0xFF1A1A2E),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Role badge in selected item
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _roleColor(user.role)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _roleDisplayLabel(user.role),
                            style: TextStyle(
                              color: _roleColor(user.role),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList();
                },
                items: filtered.map((user) {
                  final isMe = user.id == widget.currentUserId;
                  return DropdownMenuItem<int>(
                    value: user.id,
                    child: _buildDropdownItem(user, isMe),
                  );
                }).toList(),
                onChanged: (id) {
                  if (id == null) return;
                  final user =
                      filtered.firstWhere((u) => u.id == id);
                  widget.onUserChanged(user);
                },
              ),
            ),
    );
  }

  Widget _buildDropdownItem(WorkReportUser user, bool isMe) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _roleColor(user.role).withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(_roleIcon(user.role),
              size: 15, color: _roleColor(user.role)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      user.name + (isMe ? ' (Me)' : ''),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFF1A1A2E),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D6A4F)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Me',
                        style: TextStyle(
                          color: Color(0xFF2D6A4F),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 1),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: _roleColor(user.role)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _roleDisplayLabel(user.role),
                      style: TextStyle(
                        color: _roleColor(user.role),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '· ${user.teamName}',
                      style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 10,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildViewingSubtitle(
      WorkReportUser selectedUser, int filteredCount) {
    return Row(
      children: [
        Icon(
          Icons.visibility_rounded,
          size: 12,
          color: _accentColor,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            'Viewing reports for: ${selectedUser.name}',
            style: TextStyle(
              fontSize: 11,
              color: _accentColor,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (_searchQuery.isNotEmpty || _selectedRoleFilter != 'all')
          Text(
            '$filteredCount / ${widget.users.length} shown',
            style: const TextStyle(color: Color(0xFF888888), fontSize: 11),
          )
        else
          Text(
            '${widget.users.length} ${_isAdmin ? 'users' : 'members'}',
            style:
                const TextStyle(color: Color(0xFF888888), fontSize: 11),
          ),
      ],
    );
  }
}