// lib/features/general_tasks/presentation/pages/task_calendar_page.dart
//
// CHANGES in this version:
// 1. REMOVED "Mark Complete" button from _TaskDetailDialog — only "Close" shown
// 2. Statistics are now 100% derived from _allEvents (the month's loaded data)
//    — _totalTasks, _generalCount, _projectCount, _pendingCount, _completedCount
//    — all computed locally from the event list; no stale server stat endpoint
// 3. Stats refresh automatically on: month navigation, filter change, task add
// 4. _loadCalendarOnly / _loadData both call _recomputeStats() after setting events
// 5. UI is balanced after button removal (single centered Close button)

import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../data/models/task_calendar_event_model.dart';
import 'general_tasks_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Add-Task side-sheet
// ─────────────────────────────────────────────────────────────────────────────
class _AddTaskSheet extends StatefulWidget {
  final List<Map<String, dynamic>> teams;
  final int Function(dynamic) toInt;
  final String Function(Map<String, dynamic>, List<String>, String) safeLabel;
  final Future<List<Map<String, dynamic>>> Function(int) fetchMembers;
  final Future<void> Function({
    required String taskName,
    required String taskDescription,
    String? taskDeadline,
    required List<int> memberIds,
  }) onSubmit;

  const _AddTaskSheet({
    required this.teams,
    required this.toInt,
    required this.safeLabel,
    required this.fetchMembers,
    required this.onSubmit,
  });

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _taskNameController = TextEditingController();
  final _taskDescController = TextEditingController();
  final _deadlineController = TextEditingController();

  Key _teamDropdownKey = UniqueKey();

  int? _selectedTeamId;
  final List<int> _selectedMemberIds = [];
  List<Map<String, dynamic>> _members = [];
  bool _loadingMembers = false;
  bool _submitting = false;

  @override
  void dispose() {
    _taskNameController.dispose();
    _taskDescController.dispose();
    _deadlineController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        _deadlineController.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _onTeamChanged(int? value) async {
    setState(() {
      _selectedTeamId = value;
      _selectedMemberIds.clear();
      _members = [];
      _loadingMembers = value != null;
      _teamDropdownKey = UniqueKey();
    });
    if (value != null) {
      try {
        final fetched = await widget.fetchMembers(value);
        if (mounted) {
          setState(() {
            _members = fetched;
            _loadingMembers = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() { _members = []; _loadingMembers = false; });
      }
    }
  }

  Future<void> _submit() async {
    final taskName = _taskNameController.text.trim();
    if (taskName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task name is required'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        taskName: taskName,
        taskDescription: _taskDescController.text.trim(),
        taskDeadline: _deadlineController.text.trim().isEmpty
            ? null
            : _deadlineController.text.trim(),
        memberIds: List.of(_selectedMemberIds),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _memberLabel(Map<String, dynamic> member) =>
      widget.safeLabel(member, ['display_name', 'name', 'full_name', 'user_name'], 'Member');

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              const Expanded(
                child: Text('Add Task',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              ),
              IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 18)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('Task Name'),
                const SizedBox(height: 8),
                TextField(
                    controller: _taskNameController,
                    decoration: const InputDecoration(hintText: 'Task Name')),
                const SizedBox(height: 14),
                _label('Task Description'),
                const SizedBox(height: 8),
                TextField(
                    controller: _taskDescController,
                    maxLines: 3,
                    decoration: const InputDecoration(hintText: 'Task Description')),
                const SizedBox(height: 14),
                _label('Deadline'),
                const SizedBox(height: 8),
                TextField(
                  controller: _deadlineController,
                  readOnly: true,
                  onTap: _pickDeadline,
                  decoration: InputDecoration(
                    hintText: 'Deadline',
                    suffixIcon: IconButton(
                        onPressed: _pickDeadline,
                        icon: const Icon(Icons.calendar_today_outlined, size: 18)),
                  ),
                ),
                const SizedBox(height: 14),
                _label('Select Team'),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  key: _teamDropdownKey,
                  value: _selectedTeamId != null &&
                          widget.teams.any((t) => widget.toInt(t['id']) == _selectedTeamId)
                      ? _selectedTeamId
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(hintText: 'Select Team'),
                  items: [
                    const DropdownMenuItem<int>(value: null, child: Text('Select Team')),
                    ...widget.teams.map((team) => DropdownMenuItem<int>(
                          value: widget.toInt(team['id']),
                          child: Text(
                              widget.safeLabel(team, ['team_name', 'name'], 'Team'),
                              overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: _onTeamChanged,
                ),
                const SizedBox(height: 14),
                _label('Assign Team Members'),
                const SizedBox(height: 8),
                if (_loadingMembers)
                  _memberPlaceholder('Loading members...')
                else if (_members.isEmpty)
                  _memberPlaceholder(
                      _selectedTeamId == null ? 'Select a team first' : 'No members found')
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        border: Border.all(color: AppColors.borderColor),
                        borderRadius: BorderRadius.circular(4)),
                    child: Column(
                      children: _members.map((member) {
                        final memberId = widget.toInt(member['id']);
                        final selected = _selectedMemberIds.contains(memberId);
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppColors.primaryGreen,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: selected,
                          title: Text(_memberLabel(member)),
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                if (!_selectedMemberIds.contains(memberId)) {
                                  _selectedMemberIds.add(memberId);
                                }
                              } else {
                                _selectedMemberIds.remove(memberId);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white),
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Add'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _memberPlaceholder(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderColor),
            borderRadius: BorderRadius.circular(4)),
        child: Row(
          children: [
            if (_loadingMembers)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            if (_loadingMembers) const SizedBox(width: 10),
            Text(text, style: const TextStyle(color: AppColors.textMutedDark)),
          ],
        ),
      );

  Widget _label(String text) => Text(text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark));
}

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens
// ─────────────────────────────────────────────────────────────────────────────
abstract class _C {
  static const Color bg        = Color(0xFFF4F6F9);
  static const Color surface   = Colors.white;
  static const Color green     = Color(0xFF16A34A);
  static const Color greenBg   = Color(0xFFDCFCE7);
  static const Color greenFg   = Color(0xFF15803D);
  static const Color amber     = Color(0xFFF59E0B);
  static const Color amberBg   = Color(0xFFFEF3C7);
  static const Color amberFg   = Color(0xFFB45309);
  static const Color red       = Color(0xFFDC2626);
  static const Color redBg     = Color(0xFFFEE2E2);
  static const Color redFg     = Color(0xFFB91C1C);
  static const Color blue      = Color(0xFF2563EB);
  static const Color blueBg    = Color(0xFFEFF6FF);
  static const Color blueFg    = Color(0xFF1D4ED8);
  static const Color border    = Color(0xFFE8EAF0);
  static const Color textPri   = Color(0xFF1A1D23);
  static const Color textSec   = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color purple    = Color(0xFF7C3AED);
  static const Color teal      = Color(0xFF0891B2);
  static const Color tealBg    = Color(0xFFE0F2FE);
}

// ─────────────────────────────────────────────────────────────────────────────
// Task Detail Dialog — Mark Complete REMOVED
// ─────────────────────────────────────────────────────────────────────────────
class _TaskDetailDialog extends StatefulWidget {
  final TaskCalendarEventModel event;
  final VoidCallback onClose;
  final Color Function(String?) parseColor;

  const _TaskDetailDialog({
    required this.event,
    required this.onClose,
    required this.parseColor,
  });

  @override
  State<_TaskDetailDialog> createState() => _TaskDetailDialogState();
}

class _TaskDetailDialogState extends State<_TaskDetailDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Color get _accentColor => widget.parseColor(widget.event.backgroundColor);
  bool get _isCompleted  => widget.event.isCompleted;

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final deadlineStr =
        '${e.start.day.toString().padLeft(2, '0')}-'
        '${e.start.month.toString().padLeft(2, '0')}-'
        '${e.start.year}';

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(e),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          if (e.description.isNotEmpty) ...[
                            _sectionLabel('Description'),
                            const SizedBox(height: 8),
                            _descriptionCard(e.description),
                            const SizedBox(height: 18),
                          ],
                          _sectionLabel('Details'),
                          const SizedBox(height: 10),
                          _infoGrid(e, deadlineStr),
                          if ((e.projectName ?? '').isNotEmpty ||
                              (e.processName ?? '').isNotEmpty) ...[
                            const SizedBox(height: 18),
                            _sectionLabel('Project Info'),
                            const SizedBox(height: 10),
                            if ((e.projectName ?? '').isNotEmpty)
                              _projectChip(Icons.work_outline_rounded, e.projectName!, const Color(0xFF6366F1)),
                            if ((e.processName ?? '').isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _projectChip(Icons.account_tree_outlined, e.processName!, const Color(0xFF0891B2)),
                            ],
                          ],
                          // ── Replaced dual-button row with single centred Close ──
                          const SizedBox(height: 28),
                          _buildCloseButton(),
                        ],
                      ),
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

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(TaskCalendarEventModel e) {
    final color = _accentColor;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.25)!],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30, right: -30,
            child: Container(
              width: 110, height: 110,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.07)),
            ),
          ),
          Positioned(
            bottom: -20, left: 40,
            child: Container(
              width: 70, height: 70,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Type badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            e.isGeneralTask ? Icons.description_outlined : Icons.folder_outlined,
                            size: 11, color: Colors.white,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            e.isGeneralTask ? 'General Task' : 'Project Task',
                            style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600,
                              color: Colors.white, letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Status pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isCompleted
                            ? const Color(0xFF22C55E).withOpacity(0.22)
                            : const Color(0xFFF59E0B).withOpacity(0.22),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isCompleted
                              ? const Color(0xFF86EFAC)
                              : const Color(0xFFFCD34D),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isCompleted
                                  ? const Color(0xFF86EFAC)
                                  : const Color(0xFFFCD34D),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _isCompleted ? 'Completed' : 'Pending',
                            style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: _isCompleted
                                  ? const Color(0xFF86EFAC)
                                  : const Color(0xFFFCD34D),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Close button
                    GestureDetector(
                      onTap: widget.onClose,
                      child: Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  e.title,
                  style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: -0.3, height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.calendar_today_rounded, size: 12, color: Colors.white),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Due ${e.start.day.toString().padLeft(2, '0')}-'
                      '${e.start.month.toString().padLeft(2, '0')}-'
                      '${e.start.year}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
                    ),
                    if (e.isOverdue && !_isCompleted) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.25),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: const Text('Overdue',
                            style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w700,
                                color: Color(0xFFFCA5A5))),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) => Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10, fontWeight: FontWeight.w800,
          color: _C.textMuted, letterSpacing: 1.2,
        ),
      );

  Widget _descriptionCard(String desc) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Text(desc,
            style: const TextStyle(fontSize: 13.5, color: _C.textSec, height: 1.55)),
      );

  Widget _infoGrid(TaskCalendarEventModel e, String deadlineStr) {
    final items = <_InfoItem>[
      _InfoItem(icon: Icons.group_outlined, label: 'Team',
          value: (e.teamName ?? '').isEmpty ? 'No team' : e.teamName!, color: _C.teal),
      _InfoItem(icon: Icons.person_outline_rounded, label: 'Assigned To',
          value: e.assignedUsersNames.isEmpty ? 'Unassigned' : e.assignedUsersNames,
          color: const Color(0xFF8B5CF6)),
      _InfoItem(icon: Icons.calendar_month_outlined, label: 'Deadline',
          value: deadlineStr, color: _C.amber),
      _InfoItem(
          icon: _isCompleted ? Icons.check_circle_outline_rounded : Icons.pending_outlined,
          label: 'Status',
          value: _isCompleted ? 'Completed' : 'Pending',
          color: _isCompleted ? _C.green : _C.amber),
    ];

    return Column(
      children: [
        Row(children: [
          Expanded(child: _infoCard(items[0])),
          const SizedBox(width: 10),
          Expanded(child: _infoCard(items[1])),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _infoCard(items[2])),
          const SizedBox(width: 10),
          Expanded(child: _infoCard(items[3])),
        ]),
      ],
    );
  }

  Widget _infoCard(_InfoItem item) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                  color: item.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9)),
              child: Icon(item.icon, size: 16, color: item.color),
            ),
            const SizedBox(height: 8),
            Text(item.label,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _C.textMuted, letterSpacing: 0.4)),
            const SizedBox(height: 2),
            Text(item.value,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _C.textPri, height: 1.3),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      );

  Widget _projectChip(IconData icon, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );

  // ── Single full-width Close button (Mark Complete removed) ─────────────────
  Widget _buildCloseButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: widget.onClose,
        style: OutlinedButton.styleFrom(
          foregroundColor: _C.textSec,
          side: const BorderSide(color: _C.border, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Text('Close',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      ),
    );
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _InfoItem({required this.icon, required this.label, required this.value, required this.color});
}

// ─────────────────────────────────────────────────────────────────────────────
// Main page
// ─────────────────────────────────────────────────────────────────────────────
class TaskCalendarPage extends StatefulWidget {
  const TaskCalendarPage({super.key});

  @override
  State<TaskCalendarPage> createState() => _TaskCalendarPageState();
}

class _TaskCalendarPageState extends State<TaskCalendarPage>
    with SingleTickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  bool _isLoading = true;
  String? _errorMessage;

  List<TaskCalendarEventModel> _allEvents = [];
  List<Map<String, dynamic>> _teams = [];
  List<Map<String, dynamic>> _members = [];

  bool _showGeneralTasks   = true;
  bool _showProjectTasks   = true;
  bool _showPendingTasks   = true;
  bool _showCompletedTasks = true;

  int? _selectedTeamId;
  int? _selectedMemberId;

  bool _loadingMembers  = false;
  bool _filtersExpanded = false;

  Key _teamKey   = UniqueKey();
  Key _memberKey = UniqueKey();

  DateTime _focusedMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);

  // ── Statistics — computed from _allEvents, not from a separate API call ────
  int _totalTasks     = 0;
  int _generalCount   = 0;
  int _projectCount   = 0;
  int _pendingCount   = 0;
  int _completedCount = 0;

  late final AnimationController _filterAnim;
  late final Animation<double>   _filterExpand;

  @override
  void initState() {
    super.initState();
    _filterAnim   = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _filterExpand = CurvedAnimation(parent: _filterAnim, curve: Curves.easeInOut);
    _loadData();
  }

  @override
  void dispose() {
    _filterAnim.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  int _toInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '0') ?? 0;
  }

  String _safeLabel(Map<String, dynamic> item, List<String> keys, String fallback) {
    for (final key in keys) {
      final v = item[key];
      if (v == null) continue;
      if (v is String && v.trim().isNotEmpty) return v.trim();
      if (v is num || v is bool) return v.toString();
    }
    return fallback;
  }

  String _memberLabel(Map<String, dynamic> member) =>
      _safeLabel(member, ['display_name', 'name', 'full_name', 'user_name'], 'Member');

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF7367F0);
    final cleaned = hex.replaceAll('#', '');
    if (cleaned.length == 6) return Color(int.parse('FF$cleaned', radix: 16));
    return const Color(0xFF7367F0);
  }

  // ── Month range helpers ────────────────────────────────────────────────────
  String get _monthStartStr {
    final y = _focusedMonth.year;
    final m = _focusedMonth.month.toString().padLeft(2, '0');
    return '$y-$m-01';
  }

  String get _monthEndStr {
    final lastDay = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    return '${lastDay.year}-${lastDay.month.toString().padLeft(2, '0')}-${lastDay.day.toString().padLeft(2, '0')}';
  }

  // ── Compute stats purely from the loaded event list ────────────────────────
  //
  // This is called immediately after _allEvents is assigned so stats are always
  // consistent with the calendar data. No separate API call is needed.
  void _recomputeStats() {
    _totalTasks     = _allEvents.length;
    _generalCount   = _allEvents.where((e) => e.isGeneralTask).length;
    _projectCount   = _allEvents.where((e) => e.isProcessTask).length;
    _pendingCount   = _allEvents.where((e) => !e.isCompleted).length;
    _completedCount = _allEvents.where((e) => e.isCompleted).length;
  }

  // ── Data loading ───────────────────────────────────────────────────────────
  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      // Fetch teams + calendar events in parallel (no longer need stats endpoint)
      final results = await Future.wait([
        ApiService.fetchTeamsAndMembers()
            .catchError((_) => <Map<String, dynamic>>[]),
        _fetchCalendarTasksForMonth(),
      ]);

      if (!mounted) return;

      final loadedTeams  = results[0] as List<Map<String, dynamic>>;
      final loadedEvents = results[1] as List<TaskCalendarEventModel>;

      int? validTeamId   = _selectedTeamId;
      int? validMemberId = _selectedMemberId;
      if (validTeamId != null &&
          !loadedTeams.any((t) => _toInt(t['id']) == validTeamId)) {
        validTeamId   = null;
        validMemberId = null;
      }

      setState(() {
        _allEvents  = loadedEvents;
        _teams      = loadedTeams;
        _selectedTeamId   = validTeamId;
        _selectedMemberId = validMemberId;
        _teamKey = UniqueKey();

        if (validTeamId == null) {
          _members   = [];
          _memberKey = UniqueKey();
        }

        // Recompute all statistics from the freshly loaded events
        _recomputeStats();
        _isLoading = false;
      });

      if (validTeamId != null && _members.isEmpty && !_loadingMembers) {
        await _loadMembersForTeam(validTeamId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _errorMessage = e.toString(); _isLoading = false; });
    }
  }

  Future<List<TaskCalendarEventModel>> _fetchCalendarTasksForMonth() async {
    final teamIds   = _selectedTeamId   != null ? [_selectedTeamId!]   : <int>[];
    final memberIds = _selectedMemberId != null ? [_selectedMemberId!] : <int>[];

    return ApiService.fetchCalendarTasks(
      teamIds:   teamIds,
      memberIds: memberIds,
      startDate: _monthStartStr,
      endDate:   _monthEndStr,
    );
  }

  Future<void> _loadMembersForTeam(int teamId) async {
    if (!mounted) return;
    setState(() {
      _loadingMembers = true;
      _members        = [];
      _memberKey      = UniqueKey();
    });
    try {
      final fetched = await ApiService.fetchTeamMembers(teamId);
      if (!mounted) return;
      if (_selectedTeamId != teamId) return;
      setState(() {
        _members        = fetched;
        _loadingMembers = false;
        _memberKey      = UniqueKey();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _members        = [];
        _loadingMembers = false;
        _memberKey      = UniqueKey();
      });
    }
  }

  // ── Filtered events ────────────────────────────────────────────────────────
  List<TaskCalendarEventModel> get _filtered {
    return _allEvents.where((e) {
      final typeOk   = (_showGeneralTasks && e.isGeneralTask) ||
                       (_showProjectTasks && e.isProcessTask);
      final statusOk = (_showPendingTasks && !e.isCompleted) ||
                       (_showCompletedTasks && e.isCompleted);
      return typeOk && statusOk;
    }).toList();
  }

  List<TaskCalendarEventModel> _eventsForDay(DateTime day) {
    return _filtered
        .where((e) =>
            e.start.year  == day.year &&
            e.start.month == day.month &&
            e.start.day   == day.day)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  void _prevMonth() {
    setState(() =>
        _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1));
    _loadCalendarOnly();
  }

  void _nextMonth() {
    setState(() =>
        _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1));
    _loadCalendarOnly();
  }

  void _goToday() {
    setState(() =>
        _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1));
    _loadCalendarOnly();
  }

  // ── Calendar grid helpers ──────────────────────────────────────────────────
  DateTime get _gridStart {
    final first = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    return first.subtract(Duration(days: first.weekday % 7));
  }

  List<DateTime> get _gridDays =>
      List.generate(42, (i) => _gridStart.add(Duration(days: i)));

  String get _monthTitle {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[_focusedMonth.month - 1]} ${_focusedMonth.year}';
  }

  // ── Event details / day tap ────────────────────────────────────────────────
  void _onDayTap(DateTime day) {
    final events = _eventsForDay(day);
    if (events.isEmpty) return;
    _showDaySheet(day, events);
  }

  void _showDaySheet(DateTime day, List<TaskCalendarEventModel> events) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DayTasksSheet(
          day: day, events: events, onEventTap: _showEventDetails),
    );
  }

  // ── Task detail dialog — no Mark Complete callback needed ──────────────────
  Future<void> _showEventDetails(TaskCalendarEventModel event) async {
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => _TaskDetailDialog(
        event:      event,
        parseColor: _parseColor,
        onClose:    () => Navigator.pop(ctx),
      ),
    );
  }

  // ── Add task ───────────────────────────────────────────────────────────────
  Future<void> _openAddTaskSheet() async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Add Task',
      barrierColor: Colors.black54,
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final slide = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut));
        return SlideTransition(
          position: slide,
          child: Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.white,
              child: SafeArea(
                child: SizedBox(
                  width: MediaQuery.of(ctx).size.width < 900
                      ? MediaQuery.of(ctx).size.width
                      : 360,
                  child: _AddTaskSheet(
                    teams:        _teams,
                    toInt:        _toInt,
                    safeLabel:    _safeLabel,
                    fetchMembers: ApiService.fetchTeamMembers,
                    onSubmit: ({
                      required taskName,
                      required taskDescription,
                      taskDeadline,
                      required memberIds,
                    }) async {
                      final resp = await ApiService.createGeneralTask(
                          taskName:        taskName,
                          taskDescription: taskDescription,
                          taskDeadline:    taskDeadline);
                      final raw = resp['task'] ?? resp['data'] ?? resp['general_task'];
                      int createdId = 0;
                      if (raw is Map) {
                        createdId = _toInt(raw['id'] ?? raw['task_id']);
                      } else {
                        createdId = _toInt(resp['task_id']);
                      }
                      if (createdId > 0 && memberIds.isNotEmpty) {
                        await ApiService.assignGeneralTask(
                          taskId:       createdId,
                          assignedTo:   memberIds,
                          assignedDate: DateTime.now()
                              .toIso8601String()
                              .split('T')
                              .first,
                        );
                      }
                      // Reload events + immediately recompute stats
                      await _loadCalendarOnly();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(children: [
                            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                            SizedBox(width: 10),
                            Text('Task created successfully',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                          ]),
                          backgroundColor: const Color(0xFF16A34A),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.all(14),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Filter handlers ────────────────────────────────────────────────────────
  Future<void> _onTeamChanged(int? value) async {
    setState(() {
      _selectedTeamId   = value;
      _selectedMemberId = null;
      _members          = [];
      _memberKey        = UniqueKey();
      _loadingMembers   = value != null;
    });

    if (value != null) {
      try {
        final fetched = await ApiService.fetchTeamMembers(value);
        if (!mounted) return;
        if (_selectedTeamId != value) return;
        setState(() {
          _members        = fetched;
          _loadingMembers = false;
          _memberKey      = UniqueKey();
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _members        = [];
          _loadingMembers = false;
          _memberKey      = UniqueKey();
        });
      }
    }

    await _loadCalendarOnly();
  }

  Future<void> _onMemberChanged(int? value) async {
    setState(() => _selectedMemberId = value);
    await _loadCalendarOnly();
  }

  /// Loads calendar events for the current month + filters, then recomputes
  /// statistics instantly — without touching _teams or _members.
  Future<void> _loadCalendarOnly() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final loadedEvents = await _fetchCalendarTasksForMonth();
      if (!mounted) return;
      setState(() {
        _allEvents = loadedEvents;
        // Stats always mirror the freshly fetched event list
        _recomputeStats();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _errorMessage = e.toString(); _isLoading = false; });
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedTeamId   = null;
      _selectedMemberId = null;
      _members          = [];
      _teamKey          = UniqueKey();
      _memberKey        = UniqueKey();
    });
    _loadData();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : _errorMessage != null
              ? _buildError()
              : _buildContent(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor:  _C.surface,
      elevation:        0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19, color: _C.textPri),
        onPressed: () => Navigator.maybePop(context),
      ),
      title: const Text('Task Calendar',
          style: TextStyle(color: _C.textPri, fontWeight: FontWeight.w700,
              fontSize: 18, letterSpacing: -0.3)),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.refresh_rounded, color: AppColors.primaryGreen, size: 17),
          ),
          onPressed: _loadData,
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _C.border),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: _C.redBg, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.cloud_off_rounded, size: 34, color: _C.red),
          ),
          const SizedBox(height: 14),
          const Text('Something went wrong',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _C.textPri)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(_errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: _C.textSec)),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primaryGreen,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatsGrid(),
            const SizedBox(height: 12),
            _buildFilterSection(),
            const SizedBox(height: 12),
            _buildMonthNav(),
            const SizedBox(height: 12),
            _buildCalendarGrid(),
            const SizedBox(height: 12),
            _buildActionRow(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Stats grid — values always from _recomputeStats() ─────────────────────
  Widget _buildStatsGrid() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Statistics',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: _C.textMuted, letterSpacing: 0.8)),
              const Spacer(),
              // Month label so the user knows which month the stats belong to
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _monthTitle,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: AppColors.primaryGreen),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(children: [
            _statCard('Total',     _totalTasks,     AppColors.primaryGreen, Icons.assignment_outlined),
            const SizedBox(width: 8),
            _statCard('Completed', _completedCount, _C.green,              Icons.check_circle_outline_rounded),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _statCard('Pending',   _pendingCount,   _C.amber,  Icons.pending_outlined),
            const SizedBox(width: 8),
            _statCard('General',   _generalCount,   _C.teal,   Icons.description_outlined),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _statCard('Project',   _projectCount,   _C.purple, Icons.folder_outlined),
            const SizedBox(width: 8),
            Expanded(child: const SizedBox()),
          ]),
        ],
      ),
    );
  }

  Widget _statCard(String label, int value, Color color, IconData icon) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(icon, size: 15, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AnimatedSwitcher gives a subtle flip when the number changes
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, anim) =>
                        FadeTransition(opacity: anim, child: child),
                    child: Text(
                      '$value',
                      key: ValueKey('$label-$value'),
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800, color: color),
                    ),
                  ),
                  Text(label,
                      style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w600,
                          color: color.withValues(alpha: 0.8))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Filter section ─────────────────────────────────────────────────────────
  Widget _buildFilterSection() {
    final hasActiveFilter = _selectedTeamId != null || _selectedMemberId != null;
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasActiveFilter ? AppColors.primaryGreen.withValues(alpha: 0.4) : _C.border,
          width: hasActiveFilter ? 1.5 : 1,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() => _filtersExpanded = !_filtersExpanded);
              if (_filtersExpanded) _filterAnim.forward();
              else _filterAnim.reverse();
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.filter_list_rounded,
                      color: hasActiveFilter ? AppColors.primaryGreen : _C.textSec, size: 18),
                  const SizedBox(width: 8),
                  Text('Filters & Task Types',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                          color: hasActiveFilter ? AppColors.primaryGreen : _C.textPri)),
                  if (hasActiveFilter) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Text('Active',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                              color: AppColors.primaryGreen)),
                    ),
                  ],
                  const Spacer(),
                  if (hasActiveFilter)
                    GestureDetector(
                      onTap: _clearFilters,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: _C.redBg, borderRadius: BorderRadius.circular(20)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.close_rounded, color: _C.redFg, size: 11),
                            SizedBox(width: 3),
                            Text('Clear', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _C.redFg)),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 280),
                    turns: _filtersExpanded ? 0.5 : 0,
                    child: const Icon(Icons.keyboard_arrow_down_rounded, color: _C.textSec, size: 20),
                  ),
                ],
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _filterExpand,
            child: Container(
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: _C.border))),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TASK TYPES',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                          color: _C.textMuted, letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  Row(children: [
                    _typeToggle('General', Icons.description_outlined, _C.teal,
                        _showGeneralTasks, (v) => setState(() => _showGeneralTasks = v)),
                    const SizedBox(width: 8),
                    _typeToggle('Project', Icons.folder_outlined, _C.purple,
                        _showProjectTasks, (v) => setState(() => _showProjectTasks = v)),
                  ]),
                  const SizedBox(height: 12),
                  const Text('TEAM FILTERS',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                          color: _C.textMuted, letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  _buildTeamDropdown(),
                  const SizedBox(height: 8),
                  _buildMemberDropdown(),
                  const SizedBox(height: 12),
                  const Text('TASK STATUS',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                          color: _C.textMuted, letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  Row(children: [
                    _statusToggle('Pending', const Color(0xFFFF9F43),
                        _showPendingTasks, (v) => setState(() => _showPendingTasks = v)),
                    const SizedBox(width: 8),
                    _statusToggle('Completed', const Color(0xFF28C76F),
                        _showCompletedTasks, (v) => setState(() => _showCompletedTasks = v)),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeToggle(String label, IconData icon, Color color, bool value, ValueChanged<bool> onChanged) {
    return Expanded(
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: value ? color.withValues(alpha: 0.1) : _C.bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: value ? color.withValues(alpha: 0.4) : _C.border,
                width: value ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Icon(icon, size: 14, color: value ? color : _C.textMuted),
              const SizedBox(width: 6),
              Expanded(child: Text(label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: value ? color : _C.textSec))),
              Container(
                width: 16, height: 16,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: value ? color : _C.border,
                    border: Border.all(color: value ? color : _C.border)),
                child: value ? const Icon(Icons.check_rounded, size: 10, color: Colors.white) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusToggle(String label, Color color, bool value, ValueChanged<bool> onChanged) {
    return Expanded(
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: value ? color.withValues(alpha: 0.08) : _C.bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: value ? color.withValues(alpha: 0.35) : _C.border,
                width: value ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Container(width: 8, height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 7),
              Expanded(child: Text(label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: value ? _C.textPri : _C.textSec))),
              if (value) Icon(Icons.check_rounded, size: 13, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamDropdown() {
    final safeValue = _selectedTeamId != null &&
            _teams.any((t) => _toInt(t['id']) == _selectedTeamId)
        ? _selectedTeamId : null;
    return DropdownButtonFormField<int>(
      key: _teamKey,
      value: safeValue,
      isExpanded: true,
      decoration: InputDecoration(
        hintText: 'All Teams',
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true, fillColor: _C.bg,
        enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: _C.border),
            borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
            borderRadius: BorderRadius.circular(10)),
      ),
      items: [
        const DropdownMenuItem<int>(value: null, child: Text('All Teams')),
        ..._teams.map((t) => DropdownMenuItem<int>(
              value: _toInt(t['id']),
              child: Text(_safeLabel(t, ['team_name', 'name'], 'Team'),
                  overflow: TextOverflow.ellipsis),
            )),
      ],
      onChanged: _onTeamChanged,
    );
  }

  Widget _buildMemberDropdown() {
    if (_loadingMembers) {
      return _dropdownPlaceholder(
        child: const Row(children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Text('Loading members...', style: TextStyle(color: _C.textMuted)),
        ]),
      );
    }
    if (_selectedTeamId == null) {
      return _dropdownPlaceholder(
          child: const Text('Select a team first',
              style: TextStyle(color: _C.textMuted, fontSize: 14)));
    }
    if (_members.isEmpty) {
      return _dropdownPlaceholder(
          child: const Text('No members found for this team',
              style: TextStyle(color: _C.textMuted, fontSize: 14)));
    }
    final safeValue = _selectedMemberId != null &&
            _members.any((m) => _toInt(m['id']) == _selectedMemberId)
        ? _selectedMemberId : null;
    return DropdownButtonFormField<int>(
      key: _memberKey,
      value: safeValue,
      isExpanded: true,
      decoration: InputDecoration(
        hintText: 'All Members',
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true, fillColor: _C.bg,
        enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: _C.border),
            borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
            borderRadius: BorderRadius.circular(10)),
      ),
      items: [
        const DropdownMenuItem<int>(value: null, child: Text('All Members')),
        ..._members.map((m) => DropdownMenuItem<int>(
              value: _toInt(m['id']),
              child: Text(_memberLabel(m), overflow: TextOverflow.ellipsis),
            )),
      ],
      onChanged: _onMemberChanged,
    );
  }

  Widget _dropdownPlaceholder({required Widget child}) => Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
            color: _C.bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _C.border)),
        child: Align(alignment: Alignment.centerLeft, child: child),
      );

  // ── Month navigation ───────────────────────────────────────────────────────
  Widget _buildMonthNav() {
    final now = DateTime.now();
    final isCurrentMonth =
        _focusedMonth.year == now.year && _focusedMonth.month == now.month;
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          _navBtn(Icons.chevron_left_rounded, _prevMonth),
          Expanded(
            child: Column(
              children: [
                Text(_monthTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                        color: _C.textPri, letterSpacing: -0.3)),
                Text(
                  '${_filtered.length} task${_filtered.length == 1 ? '' : 's'} this month',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: _C.textMuted, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          if (!isCurrentMonth)
            TextButton(
              onPressed: _goToday,
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero),
              child: const Text('Today',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          _navBtn(Icons.chevron_right_rounded, _nextMonth),
        ],
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
              color: _C.bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.border)),
          child: Icon(icon, color: _C.textPri, size: 20),
        ),
      );

  // ── Calendar grid ──────────────────────────────────────────────────────────
  Widget _buildCalendarGrid() {
    const weekDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final days  = _gridDays;
    final today = DateTime.now();

    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: AppColors.primaryGreen.withValues(alpha: 0.06),
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: weekDays.map((d) => Expanded(
                child: Text(d,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: AppColors.primaryGreen, letterSpacing: 0.3)),
              )).toList(),
            ),
          ),
          const Divider(height: 1, color: _C.border),
          ...List.generate(6, (week) {
            final slice = days.skip(week * 7).take(7).toList();
            return Container(
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _C.border))),
              child: Row(
                children: slice.asMap().entries.map((entry) {
                  final col     = entry.key;
                  final day     = entry.value;
                  final inMonth = day.month == _focusedMonth.month;
                  final isToday = day.year  == today.year &&
                                  day.month == today.month &&
                                  day.day   == today.day;
                  final events    = _eventsForDay(day);
                  final hasEvents = events.isNotEmpty;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _onDayTap(day),
                      child: Container(
                        height: 58,
                        decoration: BoxDecoration(
                          color: isToday
                              ? AppColors.primaryGreen.withValues(alpha: 0.06)
                              : null,
                          border: col < 6
                              ? const Border(right: BorderSide(color: _C.border))
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Container(
                              width: 26, height: 26,
                              decoration: isToday
                                  ? const BoxDecoration(
                                      color: AppColors.primaryGreen,
                                      shape: BoxShape.circle)
                                  : null,
                              child: Center(
                                child: Text('${day.day}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                                      color: isToday
                                          ? Colors.white
                                          : inMonth
                                              ? _C.textPri
                                              : _C.textMuted.withValues(alpha: 0.5),
                                    )),
                              ),
                            ),
                            if (hasEvents) ...[
                              const SizedBox(height: 3),
                              _buildEventDots(events),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEventDots(List<TaskCalendarEventModel> events) {
    final dots = events.take(3).toList();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ...dots.asMap().entries.map((e) => Container(
              width: 5, height: 5,
              margin: EdgeInsets.only(right: e.key < dots.length - 1 ? 2 : 0),
              decoration: BoxDecoration(
                  color: _parseColor(e.value.backgroundColor),
                  shape: BoxShape.circle),
            )),
        if (events.length > 3) ...[
          Container(
            width: 2, height: 2,
            margin: const EdgeInsets.only(left: 1),
            decoration: const BoxDecoration(color: _C.textMuted, shape: BoxShape.circle),
          ),
        ],
      ],
    );
  }

  // ── Action row ─────────────────────────────────────────────────────────────
  Widget _buildActionRow() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _openAddTaskSheet,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Task',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 46,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const GeneralTasksPage())),
              icon: const Icon(Icons.list_rounded, size: 17),
              label: const Text('Tasks',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
                side: const BorderSide(color: AppColors.primaryGreen),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Day tasks bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _DayTasksSheet extends StatelessWidget {
  final DateTime day;
  final List<TaskCalendarEventModel> events;
  final Future<void> Function(TaskCalendarEventModel) onEventTap;

  const _DayTasksSheet({
    required this.day,
    required this.events,
    required this.onEventTap,
  });

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF7367F0);
    final c = hex.replaceAll('#', '');
    if (c.length == 6) return Color(int.parse('FF$c', radix: 16));
    return const Color(0xFF7367F0);
  }

  @override
  Widget build(BuildContext context) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final dateLabel = '${day.day} ${months[day.month - 1]} ${day.year}';

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.72),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.calendar_today_rounded,
                      color: AppColors.primaryGreen, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dateLabel,
                          style: const TextStyle(fontSize: 15,
                              fontWeight: FontWeight.w700, color: _C.textPri)),
                      Text('${events.length} task${events.length == 1 ? '' : 's'}',
                          style: const TextStyle(fontSize: 12, color: _C.textMuted)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                        color: _C.bg, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.close_rounded, size: 16, color: _C.textSec),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: _C.border),
          Flexible(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
              shrinkWrap: true,
              itemCount: events.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final e     = events[i];
                final color = _parseColor(e.backgroundColor);
                return GestureDetector(
                  onTap: () async {
                    Navigator.pop(context);
                    await onEventTap(e);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 4, height: 40,
                          decoration: BoxDecoration(
                              color: color, borderRadius: BorderRadius.circular(2)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.title,
                                  style: const TextStyle(fontSize: 13,
                                      fontWeight: FontWeight.w600, color: _C.textPri),
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                              if (e.isGeneralTask || e.isProcessTask) ...[
                                const SizedBox(height: 3),
                                Text(e.isGeneralTask ? 'General Task' : 'Project Task',
                                    style: TextStyle(fontSize: 11, color: color,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: e.isCompleted ? _C.greenBg : _C.amberBg,
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(
                            e.isCompleted ? 'Done' : 'Pending',
                            style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w700,
                              color: e.isCompleted ? _C.greenFg : _C.amberFg),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.chevron_right_rounded, size: 16, color: _C.textMuted),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}