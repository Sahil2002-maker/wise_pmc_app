// lib/features/process/presentation/widgets/process_team_sheet.dart

import 'package:flutter/material.dart';

import '../../../../core/services/api_service.dart';
import '../../../../core/utils/api_exception.dart';
import '../../data/models/process_model.dart';

/// Bottom sheet for updating the review team of a process.
/// Only shown for Stage 1, 2, and 3 (not PMC Application).
class ProcessTeamSheet extends StatefulWidget {
  final ProcessModel process;
  final List<ProcessTeamModel> teams;

  const ProcessTeamSheet({
    super.key,
    required this.process,
    required this.teams,
  });

  @override
  State<ProcessTeamSheet> createState() => _ProcessTeamSheetState();
}

class _ProcessTeamSheetState extends State<ProcessTeamSheet> {
  int? _selectedTeamId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selectedTeamId = widget.process.reviewTeam;
  }

  Future<void> _submit() async {
    if (_selectedTeamId == null) {
      _showError('Please select a team.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await ApiService.updateProcessTeam(
        orderNo: widget.process.orderNo,
        teamId: _selectedTeamId!,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        _showError(e is ApiException ? e.message : e.toString());
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.group_rounded,
                        color: Color(0xFF0EA5E9), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Update Review Team',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B)),
                        ),
                        Text(
                          widget.process.processName,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF94A3B8)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded,
                        color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),

            const Divider(height: 24),

            // Current team info
            if (widget.process.reviewTeamName != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBAE6FD)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: Color(0xFF0EA5E9), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Current: ${widget.process.reviewTeamName}',
                        style: const TextStyle(
                          color: Color(0xFF0369A1),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Team list
            Flexible(
              child: ListView.separated(
                padding:
                    const EdgeInsets.fromLTRB(20, 0, 20, 20),
                shrinkWrap: true,
                itemCount: widget.teams.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final team = widget.teams[index];
                  final isSelected = _selectedTeamId == team.id;
                  return InkWell(
                    onTap: () =>
                        setState(() => _selectedTeamId = team.id),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF0EA5E9).withValues(alpha: 0.08)
                            : const Color(0xFFF8F9FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF0EA5E9)
                              : const Color(0xFFE8EAFF),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF0EA5E9)
                                  : const Color(0xFFE8EAFF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.group_rounded,
                              size: 17,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              team.teamName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? const Color(0xFF0EA5E9)
                                    : const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded,
                                color: Color(0xFF0EA5E9), size: 20),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Submit button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5E9),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Update Team'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}