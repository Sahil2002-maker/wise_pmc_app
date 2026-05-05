// lib/features/minutes_of_meeting/presentation/add_mom_sheet.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/api_service.dart';
import '../data/models/minutes_of_meeting_model.dart';

class AddMomSheet extends StatefulWidget {
  final int projectId;
  final int? scheduledMeetingId;
  final int? editMomId;
  final String? prefilledDate;

  const AddMomSheet({
    super.key,
    required this.projectId,
    this.scheduledMeetingId,
    this.editMomId,
    this.prefilledDate,
  });

  @override
  State<AddMomSheet> createState() => _AddMomSheetState();
}

class _AddMomSheetState extends State<AddMomSheet> {
  final _titleCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime? _meetingDate;
  TimeOfDay? _meetingTime;
  bool _isSaving = false;
  bool _isLoadingMeeting = false;
  bool _isLoadingMom = false;

  // Original attendees from scheduled meeting
  List<MomAttendeeModel> _originalAttendees = [];
  // Additional attendees
  final List<Map<String, TextEditingController>> _additionalAttendees = [];

  bool get isEdit => widget.editMomId != null;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledDate != null) {
      try {
        _meetingDate = DateTime.parse(widget.prefilledDate!);
      } catch (_) {}
    }
    _addAdditionalAttendeeRow();

    if (widget.editMomId != null) {
      _loadMomForEdit(widget.editMomId!);
    } else if (widget.scheduledMeetingId != null) {
      _loadScheduledMeeting(widget.scheduledMeetingId!);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _venueCtrl.dispose();
    _descCtrl.dispose();
    for (final row in _additionalAttendees) {
      row['name']!.dispose();
      row['org']!.dispose();
      row['email']!.dispose();
    }
    super.dispose();
  }

  Future<void> _loadScheduledMeeting(int meetingId) async {
    setState(() => _isLoadingMeeting = true);
    try {
      final meeting =
          await ApiService.fetchScheduledMeetingForMom(meetingId);
      if (!mounted) return;
      setState(() {
        _titleCtrl.text = meeting.meetingTitle;
        try {
          _meetingDate = DateTime.parse(meeting.meetingDate);
        } catch (_) {}
        if (meeting.meetingTime != null && meeting.meetingTime!.isNotEmpty) {
          final parts = meeting.meetingTime!.split(':');
          if (parts.length >= 2) {
            _meetingTime = TimeOfDay(
              hour: int.tryParse(parts[0]) ?? 0,
              minute: int.tryParse(parts[1]) ?? 0,
            );
          }
        }
        _venueCtrl.text = meeting.venue ?? '';
        _originalAttendees = meeting.attendees;
        _isLoadingMeeting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMeeting = false);
    }
  }

  Future<void> _loadMomForEdit(int momId) async {
    setState(() => _isLoadingMom = true);
    try {
      final mom = await ApiService.fetchMomDetails(momId);
      if (!mounted) return;
      // Clear extra row added in initState
      for (final row in _additionalAttendees) {
        row['name']!.dispose();
        row['org']!.dispose();
        row['email']!.dispose();
      }
      _additionalAttendees.clear();

      setState(() {
        _titleCtrl.text = mom.title;
        try {
          _meetingDate = DateTime.parse(mom.meetingDate);
        } catch (_) {}
        if (mom.meetingTime != null && mom.meetingTime!.isNotEmpty) {
          final parts = mom.meetingTime!.split(':');
          if (parts.length >= 2) {
            _meetingTime = TimeOfDay(
              hour: int.tryParse(parts[0]) ?? 0,
              minute: int.tryParse(parts[1]) ?? 0,
            );
          }
        }
        _venueCtrl.text = mom.venue ?? '';
        _descCtrl.text = mom.description;
        _originalAttendees =
            mom.attendees.where((a) => a.isOriginal).toList();

        final extraAttendees =
            mom.attendees.where((a) => !a.isOriginal).toList();
        if (extraAttendees.isEmpty) {
          _addAdditionalAttendeeRow();
        } else {
          for (final a in extraAttendees) {
            _additionalAttendees.add({
              'name': TextEditingController(text: a.fullName),
              'org': TextEditingController(text: a.organisation ?? ''),
              'email': TextEditingController(text: a.email),
            });
          }
        }
        _isLoadingMom = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMom = false;
        _addAdditionalAttendeeRow();
      });
    }
  }

  void _addAdditionalAttendeeRow() {
    setState(() {
      _additionalAttendees.add({
        'name': TextEditingController(),
        'org': TextEditingController(),
        'email': TextEditingController(),
      });
    });
  }

  void _removeAdditionalAttendeeRow(int idx) {
    if (_additionalAttendees.length <= 1) return;
    final row = _additionalAttendees[idx];
    row['name']!.dispose();
    row['org']!.dispose();
    row['email']!.dispose();
    setState(() => _additionalAttendees.removeAt(idx));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _meetingDate ?? DateTime.now(),
      firstDate: DateTime(2020),
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

  String get _isoDate => _meetingDate == null
      ? ''
      : DateFormat('yyyy-MM-dd').format(_meetingDate!);

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
    if (_descCtrl.text.trim().isEmpty) {
      _showError('Please enter meeting minutes description');
      return;
    }

    final additionalAttendees = _additionalAttendees.where((row) {
      return row['name']!.text.trim().isNotEmpty &&
          row['email']!.text.trim().isNotEmpty;
    }).map((row) => {
          'full_name': row['name']!.text.trim(),
          'organisation': row['org']!.text.trim(),
          'email': row['email']!.text.trim(),
        }).toList();

    setState(() => _isSaving = true);

    try {
      Map<String, dynamic> result;

      if (isEdit) {
        result = await ApiService.updateMom(
          momId: widget.editMomId!,
          title: _titleCtrl.text.trim(),
          meetingDate: _isoDate,
          meetingTime: _isoTime.isEmpty ? null : _isoTime,
          venue:
              _venueCtrl.text.trim().isEmpty ? null : _venueCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          additionalAttendees: additionalAttendees,
        );
      } else {
        result = await ApiService.storeMom(
          projectId: widget.projectId,
          scheduledMeetingId: widget.scheduledMeetingId,
          title: _titleCtrl.text.trim(),
          meetingDate: _isoDate,
          meetingTime: _isoTime.isEmpty ? null : _isoTime,
          venue:
              _venueCtrl.text.trim().isEmpty ? null : _venueCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          additionalAttendees: additionalAttendees,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['message']?.toString() ??
            (isEdit
                ? 'MOM updated successfully!'
                : 'MOM saved, PDF generated and emails sent!')),
        backgroundColor: const Color(0xFF198754),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
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
        if (_isLoadingMeeting || _isLoadingMom)
          const Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(color: Color(0xFF198754)),
          )
        else
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _fieldLabel('Meeting Title *'),
                _textField(_titleCtrl,
                    hint: 'e.g., Monthly Project Review Meeting'),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      _fieldLabel('Meeting Date *'),
                      _datePickerField(
                        _meetingDate == null
                            ? 'Select date *'
                            : DateFormat('dd/MM/yyyy').format(_meetingDate!),
                        _pickDate,
                        hasValue: _meetingDate != null,
                      ),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      _fieldLabel('Meeting Time'),
                      _datePickerField(
                        _meetingTime == null
                            ? 'Select time'
                            : _meetingTime!.format(context),
                        _pickTime,
                        hasValue: _meetingTime != null,
                        icon: Icons.access_time_outlined,
                      ),
                    ]),
                  ),
                ]),
                const SizedBox(height: 14),
                _fieldLabel('Venue'),
                _textField(_venueCtrl,
                    hint: 'e.g., Conference Room A, Building 3'),
                const SizedBox(height: 14),

                // Original attendees (from scheduled meeting)
                if (_originalAttendees.isNotEmpty) ...[
                  _fieldLabel('Original Attendees'),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFFBAE6FD)),
                    ),
                    child: Column(
                      children: _originalAttendees
                          .map((a) => Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 6),
                                child: Row(children: [
                                  const Icon(Icons.person_outline,
                                      size: 13,
                                      color: Color(0xFF0284C7)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(a.fullName,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1E293B))),
                                      if (a.organisation != null &&
                                          a.organisation!.isNotEmpty)
                                        Text(a.organisation!,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color:
                                                    Color(0xFF64748B))),
                                      Text(a.email,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF64748B))),
                                    ]),
                                  ),
                                ]),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Additional attendees
                _fieldLabel('Additional Attendees'),
                ..._additionalAttendees.asMap().entries.map(
                      (e) => _additionalAttendeeRow(e.key, e.value),
                    ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _addAdditionalAttendeeRow,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: const Color(0xFF198754)
                              .withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(8),
                      color: const Color(0xFF198754)
                          .withValues(alpha: 0.04),
                    ),
                    child:
                        const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.person_add_outlined,
                          size: 14, color: Color(0xFF198754)),
                      SizedBox(width: 6),
                      Text('Add Additional Attendee',
                          style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF198754),
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),

                // Description
                _fieldLabel('Minutes of Meeting Description *'),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD1D5DB)),
                  ),
                  child: Column(children: [
                    TextField(
                      controller: _descCtrl,
                      maxLines: 8,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF1E293B)),
                      decoration: InputDecoration(
                        hintText: 'Enter meeting minutes...',
                        hintStyle: const TextStyle(
                            fontSize: 13, color: Color(0xFFCBD5E1)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(12),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: Color(0xFF198754), width: 1.5),
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.info_outline,
                        size: 13, color: Color(0xFF198754)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Saving will auto-generate a PDF and send it to all attendees via email.',
                        style: TextStyle(
                            fontSize: 11, color: Color(0xFF166534)),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        _buildFooter(),
      ]),
    );
  }

  Widget _additionalAttendeeRow(
      int idx, Map<String, TextEditingController> row) {
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
          if (_additionalAttendees.length > 1)
            GestureDetector(
              onTap: () => _removeAdditionalAttendeeRow(idx),
              child: const Icon(Icons.remove_circle_outline,
                  size: 16, color: Color(0xFFEF4444)),
            ),
        ]),
        const SizedBox(height: 8),
        _textField(row['name']!, hint: 'Full Name'),
        const SizedBox(height: 6),
        _textField(row['org']!, hint: 'Organisation / Company'),
        const SizedBox(height: 6),
        _textField(row['email']!,
            hint: 'Email ID', type: TextInputType.emailAddress),
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
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(
                isEdit
                    ? 'Edit Minutes of Meeting'
                    : 'Minutes of Meeting',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                isEdit
                    ? 'Update meeting details'
                    : 'Save MOM & Generate PDF',
                style: const TextStyle(
                    color: Colors.white70, fontSize: 12),
              ),
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
                  : Icon(
                      isEdit ? Icons.save_outlined : Icons.picture_as_pdf_outlined,
                      size: 15),
              label: Text(
                  _isSaving
                      ? 'Saving...'
                      : (isEdit
                          ? 'Update MOM'
                          : 'Save MoM & Generate PDF'),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D6EFD),
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

  Widget _textField(TextEditingController ctrl,
          {String? hint, TextInputType? type, int maxLines = 1}) =>
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