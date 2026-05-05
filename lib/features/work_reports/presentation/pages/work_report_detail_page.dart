import 'package:flutter/material.dart';
import '../../../../core/services/api_service.dart';
import '../../data/models/work_report_calendar_event.dart';
import '../../data/models/work_report_model.dart';

// ─── Design tokens ─────────────────────────────────────────────────────────
class _Colors {
  static const primary = Color(0xFF1B5E3B);
  static const primaryLight = Color(0xFF2E7D52);
  static const primaryGlow = Color(0xFF43A070);
  static const accent = Color(0xFF00C27C);
  static const surface = Color(0xFFF0F4F1);
  static const card = Colors.white;
  static const textDark = Color(0xFF0D1F17);
  static const textMid = Color(0xFF4A6358);
  static const textSoft = Color(0xFF8FA99A);
  static const border = Color(0xFFD8E8DF);
  static const danger = Color(0xFFD93025);
  static const amber = Color(0xFFF59E0B);
  static const info = Color(0xFF0EA5E9);
}

class WorkReportDetailPage extends StatefulWidget {
  final WorkReportCalendarEvent event;
  final int currentUserId;
  final String currentUserRole;
  final VoidCallback onSaved;

  const WorkReportDetailPage({
    super.key,
    required this.event,
    required this.currentUserId,
    required this.currentUserRole,
    required this.onSaved,
  });

  @override
  State<WorkReportDetailPage> createState() => _WorkReportDetailPageState();
}

class _WorkReportDetailPageState extends State<WorkReportDetailPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _tasksController = TextEditingController();
  final _hoursController = TextEditingController();
  final _challengesController = TextEditingController();
  final _nextDayController = TextEditingController();

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  bool isLoading = true;
  bool isSaving = false;
  bool isDeleting = false;
  String? errorMessage;
  String reportStatus = 'submitted';

  AttendanceInfo? attendance;
  WorkReportModel? existingReport;
  bool canEdit = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _loadData();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _descController.dispose();
    _tasksController.dispose();
    _hoursController.dispose();
    _challengesController.dispose();
    _nextDayController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final props = widget.event.extendedProps;
      final data = await ApiService.fetchWorkReportDetail(
        userId: props.userId,
        date: props.date,
        attendanceId: props.attendanceId,
      );
      if (!mounted) return;

      final attendanceRaw = data['attendance'] as Map<String, dynamic>?;
      final reportRaw = data['work_report'] as Map<String, dynamic>?;

      attendance =
          attendanceRaw != null ? AttendanceInfo.fromJson(attendanceRaw) : null;
      canEdit = data['can_edit'] == true;

      if (reportRaw != null) {
        existingReport = WorkReportModel.fromJson({
          ...reportRaw,
          'user_id': props.userId,
          'attendance_id': props.attendanceId,
          'date': props.date,
        });
        _descController.text = existingReport!.workDescription;
        _tasksController.text = existingReport!.tasksCompleted ?? '';
        _hoursController.text = existingReport!.hoursWorked.toString();
        _challengesController.text = existingReport!.challengesFaced ?? '';
        _nextDayController.text = existingReport!.nextDayPlan ?? '';
        reportStatus = existingReport!.status;
      } else {
        _setDefaultHours(props);
      }

      setState(() => isLoading = false);
      _animCtrl.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString().replaceAll('Exception: ', '');
        isLoading = false;
      });
    }
  }

  void _setDefaultHours(CalendarEventProps props) {
    if (props.workingHours > 0) {
      _hoursController.text = props.workingHours.toStringAsFixed(1);
    } else if (props.status.toLowerCase() == 'half-day') {
      _hoursController.text = '4.0';
    } else if (props.isIncompleteShift || props.isAbsentWithCheckin) {
      _hoursController.text = '2.0';
    } else {
      _hoursController.text = '9.0';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || !canEdit) return;
    setState(() => isSaving = true);
    try {
      final props = widget.event.extendedProps;
      final message = await ApiService.saveWorkReport(
        userId: props.userId,
        attendanceId: props.attendanceId,
        date: props.date,
        workDescription: _descController.text.trim(),
        tasksCompleted: _tasksController.text.trim(),
        hoursWorked: double.tryParse(_hoursController.text) ?? 0,
        challengesFaced: _challengesController.text.trim(),
        nextDayPlan: _nextDayController.text.trim(),
        status: reportStatus,
      );
      if (!mounted) return;
      setState(() => isSaving = false);
      _snack(message, isSuccess: true);
      widget.onSaved();
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => isSaving = false);
      _snack(e.toString().replaceAll('Exception: ', ''), isSuccess: false);
    }
  }

  Future<void> _delete() async {
    if (existingReport?.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _Colors.danger.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: _Colors.danger, size: 28),
              ),
              const SizedBox(height: 16),
              const Text('Delete Report',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _Colors.textDark)),
              const SizedBox(height: 8),
              const Text('This action cannot be undone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _Colors.textMid, fontSize: 13)),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _Colors.border),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(color: _Colors.textMid)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _Colors.danger,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Delete',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return;

    setState(() => isDeleting = true);
    try {
      final message =
          await ApiService.deleteWorkReport(existingReport!.id!);
      if (!mounted) return;
      setState(() => isDeleting = false);
      _snack(message, isSuccess: true);
      widget.onSaved();
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => isDeleting = false);
      _snack(e.toString().replaceAll('Exception: ', ''), isSuccess: false);
    }
  }

  void _snack(String message, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: isSuccess ? _Colors.accent : _Colors.danger,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Color _attendanceColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return _Colors.accent;
      case 'half-day':
        return _Colors.amber;
      case 'absent':
        return _Colors.danger;
      default:
        return _Colors.textSoft;
    }
  }

  String _displayDate(String date) {
    try {
      final d = DateTime.parse(date);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) {
      return date;
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final props = widget.event.extendedProps;

    return Scaffold(
      backgroundColor: _Colors.surface,
      body: Column(
        children: [
          _buildGradientHeader(props),
          Expanded(
            child: isLoading
                ? _buildLoader()
                : errorMessage != null
                    ? _buildError()
                    : FadeTransition(
                        opacity: _fadeAnim,
                        child: _buildBody(props),
                      ),
          ),
        ],
      ),
    );
  }

  // ── Gradient Header ────────────────────────────────────────────────────────

  Widget _buildGradientHeader(CalendarEventProps props) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_Colors.primary, _Colors.primaryGlow],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          existingReport != null
                              ? 'Edit Work Report'
                              : 'Add Work Report',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          props.userName,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!canEdit && !isLoading)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.visibility_rounded,
                              color: Colors.white, size: 13),
                          SizedBox(width: 4),
                          Text('View Only',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Body ───────────────────────────────────────────────────────────────────

  Widget _buildBody(CalendarEventProps props) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAttendanceCard(props),
          const SizedBox(height: 12),
          if (props.isIncompleteShift)
            _buildBanner(
              icon: Icons.access_time_rounded,
              message: 'Incomplete shift — check-out is missing.',
              color: _Colors.info,
            ),
          if (props.isAbsentWithCheckin)
            _buildBanner(
              icon: Icons.warning_amber_rounded,
              message:
                  'Marked absent but has a check-in. You can still submit a report.',
              color: _Colors.amber,
            ),
          if (!canEdit && existingReport != null)
            _buildBanner(
              icon: Icons.lock_outline_rounded,
              message: 'This report is in read-only mode.',
              color: _Colors.textSoft,
            ),
          const SizedBox(height: 4),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSection(
                  icon: Icons.edit_note_rounded,
                  title: 'Work Description',
                  required: true,
                  child: _textArea(
                    controller: _descController,
                    hint: 'Describe the work you completed today...',
                    minLines: 4,
                    enabled: canEdit,
                    validator: (v) => (v == null || v.trim().length < 10)
                        ? 'Minimum 10 characters required'
                        : null,
                  ),
                ),
                _buildSection(
                  icon: Icons.checklist_rounded,
                  title: 'Tasks Completed',
                  child: _textArea(
                    controller: _tasksController,
                    hint: 'List specific tasks completed...',
                    minLines: 3,
                    enabled: canEdit,
                  ),
                ),
                _buildSectionRaw(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildInlineField(
                          icon: Icons.timer_outlined,
                          label: 'Hours Worked',
                          required: true,
                          child: _textField(
                            controller: _hoursController,
                            hint: '9.0',
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            enabled: canEdit,
                            validator: (v) {
                              final h = double.tryParse(v ?? '');
                              if (h == null || h <= 0 || h > 24) {
                                return 'Enter valid hours';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInlineField(
                          icon: Icons.flag_outlined,
                          label: 'Status',
                          child: _statusDropdown(),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildSection(
                  icon: Icons.report_problem_outlined,
                  title: 'Challenges Faced',
                  child: _textArea(
                    controller: _challengesController,
                    hint: 'Any challenges or blockers encountered...',
                    minLines: 2,
                    enabled: canEdit,
                  ),
                ),
                _buildSection(
                  icon: Icons.calendar_month_outlined,
                  title: 'Next Day Plan',
                  child: _textArea(
                    controller: _nextDayController,
                    hint: 'Plans for tomorrow...',
                    minLines: 2,
                    enabled: canEdit,
                  ),
                ),
                const SizedBox(height: 8),
                if (canEdit) _actionButtons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Attendance Card ────────────────────────────────────────────────────────

  Widget _buildAttendanceCard(CalendarEventProps props) {
    String statusLabel;
    Color statusColor = _attendanceColor(props.status);

    if (props.isIncompleteShift) {
      statusLabel = 'Incomplete';
      statusColor = _Colors.info;
    } else if (props.isAbsentWithCheckin) {
      statusLabel = 'Absent (Check-in)';
      statusColor = _Colors.amber;
    } else {
      statusLabel = props.status.replaceAll('-', ' ').toUpperCase();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _Colors.primaryLight.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: _Colors.primary.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_Colors.primary, _Colors.primaryGlow],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.event_available_rounded,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Attendance Details',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _Colors.textDark,
                  ),
                ),
                const Spacer(),
                _statusChip(statusLabel, statusColor),
              ],
            ),
          ),
          // Info row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _infoTile(
                        icon: Icons.calendar_today_rounded,
                        label: 'Date',
                        value: _displayDate(props.date),
                        iconColor: _Colors.primaryLight,
                      ),
                    ),
                    _verticalDivider(),
                    Expanded(
                      child: _infoTile(
                        icon: Icons.login_rounded,
                        label: 'Check In',
                        value: props.checkIn ?? '—',
                        iconColor: _Colors.accent,
                      ),
                    ),
                    _verticalDivider(),
                    Expanded(
                      child: _infoTile(
                        icon: Icons.logout_rounded,
                        label: 'Check Out',
                        value: props.checkOut ??
                            (props.isIncompleteShift ? 'Pending' : '—'),
                        iconColor:
                            props.isIncompleteShift
                                ? _Colors.amber
                                : _Colors.danger,
                      ),
                    ),
                  ],
                ),
                if (props.leaveTypeName != null) ...[
                  const Divider(height: 20, color: _Colors.border),
                  Row(children: [
                    const Icon(Icons.beach_access_rounded,
                        size: 14, color: _Colors.textSoft),
                    const SizedBox(width: 6),
                    Text('Leave: ${props.leaveTypeName}',
                        style: const TextStyle(
                            color: _Colors.textMid,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 0.3,
          ),
        ),
      );

  Widget _verticalDivider() => Container(
      width: 1, height: 40, color: _Colors.border, margin:
          const EdgeInsets.symmetric(horizontal: 4));

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  color: _Colors.textSoft, fontSize: 10)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: _Colors.textDark,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );

  // ── Section wrappers ───────────────────────────────────────────────────────

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Widget child,
    bool required = false,
  }) {
    return _buildSectionRaw(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: _Colors.primaryLight),
            const SizedBox(width: 6),
            Text(title,
                style: const TextStyle(
                    color: _Colors.textDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
            if (required)
              const Text(' *',
                  style: TextStyle(color: _Colors.danger, fontSize: 13)),
          ]),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildSectionRaw({required Widget child}) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: child,
      );

  Widget _buildInlineField({
    required IconData icon,
    required String label,
    required Widget child,
    bool required = false,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: _Colors.primaryLight),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    color: _Colors.textDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
            if (required)
              const Text(' *',
                  style: TextStyle(color: _Colors.danger, fontSize: 13)),
          ]),
          const SizedBox(height: 8),
          child,
        ],
      );

  Widget _buildBanner({
    required IconData icon,
    required String message,
    required Color color,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w500))),
        ]),
      );

  // ── Form fields ────────────────────────────────────────────────────────────

  InputDecoration _inputDeco(String hint, bool enabled) => InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: _Colors.textSoft, fontSize: 13),
        filled: true,
        fillColor: enabled
            ? const Color(0xFFF8FBF9)
            : const Color(0xFFF2F4F3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _Colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _Colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: _Colors.primary, width: 1.8),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFECEFED)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: _Colors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: _Colors.danger, width: 1.8),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        errorStyle: const TextStyle(fontSize: 11),
      );

  Widget _textArea({
    required TextEditingController controller,
    required String hint,
    required int minLines,
    bool enabled = true,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: controller,
        minLines: minLines,
        maxLines: minLines + 2,
        enabled: enabled,
        validator: validator,
        style: const TextStyle(
            fontSize: 14, color: _Colors.textDark, height: 1.5),
        decoration: _inputDeco(hint, enabled),
      );

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(fontSize: 14, color: _Colors.textDark),
        decoration: _inputDeco(hint, enabled),
      );

  Widget _statusDropdown() => DropdownButtonFormField<String>(
        value: reportStatus,
        onChanged: canEdit
            ? (v) => setState(() => reportStatus = v ?? 'submitted')
            : null,
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(12),
        decoration: InputDecoration(
          filled: true,
          fillColor: canEdit
              ? const Color(0xFFF8FBF9)
              : const Color(0xFFF2F4F3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _Colors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _Colors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: _Colors.primary, width: 1.8),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        style:
            const TextStyle(fontSize: 14, color: _Colors.textDark),
        icon: const Icon(Icons.keyboard_arrow_down_rounded,
            color: _Colors.textMid),
        items: const [
          DropdownMenuItem(value: 'submitted', child: Text('Submit')),
          DropdownMenuItem(
              value: 'draft', child: Text('Save as Draft')),
        ],
      );

  // ── Action buttons ─────────────────────────────────────────────────────────

  Widget _actionButtons() => Row(
        children: [
          if (existingReport != null) ...[
            _circleDeleteButton(),
            const SizedBox(width: 12),
          ],
          Expanded(child: _saveButton()),
        ],
      );

  Widget _circleDeleteButton() => SizedBox(
        width: 52,
        height: 52,
        child: OutlinedButton(
          onPressed: isDeleting ? null : _delete,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: _Colors.danger, width: 1.5),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: isDeleting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _Colors.danger))
              : const Icon(Icons.delete_outline_rounded,
                  color: _Colors.danger, size: 22),
        ),
      );

  Widget _saveButton() => SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ).copyWith(
            backgroundColor: WidgetStateProperty.all(Colors.transparent),
            shadowColor: WidgetStateProperty.all(Colors.transparent),
          ),
          child: Ink(
            decoration: BoxDecoration(
              gradient: isSaving
                  ? null
                  : const LinearGradient(
                      colors: [_Colors.primary, _Colors.primaryGlow],
                    ),
              color: isSaving ? _Colors.textSoft : null,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Container(
              alignment: Alignment.center,
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.save_rounded,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          existingReport != null
                              ? 'Update Report'
                              : 'Save Report',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      );

  // ── Loader & Error ─────────────────────────────────────────────────────────

  Widget _buildLoader() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: const AlwaysStoppedAnimation(_Colors.primary),
                backgroundColor: _Colors.primary.withOpacity(0.12),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Loading report...',
                style: TextStyle(color: _Colors.textMid, fontSize: 14)),
          ],
        ),
      );

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _Colors.danger.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wifi_off_rounded,
                    color: _Colors.danger, size: 34),
              ),
              const SizedBox(height: 16),
              const Text('Something went wrong',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: _Colors.textDark)),
              const SizedBox(height: 8),
              Text(errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: _Colors.textMid, fontSize: 13, height: 1.5)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _Colors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      );
}