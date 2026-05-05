// lib/features/approval_form/presentation/approval_form_page.dart

import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/utils/api_exception.dart';
import '../data/models/approval_form_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Main Page
// ─────────────────────────────────────────────────────────────────────────────

class ApprovalFormPage extends StatefulWidget {
  final int projectId;
  final String projectName;

  const ApprovalFormPage({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<ApprovalFormPage> createState() => _ApprovalFormPageState();
}

class _ApprovalFormPageState extends State<ApprovalFormPage> {
  List<ApprovalFormModel> _forms = [];
  bool _isLoading = true;
  String? _error;

  static const _accent = Color(0xFF0F766E);

  @override
  void initState() {
    super.initState();
    _loadForms();
  }

  Future<void> _loadForms() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await ApiService.fetchApprovalForms(widget.projectId);
      if (!mounted) return;
      setState(() {
        _forms = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _cleanError(e);
        _isLoading = false;
      });
    }
  }

  /// Strips raw HTML from error messages — shows a clean string instead.
  String _cleanError(Object e) {
    final raw = e is ApiException ? e.message : e.toString();
    if (raw.trimLeft().startsWith('<')) {
      return 'Server error (403 Forbidden). Please contact your administrator.';
    }
    return raw;
  }

  Future<void> _openForm({ApprovalFormModel? existing}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _ApprovalFormFormPage(
          projectId: widget.projectId,
          projectName: widget.projectName,
          existing: existing,
        ),
        fullscreenDialog: true,
      ),
    );
    if (result == true) _loadForms();
  }

  Future<void> _confirmDelete(ApprovalFormModel f) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Delete Approval Form',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text('Delete form ${f.formNo}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Row(children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
        SizedBox(width: 10),
        Text('Deleting…'),
      ]),
      duration: Duration(seconds: 20),
      backgroundColor: Color(0xFF0F766E),
    ));

    try {
      await ApiService.deleteApprovalForm(widget.projectId, f.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Approval Form deleted successfully'),
        backgroundColor: Color(0xFF22C55E),
      ));
      _loadForms();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      final msg = _cleanError(e);
      developer.log('[Delete] error: $msg', name: 'ApprovalForm');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Delete failed: $msg'),
        backgroundColor: const Color(0xFFEF4444),
        duration: const Duration(seconds: 5),
      ));
    }
  }

  void _openView(ApprovalFormModel f) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ApprovalFormViewPage(
          form: f,
          projectName: widget.projectName,
        ),
      ),
    );
  }

  void _openPrint(ApprovalFormModel f) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _NativePrintPage(
          form: f,
          projectName: widget.projectName,
          projectId: widget.projectId,
        ),
      ),
    );
  }

  Future<void> _downloadPdf(ApprovalFormModel f) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          SizedBox(width: 12),
          Text('Downloading PDF…'),
        ]),
        duration: Duration(seconds: 60),
        backgroundColor: Color(0xFF0F766E),
      ),
    );

    try {
      final bytes =
          await ApiService.downloadApprovalFormPdfBytes(widget.projectId, f.id);
      final dir = await getTemporaryDirectory();
      final filename = 'Approval_Form_${f.formNo.replaceAll('/', '_')}.pdf';
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('PDF ready — opening…'),
        backgroundColor: Color(0xFF22C55E),
        duration: Duration(seconds: 2),
      ));
      await OpenFilex.open(file.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      final msg = _cleanError(e);
      developer.log('[PDF] error: $msg', name: 'ApprovalForm');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('PDF error: $msg'),
        backgroundColor: const Color(0xFFEF4444),
        duration: const Duration(seconds: 5),
      ));
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final d = DateTime.parse(dateStr);
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return dateStr;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF22C55E);
      case 'not_approved':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'not_approved':
        return 'Not Approved';
      default:
        return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _accent))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadForms,
                  color: _accent,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _buildHeader()),
                      _forms.isEmpty
                          ? SliverFillRemaining(child: _buildEmpty())
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (_, i) => _buildCard(_forms[i], i),
                                childCount: _forms.length,
                              ),
                            ),
                      const SliverToBoxAdapter(child: SizedBox(height: 90)),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'New Approval Form',
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
          border: Border.all(color: _accent.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.approval_outlined, color: _accent, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                'Sample Approval Forms',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _accent,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'WR/QLT/EXE/09 — ${widget.projectName}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _accent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_forms.length}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ]),
      );

  Widget _buildCard(ApprovalFormModel f, int index) {
    final statusColor = _statusColor(f.approvalStatus);
    return Container(
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
          )
        ],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            Container(
              width: 28,
              height: 28,
              decoration:
                  BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(8)),
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
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  f.formNo,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _accent,
                  ),
                ),
                if (f.dateOfSubmission != null)
                  Text(
                    _formatDate(f.dateOfSubmission),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: statusColor.withValues(alpha: 0.35)),
              ),
              child: Text(
                _statusLabel(f.approvalStatus),
                style: TextStyle(
                  fontSize: 10,
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _infoItem(Icons.inventory_2_outlined, 'Sample', f.sampleMaterial),
              const SizedBox(width: 12),
              _infoItem(Icons.business_outlined, 'Contractor', f.contractor),
              const SizedBox(width: 12),
              _infoItem(Icons.category_outlined, 'Trade', f.tradePackage),
            ]),
            if (f.creator != null && f.creator!.name.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.account_circle_outlined,
                    size: 13, color: Color(0xFF94A3B8)),
                const SizedBox(width: 5),
                Text(
                  'Created by ${f.creator!.name}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ]),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _actionBtn(
                label: 'View',
                icon: Icons.visibility_outlined,
                color: const Color(0xFF0EA5E9),
                onTap: () => _openView(f),
              ),
              _actionBtn(
                label: 'Edit',
                icon: Icons.edit_outlined,
                color: const Color(0xFFF59E0B),
                onTap: () => _openForm(existing: f),
              ),
              _actionBtn(
                label: 'Print',
                icon: Icons.print_outlined,
                color: const Color(0xFF22C55E),
                onTap: () => _openPrint(f),
              ),
              _actionBtn(
                label: 'PDF',
                icon: Icons.download_outlined,
                color: const Color(0xFF8B5CF6),
                onTap: () => _downloadPdf(f),
              ),
              _actionBtn(
                label: 'Delete',
                icon: Icons.delete_outline,
                color: const Color(0xFFEF4444),
                onTap: () => _confirmDelete(f),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _infoItem(IconData icon, String label, String? value) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          Row(children: [
            Icon(icon, size: 11, color: const Color(0xFF64748B)),
            const SizedBox(width: 3),
            Expanded(
              child: Text(
                (value != null && value.isNotEmpty) ? value : 'N/A',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF1E293B),
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ]),
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
          child: Row(mainAxisSize: MainAxisSize.min, children: [
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
          ]),
        ),
      );

  Widget _buildEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.approval_outlined, size: 56, color: _accent),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Approval Forms',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the button below to create your first sample approval form.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
          ]),
        ),
      );

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadForms,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
              ),
            ),
          ]),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Native Print Preview Page
// ─────────────────────────────────────────────────────────────────────────────

class _NativePrintPage extends StatefulWidget {
  final ApprovalFormModel form;
  final String projectName;
  final int projectId;

  const _NativePrintPage({
    required this.form,
    required this.projectName,
    required this.projectId,
  });

  @override
  State<_NativePrintPage> createState() => _NativePrintPageState();
}

class _NativePrintPageState extends State<_NativePrintPage> {
  static const _accent = Color(0xFF0F766E);
  bool _isDownloading = false;

  String _fmt(String? d) {
    if (d == null || d.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(d);
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return d;
    }
  }

  String get _statusLabel {
    switch (widget.form.approvalStatus) {
      case 'approved':
        return 'APPROVED';
      case 'not_approved':
        return 'NOT APPROVED';
      default:
        return 'PENDING';
    }
  }

  Color get _statusColor {
    switch (widget.form.approvalStatus) {
      case 'approved':
        return const Color(0xFF22C55E);
      case 'not_approved':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  Future<void> _downloadPdf() async {
    setState(() => _isDownloading = true);
    try {
      final bytes = await ApiService.downloadApprovalFormPdfBytes(
          widget.projectId, widget.form.id);
      final dir = await getTemporaryDirectory();
      final filename =
          'Approval_Form_${widget.form.formNo.replaceAll('/', '_')}.pdf';
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      await OpenFilex.open(file.path);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().trimLeft().startsWith('<')
          ? 'Server error (403). Contact your administrator.'
          : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('PDF error: $msg'),
        backgroundColor: const Color(0xFFEF4444),
      ));
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.form;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            'Print Preview',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          Text(
            f.formNo,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ]),
        actions: [
          if (_isDownloading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF0F766E)),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.download_outlined, color: Color(0xFF0F766E)),
              tooltip: 'Download PDF',
              onPressed: _downloadPdf,
            ),
          IconButton(
            icon: const Icon(Icons.copy_outlined, color: Color(0xFF64748B)),
            tooltip: 'Copy form number',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: f.formNo));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Form number copied'),
                duration: Duration(seconds: 2),
              ));
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _printCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(
                  'WR/QLT/EXE/09',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _accent,
                  ),
                ),
                const Text(
                  'WISE REALTY',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ]),
              const Divider(height: 16),
              const Center(
                child: Text(
                  'SAMPLE APPROVAL FORM',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Note: Contractor to attach this form with the Submittal transmittal format at the time of submitting Samples submittals and fill in necessary details.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    _statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: _statusColor,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          _sectionHeader('Project Information'),
          _printCard(
            child: Column(children: [
              _pRow2('Form No.', f.formNo, 'Date of Submission',
                  _fmt(f.dateOfSubmission)),
              _div(),
              _pRow2('Project', widget.projectName, 'Trade Package', f.tradePackage),
              _div(),
              _pRow2('Contractor', f.contractor, 'Submittal No.',
                  f.contractorSubmittalNumber),
            ]),
          ),
          const SizedBox(height: 12),
          _sectionHeader('Sample Details'),
          _printCard(
            child: Column(children: [
              _pRow2('Sample Material', f.sampleMaterial, 'Sample No.', f.sampleNo),
              _div(),
              _pRow2('Sample Size', f.sampleSize, 'Area of Usage', f.areaOfUsage),
            ]),
          ),
          const SizedBox(height: 12),
          _sectionHeader('Technical Specifications'),
          _printCard(
            child: Column(children: [
              _pRow2('Model Number', f.modelNumber, 'Make', f.make),
              _div(),
              _pRow3('Colour', f.colour, 'Finish', f.finish, 'Thickness', f.thickness),
              _div(),
              _pField('Other Specifications', f.otherSpecs),
              _div(),
              _pField('Comments', f.comments),
            ]),
          ),
          const SizedBox(height: 12),
          _sectionHeader('Approval & Consultant'),
          _printCard(
            child: Column(children: [
              _pField("Architect/Consultant's Comments", f.consultantComments),
              _div(),
              _pField('Consultant Signature Date', _fmt(f.consultantSignatureDate)),
            ]),
          ),
          const SizedBox(height: 12),
          _printCard(
            child: Column(children: [
              const SizedBox(height: 50),
              const Divider(thickness: 1, color: Color(0xFF1E293B)),
              const Center(
                child: Text(
                  'Architect / Consultant  (Sign & Date)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 4),
            ]),
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  Widget _printCard({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            )
          ],
        ),
        child: child,
      );

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
                color: _accent, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _accent,
            ),
          ),
        ]),
      );

  Widget _div() => const Divider(height: 14, color: Color(0xFFF1F5F9));

  Widget _pField(String label, String? value) => Column(
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
          const SizedBox(height: 3),
          Text(
            (value != null && value.isNotEmpty) ? value : '—',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );

  Widget _pRow2(String l1, String? v1, String l2, String? v2) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _pField(l1, v1)),
        const SizedBox(width: 12),
        Expanded(child: _pField(l2, v2)),
      ]);

  Widget _pRow3(
          String l1, String? v1, String l2, String? v2, String l3, String? v3) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _pField(l1, v1)),
        const SizedBox(width: 8),
        Expanded(child: _pField(l2, v2)),
        const SizedBox(width: 8),
        Expanded(child: _pField(l3, v3)),
      ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// View Page
// ─────────────────────────────────────────────────────────────────────────────

class _ApprovalFormViewPage extends StatelessWidget {
  final ApprovalFormModel form;
  final String projectName;

  const _ApprovalFormViewPage({required this.form, required this.projectName});

  static const _accent = Color(0xFF0F766E);

  String _fmt(String? d) {
    if (d == null || d.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(d);
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return d;
    }
  }

  String get _statusLabel {
    switch (form.approvalStatus) {
      case 'approved':
        return 'APPROVED';
      case 'not_approved':
        return 'NOT APPROVED';
      default:
        return 'PENDING';
    }
  }

  Color get _statusColor {
    switch (form.approvalStatus) {
      case 'approved':
        return const Color(0xFF22C55E);
      case 'not_approved':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            'Sample Approval Form',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          Text(
            form.formNo,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ]),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(
                  'WR/QLT/EXE/09',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _accent,
                  ),
                ),
                const Text(
                  'WISE REALTY',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ]),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  'SAMPLE APPROVAL FORM',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Note: Contractor to attach this form with the Submittal transmittal format at the time of submitting Samples submittals and fill in necessary details in upper part.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Project Information',
            icon: Icons.info_outline,
            children: [
              _row2('Form No.', form.formNo, 'Date of Submission',
                  _fmt(form.dateOfSubmission)),
              const SizedBox(height: 10),
              _row2('Project', projectName, 'Trade Package', form.tradePackage),
              const SizedBox(height: 10),
              _row2('Contractor', form.contractor, 'Submittal No.',
                  form.contractorSubmittalNumber),
            ],
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Sample Details',
            icon: Icons.inventory_2_outlined,
            children: [
              _row2('Sample Material', form.sampleMaterial, 'Sample No.',
                  form.sampleNo),
              const SizedBox(height: 10),
              _infoRow('Sample Size', form.sampleSize),
              const SizedBox(height: 10),
              _infoRow('Area of Usage', form.areaOfUsage),
            ],
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Technical Specifications',
            icon: Icons.settings_outlined,
            children: [
              _row2('Model Number', form.modelNumber, 'Make', form.make),
              const SizedBox(height: 10),
              _row3('Colour', form.colour, 'Finish', form.finish, 'Thickness',
                  form.thickness),
              const SizedBox(height: 10),
              _infoRow('Other Specs', form.otherSpecs),
              const SizedBox(height: 10),
              _infoRow('Comments', form.comments),
            ],
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: 'Approval Status',
            icon: Icons.check_circle_outline,
            children: [
              Row(children: [
                const Text(
                  'Sample Status: ',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: _statusColor.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    _statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: _statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              _infoRow(
                  'Architect/Consultant Comments', form.consultantComments),
              const SizedBox(height: 10),
              _infoRow('Consultant Signature Date',
                  _fmt(form.consultantSignatureDate)),
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
            child: Column(children: [
              const SizedBox(height: 40),
              const Divider(color: Color(0xFF1E293B)),
              const Text(
                'Architect/Consultant (Sign and Date)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ]),
          ),
          const SizedBox(height: 32),
        ]),
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
            )
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(children: [
              Icon(icon, size: 15, color: _accent),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _accent,
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ]),
      );

  Widget _row2(String l1, String? v1, String l2, String? v2) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _infoRow(l1, v1)),
        const SizedBox(width: 12),
        Expanded(child: _infoRow(l2, v2)),
      ]);

  Widget _row3(
          String l1, String? v1, String l2, String? v2, String l3, String? v3) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _infoRow(l1, v1)),
        const SizedBox(width: 8),
        Expanded(child: _infoRow(l2, v2)),
        const SizedBox(width: 8),
        Expanded(child: _infoRow(l3, v3)),
      ]);

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
            (value != null && value.isNotEmpty) ? value : 'N/A',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Form Page (Create / Edit)
// ─────────────────────────────────────────────────────────────────────────────

class _ApprovalFormFormPage extends StatefulWidget {
  final int projectId;
  final String projectName;
  final ApprovalFormModel? existing;

  const _ApprovalFormFormPage({
    required this.projectId,
    required this.projectName,
    this.existing,
  });

  @override
  State<_ApprovalFormFormPage> createState() => _ApprovalFormFormPageState();
}

class _ApprovalFormFormPageState extends State<_ApprovalFormFormPage> {
  static const _accent = Color(0xFF0F766E);

  String _formNo = '';
  bool _isLoadingNo = false;
  bool _formNoError = false;

  DateTime? _dateOfSubmission;
  DateTime? _consultantSignatureDate;

  final _contractorCtrl = TextEditingController();
  final _contractorSubmittalCtrl = TextEditingController();
  final _tradePackageCtrl = TextEditingController();
  final _sampleMaterialCtrl = TextEditingController();
  final _sampleNoCtrl = TextEditingController();
  final _sampleSizeCtrl = TextEditingController();
  final _areaOfUsageCtrl = TextEditingController();
  final _modelNumberCtrl = TextEditingController();
  final _makeCtrl = TextEditingController();
  final _colourCtrl = TextEditingController();
  final _finishCtrl = TextEditingController();
  final _thicknessCtrl = TextEditingController();
  final _otherSpecsCtrl = TextEditingController();
  final _commentsCtrl = TextEditingController();
  final _consultantCommentsCtrl = TextEditingController();

  String _approvalStatus = 'pending';
  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _populateFromExisting();
    } else {
      _dateOfSubmission = DateTime.now();
      _loadFormNumber();
    }
  }

  void _populateFromExisting() {
    final f = widget.existing!;
    _formNo = f.formNo;
    if (f.dateOfSubmission != null && f.dateOfSubmission!.isNotEmpty) {
      try {
        _dateOfSubmission = DateTime.parse(f.dateOfSubmission!);
      } catch (_) {}
    }
    if (f.consultantSignatureDate != null &&
        f.consultantSignatureDate!.isNotEmpty) {
      try {
        _consultantSignatureDate = DateTime.parse(f.consultantSignatureDate!);
      } catch (_) {}
    }
    _contractorCtrl.text = f.contractor ?? '';
    _contractorSubmittalCtrl.text = f.contractorSubmittalNumber ?? '';
    _tradePackageCtrl.text = f.tradePackage ?? '';
    _sampleMaterialCtrl.text = f.sampleMaterial ?? '';
    _sampleNoCtrl.text = f.sampleNo ?? '';
    _sampleSizeCtrl.text = f.sampleSize ?? '';
    _areaOfUsageCtrl.text = f.areaOfUsage ?? '';
    _modelNumberCtrl.text = f.modelNumber ?? '';
    _makeCtrl.text = f.make ?? '';
    _colourCtrl.text = f.colour ?? '';
    _finishCtrl.text = f.finish ?? '';
    _thicknessCtrl.text = f.thickness ?? '';
    _otherSpecsCtrl.text = f.otherSpecs ?? '';
    _commentsCtrl.text = f.comments ?? '';
    _consultantCommentsCtrl.text = f.consultantComments ?? '';
    _approvalStatus = f.approvalStatus;
  }

  Future<void> _loadFormNumber() async {
    if (!mounted) return;
    setState(() {
      _isLoadingNo = true;
      _formNoError = false;
    });
    try {
      final no = await ApiService.generateApprovalFormNumber(widget.projectId);
      if (mounted) {
        setState(() {
          _formNo = no;
          _isLoadingNo = false;
        });
      }
    } catch (e) {
      developer.log('[FormNo] error: $e', name: 'ApprovalForm');
      if (mounted) {
        setState(() {
          _formNo = '';
          _isLoadingNo = false;
          _formNoError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _contractorCtrl.dispose();
    _contractorSubmittalCtrl.dispose();
    _tradePackageCtrl.dispose();
    _sampleMaterialCtrl.dispose();
    _sampleNoCtrl.dispose();
    _sampleSizeCtrl.dispose();
    _areaOfUsageCtrl.dispose();
    _modelNumberCtrl.dispose();
    _makeCtrl.dispose();
    _colourCtrl.dispose();
    _finishCtrl.dispose();
    _thicknessCtrl.dispose();
    _otherSpecsCtrl.dispose();
    _commentsCtrl.dispose();
    _consultantCommentsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isSubmission) async {
    final initial = isSubmission
        ? (_dateOfSubmission ?? DateTime.now())
        : (_consultantSignatureDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              const ColorScheme.light(primary: Color(0xFF0F766E)),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isSubmission) {
          _dateOfSubmission = picked;
        } else {
          _consultantSignatureDate = picked;
        }
      });
    }
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return 'Select date';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Converts any error to a clean user-facing string,
  /// stripping raw HTML 403 pages.
  String _cleanError(Object e) {
    final raw = e is ApiException ? e.message : e.toString();
    if (raw.trimLeft().startsWith('<')) {
      return 'Server returned 403 Forbidden. '
          'Ask your administrator to move approval-form routes '
          'inside the auth:sanctum middleware group.';
    }
    return raw;
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      if (_isEditing) {
        await ApiService.updateApprovalForm(
          projectId: widget.projectId,
          id: widget.existing!.id,
          dateOfSubmission:
              _dateOfSubmission != null ? _isoDate(_dateOfSubmission!) : null,
          contractor: _contractorCtrl.text.trim(),
          contractorSubmittalNumber: _contractorSubmittalCtrl.text.trim(),
          tradePackage: _tradePackageCtrl.text.trim(),
          sampleMaterial: _sampleMaterialCtrl.text.trim(),
          sampleNo: _sampleNoCtrl.text.trim(),
          sampleSize: _sampleSizeCtrl.text.trim(),
          areaOfUsage: _areaOfUsageCtrl.text.trim(),
          modelNumber: _modelNumberCtrl.text.trim(),
          make: _makeCtrl.text.trim(),
          colour: _colourCtrl.text.trim(),
          finish: _finishCtrl.text.trim(),
          thickness: _thicknessCtrl.text.trim(),
          otherSpecs: _otherSpecsCtrl.text.trim(),
          comments: _commentsCtrl.text.trim(),
          approvalStatus: _approvalStatus,
          consultantComments: _consultantCommentsCtrl.text.trim(),
          consultantSignatureDate: _consultantSignatureDate != null
              ? _isoDate(_consultantSignatureDate!)
              : null,
        );
      } else {
        await ApiService.createApprovalForm(
          projectId: widget.projectId,
          formNo: _formNo,
          dateOfSubmission:
              _dateOfSubmission != null ? _isoDate(_dateOfSubmission!) : null,
          contractor: _contractorCtrl.text.trim(),
          contractorSubmittalNumber: _contractorSubmittalCtrl.text.trim(),
          tradePackage: _tradePackageCtrl.text.trim(),
          sampleMaterial: _sampleMaterialCtrl.text.trim(),
          sampleNo: _sampleNoCtrl.text.trim(),
          sampleSize: _sampleSizeCtrl.text.trim(),
          areaOfUsage: _areaOfUsageCtrl.text.trim(),
          modelNumber: _modelNumberCtrl.text.trim(),
          make: _makeCtrl.text.trim(),
          colour: _colourCtrl.text.trim(),
          finish: _finishCtrl.text.trim(),
          thickness: _thicknessCtrl.text.trim(),
          otherSpecs: _otherSpecsCtrl.text.trim(),
          comments: _commentsCtrl.text.trim(),
          approvalStatus: _approvalStatus,
          consultantComments: _consultantCommentsCtrl.text.trim(),
          consultantSignatureDate: _consultantSignatureDate != null
              ? _isoDate(_consultantSignatureDate!)
              : null,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          _isEditing
              ? 'Approval Form updated successfully!'
              : 'Approval Form created successfully!',
        ),
        backgroundColor: const Color(0xFF22C55E),
      ));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final msg = _cleanError(e);
      developer.log('[Submit] error: $msg', name: 'ApprovalForm');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFEF4444),
        duration: const Duration(seconds: 5),
      ));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            _isEditing ? 'Edit Approval Form' : 'New Approval Form',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          Text(
            widget.projectName,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _isSaving ? null : _submit,
              style: TextButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _isEditing ? 'Update' : 'Save',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(children: [
          // Warning banner when form-number fetch failed (e.g. 403)
          if (_formNoError && !_isEditing)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDBA74)),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFF97316), size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Form number will be assigned on save. '
                    'Fix: move routes to the "auth:sanctum" middleware group in routes/api.php.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                  ),
                ),
                GestureDetector(
                  onTap: _loadFormNumber,
                  child: const Icon(Icons.refresh,
                      color: Color(0xFFF97316), size: 18),
                ),
              ]),
            ),
          _buildFormHeader(),
          _buildSampleDetails(),
          _buildTechnicalSpecs(),
          _buildApprovalSection(),
          _buildSignatureSection(),
        ]),
      ),
    );
  }

  Widget _buildFormHeader() => _card(
        title: 'Form Details',
        icon: Icons.info_outline,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(
              'WR/QLT/EXE/09',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _accent,
              ),
            ),
            const Text(
              'WISE REALTY',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ]),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              'SAMPLE APPROVAL FORM',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              border: Border.all(color: const Color(0xFFFCD34D)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Note: Contractor to attach this form with the Submittal transmittal format at the time of submitting Samples submittals.',
              style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
            ),
          ),
          const SizedBox(height: 14),
          _label('Form No.'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Expanded(
                child: Text(
                  _isLoadingNo
                      ? 'Generating…'
                      : (_formNo.isNotEmpty
                          ? _formNo
                          : 'Will be assigned on save'),
                  style: TextStyle(
                    fontSize: 13,
                    color: (_isLoadingNo || _formNo.isEmpty)
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF1E293B),
                  ),
                ),
              ),
              if (_isLoadingNo)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF0F766E)),
                ),
            ]),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _label('Project Name'),
                _readOnlyField(widget.projectName),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _label('Date of Submission'),
                _datePicker(
                  value: _dateOfSubmission,
                  hint: 'Select date',
                  onTap: () => _pickDate(true),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          _inputField(_contractorCtrl, 'Contractor',
              hint: 'Enter contractor name'),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: _inputField(_contractorSubmittalCtrl,
                  'Contractor Submittal Number',
                  hint: 'e.g. CS-001'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _inputField(_tradePackageCtrl, 'Trade Package',
                  hint: 'e.g. Flooring'),
            ),
          ]),
        ]),
      );

  Widget _buildSampleDetails() => _card(
        title: 'Sample Details',
        icon: Icons.inventory_2_outlined,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: _inputField(_sampleMaterialCtrl, 'Sample Material',
                  hint: 'e.g. Ceramic Tile'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child:
                  _inputField(_sampleNoCtrl, 'Sample No.', hint: 'e.g. S-01'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _inputField(_sampleSizeCtrl, 'Sample Size',
                  hint: '600x600mm'),
            ),
          ]),
          const SizedBox(height: 14),
          _inputField(_areaOfUsageCtrl, 'Area of Usage',
              hint: 'Describe area of usage', maxLines: 2),
        ]),
      );

  Widget _buildTechnicalSpecs() => _card(
        title: 'Technical Specifications',
        icon: Icons.settings_outlined,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: _inputField(_modelNumberCtrl, 'Model Number',
                  hint: 'Model no.'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _inputField(_makeCtrl, 'Make', hint: 'Manufacturer'),
            ),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: _inputField(_colourCtrl, 'Colour (If applicable)',
                  hint: 'e.g. Ivory'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _inputField(_finishCtrl, 'Finish (If applicable)',
                  hint: 'e.g. Matte'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _inputField(_thicknessCtrl, 'Thickness (If applicable)',
                  hint: 'e.g. 8mm'),
            ),
          ]),
          const SizedBox(height: 14),
          _inputField(_otherSpecsCtrl, 'Other Specs.',
              hint: 'Additional specifications', maxLines: 2),
          const SizedBox(height: 14),
          _inputField(_commentsCtrl, 'Comments',
              hint: 'Enter comments', maxLines: 3),
        ]),
      );

  Widget _buildApprovalSection() => _card(
        title: 'Approval Status',
        icon: Icons.check_circle_outline,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label('Sample Status'),
          const SizedBox(height: 8),
          Row(children: [
            _statusChip('Approved', 'approved', const Color(0xFF22C55E)),
            const SizedBox(width: 10),
            _statusChip(
                'Not Approved', 'not_approved', const Color(0xFFEF4444)),
            const SizedBox(width: 10),
            _statusChip('Pending', 'pending', const Color(0xFFF59E0B)),
          ]),
          const SizedBox(height: 14),
          _inputField(
            _consultantCommentsCtrl,
            "Architect/Consultant's Comments (If any)",
            hint: 'Enter comments',
            maxLines: 3,
          ),
          const SizedBox(height: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('Consultant Signature Date'),
            _datePicker(
              value: _consultantSignatureDate,
              hint: 'Select date (optional)',
              onTap: () => _pickDate(false),
            ),
          ]),
        ]),
      );

  Widget _buildSignatureSection() => _card(
        title: 'Signature',
        icon: Icons.draw_outlined,
        child: Column(children: [
          const SizedBox(height: 40),
          const Divider(color: Color(0xFF1E293B)),
          const Text(
            'Architect/Consultant (Sign and Date)',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ]),
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
          border: Border.all(color: _accent.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(children: [
              Icon(icon, size: 15, color: _accent),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _accent,
                ),
              ),
            ]),
          ),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ]),
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
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                  const BorderSide(color: Color(0xFF0F766E), width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            isDense: true,
          ),
          style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
        ),
      ]);

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
          child: Row(children: [
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
              color: value != null ? _accent : const Color(0xFF94A3B8),
            ),
          ]),
        ),
      );

  Widget _statusChip(String label, String value, Color color) {
    final selected = _approvalStatus == value;
    return GestureDetector(
      onTap: () => setState(() => _approvalStatus = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.12)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color : const Color(0xFFE2E8F0),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (selected) Icon(Icons.check_circle, size: 13, color: color),
          if (selected) const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: selected ? color : const Color(0xFF64748B),
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ]),
      ),
    );
  }
}