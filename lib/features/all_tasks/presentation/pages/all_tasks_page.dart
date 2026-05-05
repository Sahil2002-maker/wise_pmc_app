// lib/features/all_tasks/presentation/pages/all_tasks_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../widgets/task_stats_row.dart';
import '../widgets/task_tab_bar.dart';
import '../widgets/task_list_view.dart';
import '../../data/models/all_task_models.dart';

class AllTasksPage extends StatefulWidget {
  const AllTasksPage({super.key});

  @override
  State<AllTasksPage> createState() => _AllTasksPageState();
}

class _AllTasksPageState extends State<AllTasksPage>
    with SingleTickerProviderStateMixin {
  // ── Tab controller ──────────────────────────────────────────────────────────
  late final TabController _tabController;
  final List<String> _tabs    = ['All', 'General', 'Project'];
  final List<String> _tabKeys = ['all', 'general', 'project'];

  // ── Filter state ────────────────────────────────────────────────────────────
  List<TeamModel>     _teams     = [];
  List<EmployeeModel> _employees = [];
  TeamModel?          _selectedTeam;
  EmployeeModel?      _selectedEmployee;

  // ── Task state ──────────────────────────────────────────────────────────────
  List<TaskItem>     _tasks          = [];
  bool               _isLoadingTeams = false;
  bool               _isLoadingEmps  = false;
  bool               _isLoadingTasks = false;
  bool               _isLoadingMore  = false;
  String?            _errorMessage;
  String?            _teamsError;
  String?            _employeesError;
  int                _currentPage    = 1;
  int                _totalPages     = 1;
  String             _searchQuery    = '';
  TaskStatsCombined? _stats;

  // ── Load-state flags ────────────────────────────────────────────────────────
  bool _teamsLoaded     = false;
  bool _employeesLoaded = false;

  // ── Controllers ─────────────────────────────────────────────────────────────
  final TextEditingController _taskSearchController = TextEditingController();
  final ScrollController      _scrollController     = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
    _loadTeams();
    _loadAllEmployees();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _taskSearchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Friendly error message helper ────────────────────────────────────────────

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (e is SocketException ||
        msg.contains('SocketException') ||
        msg.contains('Failed host lookup') ||
        msg.contains('ClientException') ||
        msg.contains('errno = 7')) {
      return 'No internet connection or server is unreachable.\nPlease check your network and try again.';
    }
    if (msg.contains('TimeoutException') || msg.contains('timed out')) {
      return 'The request timed out. Please check your connection and try again.';
    }
    if (msg.contains('HandshakeException') || msg.contains('CERTIFICATE')) {
      return 'Secure connection failed. Please try again.';
    }
    if (msg.contains('401') || msg.contains('Unauthorized')) {
      return 'Session expired. Please log in again.';
    }
    if (msg.contains('403') || msg.contains('Forbidden')) {
      return 'You are not authorized to perform this action.';
    }
    if (msg.contains('404') || msg.contains('Not Found')) {
      return 'The requested data was not found on the server.';
    }
    if (msg.contains('500') || msg.contains('Internal Server Error')) {
      return 'A server error occurred. Please try again later.';
    }
    // Trim raw exception prefix for cleaner display
    if (msg.startsWith('Exception: ')) return msg.replaceFirst('Exception: ', '');
    if (msg.startsWith('ClientException')) {
      return 'Network error. Please check your connection and try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  // ── Data loading ─────────────────────────────────────────────────────────────

  Future<void> _loadTeams() async {
    if (!mounted) return;
    setState(() {
      _isLoadingTeams = true;
      _teamsLoaded    = false;
      _teamsError     = null;
    });
    try {
      debugPrint('[AllTasks] Fetching teams...');
      final teams = await ApiService.fetchAllTaskTeams();
      debugPrint('[AllTasks] Teams fetched: ${teams.length}');
      if (mounted) {
        setState(() {
          _teams       = teams;
          _teamsLoaded = true;
          _teamsError  = teams.isEmpty ? 'No teams available on the server.' : null;
        });
      }
    } catch (e) {
      debugPrint('[AllTasks] Teams error: $e');
      if (mounted) {
        setState(() {
          _teamsLoaded = true;
          _teamsError  = _friendlyError(e);
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingTeams = false);
    }
  }

  Future<void> _loadAllEmployees() async {
    if (!mounted) return;
    setState(() {
      _isLoadingEmps   = true;
      _employeesLoaded = false;
      _employeesError  = null;
      _employees       = [];
    });
    try {
      debugPrint('[AllTasks] Fetching employees...');
      final emps = await ApiService.fetchAllTaskEmployees();
      debugPrint('[AllTasks] Employees fetched: ${emps.length}');
      if (mounted) {
        setState(() {
          _employees       = emps;
          _employeesLoaded = true;
          _employeesError  = emps.isEmpty ? 'No employees available on the server.' : null;
        });
      }
    } catch (e) {
      debugPrint('[AllTasks] Employees error: $e');
      if (mounted) {
        setState(() {
          _employeesLoaded = true;
          _employeesError  = _friendlyError(e);
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingEmps = false);
    }
  }

  Future<void> _loadTeamMembers(int teamId) async {
    if (!mounted) return;
    setState(() {
      _isLoadingEmps   = true;
      _employeesLoaded = false;
      _employeesError  = null;
      _employees       = [];
    });
    try {
      debugPrint('[AllTasks] Fetching team members for teamId=$teamId...');
      final emps = await ApiService.fetchAllTaskTeamMembers(teamId);
      debugPrint('[AllTasks] Team members fetched: ${emps.length}');
      if (mounted) {
        setState(() {
          _employees       = emps;
          _employeesLoaded = true;
          _employeesError  = emps.isEmpty ? 'No members found in this team.' : null;
        });
      }
    } catch (e) {
      debugPrint('[AllTasks] Team members error: $e');
      if (mounted) {
        setState(() {
          _employeesLoaded = true;
          _employeesError  = _friendlyError(e);
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingEmps = false);
    }
  }

  // ── Filter actions ────────────────────────────────────────────────────────────

  void _onTeamSelected(TeamModel? team) {
    setState(() {
      _selectedTeam     = team;
      _selectedEmployee = null;
      _employeesLoaded  = false;
      _employeesError   = null;
    });
    if (team != null) {
      _loadTeamMembers(team.id);
    } else {
      _loadAllEmployees();
    }
  }

  void _onEmployeeSelected(EmployeeModel? employee) {
    setState(() => _selectedEmployee = employee);
  }

  void _applyFilter() {
    if (_selectedEmployee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Please select an employee first.',
                  style: TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
          backgroundColor: Colors.orange[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }
    _resetAndFetch();
    _loadStatistics();
  }

  void _clearFilter() {
    setState(() {
      _selectedTeam     = null;
      _selectedEmployee = null;
      _tasks            = [];
      _stats            = null;
      _errorMessage     = null;
      _currentPage      = 1;
      _totalPages       = 1;
      _searchQuery      = '';
      _employeesLoaded  = false;
      _employeesError   = null;
    });
    _taskSearchController.clear();
    _loadAllEmployees();
  }

  // ── Task fetching ─────────────────────────────────────────────────────────────

  void _resetAndFetch() {
    setState(() {
      _tasks        = [];
      _currentPage  = 1;
      _totalPages   = 1;
      _errorMessage = null;
    });
    _fetchTasks();
  }

  Future<void> _fetchTasks({bool loadMore = false}) async {
    if (_selectedEmployee == null) return;
    setState(() => loadMore ? _isLoadingMore = true : _isLoadingTasks = true);
    try {
      final page   = loadMore ? _currentPage : 1;
      final tab    = _tabKeys[_tabController.index];
      final result = await ApiService.fetchAllTasks(
        userId:  _selectedEmployee!.id,
        tab:     tab,
        search:  _searchQuery.isEmpty ? null : _searchQuery,
        page:    page,
        perPage: 15,
      );
      if (!mounted) return;
      setState(() {
        if (loadMore) {
          _tasks.addAll(result.data);
        } else {
          _tasks       = result.data;
          _currentPage = 1;
        }
        _totalPages   = result.totalPages;
        _errorMessage = null;
      });
    } catch (e) {
      if (mounted) setState(() => _errorMessage = _friendlyError(e));
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTasks = false;
          _isLoadingMore  = false;
        });
      }
    }
  }

  Future<void> _loadStatistics() async {
  if (_selectedEmployee == null) return;
  try {
    final stats = await ApiService.fetchAllTaskStatistics(_selectedEmployee!.id);
    debugPrint('[AllTasks] Stats loaded: '
        'total=${stats.statistics.totalTasks} '      // should now show 71
        'completed=${stats.statistics.completedTasks} ' // should now show 48
        'pending=${stats.statistics.pendingTasks} '  // should now show 23
        'overdue=${stats.statistics.overdueTasks}'); // should now show 0
    if (mounted) setState(() => _stats = stats);
  } catch (e) {
    debugPrint('[AllTasks] Stats error: $e');
  }
}

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    if (_selectedEmployee != null) _resetAndFetch();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _currentPage < _totalPages) {
        setState(() => _currentPage++);
        _fetchTasks(loadMore: true);
      }
    }
  }

  Future<void> _onRefresh() async {
    if (_selectedEmployee != null) {
      _resetAndFetch();
      _loadStatistics();
    }
  }

  // ── Open team picker ──────────────────────────────────────────────────────────

  Future<void> _openTeamPicker() async {
    if (_isLoadingTeams) {
      _showLoadingSnackBar('Loading teams, please wait...');
      return;
    }

    // If not yet loaded or failed, try loading first
    if (!_teamsLoaded) {
      await _loadTeams();
    }
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SearchSheet<TeamModel>(
        title:        'Filter by Team',
        items:        List.from(_teams),
        value:        _selectedTeam,
        isLoading:    false,
        errorMessage: _teamsError,
        onRetry: () {
          Navigator.pop(context);
          _loadTeams().then((_) {
            if (mounted) {
              Future.delayed(const Duration(milliseconds: 200), _openTeamPicker);
            }
          });
        },
        itemLabel:    (t) => t.displayText,
        itemSubLabel: (t) =>
            '${t.memberCount} member${t.memberCount != 1 ? 's' : ''}',
        allowNull:    true,
        nullLabel:    'All Teams',
        nullSubLabel: 'Show tasks from all teams',
        onSelected: (team) {
          Navigator.pop(context);
          _onTeamSelected(team);
        },
      ),
    );
  }

  // ── Open employee picker ──────────────────────────────────────────────────────

  Future<void> _openEmployeePicker() async {
    if (_isLoadingEmps) {
      _showLoadingSnackBar('Loading employees, please wait...');
      return;
    }

    // If not yet loaded or failed, try loading first
    if (!_employeesLoaded) {
      if (_selectedTeam != null) {
        await _loadTeamMembers(_selectedTeam!.id);
      } else {
        await _loadAllEmployees();
      }
    }
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SearchSheet<EmployeeModel>(
        title:        'Select Employee / Team Leader',
        items:        List.from(_employees),
        value:        _selectedEmployee,
        isLoading:    false,
        errorMessage: _employeesError,
        onRetry: () {
          Navigator.pop(context);
          final reload = _selectedTeam != null
              ? _loadTeamMembers(_selectedTeam!.id)
              : _loadAllEmployees();
          reload.then((_) {
            if (mounted) {
              Future.delayed(
                  const Duration(milliseconds: 200), _openEmployeePicker);
            }
          });
        },
        itemLabel:    (e) => e.name,
        itemSubLabel: (e) {
          if (e.roleDisplay != null && e.roleDisplay!.isNotEmpty) {
            return e.roleDisplay!;
          }
          return e.isLeader ? 'Team Leader' : 'Employee';
        },
        allowNull:    false,
        onSelected: (emp) {
          Navigator.pop(context);
          _onEmployeeSelected(emp);
        },
      ),
    );
  }

  void _showLoadingSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _FilterCard(
            selectedTeam:     _selectedTeam,
            selectedEmployee: _selectedEmployee,
            isLoadingTeams:   _isLoadingTeams,
            isLoadingEmps:    _isLoadingEmps,
            onTeamTap:        _openTeamPicker,
            onEmployeeTap:    _openEmployeePicker,
            onApply:          _applyFilter,
            onClear:          _clearFilter,
          ),

          if (_stats != null) ...[
            const SizedBox(height: 4),
            TaskStatsRow(stats: _stats!),
          ],

          if (_selectedEmployee != null) ...[
            const SizedBox(height: 4),
            TaskTabBar(
              tabController:    _tabController,
              tabs:             _tabs,
              searchController: _taskSearchController,
              onSearchChanged: (val) {
                _searchQuery = val;
                _resetAndFetch();
              },
            ),
          ],

          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: AppColors.textDark, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'All Tasks',
        style: TextStyle(
          color: AppColors.textDark,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        if (_selectedEmployee != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.refresh_rounded,
                    color: AppColors.primaryGreen, size: 18),
              ),
              onPressed: _onRefresh,
            ),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFEEF0F3)),
      ),
    );
  }

  Widget _buildBody() {
    if (_selectedEmployee == null) return _buildEmptyState();
    if (_isLoadingTasks)           return _buildLoader();
    if (_errorMessage != null)     return _buildError();
    if (_tasks.isEmpty)            return _buildNoTasksState();

    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: _onRefresh,
      child: TaskListView(
        tasks:            _tasks,
        scrollController: _scrollController,
        isLoadingMore:    _isLoadingMore,
        
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96, height: 96,
            decoration: BoxDecoration(
              gradient: RadialGradient(colors: [
                AppColors.primaryGreen.withValues(alpha: 0.15),
                AppColors.primaryGreen.withValues(alpha: 0.04),
              ]),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_search_outlined,
                color: AppColors.primaryGreen, size: 44),
          ),
          const SizedBox(height: 20),
          const Text('Select an Employee',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              )),
          const SizedBox(height: 8),
          Text(
            'Choose an employee or team leader\nto view their assigned tasks.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textDark.withValues(alpha: 0.45),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoader() => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      );

  Widget _buildError() {
    final bool isNetworkError = _errorMessage != null &&
        (_errorMessage!.contains('internet') ||
         _errorMessage!.contains('unreachable') ||
         _errorMessage!.contains('timed out') ||
         _errorMessage!.contains('connection'));

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  shape: BoxShape.circle),
              child: Icon(
                isNetworkError
                    ? Icons.wifi_off_rounded
                    : Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 38,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isNetworkError ? 'Connection Failed' : 'Something Went Wrong',
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textDark.withValues(alpha: 0.55),
                  fontSize: 13,
                  height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: _resetAndFetch,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoTasksState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96, height: 96,
            decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.08),
                shape: BoxShape.circle),
            child: const Icon(Icons.assignment_turned_in_outlined,
                color: Colors.grey, size: 44),
          ),
          const SizedBox(height: 20),
          const Text('No Tasks Found',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              )),
          const SizedBox(height: 8),
          Text('No tasks match the selected filters.',
              style: TextStyle(
                  color: AppColors.textDark.withValues(alpha: 0.45),
                  fontSize: 14)),
        ],
      ),
    );
  }

  void _showUploadSheet(TaskItem task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _UploadSheet(
        task: task,
        onUploaded: () {
          Navigator.pop(context);
          _resetAndFetch();
          _loadStatistics();
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter Card
// ─────────────────────────────────────────────────────────────────────────────

class _FilterCard extends StatelessWidget {
  final TeamModel?     selectedTeam;
  final EmployeeModel? selectedEmployee;
  final bool           isLoadingTeams;
  final bool           isLoadingEmps;
  final VoidCallback   onTeamTap;
  final VoidCallback   onEmployeeTap;
  final VoidCallback   onApply;
  final VoidCallback   onClear;

  const _FilterCard({
    required this.selectedTeam,
    required this.selectedEmployee,
    required this.isLoadingTeams,
    required this.isLoadingEmps,
    required this.onTeamTap,
    required this.onEmployeeTap,
    required this.onApply,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasFilter = selectedTeam != null || selectedEmployee != null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title row ──────────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.filter_list_rounded,
                  color: AppColors.primaryGreen, size: 16),
              const SizedBox(width: 6),
              const Text('Filter Tasks',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  )),
              const Spacer(),
              if (hasFilter)
                GestureDetector(
                  onTap: onClear,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close_rounded,
                            color: Colors.redAccent, size: 11),
                        SizedBox(width: 3),
                        Text('Clear',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            )),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Dropdowns + Apply in one row ───────────────────────────────
          Row(
            children: [
              // Team picker
              Expanded(
                child: _CompactDropdown(
                  icon: Icons.groups_rounded,
                  hint: 'All Teams',
                  value: selectedTeam?.displayText,
                  isLoading: isLoadingTeams,
                  onTap: onTeamTap,
                ),
              ),
              const SizedBox(width: 8),
              // Employee picker
              Expanded(
                child: _CompactDropdown(
                  icon: Icons.person_rounded,
                  hint: 'Employee *',
                  value: selectedEmployee?.name,
                  isLoading: isLoadingEmps,
                  onTap: onEmployeeTap,
                ),
              ),
              const SizedBox(width: 8),
              // Apply button
              SizedBox(
                height: 42,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: onApply,
                  child: const Text('Apply',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactDropdown extends StatelessWidget {
  final IconData     icon;
  final String       hint;
  final String?      value;
  final bool         isLoading;
  final VoidCallback onTap;

  const _CompactDropdown({
    required this.icon,
    required this.hint,
    required this.value,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasValue = value != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: hasValue
              ? AppColors.primaryGreen.withValues(alpha: 0.04)
              : const Color(0xFFF8F9FB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasValue
                ? AppColors.primaryGreen.withValues(alpha: 0.45)
                : const Color(0xFFDFE3EA),
            width: hasValue ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 15,
                color: hasValue
                    ? AppColors.primaryGreen
                    : AppColors.textDark.withValues(alpha: 0.3)),
            const SizedBox(width: 6),
            Expanded(
              child: isLoading
                  ? SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryGreen.withValues(alpha: 0.6),
                      ),
                    )
                  : Text(
                      value ?? hint,
                      style: TextStyle(
                        color: hasValue
                            ? AppColors.textDark
                            : AppColors.textDark.withValues(alpha: 0.38),
                        fontSize: 12,
                        fontWeight:
                            hasValue ? FontWeight.w600 : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: hasValue
                  ? AppColors.primaryGreen
                  : AppColors.textDark.withValues(alpha: 0.3),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool   required;
  const _FieldLabel({required this.label, this.required = false});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: AppColors.textDark,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        children: required
            ? const [TextSpan(text: ' *', style: TextStyle(color: Colors.redAccent))]
            : [],
      ),
    );
  }
}

class _DropdownTile extends StatelessWidget {
  final IconData     icon;
  final String       hint;
  final String?      value;
  final String?      subValue;
  final bool         isLoading;
  final VoidCallback onTap;

  const _DropdownTile({
    required this.icon,
    required this.hint,
    required this.value,
    required this.isLoading,
    required this.onTap,
    this.subValue,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasValue = value != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: hasValue
              ? AppColors.primaryGreen.withValues(alpha: 0.04)
              : const Color(0xFFF8F9FB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasValue
                ? AppColors.primaryGreen.withValues(alpha: 0.45)
                : const Color(0xFFDFE3EA),
            width: hasValue ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18,
                color: hasValue
                    ? AppColors.primaryGreen
                    : AppColors.textDark.withValues(alpha: 0.3)),
            const SizedBox(width: 10),
            Expanded(
              child: isLoading
                  ? Row(
                      children: [
                        SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryGreen.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('Loading...',
                            style: TextStyle(
                              color: AppColors.textDark.withValues(alpha: 0.35),
                              fontSize: 13,
                            )),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          value ?? hint,
                          style: TextStyle(
                            color: hasValue
                                ? AppColors.textDark
                                : AppColors.textDark.withValues(alpha: 0.38),
                            fontSize: 13,
                            fontWeight:
                                hasValue ? FontWeight.w600 : FontWeight.w400,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subValue != null) ...[
                          const SizedBox(height: 1),
                          Text(
                            subValue!,
                            style: TextStyle(
                              color: AppColors.primaryGreen.withValues(alpha: 0.75),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
            const SizedBox(width: 6),
            isLoading
                ? const SizedBox.shrink()
                : Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: hasValue
                        ? AppColors.primaryGreen
                        : AppColors.textDark.withValues(alpha: 0.3),
                    size: 20,
                  ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search Sheet  ── generic, with error + retry support
// ─────────────────────────────────────────────────────────────────────────────

class _SearchSheet<T> extends StatefulWidget {
  final String             title;
  final List<T>            items;
  final T?                 value;
  final bool               isLoading;
  final String?            errorMessage;
  final VoidCallback?      onRetry;
  final String Function(T) itemLabel;
  final String Function(T) itemSubLabel;
  final bool               allowNull;
  final String?            nullLabel;
  final String?            nullSubLabel;
  final ValueChanged<T?>   onSelected;

  const _SearchSheet({
    required this.title,
    required this.items,
    required this.value,
    required this.isLoading,
    required this.itemLabel,
    required this.itemSubLabel,
    required this.allowNull,
    required this.onSelected,
    this.errorMessage,
    this.onRetry,
    this.nullLabel,
    this.nullSubLabel,
  });

  @override
  State<_SearchSheet<T>> createState() => _SearchSheetState<T>();
}

class _SearchSheetState<T> extends State<_SearchSheet<T>> {
  final TextEditingController _ctrl = TextEditingController();
  late List<T> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.items);
    _ctrl.addListener(_filter);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_filter);
    _ctrl.dispose();
    super.dispose();
  }

  void _filter() {
    final q = _ctrl.text.toLowerCase().trim();
    setState(() {
      _filtered = q.isEmpty
          ? List.from(widget.items)
          : widget.items
              .where((i) =>
                  widget.itemLabel(i).toLowerCase().contains(q) ||
                  widget.itemSubLabel(i).toLowerCase().contains(q))
              .toList();
    });
  }

  bool _isSelected(T item) {
    if (widget.value == null) return false;
    return widget.itemLabel(widget.value as T) == widget.itemLabel(item);
  }

  // ── FIX: Show error state whenever errorMessage is set, regardless of items ──
  bool get _hasError => widget.errorMessage != null;

  bool get _isNetworkError {
    if (widget.errorMessage == null) return false;
    final msg = widget.errorMessage!;
    return msg.contains('internet') ||
        msg.contains('unreachable') ||
        msg.contains('connection') ||
        msg.contains('timed out') ||
        msg.contains('network');
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.78;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 14),

          // ── Title ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(widget.title,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      )),
                ),
                if (!widget.isLoading && !_hasError)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${widget.items.length} total',
                      style: const TextStyle(
                        color: AppColors.primaryGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Loading ────────────────────────────────────────────────────────
          if (widget.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primaryGreen),
                  SizedBox(height: 16),
                  Text('Loading data...',
                      style: TextStyle(
                          color: AppColors.textDark, fontSize: 14)),
                ],
              ),
            )

          // ── Error with Retry ───────────────────────────────────────────────
          else if (_hasError)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.07),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isNetworkError
                          ? Icons.wifi_off_rounded
                          : Icons.cloud_off_rounded,
                      color: Colors.redAccent,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isNetworkError ? 'No Connection' : 'Failed to load data',
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.errorMessage!,
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textDark.withValues(alpha: 0.5),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (widget.onRetry != null)
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: widget.onRetry,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Try Again',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                ],
              ),
            )

          // ── Normal list ────────────────────────────────────────────────────
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _ctrl,
                autofocus: false,
                style: const TextStyle(fontSize: 14, color: AppColors.textDark),
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: TextStyle(
                      color: AppColors.textDark.withValues(alpha: 0.35),
                      fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppColors.primaryGreen, size: 20),
                  suffixIcon: _ctrl.text.isNotEmpty
                      ? GestureDetector(
                          onTap: _ctrl.clear,
                          child: Icon(Icons.close_rounded,
                              color: AppColors.textDark.withValues(alpha: 0.4),
                              size: 18),
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF4F6F9),
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: AppColors.primaryGreen.withValues(alpha: 0.4)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 24),
                children: [
                  if (widget.allowNull && widget.nullLabel != null)
                    _SheetTile(
                      label:      widget.nullLabel!,
                      subLabel:   widget.nullSubLabel ?? '',
                      isSelected: widget.value == null,
                      onTap:      () => widget.onSelected(null),
                    ),

                  if (_filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded,
                                color: AppColors.textDark.withValues(alpha: 0.22),
                                size: 38),
                            const SizedBox(height: 10),
                            Text(
                              widget.items.isEmpty
                                  ? 'No data available'
                                  : 'No results found',
                              style: TextStyle(
                                color: AppColors.textDark.withValues(alpha: 0.4),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._filtered.map(
                      (item) => _SheetTile(
                        label:      widget.itemLabel(item),
                        subLabel:   widget.itemSubLabel(item),
                        isSelected: _isSelected(item),
                        onTap:      () => widget.onSelected(item),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  final String       label;
  final String       subLabel;
  final bool         isSelected;
  final VoidCallback onTap;

  const _SheetTile({
    required this.label,
    required this.subLabel,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGreen.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryGreen.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.primaryGreen
                            : AppColors.textDark,
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                      )),
                  if (subLabel.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subLabel,
                        style: TextStyle(
                          color: AppColors.textDark.withValues(alpha: 0.42),
                          fontSize: 11,
                        )),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 22, height: 22,
                decoration: const BoxDecoration(
                  color: AppColors.primaryGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 13),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Upload Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _UploadSheet extends StatefulWidget {
  final TaskItem     task;
  final VoidCallback onUploaded;

  const _UploadSheet({required this.task, required this.onUploaded});

  @override
  State<_UploadSheet> createState() => _UploadSheetState();
}

class _UploadSheetState extends State<_UploadSheet> {
  bool    _uploading = false;
  String? _errorMsg;

  Future<void> _pickAndUpload() async {
    // Uncomment when file_picker is configured:
    //
    // final result = await FilePicker.platform.pickFiles();
    // if (result == null || result.files.single.path == null) return;
    // final file = File(result.files.single.path!);
    // setState(() { _uploading = true; _errorMsg = null; });
    // try {
    //   final ok = await ApiService.uploadAllTaskFile(
    //       widget.task.id, widget.task.taskType, file);
    //   if (ok) widget.onUploaded();
    //   else setState(() => _errorMsg = 'Upload failed. Please try again.');
    // } catch (e) {
    //   setState(() => _errorMsg = e.toString());
    // } finally {
    //   if (mounted) setState(() => _uploading = false);
    // }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.upload_file_rounded,
                    color: AppColors.primaryGreen, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Upload Task File',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                          letterSpacing: -0.2,
                        )),
                    SizedBox(height: 2),
                    Text('Attach a file to this task',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textMutedDark)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.task_alt_rounded,
                    color: AppColors.primaryGreen, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.task.taskName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      )),
                ),
              ],
            ),
          ),
          if (_errorMsg != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Colors.redAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_errorMsg!,
                        style: const TextStyle(
                            color: Colors.red, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _uploading ? null : _pickAndUpload,
              icon: _uploading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.attach_file_rounded, size: 18),
              label: Text(
                _uploading ? 'Uploading...' : 'Choose & Upload File',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}