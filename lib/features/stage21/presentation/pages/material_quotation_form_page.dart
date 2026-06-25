import 'package:flutter/material.dart';
import '../controllers/material_quotation_controller.dart';

class MaterialQuotationFormPage extends StatefulWidget {
  final MaterialQuotationController controller;
  final bool isEdit;
  final int? quotationId;

  const MaterialQuotationFormPage({
    super.key,
    required this.controller,
    required this.isEdit,
    this.quotationId,
  });

  @override
  State<MaterialQuotationFormPage> createState() =>
      _MaterialQuotationFormPageState();
}

class _MaterialQuotationFormPageState
    extends State<MaterialQuotationFormPage> {
  static const Color _accent = Color(0xFF7C3AED);

  MaterialQuotationController get _ctrl => widget.controller;

  Future<void> _save() async {
    final ok = widget.isEdit
        ? await _ctrl.saveEdit(widget.quotationId!)
        : await _ctrl.saveCreate();
    if (ok && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.isEdit
            ? 'Quotation updated successfully.'
            : 'Quotation created successfully.'),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _pickDate(TextEditingController dateCtrl) async {
    final now  = DateTime.now();
    final date = await showDatePicker(
      context:     context,
      initialDate: now,
      firstDate:   DateTime(2020),
      lastDate:    DateTime(2030),
      builder:     (_, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
              primary: Color(0xFF7C3AED)),
        ),
        child: child!,
      ),
    );
    if (date != null) {
      dateCtrl.text =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        elevation:       0,
        title: Text(
          widget.isEdit
              ? 'Edit Material Quotation'
              : 'Create Material Quotation',
          style: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          if (_ctrl.formLoading && _ctrl.rows.isEmpty) {
            return const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF7C3AED)));
          }
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderCard(),
                      const SizedBox(height: 16),
                      if (_ctrl.formError != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: Color(0xFFEF4444), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_ctrl.formError!,
                                    style: const TextStyle(
                                        color: Color(0xFFEF4444),
                                        fontSize: 13)),
                              ),
                            ],
                          ),
                        ),
                      const Text('Quotation Rows',
                          style: TextStyle(
                              fontSize:   14,
                              fontWeight: FontWeight.w700,
                              color:      Color(0xFF1E293B))),
                      const SizedBox(height: 8),
                      ..._ctrl.rows
                          .asMap()
                          .entries
                          .map((e) => _buildRow(e.key, e.value)),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _ctrl.addRow,
                        icon: const Icon(Icons.add_rounded,
                            color: Color(0xFF7C3AED)),
                        label: const Text('Add Row',
                            style:
                                TextStyle(color: Color(0xFF7C3AED))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Color(0xFF7C3AED)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                color: Colors.white,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _ctrl.formLoading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _ctrl.formLoading
                        ? const SizedBox(
                            width:  20,
                            height: 20,
                            child:  CircularProgressIndicator(
                                color:       Colors.white,
                                strokeWidth: 2),
                          )
                        : Text(
                            widget.isEdit
                                ? 'Update Quotation'
                                : 'Save Quotation',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize:   15),
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset:     const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('WR/QUO/21',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              Text('WISE REALTY',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const Divider(height: 16),
          Row(
            children: [
              const Text('No.: ',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color:      Color(0xFF475569))),
              Text(_ctrl.nextQuotationNo,
                  style: const TextStyle(
                      color:      Color(0xFF1E293B),
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Project: ',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color:      Color(0xFF475569))),
              Expanded(
                child: Text(_ctrl.projectName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF1E293B))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Register Month *',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color:      Color(0xFF475569),
                  fontSize:   13)),
          const SizedBox(height: 6),
          _QuotationMonthPicker(
            value:     _ctrl.selectedMonth,
            onChanged: _ctrl.setMonth,
          ),
        ],
      ),
    );
  }

  Widget _buildRow(int index, QuotationRowState row) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color:        const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Row ${index + 1}',
                    style: const TextStyle(
                        fontSize:   11,
                        fontWeight: FontWeight.w700,
                        color:      Color(0xFF7C3AED))),
              ),
              const Spacer(),
              if (_ctrl.rows.length > 1)
                IconButton(
                  onPressed:   () => _ctrl.removeRow(index),
                  icon: const Icon(Icons.remove_circle_outline_rounded,
                      color: Color(0xFFEF4444), size: 20),
                  padding:     EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _QuotationFieldWithDate(
                  label: 'Date *',
                  ctrl:  row.date,
                  onTap: () => _pickDate(row.date),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuotationField(
                  label:       'Quotation Name *',
                  ctrl:        row.quotationName,
                  placeholder: 'Name',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _QuotationField(
                  label:       'Unit',
                  ctrl:        row.unit,
                  placeholder: 'Unit',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuotationField(
                  label:       'Quotation No. / Receipt',
                  ctrl:        row.quotationNumber,
                  placeholder: 'No. / date',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _QuotationField(
                  label:       'Total Rate',
                  ctrl:        row.totalRate,
                  placeholder: '0.00',
                  inputType:   TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuotationField(
                  label:       'Record Holder',
                  ctrl:        row.recordHolder,
                  placeholder: 'Name',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _QuotationField(
            label:       'Remarks',
            ctrl:        row.remarks,
            placeholder: 'Remarks',
          ),
        ],
      ),
    );
  }
}

// ── Shared field widgets (local to this file — not imported from
//    material_stock_form_page.dart, since Dart cannot export/import
//    private (_-prefixed) classes across files) ────────────────────────────

class _QuotationField extends StatelessWidget {
  final String                label;
  final TextEditingController ctrl;
  final String                placeholder;
  final TextInputType         inputType;

  const _QuotationField({
    required this.label,
    required this.ctrl,
    required this.placeholder,
    this.inputType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize:   11,
                fontWeight: FontWeight.w600,
                color:      Color(0xFF475569))),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          keyboardType: inputType,
          decoration: InputDecoration(
            hintText:       placeholder,
            hintStyle:      const TextStyle(
                color: Color(0xFFB0BAC9), fontSize: 12),
            filled:         true,
            fillColor:      const Color(0xFFF8FAFF),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:   const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:   const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:   const BorderSide(
                  color: Color(0xFF7C3AED), width: 1.5),
            ),
          ),
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

class _QuotationFieldWithDate extends StatelessWidget {
  final String                label;
  final TextEditingController ctrl;
  final VoidCallback          onTap;

  const _QuotationFieldWithDate({
    required this.label,
    required this.ctrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize:   11,
                fontWeight: FontWeight.w600,
                color:      Color(0xFF475569))),
        const SizedBox(height: 4),
        TextFormField(
          controller:  ctrl,
          readOnly:    true,
          onTap:       onTap,
          decoration: InputDecoration(
            hintText:       'YYYY-MM-DD',
            hintStyle:      const TextStyle(
                color: Color(0xFFB0BAC9), fontSize: 12),
            filled:         true,
            fillColor:      const Color(0xFFF8FAFF),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 8),
            suffixIcon: const Icon(Icons.calendar_today_rounded,
                size: 14, color: Color(0xFF94A3B8)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:   const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:   const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:   const BorderSide(
                  color: Color(0xFF7C3AED), width: 1.5),
            ),
          ),
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

// ── Month Picker (local copy — same reasoning as above) ─────────────────────

class _QuotationMonthPicker extends StatelessWidget {
  final String                value;
  final ValueChanged<String>  onChanged;

  const _QuotationMonthPicker({required this.value, required this.onChanged});

  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String _label(String v) {
    try {
      final parts = v.split('-');
      final idx   = int.parse(parts[1]) - 1;
      return '${_months[idx]} ${parts[0]}';
    } catch (_) {
      return v;
    }
  }

  Future<void> _pick(BuildContext context) async {
    final parts  = value.split('-');
    int year     = int.tryParse(parts[0]) ?? DateTime.now().year;
    int month    = int.tryParse(parts.length > 1 ? parts[1] : '1') ?? 1;

    await showDialog(
      context: context,
      builder: (_) => _QuotationMonthPickerDialog(
        initialYear:  year,
        initialMonth: month,
        onPicked:     (y, m) {
          onChanged('$y-${m.toString().padLeft(2, '0')}');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:        () => _pick(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color:        const Color(0xFFF8FAFF),
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_outlined,
                size: 16, color: Color(0xFF94A3B8)),
            const SizedBox(width: 8),
            Text(_label(value),
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF1E293B))),
            const Spacer(),
            const Icon(Icons.arrow_drop_down_rounded,
                color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}

class _QuotationMonthPickerDialog extends StatefulWidget {
  final int initialYear;
  final int initialMonth;
  final void Function(int year, int month) onPicked;

  const _QuotationMonthPickerDialog({
    required this.initialYear,
    required this.initialMonth,
    required this.onPicked,
  });

  @override
  State<_QuotationMonthPickerDialog> createState() =>
      _QuotationMonthPickerDialogState();
}

class _QuotationMonthPickerDialogState
    extends State<_QuotationMonthPickerDialog> {
  late int _year;
  late int _month;

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _year  = widget.initialYear;
    _month = widget.initialMonth;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => setState(() => _year--),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Text('$_year',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          IconButton(
            onPressed: () => setState(() => _year++),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
      content: SizedBox(
        width:  280,
        height: 180,
        child: GridView.builder(
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:   3,
            childAspectRatio: 2.2,
            mainAxisSpacing:  8,
            crossAxisSpacing: 8,
          ),
          itemCount:   12,
          itemBuilder: (_, i) {
            final selected = i + 1 == _month;
            return InkWell(
              onTap: () {
                setState(() => _month = i + 1);
                widget.onPicked(_year, _month);
                Navigator.pop(context);
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF7C3AED)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  _months[i],
                  style: TextStyle(
                    fontSize:   12,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.white
                        : const Color(0xFF475569),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}