import 'package:flutter/material.dart';
import '../../data/models/material_quotation_model.dart';

class MaterialQuotationViewPage extends StatelessWidget {
  final MaterialQuotationModel quotation;

  static const Color _accent = Color(0xFF7C3AED);

  const MaterialQuotationViewPage({super.key, required this.quotation});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        elevation:       0,
        title: Text(quotation.quotationNo,
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _card(
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
                  _meta('Quotation No.', quotation.quotationNo),
                  _meta('Month',         quotation.formattedMonth),
                  if (quotation.creatorName != null)
                    _meta('Created By', quotation.creatorName!),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Quotation Items',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            if (quotation.items.isEmpty)
              _card(
                child: const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child:   Text('No items.',
                        style: TextStyle(color: Color(0xFF94A3B8))),
                  ),
                ),
              )
            else
              ...quotation.items.asMap().entries.map(
                    (e) => _itemCard(e.key + 1, e.value),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(16),
      margin:  const EdgeInsets.only(bottom: 4),
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
      child: child,
    );
  }

  Widget _meta(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text('$label:',
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color:      Color(0xFF475569),
                    fontSize:   13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Color(0xFF1E293B), fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _itemCard(int index, MaterialQuotationItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF5F3FF),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  width:  24,
                  height: 24,
                  decoration: BoxDecoration(
                    color:        _accent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text('$index',
                      style: const TextStyle(
                          color:      Colors.white,
                          fontSize:   11,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(item.quotationName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize:   13,
                          color:      Color(0xFF1E293B))),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _row('Date',           item.date ?? '-'),
                _row('Unit',           item.unit ?? '-'),
                _row('Quotation No.',  item.quotationNumber ?? '-'),
                _row('Total Rate',
                    item.totalRate != null
                        ? item.totalRate.toString()
                        : '-'),
                _row('Record Holder', item.recordHolder ?? '-'),
                _row('Remarks',       item.remarks ?? '-'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text('$label:',
                style: const TextStyle(
                    fontSize:   12,
                    color:      Color(0xFF64748B),
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF1E293B))),
          ),
        ],
      ),
    );
  }
}