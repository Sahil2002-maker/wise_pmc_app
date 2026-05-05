// lib/features/re_execution/presentation/re_execution_list_page.dart

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/api_exception.dart';
import '../data/models/re_execution_model.dart';
import '../data/services/re_execution_api_service.dart';
import 're_execution_detail_page.dart';
import 're_execution_form_page.dart';

class ReExecutionListPage extends StatefulWidget {
  final int projectId;
  final String projectName;

  const ReExecutionListPage({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<ReExecutionListPage> createState() => _ReExecutionListPageState();
}

class _ReExecutionListPageState extends State<ReExecutionListPage> {
  final List<ReExecutionModel> _reports = [];
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;

  int _currentPage = 1;
  int _lastPage = 1;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _loadReports();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _currentPage < _lastPage) {
      _loadMore();
    }
  }

  Future<void> _loadReports({bool refresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
      if (refresh) {
        _reports.clear();
        _currentPage = 1;
      }
    });

    try {
      final result = await ReExecutionApiService.fetchReports(
        projectId: widget.projectId,
        page: 1,
      );

      if (!mounted) return;
      final list = result['reports'] as List<ReExecutionModel>;
      setState(() {
        _reports
          ..clear()
          ..addAll(list);
        _currentPage = result['current_page'] as int;
        _lastPage    = result['last_page'] as int;
        _total       = result['total'] as int;
        _isLoading   = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error     = e is ApiException ? e.message : e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (!mounted || _isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final result = await ReExecutionApiService.fetchReports(
        projectId: widget.projectId,
        page: _currentPage + 1,
      );
      if (!mounted) return;
      final list = result['reports'] as List<ReExecutionModel>;
      setState(() {
        _reports.addAll(list);
        _currentPage   = result['current_page'] as int;
        _lastPage      = result['last_page'] as int;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _deleteReport(ReExecutionModel r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Report'),
        content: Text(
          'Delete report for ${r.reportDateDisplay ?? r.reportDate}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ReExecutionApiService.deleteReport(
        projectId: widget.projectId,
        reportId:  r.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Report deleted'),
        backgroundColor: AppColors.primaryGreen,
      ));
      _loadReports(refresh: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: const Color(0xFFEF4444),
      ));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: _buildAppBar(),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final created = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => ReExecutionFormPage(
                  projectId:   widget.projectId,
                  projectName: widget.projectName,
                ),
              ),
            );
            if (created == true) _loadReports(refresh: true);
          },
          backgroundColor: AppColors.primaryGreen,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('New Report',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
        body: _buildBody(),
      );

  AppBar _buildAppBar() => AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Daily Progress Reports',
              style: TextStyle(
                  color: Color(0xFF1E293B), fontWeight: FontWeight.w700, fontSize: 16)),
          Text(widget.projectName,
              style: const TextStyle(
                  color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w400)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
            onPressed: _isLoading ? null : () => _loadReports(refresh: true),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE2E8F0)),
        ),
      );

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: AppColors.primaryGreen),
          const SizedBox(height: 12),
          const Text('Loading reports…', style: TextStyle(color: Color(0xFF64748B))),
        ]),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF1E293B))),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _loadReports(refresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
            ),
          ]),
        ),
      );
    }
    if (_reports.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.description_outlined, size: 56,
              color: AppColors.primaryGreen.withValues(alpha: 0.35)),
          const SizedBox(height: 12),
          const Text('No reports yet',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 16)),
          const SizedBox(height: 6),
          const Text('Tap + to create the first Daily Progress Report',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadReports(refresh: true),
      color: AppColors.primaryGreen,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _reports.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _reports.length) {
            return Center(
                child: Padding(
              padding: const EdgeInsets.all(16),
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            ));
          }
          return _buildReportCard(_reports[i]);
        },
      ),
    );
  }

  Widget _buildReportCard(ReExecutionModel r) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1))
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            final changed = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => ReExecutionDetailPage(
                  projectId:   widget.projectId,
                  reportId:    r.id,
                  projectName: widget.projectName,
                ),
              ),
            );
            if (changed == true) _loadReports(refresh: true);
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 13, color: AppColors.primaryGreen),
                    const SizedBox(width: 5),
                    Text(
                      r.reportDateDisplay ?? r.reportDate ?? 'N/A',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryGreen),
                    ),
                  ]),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF94A3B8)),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit',   child: Text('Edit')),
                    const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete',
                            style: TextStyle(color: Color(0xFFEF4444)))),
                  ],
                  onSelected: (val) async {
                    if (val == 'edit') {
                      final changed = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReExecutionFormPage(
                            projectId:   widget.projectId,
                            projectName: widget.projectName,
                            reportId:    r.id,
                          ),
                        ),
                      );
                      if (changed == true) _loadReports(refresh: true);
                    } else if (val == 'delete') {
                      _deleteReport(r);
                    }
                  },
                ),
              ]),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFEFF3F8)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _statChip(
                  icon: Icons.wb_sunny_outlined,
                  color: const Color(0xFFF59E0B),
                  label: 'Day',
                  value: '${r.totalDayManpower}',
                )),
                const SizedBox(width: 8),
                Expanded(child: _statChip(
                  icon: Icons.nights_stay_outlined,
                  color: const Color(0xFF3B82F6),
                  label: 'Night',
                  value: '${r.totalNightManpower}',
                )),
                const SizedBox(width: 8),
                Expanded(child: _statChip(
                  icon: Icons.photo_library_outlined,
                  color: const Color(0xFF8B5CF6),
                  label: 'Photos',
                  value: '${r.photoCount}',
                )),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.person_outline, size: 13, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Expanded(
                    child: Text(r.createdByName ?? 'N/A',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        overflow: TextOverflow.ellipsis)),
                if (r.createdAt != null)
                  Text(r.createdAt!,
                      style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1))),
              ]),
            ]),
          ),
        ),
      );

  Widget _statChip({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: color)),
          Text(label,
              style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7))),
        ]),
      );
}