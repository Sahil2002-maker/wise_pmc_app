import 'package:flutter/material.dart';

class WorkReportLegend extends StatelessWidget {
  const WorkReportLegend({super.key});

  static const _items = [
    _LegendItem(color: Color(0xFF28C76F), label: 'Present + Submitted'),
    _LegendItem(color: Color(0xFFFF9F43), label: 'Present - No Report'),
    _LegendItem(color: Color(0xFFFFC107), label: 'Half Day'),
    _LegendItem(color: Color(0xFF17A2B8), label: 'Incomplete Shift'),
    _LegendItem(color: Color(0xFFDC3545), label: 'Absent'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'LEGEND',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: Color(0xFF888888),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: _items
                .map((item) => _buildItem(item.color, item.label))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF555555),
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _LegendItem {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});
}