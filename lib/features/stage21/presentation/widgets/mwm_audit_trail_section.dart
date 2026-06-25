// lib/features/stage21/presentation/widgets/mwm_audit_trail_section.dart
//
// Self-contained widget for the "Audit Trail – Removed Entries" section.
// Drop it into the MWM list page below the main records list.
//
// Usage:
//   MwmAuditTrailSection(projectId: widget.projectId)

import 'package:flutter/material.dart';
import '../controllers/mwm_audit_trail_controller.dart';
import '../../data/models/mwm_deleted_entry_model.dart';

class MwmAuditTrailSection extends StatefulWidget {
  final int projectId;

  const MwmAuditTrailSection({super.key, required this.projectId});

  @override
  State<MwmAuditTrailSection> createState() => _MwmAuditTrailSectionState();
}

class _MwmAuditTrailSectionState extends State<MwmAuditTrailSection> {
  late MwmAuditTrailController _ctrl;
  final TextEditingController _searchCtrl = TextEditingController();

  // ── Colours (matches web amber/warning audit palette) ──────────────────────
  static const Color _amber = Color(0xFFF59E0B);
  static const Color _amberLight = Color(0xFFFFF8E7);
  static const Color _amberBorder = Color(0xFFFFD700);
  static const Color _netRed = Color(0xFFDC2626);
  static const Color _muted = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _ctrl = MwmAuditTrailController(projectId: widget.projectId);
    _ctrl.load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _amberBorder.withValues(alpha: 0.55)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildInfoBanner(),
            _buildSearchBar(),
            _buildBody(),
            _buildPagination(),
          ],
        ),
      ),
    );
  }

  // ── Section header (title + "Read Only" badge) ─────────────────────────────

  Widget _buildHeader() => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: _amberLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          border: Border(
            bottom: BorderSide(color: _amberBorder.withValues(alpha: 0.4)),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: _amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.history_outlined,
                  color: _amber, size: 18),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Audit Trail — Removed Entries',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF92400E),
                ),
              ),
            ),
            // "Read Only" badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: _amber,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Read Only',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      );

  // ── Info banner ────────────────────────────────────────────────────────────

  Widget _buildInfoBanner() => Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        color: const Color(0xFFFFFBEB),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded,
                size: 14, color: _amber),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Entries removed during edit are preserved here for audit '
                'purposes. Files are retained on S3.',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF78350F),
                ),
              ),
            ),
          ],
        ),
      );

  // ── Search bar ─────────────────────────────────────────────────────────────

  Widget _buildSearchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
        child: TextField(
          controller: _searchCtrl,
          onChanged: _ctrl.onSearch,
          decoration: InputDecoration(
            hintText: 'Search by MWM No., vehicle, material type…',
            hintStyle:
                const TextStyle(color: Color(0xFFB0BAC9), fontSize: 12),
            prefixIcon:
                const Icon(Icons.search_rounded, color: _amber, size: 16),
            filled: true,
            fillColor: const Color(0xFFFFFBEB),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                  color: _amberBorder.withValues(alpha: 0.4)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                  color: _amberBorder.withValues(alpha: 0.4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _amber, width: 1.5),
            ),
          ),
          style: const TextStyle(fontSize: 12),
        ),
      );

  // ── Body (loading / error / empty / list) ──────────────────────────────────

  Widget _buildBody() {
    if (_ctrl.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(
          child: CircularProgressIndicator(color: _amber),
        ),
      );
    }

    if (_ctrl.error != null) {
      return _buildError();
    }

    if (_ctrl.totalAll == 0) {
      return _buildEmpty();
    }

    if (_ctrl.currentPage.isEmpty) {
      return _buildEmpty(
          message: 'No entries match your search.');
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Column(
        children: _ctrl.currentPage
            .asMap()
            .entries
            .map((e) => _buildEntryCard(e.key, e.value))
            .toList(),
      ),
    );
  }

  // ── Error ──────────────────────────────────────────────────────────────────

  Widget _buildError() => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Color(0xFFEF4444), size: 40),
            const SizedBox(height: 8),
            Text(
              _ctrl.error ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _ctrl.load(refresh: true),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry', style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _amber,
                side: const BorderSide(color: _amber),
              ),
            ),
          ],
        ),
      );

  // ── Empty ──────────────────────────────────────────────────────────────────

  Widget _buildEmpty({String message = 'No removed entries yet.'}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          children: [
            Icon(Icons.history_toggle_off_outlined,
                size: 48,
                color: _amber.withValues(alpha: 0.4)),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: _muted, fontSize: 13),
            ),
          ],
        ),
      );

  // ── Entry card ─────────────────────────────────────────────────────────────
  //
  // Because there are many columns (14 in the web table), we render each
  // deleted entry as a compact card with two sections:
  //   1. Identity row  (MWM No., Date, Entry #)
  //   2. Weight row    (Gross, Tare, Net)
  //   3. Details       (Vehicle, Challan, Material Type)
  //   4. Audit row     (Created By / At, Removed By / At)

  Widget _buildEntryCard(int localIndex, MwmDeletedEntryModel e) {
    final globalIndex =
        (_ctrl.currentPageNumber - 1) * 10 + localIndex + 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: _amberBorder.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card header ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
            decoration: BoxDecoration(
              color: _amber.withValues(alpha: 0.12),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                // Row number
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _amber,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$globalIndex',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.mwmNo,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF92400E),
                        ),
                      ),
                      Text(
                        e.measurementDate,
                        style: const TextStyle(
                            fontSize: 11, color: _muted),
                      ),
                    ],
                  ),
                ),
                // Entry # badge  (mirrors web "Entry #2" badge)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _amber.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    'Entry #${e.originalEntryIndex}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF92400E),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Weight row ─────────────────────────────────────────────
                Row(
                  children: [
                    _weightChip('Gross Wt.', '${e.grossWeight} kg',
                        isNet: false),
                    const SizedBox(width: 8),
                    _weightChip('Tare Wt.', '${e.tareWeight} kg',
                        isNet: false),
                    const SizedBox(width: 8),
                    _weightChip(
                        'Net Material Wt.', '${e.netMaterialWeight} kg',
                        isNet: true),
                  ],
                ),
                const SizedBox(height: 10),

                // ── Details row ────────────────────────────────────────────
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    _detailItem(
                        Icons.directions_car_outlined,
                        'Vehicle No.',
                        e.vehicleNumber),
                    _detailItem(Icons.receipt_outlined, 'Challan No.',
                        e.challanNumber),
                    _detailItem(Icons.category_outlined,
                        'Material Type', e.materialTypeName),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFE9D5A0)),
                const SizedBox(height: 10),

                // ── Audit trail row ────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _auditBlock(
                        icon: Icons.person_add_alt_1_outlined,
                        title: 'Created By',
                        name: e.originalCreatedBy,
                        datetime: e.originalCreatedAt,
                        color: const Color(0xFF3B82F6),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _auditBlock(
                        icon: Icons.delete_sweep_outlined,
                        title: 'Removed By',
                        name: e.deletedBy,
                        datetime: e.deletedAt,
                        color: _netRed,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Weight chip ────────────────────────────────────────────────────────────

  Widget _weightChip(String label, String value, {required bool isNet}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isNet
              ? _netRed.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: isNet
                ? _netRed.withValues(alpha: 0.35)
                : const Color(0xFFE2E8F0),
            width: isNet ? 1.5 : 1,
          ),
        ),
        child: Column(children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: isNet ? _netRed : _muted,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isNet ? _netRed : const Color(0xFF1E293B),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Detail item ────────────────────────────────────────────────────────────

  Widget _detailItem(IconData icon, String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 9,
                  color: _muted,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2)),
          const SizedBox(height: 2),
          Row(children: [
            Icon(icon, size: 11, color: _muted),
            const SizedBox(width: 3),
            Text(
              value,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B)),
            ),
          ]),
        ],
      );

  // ── Audit block ────────────────────────────────────────────────────────────

  Widget _auditBlock({
    required IconData icon,
    required String title,
    required String name,
    required String datetime,
    required Color color,
  }) =>
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.2),
              ),
            ]),
            const SizedBox(height: 4),
            Text(
              name,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B)),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.access_time_outlined,
                  size: 10, color: _muted),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  datetime,
                  style:
                      const TextStyle(fontSize: 10, color: _muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ],
        ),
      );

  // ── Pagination row ─────────────────────────────────────────────────────────

  Widget _buildPagination() {
    if (_ctrl.loading || _ctrl.error != null || _ctrl.totalAll == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        children: [
          // Range text (matches "Showing 1 to 1 of 1 entries" in the web)
          Text(
            _ctrl.pageRangeText,
            style: const TextStyle(fontSize: 11, color: _muted),
          ),
          if (_ctrl.totalPages > 1) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Previous
                _pageBtn(
                  label: '‹ Previous',
                  enabled: _ctrl.hasPrev,
                  onTap: _ctrl.prevPage,
                ),
                const SizedBox(width: 8),
                // Page number chips (show up to 5)
                ..._buildPageChips(),
                const SizedBox(width: 8),
                // Next
                _pageBtn(
                  label: 'Next ›',
                  enabled: _ctrl.hasNext,
                  onTap: _ctrl.nextPage,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildPageChips() {
    final total = _ctrl.totalPages;
    final current = _ctrl.currentPageNumber;

    // Show at most 5 page buttons centred around the current page
    int start = (current - 2).clamp(1, total);
    int end = (start + 4).clamp(1, total);
    start = (end - 4).clamp(1, total);

    return List.generate(end - start + 1, (i) {
      final page = start + i;
      final isActive = page == current;
      return GestureDetector(
        onTap: () => _ctrl.goToPage(page),
        child: Container(
          width: 30,
          height: 30,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isActive ? _amber : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive
                  ? _amber
                  : _amberBorder.withValues(alpha: 0.4),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '$page',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isActive ? Colors.white : const Color(0xFF92400E),
            ),
          ),
        ),
      );
    });
  }

  Widget _pageBtn({
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: enabled
                ? _amber.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: enabled
                  ? _amber.withValues(alpha: 0.4)
                  : Colors.grey.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: enabled ? const Color(0xFF92400E) : _muted,
            ),
          ),
        ),
      );
}