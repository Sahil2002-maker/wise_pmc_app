// lib/features/minutes_of_meeting/presentation/view_scheduled_meeting_sheet.dart

import 'package:flutter/material.dart';
import '../../../../core/services/api_service.dart';
import '../data/models/minutes_of_meeting_model.dart';

class ViewScheduledMeetingSheet extends StatefulWidget {
  final int meetingId;
  final Function(int meetingId) onAddMom;

  const ViewScheduledMeetingSheet({
    super.key,
    required this.meetingId,
    required this.onAddMom,
  });

  @override
  State<ViewScheduledMeetingSheet> createState() =>
      _ViewScheduledMeetingSheetState();
}

class _ViewScheduledMeetingSheetState
    extends State<ViewScheduledMeetingSheet> {
  ScheduledMeetingModel? _meeting;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final meeting =
          await ApiService.fetchScheduledMeetingDetails(widget.meetingId);
      if (!mounted) return;
      setState(() {
        _meeting = meeting;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2)),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
          ),
          child: Row(children: [
            const Icon(Icons.calendar_today_outlined,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Scheduled Meeting',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
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
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(color: Color(0xFF198754)),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!,
                style: const TextStyle(color: Color(0xFFEF4444))),
          )
        else if (_meeting != null)
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildContent(_meeting!),
            ),
          ),
        if (_meeting != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8))),
                  child: const Text('Close'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () =>
                      widget.onAddMom(widget.meetingId),
                  icon: const Icon(Icons.file_present_outlined, size: 15),
                  label: const Text('Add MOM',
                      style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF198754),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
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

  Widget _buildContent(ScheduledMeetingModel m) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Meeting info
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(children: [
          _infoRow('Title', m.meetingTitle),
          const Divider(height: 1, color: Color(0xFFEFF3F8)),
          _infoRow('Date',
              m.meetingDateFormatted ?? m.meetingDate),
          const Divider(height: 1, color: Color(0xFFEFF3F8)),
          _infoRow('Time',
              m.meetingTimeFormatted ?? 'Time not specified'),
          const Divider(height: 1, color: Color(0xFFEFF3F8)),
          _infoRow('Venue', m.venue ?? 'Not specified'),
        ]),
      ),
      if (m.meetingAgenda != null && m.meetingAgenda!.isNotEmpty) ...[
        const SizedBox(height: 16),
        _sectionTitle('Agenda'),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(m.meetingAgenda!,
              style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF1E293B),
                  height: 1.6)),
        ),
      ],
      if (m.attendees.isNotEmpty) ...[
        const SizedBox(height: 16),
        _sectionTitle('Attendees (${m.attendees.length})'),
        const SizedBox(height: 8),
        ...m.attendees.map((a) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(children: [
                const Icon(Icons.person_outline,
                    size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                              fontSize: 11, color: Color(0xFF64748B))),
                    Text(a.email,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF64748B))),
                  ]),
                ),
              ]),
            )),
      ],
    ]);
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 80,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B))),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF1E293B))),
        ),
      ]),
    );
  }

  Widget _sectionTitle(String title) {
    return Row(children: [
      Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
              color: const Color(0xFF198754),
              borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(title.toUpperCase(),
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
              letterSpacing: 0.5)),
    ]);
  }
}