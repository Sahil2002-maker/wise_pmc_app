// lib/features/employee_report/presentation/widgets/report_filter_sheet.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/employee_report_models.dart';

/// Modal bottom-sheet with date range, team, and employee pickers.
/// Returns a [FilterResult] via Navigator.pop when the user taps "Apply".
class ReportFilterSheet extends StatefulWidget {
  final List<ReportUser> allUsers;
  final List<ReportTeam> allTeams;
  final DateTime initialStart;
  final DateTime initialEnd;
  final String initialTeamId;
  final List<String> initialEmpIds;

  const ReportFilterSheet({
    super.key,
    required this.allUsers,
    required this.allTeams,
    required this.initialStart,
    required this.initialEnd,
    required this.initialTeamId,
    required this.initialEmpIds,
  });

  @override
  State<ReportFilterSheet> createState() => _ReportFilterSheetState();
}

class _ReportFilterSheetState extends State<ReportFilterSheet> {
  late DateTime _start;
  late DateTime _end;
  late String _teamId;
  late List<String> _empIds;

  final _fmt = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _start  = widget.initialStart;
    _end    = widget.initialEnd;
    _teamId = widget.initialTeamId;
    _empIds = List.from(widget.initialEmpIds);
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _start : _end;
    final first   = isStart ? DateTime(2020) : _start;
    final last    = isStart ? _end : DateTime.now().add(const Duration(days: 365));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primaryGreen,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
        if (_end.isBefore(_start)) _end = _start;
      } else {
        _end = picked;
      }
    });
  }

  void _toggleEmployee(String id) {
    setState(() {
      if (id == 'all') {
        _empIds = ['all'];
        return;
      }
      _empIds.remove('all');
      if (_empIds.contains(id)) {
        _empIds.remove(id);
        if (_empIds.isEmpty) _empIds = ['all'];
      } else {
        _empIds.add(id);
      }
    });
  }

  bool _isEmpSelected(String id) {
    if (id == 'all') return _empIds.contains('all');
    return !_empIds.contains('all') && _empIds.contains(id);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      height: mq.size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFFF4F6FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          _buildSheetHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                _sectionLabel('Date Range'),
                _buildDateRow(),
                const SizedBox(height: 16),
                _sectionLabel('Team'),
                _buildTeamSelector(),
                const SizedBox(height: 16),
                _sectionLabel('Employees'),
                _buildEmployeeSelector(),
                const SizedBox(height: 20),
                _buildApplyButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildSheetHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 16, 8),
      child: Row(
        children: [
          const Text('Report Filters',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B))),
          const Spacer(),
          TextButton(
            onPressed: () {
              setState(() {
                _start  = DateTime.now().subtract(const Duration(days: 6));
                _end    = DateTime.now();
                _teamId = 'all';
                _empIds = ['all'];
              });
            },
            child: const Text('Reset',
                style: TextStyle(color: AppColors.primaryGreen, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.5)),
    );
  }

  Widget _buildDateRow() {
    return Row(
      children: [
        Expanded(child: _dateCard('From', _start, isStart: true)),
        const SizedBox(width: 10),
        Expanded(child: _dateCard('To', _end, isStart: false)),
      ],
    );
  }

  Widget _dateCard(String label, DateTime date, {required bool isStart}) {
    return GestureDetector(
      onTap: () => _pickDate(isStart: isStart),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_outlined,
                size: 16, color: AppColors.primaryGreen),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(_fmt.format(date),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamSelector() {
    final teams = [
      const ReportTeam(id: -1, teamName: 'All Teams', teamColor: '#28c76f'),
      ...widget.allTeams,
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: teams.map((t) {
        final id       = t.id == -1 ? 'all' : t.id.toString();
        final selected = _teamId == id;
        return GestureDetector(
          onTap: () => setState(() => _teamId = id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryGreen : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? AppColors.primaryGreen
                    : Colors.grey.shade300,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                          color:
                              AppColors.primaryGreen.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2))
                    ]
                  : [],
            ),
            child: Text(t.teamName,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                        selected ? Colors.white : const Color(0xFF475569))),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmployeeSelector() {
    final users = [
      const ReportUser(id: -1, name: 'All Employees'),
      ...widget.allUsers,
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: users.asMap().entries.map((entry) {
          final idx      = entry.key;
          final u        = entry.value;
          final id       = u.id == -1 ? 'all' : u.id.toString();
          final selected = _isEmpSelected(id);
          final isLast   = idx == users.length - 1;

          return Column(
            children: [
              InkWell(
                onTap: () => _toggleEmployee(id),
                borderRadius: BorderRadius.vertical(
                  top: idx == 0
                      ? const Radius.circular(12)
                      : Radius.zero,
                  bottom: isLast
                      ? const Radius.circular(12)
                      : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primaryGreen
                              : Colors.transparent,
                          border: Border.all(
                            color: selected
                                ? AppColors.primaryGreen
                                : Colors.grey.shade400,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: selected
                            ? const Icon(Icons.check_rounded,
                                size: 13, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Text(u.name,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: selected
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFF475569))),
                    ],
                  ),
                ),
              ),
              if (!isLast)
                Divider(
                    height: 1,
                    color: Colors.grey.shade100,
                    indent: 46),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildApplyButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.pop(
            context,
            _FilterResult(
              startDate: _start,
              endDate:   _end,
              teamId:    _teamId,
              empIds:    _empIds,
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
        child: const Text('Apply Filters',
            style:
                TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// Expose FilterResult for use in the parent page
class _FilterResult {
  final DateTime startDate;
  final DateTime endDate;
  final String teamId;
  final List<String> empIds;

  const _FilterResult({
    required this.startDate,
    required this.endDate,
    required this.teamId,
    required this.empIds,
  });
}