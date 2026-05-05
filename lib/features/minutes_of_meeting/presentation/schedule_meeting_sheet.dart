// lib/features/minutes_of_meeting/presentation/schedule_meeting_sheet.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/api_service.dart';

class ScheduleMeetingSheet extends StatefulWidget {
  final int projectId;
  final String? prefilledDate;

  const ScheduleMeetingSheet({
    super.key,
    required this.projectId,
    this.prefilledDate,
  });

  @override
  State<ScheduleMeetingSheet> createState() => _ScheduleMeetingSheetState();
}

class _ScheduleMeetingSheetState extends State<ScheduleMeetingSheet> {
  final _titleCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();
  final _agendaCtrl = TextEditingController();
  DateTime? _meetingDate;
  TimeOfDay? _meetingTime;
  bool _isSaving = false;

  final List<Map<String, TextEditingController>> _attendees = [];

  @override
  void initState() {
    super.initState();
    // Prefill date if provided
    if (widget.prefilledDate != null) {
      try {
        _meetingDate = DateTime.parse(widget.prefilledDate!);
      } catch (_) {}
    }
    _addAttendeeRow();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _venueCtrl.dispose();
    _agendaCtrl.dispose();
    for (final row in _attendees) {
      row['name']!.dispose();
      row['org']!.dispose();
      row['email']!.dispose();
    }
    super.dispose();
  }

  void _addAttendeeRow() {
    setState(() {
      _attendees.add({
        'name': TextEditingController(),
        'org': TextEditingController(),
        'email': TextEditingController(),
      });
    });
  }

  void _removeAttendeeRow(int idx) {
    if (_attendees.length <= 1) return;
    final row = _attendees[idx];
    row['name']!.dispose();
    row['org']!.dispose();
    row['email']!.dispose();
    setState(() => _attendees.removeAt(idx));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _meetingDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              const ColorScheme.light(primary: Color(0xFF198754)),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _meetingDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _meetingTime ?? TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              const ColorScheme.light(primary: Color(0xFF198754)),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _meetingTime = picked);
  }

  String get _dateDisplay => _meetingDate == null
      ? 'Select meeting date *'
      : DateFormat('dd/MM/yyyy').format(_meetingDate!);

  String get _timeDisplay => _meetingTime == null
      ? 'Select meeting time'
      : _meetingTime!.format(context);

  String get _isoDate => _meetingDate == null
      ? ''
      : '${_meetingDate!.year}-${_meetingDate!.month.toString().padLeft(2, '0')}-${_meetingDate!.day.toString().padLeft(2, '0')}';

  String get _isoTime => _meetingTime == null
      ? ''
      : '${_meetingTime!.hour.toString().padLeft(2, '0')}:${_meetingTime!.minute.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (_isSaving) return;

    if (_titleCtrl.text.trim().isEmpty) {
      _showError('Please enter a meeting title');
      return;
    }
    if (_meetingDate == null) {
      _showError('Please select a meeting date');
      return;
    }

    final validAttendees = _attendees.where((row) {
      return row['name']!.text.trim().isNotEmpty &&
          row['email']!.text.trim().isNotEmpty;
    }).map((row) => {
          'full_name': row['name']!.text.trim(),
          'organisation': row['org']!.text.trim(),
          'email': row['email']!.text.trim(),
        }).toList();

    if (validAttendees.isEmpty) {
      _showError('Please add at least one attendee with name and email');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final result = await ApiService.storeScheduledMeeting(
        projectId: widget.projectId,
        meetingTitle: _titleCtrl.text.trim(),
        meetingDate: _isoDate,
        meetingTime: _isoTime.isEmpty ? null : _isoTime,
        venue: _venueCtrl.text.trim().isEmpty ? null : _venueCtrl.text.trim(),
        meetingAgenda: _agendaCtrl.text.trim().isEmpty
            ? null
            : _agendaCtrl.text.trim(),
        attendees: validAttendees,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['message']?.toString() ??
            'Meeting scheduled and invitations sent!'),
        backgroundColor: const Color(0xFF198754),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _buildHandle(),
        _buildHeader(),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              _fieldLabel('Meeting Title *'),
              _textField(_titleCtrl, hint: 'e.g., Monthly Project Review'),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    _fieldLabel('Meeting Date *'),
                    _datePickerField(_dateDisplay, _pickDate,
                        hasValue: _meetingDate != null),
                  ]),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    _fieldLabel('Meeting Time'),
                    _datePickerField(_timeDisplay, _pickTime,
                        hasValue: _meetingTime != null,
                        icon: Icons.access_time_outlined),
                  ]),
                ),
              ]),
              const SizedBox(height: 14),
              _fieldLabel('Venue'),
              _textField(_venueCtrl, hint: 'e.g., Conference Room A'),
              const SizedBox(height: 14),
              _fieldLabel('Attendees *'),
              ..._attendees.asMap().entries.map(
                    (e) => _attendeeRow(e.key, e.value),
                  ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _addAttendeeRow,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: const Color(0xFF198754).withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFF198754).withValues(alpha: 0.04),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_circle_outline,
                        size: 15, color: Color(0xFF198754)),
                    SizedBox(width: 6),
                    Text('Add Another Attendee',
                        style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF198754),
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
              _fieldLabel('Meeting Agenda'),
              _textField(_agendaCtrl,
                  hint: 'Enter the meeting agenda...', maxLines: 4),
            ]),
          ),
        ),
        _buildFooter(),
      ]),
    );
  }

  Widget _attendeeRow(int idx, Map<String, TextEditingController> row) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Attendee ${idx + 1}',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B))),
          const Spacer(),
          if (_attendees.length > 1)
            GestureDetector(
              onTap: () => _removeAttendeeRow(idx),
              child: const Icon(Icons.remove_circle_outline,
                  size: 16, color: Color(0xFFEF4444)),
            ),
        ]),
        const SizedBox(height: 8),
        _textField(row['name']!, hint: 'Full Name *'),
        const SizedBox(height: 6),
        _textField(row['org']!, hint: 'Organisation / Company'),
        const SizedBox(height: 6),
        _textField(row['email']!,
            hint: 'Email ID *', type: TextInputType.emailAddress),
      ]),
    );
  }

  Widget _buildHandle() => Center(
        child: Container(
          margin: const EdgeInsets.only(top: 12, bottom: 4),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2)),
        ),
      );

  Widget _buildHeader() => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
        ),
        child: Row(children: [
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text('Schedule New Meeting',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
              SizedBox(height: 2),
              Text('Fill in details and send invitations',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 12)),
            ]),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.close,
                    color: Colors.white, size: 18)),
          ),
        ]),
      );

  Widget _buildFooter() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isSaving ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF374151),
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              child: const Text('Close',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _submit,
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_outlined, size: 15),
              label: Text(
                  _isSaving ? 'Scheduling...' : 'Schedule & Send',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF198754),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
            ),
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

  Widget _textField(
    TextEditingController ctrl, {
    String? hint,
    TextInputType? type,
    int maxLines = 1,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: type,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: Color(0xFF198754), width: 1.5)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        ),
      );

  Widget _datePickerField(String display, VoidCallback onTap,
          {bool hasValue = false,
          IconData icon = Icons.calendar_today_outlined}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD1D5DB)),
              borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Expanded(
                child: Text(display,
                    style: TextStyle(
                        fontSize: 13,
                        color: hasValue
                            ? const Color(0xFF1E293B)
                            : const Color(0xFF9CA3AF)))),
            Icon(icon, size: 16, color: const Color(0xFF6B7280)),
          ]),
        ),
      );
}