import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/services/api_service.dart';
import '../data/models/minutes_of_meeting_model.dart';
import 'add_mom_sheet.dart';
import 'mom_calendar_widget.dart';
import 'schedule_meeting_sheet.dart';
import 'view_mom_sheet.dart';
import 'view_scheduled_meeting_sheet.dart';

class MinutesOfMeetingPage extends StatefulWidget {
  final int projectId;
  final String projectName;
  final bool isAdmin;

  const MinutesOfMeetingPage({
    super.key,
    required this.projectId,
    required this.projectName,
    this.isAdmin = false,
  });

  @override
  State<MinutesOfMeetingPage> createState() => _MinutesOfMeetingPageState();
}

class _MinutesOfMeetingPageState extends State<MinutesOfMeetingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<CalendarMeetingEvent> _calendarEvents = [];
  List<ScheduledMeetingModel> _meetingsList = [];

  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;

  DateTime _currentMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!mounted) return;

    if (silent) {
      setState(() => _isRefreshing = true);
    } else {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait([
        ApiService.fetchCalendarEvents(widget.projectId),
        ApiService.fetchMeetingsList(widget.projectId),
      ]);

      if (!mounted) return;

      setState(() {
        _calendarEvents = results[0] as List<CalendarMeetingEvent>;
        _meetingsList = results[1] as List<ScheduledMeetingModel>;
        _isLoading = false;
        _isRefreshing = false;
        _error = null;
      });
    } catch (e) {
      developer.log('[MOM] loadData error: $e', name: 'MOM');

      if (!mounted) return;

      setState(() {
        if (!silent) _error = e.toString();
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  void _openScheduleMeeting({String? prefilledDate}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScheduleMeetingSheet(
        projectId: widget.projectId,
        prefilledDate: prefilledDate,
      ),
    );

    if (result == true) {
      _loadData(silent: true);
    }
  }

  void _openAddMom({int? scheduledMeetingId, String? prefilledDate}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddMomSheet(
        projectId: widget.projectId,
        scheduledMeetingId: scheduledMeetingId,
        prefilledDate: prefilledDate,
      ),
    );

    if (result == true) {
      _loadData(silent: true);
    }
  }

  void _openViewMom(int momId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ViewMomSheet(
        momId: momId,
        projectId: widget.projectId,
        onUpdated: () => _loadData(silent: true),
      ),
    );
  }

  void _openViewScheduled(int meetingId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ViewScheduledMeetingSheet(
        meetingId: meetingId,
        onAddMom: (id) {
          Navigator.pop(context);
          Future.delayed(const Duration(milliseconds: 300), () {
            _openAddMom(scheduledMeetingId: id);
          });
        },
      ),
    );
  }

  void _deleteMeeting(int meetingId) async {
    final confirm = await _showConfirmDialog(
      'Delete Meeting',
      'Are you sure you want to delete this scheduled meeting?',
    );
    if (!confirm) return;

    try {
      await ApiService.deleteScheduledMeeting(meetingId);
      if (mounted) {
        _showSnack('Meeting deleted successfully', isError: false);
        _loadData(silent: true);
      }
    } catch (e) {
      if (mounted) _showSnack(e.toString(), isError: true);
    }
  }

  void _deleteMom(int momId) async {
    final confirm = await _showConfirmDialog(
      'Delete MOM',
      'Are you sure you want to delete this Minutes of Meeting?',
    );
    if (!confirm) return;

    try {
      await ApiService.deleteMom(momId);
      if (mounted) {
        _showSnack('MOM deleted successfully', isError: false);
        _loadData(silent: true);
      }
    } catch (e) {
      if (mounted) _showSnack(e.toString(), isError: true);
    }
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _showSnack(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF198754)),
            )
          : _error != null
              ? _buildError()
              : _buildBody(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.projectName,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const Text(
            'Minutes of Meeting',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ],
      ),
      actions: [
        if (_isRefreshing)
          const Padding(
            padding: EdgeInsets.only(right: 14),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF198754),
              ),
            ),
          )
        else
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
            onPressed: () => _loadData(),
          ),
        _buildAddMenu(),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(46),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF198754),
            unselectedLabelColor: const Color(0xFF94A3B8),
            indicatorColor: const Color(0xFF198754),
            indicatorWeight: 2.5,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            unselectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            tabs: const [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_month_outlined, size: 14),
                    SizedBox(width: 5),
                    Text('Calendar'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.list_alt_outlined, size: 14),
                    SizedBox(width: 5),
                    Text('Meetings List'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddMenu() {
    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFF198754),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 18),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (val) {
        if (val == 'schedule') _openScheduleMeeting();
        if (val == 'mom') _openAddMom();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'schedule',
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: Color(0xFF198754),
              ),
              SizedBox(width: 10),
              Text(
                'Schedule Meeting',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'mom',
          child: Row(
            children: [
              Icon(
                Icons.file_present_outlined,
                size: 16,
                color: Color(0xFF3B82F6),
              ),
              SizedBox(width: 10),
              Text(
                'Add Minutes of Meeting',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildCalendarTab(),
        _buildListTab(),
      ],
    );
  }

  Widget _buildCalendarTab() {
    return RefreshIndicator(
      onRefresh: () => _loadData(),
      color: const Color(0xFF198754),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 12),
            MomCalendarWidget(
              events: _calendarEvents,
              currentMonth: _currentMonth,
              onMonthChanged: (m) => setState(() => _currentMonth = m),
              onDayTapped: (date, events) => _showDayMeetings(date, events),
            ),
            const SizedBox(height: 12),
            _buildLegend(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _legendItem(
            color: const Color(0xFFE7F3FF),
            borderColor: const Color(0xFF0D6EFD),
            label: 'Today',
          ),
          _legendItem(
            color: const Color(0xFFD1F4DD),
            borderColor: const Color(0xFF198754),
            label: 'Has Meeting',
          ),
          _legendItem(
            color: const Color(0xFFFFE6E6),
            borderColor: const Color(0xFFDC3545),
            label: 'Multiple',
          ),
        ],
      ),
    );
  }

  Widget _legendItem({
    required Color color,
    required Color borderColor,
    required String label,
  }) {
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: borderColor, width: 1.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
        ),
      ],
    );
  }

  void _showDayMeetings(String date, List<CalendarMeetingEvent> events) {
    final formattedDate = _formatDisplayDate(date);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DayMeetingsSheet(
        date: formattedDate,
        rawDate: date,
        events: events,
        onSchedule: () {
          Navigator.pop(context);
          Future.delayed(const Duration(milliseconds: 300), () {
            _openScheduleMeeting(prefilledDate: date);
          });
        },
        onAddMom: (id) {
          Navigator.pop(context);
          Future.delayed(const Duration(milliseconds: 300), () {
            _openAddMom(scheduledMeetingId: id);
          });
        },
        onAddMomBlank: () {
          Navigator.pop(context);
          Future.delayed(const Duration(milliseconds: 300), () {
            _openAddMom(prefilledDate: date);
          });
        },
      ),
    );
  }

  String _formatDisplayDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('MMMM d, yyyy').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildListTab() {
    if (_meetingsList.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadData(),
        color: const Color(0xFF198754),
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 52,
                      color: const Color(0xFF198754).withOpacity(0.3),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No meetings yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Schedule a meeting or add meeting minutes',
                      style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _openScheduleMeeting,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Schedule Meeting'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF198754),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadData(),
      color: const Color(0xFF198754),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _meetingsList.length,
        itemBuilder: (_, i) => _buildMeetingCard(_meetingsList[i]),
      ),
    );
  }

  Widget _buildMeetingCard(ScheduledMeetingModel meeting) {
    final hasMom = meeting.hasMom;
    final statusColor =
        hasMom ? const Color(0xFF198754) : const Color(0xFF0D6EFD);
    final statusLabel = hasMom ? 'MOM Added' : 'Scheduled';
    final bgColor =
        hasMom ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC);
    final borderColor =
        hasMom ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meeting.meetingTitle,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 12,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            meeting.meetingDateFormatted ?? meeting.meetingDate,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          if (meeting.meetingTimeFormatted != null &&
                              meeting.meetingTimeFormatted != 'N/A') ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.access_time_outlined,
                              size: 12,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              meeting.meetingTimeFormatted!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (meeting.venue != null && meeting.venue!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 12,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      meeting.venue!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if ((meeting.attendeesCount ?? 0) > 0) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.people_outline,
                    size: 12,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${meeting.attendeesCount} attendees',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 10),
            _buildMeetingActions(meeting),
          ],
        ),
      ),
    );
  }

  Widget _buildMeetingActions(ScheduledMeetingModel meeting) {
    if (meeting.hasMom && meeting.momId != null) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _actionBtn(
            label: 'View MOM',
            color: const Color(0xFF0D6EFD),
            icon: Icons.visibility_outlined,
            onTap: () => _openViewMom(meeting.momId!),
          ),
          _actionBtn(
            label: 'Edit MOM',
            color: const Color(0xFFF59E0B),
            icon: Icons.edit_outlined,
            onTap: () => _openEditMom(meeting.momId!),
          ),
          _downloadPdfBtn(meeting.momId!),
          _actionBtn(
            label: 'Delete',
            color: const Color(0xFFEF4444),
            icon: Icons.delete_outline,
            onTap: () => _deleteMom(meeting.momId!),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _actionBtn(
          label: 'View',
          color: const Color(0xFF0D6EFD),
          icon: Icons.visibility_outlined,
          onTap: () => _openViewScheduled(meeting.id),
        ),
        _actionBtn(
          label: 'Add MOM',
          color: const Color(0xFF198754),
          icon: Icons.file_present_outlined,
          onTap: () => _openAddMom(scheduledMeetingId: meeting.id),
        ),
        _actionBtn(
          label: 'Delete',
          color: const Color(0xFFEF4444),
          icon: Icons.delete_outline,
          onTap: () => _deleteMeeting(meeting.id),
        ),
      ],
    );
  }

  Widget _actionBtn({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration:
            BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _downloadPdfBtn(int momId) {
    return _DownloadPdfButton(momId: momId);
  }

  void _openEditMom(int momId) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddMomSheet(
        projectId: widget.projectId,
        editMomId: momId,
      ),
    );

    if (result == true) {
      _loadData(silent: true);
    }
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
            const SizedBox(height: 12),
            Text(
              _error ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF1E293B), fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _loadData(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF198754),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadPdfButton extends StatefulWidget {
  final int momId;

  const _DownloadPdfButton({required this.momId});

  @override
  State<_DownloadPdfButton> createState() => _DownloadPdfButtonState();
}

class _DownloadPdfButtonState extends State<_DownloadPdfButton> {
  bool _downloading = false;

  Future<void> _download() async {
    if (_downloading) return;

    setState(() => _downloading = true);

    try {
      await ApiService.downloadMomPdf(widget.momId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF downloaded successfully'),
          backgroundColor: Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download PDF: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _download,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF198754),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_downloading)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Colors.white,
                ),
              )
            else
              const Icon(
                Icons.download_outlined,
                size: 12,
                color: Colors.white,
              ),
            const SizedBox(width: 5),
            const Text(
              'PDF',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayMeetingsSheet extends StatelessWidget {
  final String date;
  final String rawDate;
  final List<CalendarMeetingEvent> events;
  final VoidCallback onSchedule;
  final Function(int meetingId) onAddMom;
  final VoidCallback onAddMomBlank;

  const _DayMeetingsSheet({
    required this.date,
    required this.rawDate,
    required this.events,
    required this.onSchedule,
    required this.onAddMom,
    required this.onAddMomBlank,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: Color(0xFF198754),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Meetings on $date',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onSchedule,
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text(
                      'Schedule Meeting',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF198754),
                      side: const BorderSide(color: Color(0xFF198754)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onAddMomBlank,
                    icon: const Icon(Icons.file_present_outlined, size: 14),
                    label: const Text(
                      'Add MOM',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D6EFD),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.event_available_outlined,
                    size: 40,
                    color: const Color(0xFF198754).withOpacity(0.3),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No meetings on this date',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  ),
                ],
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: events.length,
                itemBuilder: (_, i) => _buildEventItem(events[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEventItem(CalendarMeetingEvent event) {
    final isScheduled = event.type == 'scheduled';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: isScheduled
                ? const Color(0xFF0D6EFD)
                : const Color(0xFF198754),
            width: 4,
          ),
          right: const BorderSide(color: Color(0xFFE2E8F0)),
          top: const BorderSide(color: Color(0xFFE2E8F0)),
          bottom: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (event.time != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    _formatTime(event.time!),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isScheduled
                        ? const Color(0xFF0D6EFD)
                        : const Color(0xFF198754),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isScheduled ? 'Scheduled' : 'MOM Added',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isScheduled)
            GestureDetector(
              onTap: () => onAddMom(event.id),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF198754),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Add MOM',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(String time) {
    try {
      final parts = time.split(':');
      if (parts.length >= 2) {
        final h = int.parse(parts[0]);
        final m = parts[1].padLeft(2, '0');
        final ampm = h >= 12 ? 'PM' : 'AM';
        final h12 = h % 12 == 0 ? 12 : h % 12;
        return '$h12:$m $ampm';
      }
    } catch (_) {}
    return time;
  }
}