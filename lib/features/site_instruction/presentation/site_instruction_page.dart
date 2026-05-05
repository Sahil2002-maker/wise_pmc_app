// lib/features/site_instruction/presentation/site_instruction_page.dart

import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/utils/api_exception.dart';
import '../data/models/site_instruction_model.dart';

class SiteInstructionPage extends StatefulWidget {
  final int projectId;
  final String projectName;

  const SiteInstructionPage({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<SiteInstructionPage> createState() => _SiteInstructionPageState();
}

class _SiteInstructionPageState extends State<SiteInstructionPage> {
  List<SiteInstructionModel> _instructions = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInstructions();
  }

  Future<void> _loadInstructions() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await ApiService.fetchSiteInstructions(widget.projectId);
      if (!mounted) return;
      setState(() {
        _instructions = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openCreateForm() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _SiteInstructionFormPage(
          projectId: widget.projectId,
          projectName: widget.projectName,
        ),
        fullscreenDialog: true,
      ),
    );

    if (result == true) {
      await _loadInstructions();
    }
  }

  Future<void> _openEditForm(SiteInstructionModel instr) async {
    try {
      _showLoadingDialog('Loading instruction...');
      final fresh = await ApiService.fetchSiteInstruction(
        widget.projectId,
        instr.id,
      );
      if (!mounted) return;
      Navigator.pop(context); // close loading

      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => _SiteInstructionFormPage(
            projectId: widget.projectId,
            projectName: widget.projectName,
            existing: fresh,
          ),
          fullscreenDialog: true,
        ),
      );

      if (result == true) {
        await _loadInstructions();
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst || route is PageRoute);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'Failed to load instruction: $e',
          ),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _confirmDelete(SiteInstructionModel instr) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Delete Instruction',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text(
          'Are you sure you want to delete instruction ${instr.instructionNo}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ApiService.deleteSiteInstruction(widget.projectId, instr.id);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Site Instruction deleted successfully'),
          backgroundColor: Color(0xFF22C55E),
        ),
      );

      await _loadInstructions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  void _openView(SiteInstructionModel instr) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SiteInstructionViewPage(
          instruction: instr,
          projectName: widget.projectName,
        ),
      ),
    );
  }

  Future<void> _printInstruction(SiteInstructionModel instr) async {
    try {
      _showLoadingDialog('Preparing print...');
      final bytes = await ApiService.printSiteInstructionPdf(
        widget.projectId,
        instr.id,
      );
      if (!mounted) return;
      Navigator.pop(context);

      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'Site_Instruction_${instr.instructionNo.replaceAll('/', '_')}',
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst || route is PageRoute);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'Print failed: $e',
          ),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _downloadInstruction(SiteInstructionModel instr) async {
    try {
      _showLoadingDialog('Downloading PDF...');
      final bytes = await ApiService.downloadSiteInstructionPdf(
        widget.projectId,
        instr.id,
      );

      final dir = await getTemporaryDirectory();
      final fileName =
          'Site_Instruction_${instr.instructionNo.replaceAll('/', '_')}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      Navigator.pop(context);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Site Instruction PDF',
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst || route is PageRoute);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'Download failed: $e',
          ),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  void _showLoadingDialog(String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(color: AppColors.primaryGreen),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final d = DateTime.parse(dateStr);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryGreen,
              ),
            )
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadInstructions,
                  color: AppColors.primaryGreen,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _buildHeader()),
                      _instructions.isEmpty
                          ? SliverFillRemaining(child: _buildEmpty())
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (_, i) => _buildCard(_instructions[i], i),
                                childCount: _instructions.length,
                              ),
                            ),
                      const SliverToBoxAdapter(child: SizedBox(height: 80)),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateForm,
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'New Instruction',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildHeader() => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primaryGreen.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.menu_book_outlined,
                color: AppColors.primaryGreen,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Site Instructions',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'WR/EXE/10 — ${widget.projectName}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_instructions.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildCard(SiteInstructionModel instr, int index) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.06),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          instr.instructionNo,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                        Text(
                          _formatDate(instr.date),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Site Instruction',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF7C3AED),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _infoItem(
                        Icons.person_outline,
                        'Issued By',
                        instr.issuedBy,
                      ),
                      const SizedBox(width: 16),
                      _infoItem(
                        Icons.person_pin_outlined,
                        'Issued To',
                        instr.issuedTo,
                      ),
                      const SizedBox(width: 16),
                      _infoItem(
                        Icons.link_outlined,
                        'Reference',
                        instr.reference,
                      ),
                    ],
                  ),
                  if (instr.creator != null && instr.creator!.name.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.account_circle_outlined,
                          size: 13,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Created by ${instr.creator!.name}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (instr.instructions != null &&
                      instr.instructions!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'INSTRUCTIONS',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF94A3B8),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            instr.instructions!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF1E293B),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _actionBtn(
                        label: 'View',
                        icon: Icons.visibility_outlined,
                        color: const Color(0xFF0EA5E9),
                        onTap: () => _openView(instr),
                      ),
                      _actionBtn(
                        label: 'Edit',
                        icon: Icons.edit_outlined,
                        color: const Color(0xFFF59E0B),
                        onTap: () => _openEditForm(instr),
                      ),
                      _actionBtn(
                        label: 'Print',
                        icon: Icons.print_outlined,
                        color: const Color(0xFF22C55E),
                        onTap: () => _printInstruction(instr),
                      ),
                      _actionBtn(
                        label: 'PDF',
                        icon: Icons.download_outlined,
                        color: const Color(0xFF8B5CF6),
                        onTap: () => _downloadInstruction(instr),
                      ),
                      _actionBtn(
                        label: 'Delete',
                        icon: Icons.delete_outline,
                        color: const Color(0xFFEF4444),
                        onTap: () => _confirmDelete(instr),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _infoItem(IconData icon, String label, String? value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(icon, size: 11, color: const Color(0xFF64748B)),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    value?.isNotEmpty == true ? value! : 'N/A',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.menu_book_outlined,
                  size: 56,
                  color: Color(0xFF7C3AED),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No Site Instructions',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap the button below to create your first site instruction.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
            ],
          ),
        ),
      );

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Color(0xFFEF4444),
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadInstructions,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// View Page
// ═══════════════════════════════════════════════════════════════════════════

class _SiteInstructionViewPage extends StatelessWidget {
  final SiteInstructionModel instruction;
  final String projectName;

  const _SiteInstructionViewPage({
    required this.instruction,
    required this.projectName,
  });

  String _fmtDate(String? d) {
    if (d == null || d.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(d);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return d;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Site Instruction',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            Text(
              instruction.instructionNo,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'WR/EXE/10',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        'WISE REALTY',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'SITE INSTRUCTION- No- ${instruction.instructionNo}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _sectionCard(
              title: 'Instruction Details',
              icon: Icons.info_outline,
              children: [
                _row2(
                  'Project',
                  projectName,
                  'Project No.',
                  instruction.projectNumber,
                ),
                const SizedBox(height: 10),
                _row2(
                  'Issued By',
                  instruction.issuedBy,
                  'Issued To',
                  instruction.issuedTo,
                ),
                const SizedBox(height: 10),
                _row2(
                  'Reference',
                  instruction.reference,
                  'Date',
                  _fmtDate(instruction.date),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _sectionCard(
              title: 'INSTRUCTIONS',
              icon: Icons.description_outlined,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    instruction.instructions?.isNotEmpty == true
                        ? instruction.instructions!
                        : 'No instructions provided',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1E293B),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _sectionCard(
              title: 'ACTION TAKEN BY CONTRACTOR',
              icon: Icons.engineering_outlined,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    instruction.actionTaken?.isNotEmpty == true
                        ? instruction.actionTaken!
                        : 'No action taken yet',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1E293B),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const SizedBox(height: 52),
                        const Divider(color: Color(0xFF1E293B)),
                        const Text(
                          'Signatures of\nIssuing authority',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Date: ${_fmtDate(instruction.authorityAcceptanceDate)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        const SizedBox(height: 52),
                        const Divider(color: Color(0xFF1E293B)),
                        const Text(
                          'Contractor acceptance\n(Date and signature)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Date: ${_fmtDate(instruction.contractorAcceptanceDate)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: const [
                        SizedBox(height: 52),
                        Divider(color: Color(0xFF1E293B)),
                        Text(
                          'Acceptance of contractor action\n(Date & sign. Of Issuing authority)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Date: _____________',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) =>
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 15, color: const Color(0xFF7C3AED)),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ],
        ),
      );

  Widget _row2(String l1, String? v1, String l2, String? v2) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _infoRow(l1, v1)),
          const SizedBox(width: 12),
          Expanded(child: _infoRow(l2, v2)),
        ],
      );

  Widget _infoRow(String label, String? value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value?.isNotEmpty == true ? value! : 'N/A',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// Form Page (Create / Edit)
// ═══════════════════════════════════════════════════════════════════════════

class _SiteInstructionFormPage extends StatefulWidget {
  final int projectId;
  final String projectName;
  final SiteInstructionModel? existing;

  const _SiteInstructionFormPage({
    required this.projectId,
    required this.projectName,
    this.existing,
  });

  @override
  State<_SiteInstructionFormPage> createState() =>
      _SiteInstructionFormPageState();
}

class _SiteInstructionFormPageState extends State<_SiteInstructionFormPage> {
  final _projectNumberCtrl = TextEditingController();
  final _issuedByCtrl = TextEditingController();
  final _issuedToCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  final _actionTakenCtrl = TextEditingController();

  String _instructionNo = '';
  DateTime? _date;
  DateTime? _contractorAcceptanceDate;
  DateTime? _authorityAcceptanceDate;

  bool _isSaving = false;
  bool _isLoadingNo = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _populateFromExisting();
    } else {
      _date = DateTime.now();
      _loadInstructionNumber();
    }
  }

  void _populateFromExisting() {
    final i = widget.existing!;
    _instructionNo = i.instructionNo;

    try {
      _date = DateTime.parse(i.date);
    } catch (_) {
      _date = DateTime.now();
    }

    _projectNumberCtrl.text = i.projectNumber ?? '';
    _issuedByCtrl.text = i.issuedBy ?? '';
    _issuedToCtrl.text = i.issuedTo ?? '';
    _referenceCtrl.text = i.reference ?? '';
    _instructionsCtrl.text = i.instructions ?? '';
    _actionTakenCtrl.text = i.actionTaken ?? '';

    if (i.contractorAcceptanceDate != null &&
        i.contractorAcceptanceDate!.isNotEmpty) {
      try {
        _contractorAcceptanceDate = DateTime.parse(i.contractorAcceptanceDate!);
      } catch (_) {}
    }

    if (i.authorityAcceptanceDate != null &&
        i.authorityAcceptanceDate!.isNotEmpty) {
      try {
        _authorityAcceptanceDate = DateTime.parse(i.authorityAcceptanceDate!);
      } catch (_) {}
    }
  }

  Future<void> _loadInstructionNumber() async {
    if (!mounted) return;
    setState(() => _isLoadingNo = true);

    try {
      final no =
          await ApiService.generateSiteInstructionNumber(widget.projectId);
      if (mounted) {
        setState(() => _instructionNo = no);
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoadingNo = false);
    }
  }

  @override
  void dispose() {
    _projectNumberCtrl.dispose();
    _issuedByCtrl.dispose();
    _issuedToCtrl.dispose();
    _referenceCtrl.dispose();
    _instructionsCtrl.dispose();
    _actionTakenCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(String field) async {
    DateTime initial;
    switch (field) {
      case 'date':
        initial = _date ?? DateTime.now();
        break;
      case 'contractor':
        initial = _contractorAcceptanceDate ?? DateTime.now();
        break;
      case 'authority':
        initial = _authorityAcceptanceDate ?? DateTime.now();
        break;
      default:
        initial = DateTime.now();
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              ColorScheme.light(primary: AppColors.primaryGreen),
        ),
        child: child!,
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        switch (field) {
          case 'date':
            _date = picked;
            break;
          case 'contractor':
            _contractorAcceptanceDate = picked;
            break;
          case 'authority':
            _authorityAcceptanceDate = picked;
            break;
        }
      });
    }
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return 'Select date';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (_isSaving) return;

    if (_date == null) {
      _showError('Please select a date.');
      return;
    }

    if (!_isEditing && _instructionNo.trim().isEmpty) {
      _showError('Instruction number is still generating. Please wait.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (_isEditing) {
        await ApiService.updateSiteInstruction(
          projectId: widget.projectId,
          id: widget.existing!.id,
          date: _isoDate(_date!),
          projectNumber: _projectNumberCtrl.text.trim(),
          issuedBy: _issuedByCtrl.text.trim(),
          issuedTo: _issuedToCtrl.text.trim(),
          reference: _referenceCtrl.text.trim(),
          instructions: _instructionsCtrl.text.trim(),
          actionTaken: _actionTakenCtrl.text.trim(),
          contractorAcceptanceDate: _contractorAcceptanceDate != null
              ? _isoDate(_contractorAcceptanceDate!)
              : null,
          authorityAcceptanceDate: _authorityAcceptanceDate != null
              ? _isoDate(_authorityAcceptanceDate!)
              : null,
        );
      } else {
        await ApiService.createSiteInstruction(
          projectId: widget.projectId,
          instructionNo: _instructionNo,
          date: _isoDate(_date!),
          projectNumber: _projectNumberCtrl.text.trim(),
          issuedBy: _issuedByCtrl.text.trim(),
          issuedTo: _issuedToCtrl.text.trim(),
          reference: _referenceCtrl.text.trim(),
          instructions: _instructionsCtrl.text.trim(),
          actionTaken: _actionTakenCtrl.text.trim(),
          contractorAcceptanceDate: _contractorAcceptanceDate != null
              ? _isoDate(_contractorAcceptanceDate!)
              : null,
          authorityAcceptanceDate: _authorityAcceptanceDate != null
              ? _isoDate(_authorityAcceptanceDate!)
              : null,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Site Instruction updated successfully!'
                : 'Site Instruction created successfully!',
          ),
          backgroundColor: AppColors.primaryGreen,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showError(e is ApiException ? e.message : e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFEF4444),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? 'Edit Site Instruction' : 'New Site Instruction',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            Text(
              widget.projectName,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _isSaving ? null : _submit,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _isEditing ? 'Update' : 'Save',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeaderSection()),
          SliverToBoxAdapter(child: _buildInstructionsSection()),
          SliverToBoxAdapter(child: _buildActionTakenSection()),
          SliverToBoxAdapter(child: _buildSignatureSection()),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() => _card(
        title: 'Instruction Details',
        icon: Icons.info_outline,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'WR/EXE/10',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text(
                  'WISE REALTY',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _label('Instruction No.'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _isLoadingNo ? 'Generating…' : _instructionNo,
                      style: TextStyle(
                        fontSize: 13,
                        color: _isLoadingNo
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  if (_isLoadingNo)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Project'),
                      _readOnlyField(widget.projectName),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _inputField(
                    _projectNumberCtrl,
                    'Project Number',
                    hint: 'Enter project number',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _inputField(
                    _issuedByCtrl,
                    'Issued By',
                    hint: 'Enter name',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _inputField(
                    _issuedToCtrl,
                    'Issued To',
                    hint: 'Enter name',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _inputField(
                    _referenceCtrl,
                    'Reference',
                    hint: 'Enter reference',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Date *'),
                      _datePicker(
                        value: _date,
                        hint: 'Select date',
                        onTap: () => _pickDate('date'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _buildInstructionsSection() => _card(
        title: 'INSTRUCTIONS',
        icon: Icons.description_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _instructionsCtrl,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: 'Enter site instructions…',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFCBD5E1),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: AppColors.primaryGreen, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      );

  Widget _buildActionTakenSection() => _card(
        title: 'ACTION TAKEN BY CONTRACTOR',
        icon: Icons.engineering_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _actionTakenCtrl,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: 'Enter action taken by contractor…',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFCBD5E1),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: AppColors.primaryGreen, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      );

  Widget _buildSignatureSection() => _card(
        title: 'Acceptance Dates',
        icon: Icons.draw_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Authority Acceptance Date'),
                      _datePicker(
                        value: _authorityAcceptanceDate,
                        hint: 'Optional',
                        onTap: () => _pickDate('authority'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Contractor Acceptance Date'),
                      _datePicker(
                        value: _contractorAcceptanceDate,
                        hint: 'Optional',
                        onTap: () => _pickDate('contractor'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _signatureBox('Signatures of\nIssuing authority'),
                _signatureBox('Contractor acceptance\n(Date and signature)'),
                _signatureBox('Acceptance of contractor action\n(Date & sign.)'),
              ],
            ),
          ],
        ),
      );

  Widget _card({
    required String title,
    required IconData icon,
    required Widget child,
  }) =>
      Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.06),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 15, color: const Color(0xFF7C3AED)),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: child,
            ),
          ],
        ),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
      );

  Widget _readOnlyField(String value) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          value,
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
      );

  Widget _inputField(
    TextEditingController ctrl,
    String label, {
    String? hint,
    TextInputType? type,
    int maxLines = 1,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          TextField(
            controller: ctrl,
            keyboardType: type,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: AppColors.primaryGreen, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
          ),
        ],
      );

  Widget _datePicker({
    required DateTime? value,
    required String hint,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value != null ? _fmtDate(value) : hint,
                  style: TextStyle(
                    fontSize: 13,
                    color: value != null
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFCBD5E1),
                  ),
                ),
              ),
              Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: value != null
                    ? const Color(0xFF7C3AED)
                    : const Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      );

  Widget _signatureBox(String label) => Expanded(
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Divider(color: Color(0xFF1E293B)),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
}