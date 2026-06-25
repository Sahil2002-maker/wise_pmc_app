import 'package:flutter/material.dart';
import '../../data/models/material_stock_model.dart';

class MaterialStockViewPage extends StatelessWidget {
  final MaterialStockModel stock;

  static const Color _accent = Color(0xFF2563EB);

  const MaterialStockViewPage({super.key, required this.stock});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        elevation:       0,
        title: Text(
          stock.stockNo,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('WR/EXE/21',
                          style: TextStyle(
                              fontWeight: FontWeight.w700)),
                      Text('WISE REALTY',
                          style: TextStyle(
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const Divider(height: 16),
                  _metaRow('Register No.', stock.stockNo),
                  _metaRow('Month', stock.formattedMonth),
                  if (stock.creatorName != null)
                    _metaRow('Created By', stock.creatorName!),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ── Items ──────────────────────────────────────────────────────
            const Text(
              'Material Items',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            if (stock.items.isEmpty)
              _card(
                child: const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child:   Text('No items found.',
                        style: TextStyle(color: Color(0xFF94A3B8))),
                  ),
                ),
              )
            else
              ...stock.items.asMap().entries.map(
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

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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

  Widget _itemCard(int index, MaterialStockItem item) {
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
              color: Color(0xFFEEF2FF),
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
                  child: Text(
                    item.material,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color:      Color(0xFF1E293B),
                        fontSize:   13),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _detailRow('Date',           item.date ?? '-'),
                _detailRow('Unit',           item.unit ?? '-'),
                _detailRow('Invoice No.',    item.invoiceNo ?? '-'),
                _detailRow('Total Received',
                    item.totalReceived?.toString() ?? '-'),
                _detailRow('Used Qty',
                    item.usedQty?.toString() ?? '-'),
                _detailRow('Record Holder', item.recordHolder ?? '-'),
                _detailRow('Remarks',       item.remarks ?? '-'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
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