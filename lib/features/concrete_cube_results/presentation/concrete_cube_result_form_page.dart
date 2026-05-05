// lib/features/concrete_cube_results/presentation/concrete_cube_result_form_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/models/concrete_cube_result_model.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/utils/api_exception.dart';

class ConcreteCubeResultFormPage extends StatefulWidget {
  final int projectId;
  final String projectName;
  final ConcreteCubeResultModel? existing;

  const ConcreteCubeResultFormPage({
    super.key,
    required this.projectId,
    required this.projectName,
    this.existing,
  });

  @override
  State<ConcreteCubeResultFormPage> createState() =>
      _ConcreteCubeResultFormPageState();
}

// ── Row data holder ───────────────────────────────────────────────────────────

class _TestRowData {
  final TextEditingController dateCtrl = TextEditingController();
  final TextEditingController gradeCtrl = TextEditingController();
  final TextEditingController locationCtrl = TextEditingController();
  final TextEditingController totalQtyCtrl = TextEditingController();
  final TextEditingController ageOfCubeCtrl = TextEditingController();

  // weight/dimensions
  final TextEditingController weightCtrl = TextEditingController();
  final TextEditingController lengthCtrl = TextEditingController();
  final TextEditingController breadthCtrl = TextEditingController();

  // 7-day
  final TextEditingController maxLoad7_1 = TextEditingController();
  final TextEditingController maxLoad7_2 = TextEditingController();
  final TextEditingController maxLoad7_3 = TextEditingController();
  final TextEditingController cs7_1 = TextEditingController();
  final TextEditingController cs7_2 = TextEditingController();
  final TextEditingController cs7_3 = TextEditingController();

  // 28-day
  final TextEditingController maxLoad28_1 = TextEditingController();
  final TextEditingController maxLoad28_2 = TextEditingController();
  final TextEditingController maxLoad28_3 = TextEditingController();
  final TextEditingController cs28_1 = TextEditingController();
  final TextEditingController cs28_2 = TextEditingController();
  final TextEditingController cs28_3 = TextEditingController();

  final TextEditingController remarksCtrl = TextEditingController();

  String avg7Display = '';
  String avg28Display = '';

  void dispose() {
    for (final c in _allControllers) {
      c.dispose();
    }
  }

  List<TextEditingController> get _allControllers => [
        dateCtrl,
        gradeCtrl,
        locationCtrl,
        totalQtyCtrl,
        ageOfCubeCtrl,
        weightCtrl,
        lengthCtrl,
        breadthCtrl,
        maxLoad7_1,
        maxLoad7_2,
        maxLoad7_3,
        cs7_1,
        cs7_2,
        cs7_3,
        maxLoad28_1,
        maxLoad28_2,
        maxLoad28_3,
        cs28_1,
        cs28_2,
        cs28_3,
        remarksCtrl,
      ];

  List<String> get maxLoad7 =>
      [maxLoad7_1.text, maxLoad7_2.text, maxLoad7_3.text];

  List<String> get cs7 => [cs7_1.text, cs7_2.text, cs7_3.text];

  List<String> get maxLoad28 =>
      [maxLoad28_1.text, maxLoad28_2.text, maxLoad28_3.text];

  List<String> get cs28 => [cs28_1.text, cs28_2.text, cs28_3.text];

  double? get computedAvg7 {
    final vals = cs7
        .map((v) => double.tryParse(v))
        .whereType<double>()
        .where((v) => v > 0)
        .toList();

    if (vals.isEmpty) return null;
    return vals.reduce((a, b) => a + b) / vals.length;
  }

  double? get computedAvg28 {
    final vals = cs28
        .map((v) => double.tryParse(v))
        .whereType<double>()
        .where((v) => v > 0)
        .toList();

    if (vals.isEmpty) return null;
    return vals.reduce((a, b) => a + b) / vals.length;
  }

  void updateAvgDisplays() {
    final a7 = computedAvg7;
    final a28 = computedAvg28;
    avg7Display = a7 != null ? a7.toStringAsFixed(2) : '';
    avg28Display = a28 != null ? a28.toStringAsFixed(2) : '';
  }

  Map<String, dynamic> toJson() {
    return {
      'date_of_testing': dateCtrl.text.trim(),
      'grade_of_concrete': gradeCtrl.text.trim(),
      'location': locationCtrl.text.trim(),
      'total_qty': totalQtyCtrl.text.trim(),
      'age_of_cube': ageOfCubeCtrl.text.trim(),
      'weight_dimensions': [
        {
          'weight': weightCtrl.text.trim(),
          'length': lengthCtrl.text.trim(),
          'breadth': breadthCtrl.text.trim(),
        }
      ],
      'max_load_7_days': maxLoad7,
      'compressive_strength_7_days': cs7,
      'max_load_28_days': maxLoad28,
      'compressive_strength_28_days': cs28,
      'remarks': remarksCtrl.text.trim(),
    };
  }
}

// ── State ─────────────────────────────────────────────────────────────────────

class _ConcreteCubeResultFormPageState
    extends State<ConcreteCubeResultFormPage> {
  static const _accent = Color(0xFF1565C0);

  final List<_TestRowData> _rows = [];
  final _checkedByCtrl = TextEditingController();
  final _qaByCtrl = TextEditingController();
  final _preparedByCtrl = TextEditingController();

  bool _isSaving = false;
  bool get _isEditing => widget.existing != null;

  String _overallAvg7 = '';
  String _overallAvg28 = '';

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _populateFromExisting();
    } else {
      for (int i = 0; i < 5; i++) {
        _rows.add(_TestRowData());
      }
    }
  }

  void _populateFromExisting() {
    final e = widget.existing!;
    _checkedByCtrl.text = e.checkedBy ?? '';
    _qaByCtrl.text = e.qaBy ?? '';
    _preparedByCtrl.text = e.preparedBy ?? '';

    for (final entry in e.testData) {
      final row = _TestRowData();
      row.dateCtrl.text = entry.dateOfTesting;
      row.gradeCtrl.text = entry.gradeOfConcrete;
      row.locationCtrl.text = entry.location;
      row.totalQtyCtrl.text = entry.totalQty;
      row.ageOfCubeCtrl.text = entry.ageOfCube;

      if (entry.weightDimensions.isNotEmpty) {
        row.weightCtrl.text = entry.weightDimensions[0].weight;
        row.lengthCtrl.text = entry.weightDimensions[0].length;
        row.breadthCtrl.text = entry.weightDimensions[0].breadth;
      }

      _setList(
        [row.maxLoad7_1, row.maxLoad7_2, row.maxLoad7_3],
        entry.maxLoad7Days,
      );
      _setList(
        [row.cs7_1, row.cs7_2, row.cs7_3],
        entry.compressiveStrength7Days,
      );
      _setList(
        [row.maxLoad28_1, row.maxLoad28_2, row.maxLoad28_3],
        entry.maxLoad28Days,
      );
      _setList(
        [row.cs28_1, row.cs28_2, row.cs28_3],
        entry.compressiveStrength28Days,
      );

      row.remarksCtrl.text = entry.remarks;
      row.updateAvgDisplays();
      _rows.add(row);
    }

    if (_rows.isEmpty) {
      for (int i = 0; i < 5; i++) {
        _rows.add(_TestRowData());
      }
    }

    _recalcOverall();
  }

  void _setList(List<TextEditingController> ctrls, List<String> vals) {
    for (int i = 0; i < ctrls.length; i++) {
      ctrls[i].text = i < vals.length ? vals[i] : '';
    }
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    _checkedByCtrl.dispose();
    _qaByCtrl.dispose();
    _preparedByCtrl.dispose();
    super.dispose();
  }

  void _addRow() {
    setState(() => _rows.add(_TestRowData()));
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) return;

    setState(() {
      _rows[index].dispose();
      _rows.removeAt(index);
      _recalcOverall();
    });
  }

  void _onCompressiveChanged() {
    setState(() {
      for (final row in _rows) {
        row.updateAvgDisplays();
      }
      _recalcOverall();
    });
  }

  void _recalcOverall() {
    double sum7 = 0;
    double count7 = 0;
    double sum28 = 0;
    double count28 = 0;

    for (final row in _rows) {
      for (final v in row.cs7) {
        final d = double.tryParse(v);
        if (d != null && d > 0) {
          sum7 += d;
          count7++;
        }
      }

      for (final v in row.cs28) {
        final d = double.tryParse(v);
        if (d != null && d > 0) {
          sum28 += d;
          count28++;
        }
      }
    }

    _overallAvg7 = count7 > 0 ? (sum7 / count7).toStringAsFixed(2) : '';
    _overallAvg28 = count28 > 0 ? (sum28 / count28).toStringAsFixed(2) : '';
  }

  Future<void> _submit() async {
    if (_isSaving) return;

    final validRows = _rows
        .where(
          (r) =>
              r.dateCtrl.text.trim().isNotEmpty &&
              r.gradeCtrl.text.trim().isNotEmpty,
        )
        .toList();

    if (validRows.isEmpty) {
      _showError(
        'Please fill in at least one row with Date of Testing and Grade of Concrete.',
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final testData = validRows.map((r) => r.toJson()).toList();
      final avg7 = _overallAvg7.isNotEmpty ? double.tryParse(_overallAvg7) : null;
      final avg28 =
          _overallAvg28.isNotEmpty ? double.tryParse(_overallAvg28) : null;

      if (_isEditing) {
        await ApiService.updateConcreteCubeResult(
          projectId: widget.projectId,
          id: widget.existing!.id,
          testData: testData,
          avg7Days: avg7,
          avg28Days: avg28,
          checkedBy: _checkedByCtrl.text.trim(),
          qaBy: _qaByCtrl.text.trim(),
          preparedBy: _preparedByCtrl.text.trim(),
        );
      } else {
        await ApiService.createConcreteCubeResult(
          projectId: widget.projectId,
          testData: testData,
          avg7Days: avg7,
          avg28Days: avg28,
          checkedBy: _checkedByCtrl.text.trim(),
          qaBy: _qaByCtrl.text.trim(),
          preparedBy: _preparedByCtrl.text.trim(),
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Test updated successfully!'
                : 'Test created successfully!',
          ),
          backgroundColor: const Color(0xFF22C55E),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showError(e is ApiException ? e.message : e.toString());
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
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

  Future<void> _pickDate(_TestRowData row) async {
    DateTime initial = DateTime.now();

    if (row.dateCtrl.text.isNotEmpty) {
      try {
        initial = DateTime.parse(row.dateCtrl.text);
      } catch (_) {}
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _accent),
        ),
        child: child!,
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        row.dateCtrl.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
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
              _isEditing ? 'Edit Concrete Cube Test' : 'New Concrete Cube Test',
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
          ],
        ),
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
                      _isEditing ? 'Update' : 'Save Test',
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
          SliverToBoxAdapter(child: _buildHeaderInfo()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Test Data',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  GestureDetector(
                    onTap: _addRow,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 15, color: Colors.white),
                          SizedBox(width: 5),
                          Text(
                            'Add Row',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _buildTestRowCard(i),
              childCount: _rows.length,
            ),
          ),
          SliverToBoxAdapter(child: _buildOverallAverages()),
          SliverToBoxAdapter(child: _buildSignatures()),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildHeaderInfo() => Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _accent.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'WR/EXE/05',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text(
                  'WISE REALTY',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'TESTING OF CONCRETE CUBES',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _accent,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Name Of The Project:',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          widget.projectName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1E293B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _buildTestRowCard(int index) {
    final row = _rows[index];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}'.padLeft(2, '0'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Test Entry',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: _accent,
                    ),
                  ),
                ),
                if (_rows.length > 1)
                  GestureDetector(
                    onTap: () => _removeRow(index),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: Color(0xFFEF4444),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('Date of Testing *'),
                          GestureDetector(
                            onTap: () => _pickDate(row),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: const Color(0xFFD1D5DB)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      row.dateCtrl.text.isEmpty
                                          ? 'Select date'
                                          : _formatDisplayDate(row.dateCtrl.text),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: row.dateCtrl.text.isEmpty
                                            ? const Color(0xFF9CA3AF)
                                            : const Color(0xFF1E293B),
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 15,
                                    color: Color(0xFF6B7280),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _inputField(
                        row.gradeCtrl,
                        'Grade *',
                        hint: 'e.g. M25',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _inputField(
                        row.locationCtrl,
                        'Location',
                        hint: 'Location',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _inputField(
                        row.totalQtyCtrl,
                        'Total Qty',
                        hint: 'Qty',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _inputField(
                        row.ageOfCubeCtrl,
                        'Age of Cube',
                        hint: 'e.g. 28 days',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _sectionHeader('Weight & Dimensions of Cube'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _numField(
                        row.weightCtrl,
                        'Weight (kg)',
                        hint: 'Weight',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _numField(
                        row.lengthCtrl,
                        'Length (mm)',
                        hint: 'Length',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _numField(
                        row.breadthCtrl,
                        'Breadth (mm)',
                        hint: 'Breadth',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _sectionHeader('Test at 7 Days'),
                const SizedBox(height: 6),
                _testTripleRow(
                  loadCtrls: [row.maxLoad7_1, row.maxLoad7_2, row.maxLoad7_3],
                  csCtrls: [row.cs7_1, row.cs7_2, row.cs7_3],
                  avg: row.avg7Display,
                  color: const Color(0xFF0891B2),
                  onChanged: _onCompressiveChanged,
                ),
                const SizedBox(height: 10),
                _sectionHeader('Test at 28 Days'),
                const SizedBox(height: 6),
                _testTripleRow(
                  loadCtrls: [
                    row.maxLoad28_1,
                    row.maxLoad28_2,
                    row.maxLoad28_3,
                  ],
                  csCtrls: [row.cs28_1, row.cs28_2, row.cs28_3],
                  avg: row.avg28Display,
                  color: const Color(0xFF059669),
                  onChanged: _onCompressiveChanged,
                ),
                const SizedBox(height: 10),
                _inputField(
                  row.remarksCtrl,
                  'Remarks',
                  hint: 'Pass / Fail / Notes',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _testTripleRow({
    required List<TextEditingController> loadCtrls,
    required List<TextEditingController> csCtrls,
    required String avg,
    required Color color,
    required VoidCallback onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Max Load (kN)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Comp. Strength (N/mm²)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 60,
                child: Text(
                  'Avg',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...List.generate(3, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  Expanded(
                    child: _numFieldSmall(loadCtrls[i], 'T${i + 1}', () {}),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _numFieldSmall(csCtrls[i], 'T${i + 1}', onChanged),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 60,
                    child: i == 2
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: avg.isNotEmpty
                                  ? color.withValues(alpha: 0.12)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: avg.isNotEmpty
                                    ? color.withValues(alpha: 0.3)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Text(
                              avg.isEmpty ? '—' : avg,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: avg.isNotEmpty
                                    ? color
                                    : const Color(0xFFCBD5E1),
                              ),
                            ),
                          )
                        : const SizedBox(),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildOverallAverages() => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _accent.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Overall Average N/mm²',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _avgDisplay(
                    '7 Days Overall Avg',
                    _overallAvg7.isEmpty ? '—' : _overallAvg7,
                    const Color(0xFF0891B2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _avgDisplay(
                    '28 Days Overall Avg',
                    _overallAvg28.isEmpty ? '—' : _overallAvg28,
                    const Color(0xFF059669),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _avgDisplay(String label, String value, Color color) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      );

  Widget _buildSignatures() => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _accent.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Signatures',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _inputField(
                    _checkedByCtrl,
                    'CHECKED BY',
                    hint: 'Name',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _inputField(
                    _qaByCtrl,
                    'Q.A. BY',
                    hint: 'Name',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _inputField(
              _preparedByCtrl,
              'Prepared and Issued by',
              hint: 'Name',
            ),
          ],
        ),
      );

  Widget _sectionHeader(String text) => Row(
        children: [
          Container(
            width: 3,
            height: 12,
            decoration: BoxDecoration(
              color: _accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
              letterSpacing: 0.2,
            ),
          ),
        ],
      );

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
      );

  InputDecoration _inputDeco(String? hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        isDense: true,
      );

  Widget _inputField(
    TextEditingController ctrl,
    String label, {
    String? hint,
    int maxLines = 1,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(label),
          TextField(
            controller: ctrl,
            maxLines: maxLines,
            decoration: _inputDeco(hint),
            style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
          ),
        ],
      );

  Widget _numField(
    TextEditingController ctrl,
    String label, {
    String? hint,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(label),
          TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: _inputDeco(hint),
            style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
          ),
        ],
      );

  Widget _numFieldSmall(
    TextEditingController ctrl,
    String hint,
    VoidCallback onChanged,
  ) =>
      TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        ],
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _accent, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          isDense: true,
        ),
        style: const TextStyle(fontSize: 11, color: Color(0xFF1E293B)),
      );

  String _formatDisplayDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return iso;
    }
  }
}