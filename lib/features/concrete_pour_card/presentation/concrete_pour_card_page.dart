// lib/features/concrete_pour_card/presentation/concrete_pour_card_page.dart

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../../core/services/api_service.dart';
import '../../../../core/utils/api_exception.dart';
import '../data/models/concrete_pour_card_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Main listing page
// ─────────────────────────────────────────────────────────────────────────────

class ConcretePourCardPage extends StatefulWidget {
  final int projectId;
  final String projectName;

  const ConcretePourCardPage({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<ConcretePourCardPage> createState() => _ConcretePourCardPageState();
}

class _ConcretePourCardPageState extends State<ConcretePourCardPage> {
  List<ConcretePourCardModel> _cards = [];
  bool _isLoading = true;
  String? _error;

  static const _accent = Color(0xFF0F766E);

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _loadCards() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await ApiService.fetchConcretePourCards(widget.projectId);
      final sorted = List<ConcretePourCardModel>.from(list)
        ..sort((a, b) {
          final dateCompare = b.date.compareTo(a.date);
          if (dateCompare != 0) return dateCompare;
          return b.id.compareTo(a.id);
        });
      if (!mounted) return;
      setState(() {
        _cards = sorted;
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

  Future<void> _openForm({ConcretePourCardModel? existing}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _ConcretePourCardFormPage(
          projectId: widget.projectId,
          projectName: widget.projectName,
          existing: existing,
        ),
        fullscreenDialog: true,
      ),
    );
    if (result == true) _loadCards();
  }

  Future<void> _confirmDelete(ConcretePourCardModel card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Card',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content:
            Text('Delete card ${card.cardNo}? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiService.deleteConcretePourCard(widget.projectId, card.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Card deleted successfully'),
        backgroundColor: Color(0xFF22C55E),
      ));
      _loadCards();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: const Color(0xFFEF4444),
      ));
    }
  }

  void _openView(ConcretePourCardModel card) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => _ConcretePourCardViewPage(
                  card: card,
                  projectName: widget.projectName,
                )));
  }

  // ── Print: download PDF bytes → native Android print dialog ──────────────
  Future<void> _printCard(ConcretePourCardModel card) async {
    if (!mounted) return;

    // Show loading snackbar
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Row(children: [
        SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white)),
        SizedBox(width: 12),
        Text('Preparing print…'),
      ]),
      duration: Duration(seconds: 30),
      backgroundColor: Color(0xFF0F766E),
    ));

    try {
      final bytes = await ApiService.downloadConcretePourCardPdf(
          widget.projectId, card.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Open native Android/iOS print dialog
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'Concrete_Pour_Card_${card.cardNo.replaceAll('/', '_')}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Print error: $e'),
        backgroundColor: const Color(0xFFEF4444),
      ));
    }
  }

  // ── PDF download/share ────────────────────────────────────────────────────
  Future<void> _downloadPdf(ConcretePourCardModel card) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Row(children: [
        SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white)),
        SizedBox(width: 12),
        Text('Preparing PDF…'),
      ]),
      duration: Duration(seconds: 30),
      backgroundColor: Color(0xFF0F766E),
    ));

    try {
      final bytes = await ApiService.downloadConcretePourCardPdf(
          widget.projectId, card.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'Concrete_Pour_Card_${card.cardNo.replaceAll('/', '_')}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('PDF error: $e'),
        backgroundColor: const Color(0xFFEF4444),
      ));
    }
  }

  // ── Formatting ────────────────────────────────────────────────────────────

  String _formatDate(String? d) {
    if (d == null || d.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(d);
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return d;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _accent))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadCards,
                  color: _accent,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _buildHeader()),
                      _cards.isEmpty
                          ? SliverFillRemaining(child: _buildEmpty())
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (_, i) => _buildCard(_cards[i], i),
                                childCount: _cards.length,
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
        label: const Text('New Card',
            style: TextStyle(fontWeight: FontWeight.w600)),
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
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.credit_card_outlined, color: _accent, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text('Concrete Pour Cards',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _accent)),
              const SizedBox(height: 2),
              Text(widget.projectName,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _accent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('${_cards.length}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ),
        ]),
      );

  Widget _buildCard(ConcretePourCardModel card, int index) {
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
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(children: [
        // Card header
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.06),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text('${index + 1}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(card.cardNo,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _accent)),
                Text(_formatDate(card.date),
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF64748B))),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('Pour Card',
                  style: TextStyle(
                      fontSize: 10,
                      color: _accent,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        ),

        // Card body
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              _infoItem(Icons.work_outline, 'Work Name', card.workName),
              const SizedBox(width: 12),
              _infoItem(Icons.science_outlined, 'Grade', card.grade),
              const SizedBox(width: 12),
              _infoItem(
                Icons.schedule_outlined,
                'Duration',
                (card.startTime != null && card.endTime != null)
                    ? '${card.startTime} - ${card.endTime}'
                    : null,
              ),
            ]),

            if (card.creator != null && card.creator!.name.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.account_circle_outlined,
                    size: 13, color: Color(0xFF94A3B8)),
                const SizedBox(width: 5),
                Text('Created by ${card.creator!.name}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF64748B))),
              ]),
            ],

            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),

            // Action buttons
            Wrap(spacing: 8, runSpacing: 8, children: [
              _actionBtn(
                  label: 'View',
                  icon: Icons.visibility_outlined,
                  color: const Color(0xFF0EA5E9),
                  onTap: () => _openView(card)),
              _actionBtn(
                  label: 'Edit',
                  icon: Icons.edit_outlined,
                  color: const Color(0xFFF59E0B),
                  onTap: () => _openForm(existing: card)),
              // ── Print now uses native Android print dialog ──
              _actionBtn(
                  label: 'Print',
                  icon: Icons.print_outlined,
                  color: const Color(0xFF22C55E),
                  onTap: () => _printCard(card)),
              _actionBtn(
                  label: 'PDF',
                  icon: Icons.download_outlined,
                  color: const Color(0xFF8B5CF6),
                  onTap: () => _downloadPdf(card)),
              _actionBtn(
                  label: 'Delete',
                  icon: Icons.delete_outline,
                  color: const Color(0xFFEF4444),
                  onTap: () => _confirmDelete(card)),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _infoItem(IconData icon, String label, String? value) => Expanded(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 9,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3)),
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
                    fontWeight: FontWeight.w500),
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
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600)),
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
              child: Icon(Icons.credit_card_outlined, size: 56, color: _accent),
            ),
            const SizedBox(height: 20),
            const Text('No Concrete Pour Cards',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            const Text(
              'Tap the button below to create your first concrete pour card.',
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
            const Icon(Icons.error_outline,
                color: Color(0xFFEF4444), size: 48),
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF1E293B))),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadCards,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _accent, foregroundColor: Colors.white),
            ),
          ]),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// View Page
// ─────────────────────────────────────────────────────────────────────────────

class _ConcretePourCardViewPage extends StatelessWidget {
  final ConcretePourCardModel card;
  final String projectName;

  const _ConcretePourCardViewPage({
    required this.card,
    required this.projectName,
  });

  static const _accent = Color(0xFF0F766E);

  String _fmtDate(String? d) {
    if (d == null || d.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(d);
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Concrete Pour Card',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B))),
          Text(card.cardNo,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        ]),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionCard(
            title: 'CONCRETE POUR CARD',
            icon: Icons.credit_card_outlined,
            children: [
              _row2('Card No.', card.cardNo, 'Date', _fmtDate(card.date)),
              const SizedBox(height: 10),
              _row2('Name of Work', card.workName, 'Grade', card.grade),
              const SizedBox(height: 10),
              _row2(
                  'Time',
                  card.time,
                  'Duration',
                  (card.startTime != null && card.endTime != null)
                      ? '${card.startTime} – ${card.endTime}'
                      : null),
            ],
          ),
          const SizedBox(height: 12),

          // Checklist table
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.06),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(10)),
                ),
                child: Row(children: [
                  Icon(Icons.checklist_outlined, size: 15, color: _accent),
                  const SizedBox(width: 8),
                  Text('Checklist',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _accent)),
                ]),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                color: const Color(0xFFF1F5F9),
                child: const Row(children: [
                  SizedBox(
                      width: 36,
                      child: Text('SR.',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B)))),
                  Expanded(
                      child: Text('DESCRIPTION',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B)))),
                  SizedBox(
                      width: 120,
                      child: Text('VALUE/REMARKS',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B)))),
                ]),
              ),
              ...List.generate(kDefaultChecklistItems.length, (i) {
                final def = kDefaultChecklistItems[i];
                final saved = i < card.checklistItems.length
                    ? card.checklistItems[i]
                    : <String, dynamic>{};
                final value = saved['value']?.toString() ?? '';

                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: i % 2 == 0
                        ? Colors.white
                        : const Color(0xFFFAFAFB),
                    border: const Border(
                        bottom:
                            BorderSide(color: Color(0xFFF1F5F9), width: 1)),
                  ),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    SizedBox(
                      width: 36,
                      child: Text(def['sr_no']!,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600)),
                    ),
                    Expanded(
                      child: Text(def['description']!,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1E293B),
                              height: 1.4)),
                    ),
                    SizedBox(
                      width: 120,
                      child: Text(
                          value.isNotEmpty ? value : '—',
                          style: TextStyle(
                              fontSize: 12,
                              color: value.isNotEmpty
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFF94A3B8)),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                );
              }),
            ]),
          ),
          const SizedBox(height: 12),

          _sectionCard(
            title: 'Checked By',
            icon: Icons.how_to_reg_outlined,
            children: [
              Text(
                (card.checkedBy != null && card.checkedBy!.isNotEmpty)
                    ? card.checkedBy!
                    : 'N/A',
                style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w500),
              ),
            ],
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
                offset: const Offset(0, 2))
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
              Text(title,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _accent)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ]),
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
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3)),
          const SizedBox(height: 2),
          Text(
            (value != null && value.isNotEmpty) ? value : 'N/A',
            style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w500),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Form Page (Create / Edit)  — unchanged from original
// ─────────────────────────────────────────────────────────────────────────────

class _ConcretePourCardFormPage extends StatefulWidget {
  final int projectId;
  final String projectName;
  final ConcretePourCardModel? existing;

  const _ConcretePourCardFormPage({
    required this.projectId,
    required this.projectName,
    this.existing,
  });

  @override
  State<_ConcretePourCardFormPage> createState() =>
      _ConcretePourCardFormPageState();
}

class _ConcretePourCardFormPageState
    extends State<_ConcretePourCardFormPage> {
  static const _accent = Color(0xFF0F766E);

  String _cardNo = '';
  bool _isLoadingNo = false;

  DateTime? _date;
  TimeOfDay? _time;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  final _workNameCtrl = TextEditingController();
  final _gradeCtrl = TextEditingController();
  final _checkedByCtrl = TextEditingController();

  late List<TextEditingController> _checklistValueCtrls;

  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _checklistValueCtrls = List.generate(
        kDefaultChecklistItems.length, (_) => TextEditingController());

    if (_isEditing) {
      _populateFromExisting();
    } else {
      _date = DateTime.now();
      _loadCardNumber();
    }
  }

  void _populateFromExisting() {
    final c = widget.existing!;
    _cardNo = c.cardNo;
    try {
      _date = DateTime.parse(c.date);
    } catch (_) {
      _date = DateTime.now();
    }
    if (c.time != null && c.time!.isNotEmpty) {
      final parts = c.time!.split(':');
      if (parts.length >= 2) {
        _time = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 0,
            minute: int.tryParse(parts[1]) ?? 0);
      }
    }
    if (c.startTime != null && c.startTime!.isNotEmpty) {
      final parts = c.startTime!.split(':');
      if (parts.length >= 2) {
        _startTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 0,
            minute: int.tryParse(parts[1]) ?? 0);
      }
    }
    if (c.endTime != null && c.endTime!.isNotEmpty) {
      final parts = c.endTime!.split(':');
      if (parts.length >= 2) {
        _endTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 0,
            minute: int.tryParse(parts[1]) ?? 0);
      }
    }
    _workNameCtrl.text = c.workName ?? '';
    _gradeCtrl.text = c.grade ?? '';
    _checkedByCtrl.text = c.checkedBy ?? '';
    for (int i = 0; i < kDefaultChecklistItems.length; i++) {
      if (i < c.checklistItems.length) {
        _checklistValueCtrls[i].text =
            c.checklistItems[i]['value']?.toString() ?? '';
      }
    }
  }

  Future<void> _loadCardNumber() async {
    if (!mounted) return;
    setState(() => _isLoadingNo = true);
    try {
      final no =
          await ApiService.generateConcretePourCardNumber(widget.projectId);
      if (mounted) setState(() => _cardNo = no);
    } catch (_) {}
    if (mounted) setState(() => _isLoadingNo = false);
  }

  @override
  void dispose() {
    _workNameCtrl.dispose();
    _gradeCtrl.dispose();
    _checkedByCtrl.dispose();
    for (final c in _checklistValueCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final initial = _date ?? today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(today) ? today : initial,
      firstDate: DateTime(2020),
      lastDate: today,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: _accent)),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickTime(bool isGeneral) async {
    final initial =
        isGeneral ? (_time ?? TimeOfDay.now()) : (_startTime ?? TimeOfDay.now());
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: _accent)),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isGeneral) _time = picked;
      });
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: _accent)),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _startTime = picked);
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: _accent)),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _endTime = picked);
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return 'Select date';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _fmtTime(TimeOfDay? t) {
    if (t == null) return 'Select time';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String? _isoTime(TimeOfDay? t) {
    if (t == null) return null;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  List<Map<String, dynamic>> _buildChecklistPayload() {
    return List.generate(kDefaultChecklistItems.length, (i) {
      final def = kDefaultChecklistItems[i];
      return {
        'sr_no': def['sr_no'],
        'description': def['description'],
        'value': _checklistValueCtrls[i].text.trim(),
      };
    });
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (_date == null) {
      _showError('Please select a date.');
      return;
    }
    setState(() => _isSaving = true);
    try {
      if (_isEditing) {
        await ApiService.updateConcretePourCard(
          projectId: widget.projectId,
          id: widget.existing!.id,
          date: _isoDate(_date!),
          time: _isoTime(_time),
          grade: _gradeCtrl.text.trim(),
          startTime: _isoTime(_startTime),
          endTime: _isoTime(_endTime),
          workName: _workNameCtrl.text.trim(),
          checklistItems: _buildChecklistPayload(),
          checkedBy: _checkedByCtrl.text.trim(),
        );
      } else {
        await ApiService.createConcretePourCard(
          projectId: widget.projectId,
          cardNo: _cardNo,
          date: _isoDate(_date!),
          time: _isoTime(_time),
          grade: _gradeCtrl.text.trim(),
          startTime: _isoTime(_startTime),
          endTime: _isoTime(_endTime),
          workName: _workNameCtrl.text.trim(),
          checklistItems: _buildChecklistPayload(),
          checkedBy: _checkedByCtrl.text.trim(),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEditing
            ? 'Concrete Pour Card updated successfully!'
            : 'Concrete Pour Card created successfully!'),
        backgroundColor: const Color(0xFF22C55E),
      ));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showError(e is ApiException ? e.message : e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFFEF4444),
    ));
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
            _isEditing
                ? 'Edit Concrete Pour Card'
                : 'Create Concrete Pour Card',
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B)),
          ),
          Text(widget.projectName,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
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
                          strokeWidth: 2, color: Colors.white))
                  : Text(_isEditing ? 'Update' : 'Save Card',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeaderSection()),
          SliverToBoxAdapter(child: _buildChecklistSection()),
          SliverToBoxAdapter(child: _buildCheckedBySection()),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() => _card(
        title: 'CONCRETE POUR CARD',
        icon: Icons.credit_card_outlined,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _label('Card No.'),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        _isLoadingNo ? 'Generating…' : _cardNo,
                        style: TextStyle(
                            fontSize: 13,
                            color: _isLoadingNo
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF1E293B)),
                      ),
                    ),
                    if (_isLoadingNo)
                      const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _accent)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _inputField(_workNameCtrl, 'Name of the Work',
                  hint: 'Enter work name'),
            ),
          ]),
          const SizedBox(height: 14),

          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              flex: 2,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _label('Date *'),
                _datePicker(
                    value: _date, hint: 'Select date', onTap: _pickDate),
              ]),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _label('Time'),
                _timePicker(
                    value: _time,
                    hint: 'HH:MM',
                    onTap: () => _pickTime(true)),
              ]),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _inputField(_gradeCtrl, 'Grade', hint: 'e.g. M25'),
            ),
          ]),
          const SizedBox(height: 14),

          Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _label('Start Time'),
                _timePicker(
                    value: _startTime,
                    hint: 'HH:MM',
                    onTap: _pickStartTime),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _label('End Time'),
                _timePicker(
                    value: _endTime, hint: 'HH:MM', onTap: _pickEndTime),
              ]),
            ),
          ]),
        ]),
      );

  Widget _buildChecklistSection() => _card(
        title: 'Checklist',
        icon: Icons.checklist_outlined,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6)),
            child: const Row(children: [
              SizedBox(
                  width: 36,
                  child: Text('SR.NO.',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B)))),
              Expanded(
                  child: Text('DESCRIPTION',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B)))),
              SizedBox(
                  width: 130,
                  child: Text('VALUE/REMARKS',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B)))),
            ]),
          ),
          const SizedBox(height: 4),

          ...List.generate(kDefaultChecklistItems.length, (i) {
            final def = kDefaultChecklistItems[i];
            final isMultiLine = kMultiLineItems.contains(i);
            String descDisplay = def['description']!;
            if (i == 8) {
              descDisplay = 'Slump\n  - Morning\n  - Noon\n  - Evening';
            } else if (i == 9) {
              descDisplay =
                  'Water Quantity\n  - Morning\n  - Noon\n  - Evening';
            } else if (i == 12) {
              descDisplay = 'Cube test result\n  - 07 days\n  - 28 days';
            }

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color:
                    i % 2 == 0 ? Colors.white : const Color(0xFFFAFAFB),
                border: const Border(
                    bottom:
                        BorderSide(color: Color(0xFFF1F5F9), width: 1)),
              ),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                SizedBox(
                  width: 36,
                  child: Text(def['sr_no']!,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  child: Text(descDisplay,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1E293B),
                          height: 1.4)),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 130,
                  child: TextField(
                    controller: _checklistValueCtrls[i],
                    maxLines: isMultiLine ? 4 : 1,
                    decoration: InputDecoration(
                      hintText: isMultiLine ? 'Enter values…' : 'Value',
                      hintStyle: const TextStyle(
                          fontSize: 11, color: Color(0xFFCBD5E1)),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide:
                              const BorderSide(color: _accent, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      isDense: true,
                    ),
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF1E293B)),
                  ),
                ),
              ]),
            );
          }),
        ]),
      );

  Widget _buildCheckedBySection() => _card(
        title: 'Checked By',
        icon: Icons.how_to_reg_outlined,
        child: _inputField(_checkedByCtrl, 'Checked By', hint: 'Enter name'),
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
                offset: const Offset(0, 2))
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
              Text(title,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _accent)),
            ]),
          ),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ]),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151))),
      );

  Widget _inputField(
    TextEditingController ctrl,
    String label, {
    String? hint,
    int maxLines = 1,
  }) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label(label),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _accent, width: 1.5)),
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
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
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
                        : const Color(0xFFCBD5E1)),
              ),
            ),
            Icon(Icons.calendar_today_outlined,
                size: 16,
                color: value != null ? _accent : const Color(0xFF94A3B8)),
          ]),
        ),
      );

  Widget _timePicker({
    required TimeOfDay? value,
    required String hint,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Expanded(
              child: Text(
                value != null ? _fmtTime(value) : hint,
                style: TextStyle(
                    fontSize: 13,
                    color: value != null
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFCBD5E1)),
              ),
            ),
            Icon(Icons.access_time_outlined,
                size: 16,
                color: value != null ? _accent : const Color(0xFF94A3B8)),
          ]),
        ),
      );
}