// lib/features/minutes_of_meeting/presentation/view_mom_sheet.dart

import 'package:flutter/material.dart';
import '../../../../core/services/api_service.dart';
import '../data/models/minutes_of_meeting_model.dart';

class ViewMomSheet extends StatefulWidget {
  final int momId;
  final int projectId;
  final VoidCallback? onUpdated;

  const ViewMomSheet({
    super.key,
    required this.momId,
    required this.projectId,
    this.onUpdated,
  });

  @override
  State<ViewMomSheet> createState() => _ViewMomSheetState();
}

class _ViewMomSheetState extends State<ViewMomSheet> {
  MinutesOfMeetingModel? _mom;
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
      final mom = await ApiService.fetchMomDetails(widget.momId);
      if (!mounted) return;
      setState(() {
        _mom = mom;
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
        // Handle
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
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
          ),
          child: Row(children: [
            const Icon(Icons.file_present_outlined,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Minutes of Meeting',
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
        else if (_mom != null)
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildContent(_mom!),
            ),
          ),
        if (_mom != null)
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
                child: _DownloadPdfButton2(momId: widget.momId),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _buildContent(MinutesOfMeetingModel mom) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Meeting details card
      _infoCard([
        _infoRow('Title', mom.title),
        _infoRow('Date', mom.meetingDateFormatted ?? mom.meetingDate),
        _infoRow('Time', mom.meetingTimeFormatted ?? 'Not specified'),
        _infoRow('Venue', mom.venue ?? 'Not specified'),
        if (mom.creator != null)
          _infoRow(
              'Prepared By',
              '${mom.creator!['name'] ?? ''} (${mom.creator!['email'] ?? ''})'),
      ]),
      const SizedBox(height: 16),

      // Attendees
      _sectionTitle('Attendees'),
      const SizedBox(height: 8),
      ...mom.attendees.map((a) => _attendeeChip(a)),
      const SizedBox(height: 16),

      // Description
      _sectionTitle('Minutes of Meeting'),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          mom.description,
          style: const TextStyle(
              fontSize: 13, color: Color(0xFF1E293B), height: 1.6),
        ),
      ),
    ]);
  }

  Widget _infoCard(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: rows
            .asMap()
            .entries
            .map((e) => Column(children: [
                  e.value,
                  if (e.key < rows.length - 1)
                    const Divider(height: 1, color: Color(0xFFEFF3F8)),
                ]))
            .toList(),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 100,
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

  Widget _attendeeChip(MomAttendeeModel a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: a.isOriginal
            ? const Color(0xFFF0F9FF)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: a.isOriginal
                ? const Color(0xFFBAE6FD)
                : const Color(0xFFE2E8F0)),
      ),
      child: Row(children: [
        const Icon(Icons.person_outline,
            size: 14, color: Color(0xFF64748B)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              Text(a.fullName,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B))),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: a.isOriginal
                      ? const Color(0xFF0D6EFD)
                      : const Color(0xFF94A3B8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  a.isOriginal ? 'Original' : 'Additional',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ]),
            if (a.organisation != null && a.organisation!.isNotEmpty)
              Text(a.organisation!,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF64748B))),
            Text(a.email,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF64748B))),
          ]),
        ),
      ]),
    );
  }
}

// Download button for view sheet
class _DownloadPdfButton2 extends StatefulWidget {
  final int momId;
  const _DownloadPdfButton2({required this.momId});

  @override
  State<_DownloadPdfButton2> createState() => _DownloadPdfButton2State();
}

class _DownloadPdfButton2State extends State<_DownloadPdfButton2> {
  bool _downloading = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _downloading ? null : _download,
      icon: _downloading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.download_outlined, size: 15),
      label: Text(_downloading ? 'Downloading...' : 'Download PDF',
          style: const TextStyle(fontSize: 13)),
      style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF198754),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8))),
    );
  }

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      await ApiService.downloadMomPdf(widget.momId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('PDF downloaded'),
        backgroundColor: Color(0xFF198754),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }
}