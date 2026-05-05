// lib/features/concreting_checklist/presentation/concreting_checklist_view_page.dart

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../data/models/concreting_checklist_model.dart';

class ConcretingChecklistViewPage extends StatelessWidget {
  final ConcretingChecklistModel checklist;
  final String projectName;

  const ConcretingChecklistViewPage({
    super.key,
    required this.checklist,
    required this.projectName,
  });

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
        surfaceTintColor: Colors.transparent,
        title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          const Text('Concreting Checklist',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B))),
          Text(checklist.checklistNo,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF64748B))),
        ]),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // ── Header card ────────────────────────────────────────────
          _sectionCard(
            title: 'WR/EXE/06 — Checklist for Concreting',
            icon: Icons.layers_outlined,
            children: [
              _row2('Checklist No.', checklist.checklistNo, 'Date',
                  _fmtDate(checklist.checklistDate)),
              const SizedBox(height: 10),
              _infoRow('Project', projectName),
              const SizedBox(height: 8),
              _row2('Location', checklist.location, 'Part / Wing',
                  checklist.partWing),
              const SizedBox(height: 8),
              _infoRow('Date of Casting',
                  _fmtDate(checklist.dateOfCasting)),
            ],
          ),
          const SizedBox(height: 12),

          // ── Check following points ─────────────────────────────────
          _sectionCard(
            title: 'Check Following Points',
            icon: Icons.checklist_outlined,
            children: [
              _row2(
                  '01) HFL Reference',
                  checklist.hflReference,
                  '03) Shuttering',
                  checklist.shuttering),
              const SizedBox(height: 8),
              _row2('04) Reinforcement', checklist.reinforcement,
                  '05) Electrical', checklist.electrical),
              const SizedBox(height: 8),
              _row2('06) Plumbing', checklist.plumbing, '07) General',
                  checklist.general),
            ],
          ),
          const SizedBox(height: 12),

          // ── Drawings available ─────────────────────────────────────
          _sectionCard(
            title: 'Drawings Available',
            icon: Icons.description_outlined,
            children: [
              _row2('01) RCC', checklist.rcc, '02) RCC Drawing',
                  checklist.rccDrawing),
              const SizedBox(height: 8),
              _row2('03) Plumbing Drawing', checklist.plumbingDrawing,
                  '04) Architect', checklist.architectDrawing),
            ],
          ),
          const SizedBox(height: 12),

          // ── Test results table ─────────────────────────────────────
          _sectionCard(
            title: 'Checklist Items',
            icon: Icons.list_alt_outlined,
            children: [
              if (checklist.testResults.isEmpty)
                const Text('No checklist items recorded.',
                    style: TextStyle(
                        color: Color(0xFF94A3B8), fontSize: 13))
              else
                _buildTestResultsTable(),
            ],
          ),

          // ── Additional observations ────────────────────────────────
          if (checklist.additionalObservations?.isNotEmpty ==
              true) ...[
            const SizedBox(height: 12),
            _sectionCard(
              title: 'Additional Observations',
              icon: Icons.notes_outlined,
              children: [
                Text(
                  checklist.additionalObservations!,
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1E293B),
                      height: 1.5),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // ── Signature section ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                  const SizedBox(height: 40),
                  const Divider(color: Color(0xFF1E293B)),
                  const Text('Contractor Representative',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  const Text('Date:',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B))),
                ]),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                  const SizedBox(height: 40),
                  const Divider(color: Color(0xFF1E293B)),
                  const Text('Project Engineer / Client',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  const Text('Date:',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B))),
                ]),
              ),
            ]),
          ),

          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  // ── Test results grouped by section ─────────────────────────────────────

  Widget _buildTestResultsTable() {
    // Group results by section using the same section logic as the web blade
    final Map<String, List<ConcretingTestResult>> sections = {
      'LEVEL': [],
      'SHUTTERING': [],
      'REINFORCEMENT (Clean & Rust Free)': [],
      'ELECTRICAL CONDUITS & BOXES': [],
      'GENERAL': [],
    };

    String currentSection = '';
    for (final t in checklist.testResults) {
      final p = t.particulars.toLowerCase();
      if (p.contains('level of slab') || p.contains('check the level')) {
        currentSection = 'LEVEL';
      } else if (p.contains('dimensions, diagonals') ||
          p.contains('beam is in line') ||
          p.contains('plywood') ||
          p.contains('shuttering oil') ||
          p.contains('stoppers') ||
          p.contains('gaps in shuttering') ||
          p.contains('binding wires') ||
          p.contains('spans checked') ||
          p.contains('defective spans') ||
          p.contains('shear keys') ||
          p.contains('additional central') ||
          p.contains('over lap') ||
          p.contains('teer lapha') ||
          p.contains('props are vertical') ||
          p.contains('supporting system') ||
          p.contains('sprinkle') ||
          p.contains('adjustment of height') ||
          p.contains('runners are') ||
          p.contains('camber') ||
          p.contains('lift well') ||
          p.contains('depth/ thickness')) {
        currentSection = 'SHUTTERING';
      } else if (p.contains('diameter & number') ||
          p.contains('lap length') ||
          p.contains('bends & l') ||
          p.contains('chairs in proper') ||
          p.contains('top bar') ||
          p.contains('coverings are in contact') ||
          p.contains('covering blocks') ||
          p.contains('joints are well tied') ||
          p.contains('reduced column') ||
          p.contains('dowels for further')) {
        currentSection = 'REINFORCEMENT (Clean & Rust Free)';
      } else if (p.contains('90°') ||
          p.contains('drops in the position') ||
          p.contains('conduits drop in beam') ||
          p.contains('slurry not entering') ||
          p.contains('coupling is not allowed') ||
          p.contains('electrical material') ||
          p.contains('a/c or any other')) {
        currentSection = 'ELECTRICAL CONDUITS & BOXES';
      } else if (p.contains('floor on which props') ||
          p.contains('method of placing') ||
          p.contains('availability of cement') ||
          p.contains('vibrators') ||
          p.contains('mixer hoist') ||
          p.contains('slump cone') ||
          p.contains('tarpaulin') ||
          p.contains('surface is leveled') ||
          p.contains('beam depth') ||
          p.contains('found equal') ||
          p.contains('external beams') ||
          p.contains('electrical conduits') ||
          p.contains('stair case') ||
          p.contains('bharat-ghoota')) {
        currentSection = 'GENERAL';
      }

      if (currentSection.isNotEmpty &&
          sections.containsKey(currentSection)) {
        sections[currentSection]!.add(t);
      }
    }

    final children = <Widget>[];

    sections.forEach((sectionName, items) {
      if (items.isEmpty) return;

      children.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: AppColors.primaryGreen.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          sectionName,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryGreen),
        ),
      ));

      for (final t in items) {
        children.add(_testResultRow(t));
      }
    });

    return Column(children: children);
  }

  Widget _testResultRow(ConcretingTestResult t) {
    Color checkColor;
    IconData checkIcon;
    String checkLabel;
    if (t.checkYes) {
      checkColor = const Color(0xFF22C55E);
      checkIcon = Icons.check_circle;
      checkLabel = 'Yes';
    } else if (t.checkNo) {
      checkColor = const Color(0xFFEF4444);
      checkIcon = Icons.cancel;
      checkLabel = 'No';
    } else {
      checkColor = const Color(0xFF94A3B8);
      checkIcon = Icons.remove;
      checkLabel = '—';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 28,
          child: Text(t.srNo.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryGreen)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(t.particulars,
              style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF1E293B),
                  height: 1.4)),
        ),
        const SizedBox(width: 8),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: checkColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(checkIcon, size: 10, color: checkColor),
            const SizedBox(width: 3),
            Text(checkLabel,
                style: TextStyle(
                    fontSize: 10,
                    color: checkColor,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
        if (t.remark.isNotEmpty) ...[
          const SizedBox(width: 6),
          SizedBox(
            width: 72,
            child: Text(t.remark,
                style: const TextStyle(
                    fontSize: 10, color: Color(0xFF64748B)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ]),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

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
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10)),
            ),
            child: Row(children: [
              Icon(icon, size: 15, color: AppColors.primaryGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryGreen)),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children),
          ),
        ]),
      );

  Widget _row2(
          String l1, String? v1, String l2, String? v2) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _infoRow(l1, v1)),
        const SizedBox(width: 12),
        Expanded(child: _infoRow(l2, v2)),
      ]);

  Widget _infoRow(String label, String? value) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3)),
        const SizedBox(height: 2),
        Text(
          value?.isNotEmpty == true ? value! : 'N/A',
          style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w500),
        ),
      ]);
}