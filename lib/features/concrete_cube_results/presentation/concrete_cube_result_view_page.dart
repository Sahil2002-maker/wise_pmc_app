// lib/features/concrete_cube_results/presentation/concrete_cube_result_view_page.dart

import 'package:flutter/material.dart';
import '../data/models/concrete_cube_result_model.dart';

class ConcreteCubeResultViewPage extends StatelessWidget {
  final ConcreteCubeResultModel result;
  final String projectName;

  const ConcreteCubeResultViewPage({
    super.key,
    required this.result,
    required this.projectName,
  });

  static const _accent = Color(0xFF1565C0);

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

  String _fmtNum(String v) {
    final d = double.tryParse(v);
    return d != null && d > 0 ? d.toStringAsFixed(2) : '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Testing of Concrete Cubes',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B))),
          Text(result.uniqueNumber,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF64748B))),
        ]),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Top header banner ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                const Text('WR/EXE/05',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF1E293B))),
                const Text('WISE REALTY',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF1E293B))),
              ]),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'TESTING OF CONCRETE CUBES',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _accent,
                      letterSpacing: 0.5),
                ),
              ),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                _headerInfoItem('Checklist No.',
                    result.uniqueNumber),
                _headerInfoItem('Test No.',
                    result.resultNo.toString()),
              ]),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: _headerInfoItem('Project', projectName),
              ),
            ]),
          ),
          const SizedBox(height: 14),

          // ── Test data table ───────────────────────────────────────────
          _sectionCard(
            title: 'Test Data',
            icon: Icons.table_chart_outlined,
            child: result.testData.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No test data available.',
                          style: TextStyle(
                              color: Color(0xFF94A3B8))),
                    ))
                : Column(
                    children: result.testData
                        .asMap()
                        .entries
                        .map((e) =>
                            _testEntryCard(e.key, e.value))
                        .toList()),
          ),
          const SizedBox(height: 14),

          // ── Overall averages ──────────────────────────────────────────
          _sectionCard(
            title: 'Overall Averages',
            icon: Icons.analytics_outlined,
            child: Row(children: [
              Expanded(
                child: _avgTile(
                  label: 'Overall Avg 7 Days',
                  value: result.avg7Days != null
                      ? '${result.avg7Days!.toStringAsFixed(2)} N/mm²'
                      : 'N/A',
                  color: const Color(0xFF0891B2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _avgTile(
                  label: 'Overall Avg 28 Days',
                  value: result.avg28Days != null
                      ? '${result.avg28Days!.toStringAsFixed(2)} N/mm²'
                      : 'N/A',
                  color: const Color(0xFF059669),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),

          // ── Signatures ────────────────────────────────────────────────
          _sectionCard(
            title: 'Signatures',
            icon: Icons.draw_outlined,
            child: Column(children: [
              Row(children: [
                Expanded(
                    child: _signatureBlock(
                        'CHECKED BY', result.checkedBy)),
                const SizedBox(width: 12),
                Expanded(
                    child:
                        _signatureBlock('Q.A. BY', result.qaBy)),
              ]),
              const SizedBox(height: 12),
              _signatureBlock(
                  'Prepared and Issued by', result.preparedBy,
                  fullWidth: true),
            ]),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _headerInfoItem(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 1),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B))),
        ],
      );

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) =>
      Container(
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
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _accent)),
            ]),
          ),
          Padding(
              padding: const EdgeInsets.all(14), child: child),
        ]),
      );

  Widget _testEntryCard(int index, ConcreteCubeTestEntry e) {
    final avg7 = e.avg7Days;
    final avg28 = e.avg28Days;
    final wd =
        e.weightDimensions.isNotEmpty ? e.weightDimensions[0] : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        // Row header
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
          Row(children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(6)),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}'.padLeft(2, '0'),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            Text(_fmtDate(e.dateOfTesting),
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF1E293B))),
          ]),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(e.gradeOfConcrete,
                style: const TextStyle(
                    fontSize: 11,
                    color: _accent,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 10),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        const SizedBox(height: 10),

        // Basic fields
        Row(children: [
          _entryField('Location', e.location),
          _entryField('Total Qty', e.totalQty),
          _entryField('Age of Cube', e.ageOfCube),
        ]),
        if (wd != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            _entryField('Weight', '${wd.weight} kg'),
            _entryField('Length', '${wd.length} mm'),
            _entryField('Breadth', '${wd.breadth} mm'),
          ]),
        ],
        const SizedBox(height: 10),

        // 7-day tests
        _compressiveRow(
          label: '7-Day Tests',
          loads: e.maxLoad7Days,
          strengths: e.compressiveStrength7Days,
          avg: avg7,
          color: const Color(0xFF0891B2),
        ),
        const SizedBox(height: 8),

        // 28-day tests
        _compressiveRow(
          label: '28-Day Tests',
          loads: e.maxLoad28Days,
          strengths: e.compressiveStrength28Days,
          avg: avg28,
          color: const Color(0xFF059669),
        ),

        if (e.remarks.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.notes_outlined,
                size: 13, color: Color(0xFF94A3B8)),
            const SizedBox(width: 5),
            const Text('Remarks: ',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B))),
            Expanded(
              child: Text(e.remarks,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF1E293B))),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _compressiveRow({
    required String label,
    required List<String> loads,
    required List<String> strengths,
    required double? avg,
    required Color color,
  }) {
    final validLoads =
        loads.where((v) => v.isNotEmpty).toList();
    final validStrengths =
        strengths.where((v) => v.isNotEmpty).toList();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color)),
          if (avg != null)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                'Avg: ${avg.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w700),
              ),
            ),
        ]),
        if (validLoads.isNotEmpty || validStrengths.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Max Load (kN)',
                    style: TextStyle(
                        fontSize: 9,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                    validLoads.isEmpty
                        ? 'N/A'
                        : validLoads.join(', '),
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF1E293B))),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Comp. Strength (N/mm²)',
                    style: TextStyle(
                        fontSize: 9,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                    validStrengths.isEmpty
                        ? 'N/A'
                        : validStrengths.join(', '),
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF1E293B))),
              ]),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _entryField(String label, String? value) => Expanded(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 9,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3)),
          const SizedBox(height: 2),
          Text(
              (value != null && value.isNotEmpty) ? value : 'N/A',
              style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF1E293B),
                  fontWeight: FontWeight.w500)),
        ]),
      );

  Widget _avgTile(
          {required String label,
          required String value,
          required Color color}) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color)),
        ]),
      );

  Widget _signatureBlock(String label, String? value,
      {bool fullWidth = false}) {
    final child = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
      Text(label,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151))),
      const SizedBox(height: 24),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(
            border: Border(
                top: BorderSide(color: Color(0xFF1E293B), width: 1))),
        child: Text(
            (value != null && value.isNotEmpty) ? value : '—',
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF1E293B))),
      ),
    ]);

    return fullWidth ? child : child;
  }
}