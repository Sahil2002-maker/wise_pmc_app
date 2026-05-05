// lib/features/architecture_checklist/presentation/architecture_checklist_page.dart

import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/utils/api_exception.dart';
import '../data/models/architecture_checklist_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Inspection item descriptions (mirrors web blade template exactly)
// ─────────────────────────────────────────────────────────────────────────────
const List<String> _kInspectionItems = [
  '1) Boundaries as per latest site demarcation given by approved drawing issued by Architect with latest/CIDCO demand',
  '2) Ground water tank or plastic tank /UG/WT/Pump Room/Transformer Room as per drawing or not.',
  '3) Location of compound wall, front gates sizes as per drawing.',
  '4) WC/Bath/Toilet Sunk/Terrace shown in drawing properly',
  '5) Check Head Room Depth (Beam Depth) and change if required at entrance to building',
  '6) Dowel for adjacent structure /Check overlap for steel given.',
  '7) Plinth Elevation Features Details',
  '8) Lift Details/Floating Column Details',
  '9) All the Room Sizes/floor to floor height level.',
  '10) Duct Opening as per drawing available or not.',
  '11) RCC staircase plan/ dowels given or not.',
  '12) Column sizes/Lintel Levels/Canopy widths as designed/not.',
  '13) Direction of Shutter opening/Frame fixing/Size',
  '14) RCC Column reduction stroke, Reduced Properties',
  '15) Kitchen otta position with sink sizes, As per drawing/not.',
  '16) RCC Loft position with width, Provided/not',
  '17) MC Chajja Levels and Beam drops, Provided/not',
  '18) Rainwater pipe /stopping pattern/terrace drain, Provided/not',
  '19) Levels of shops (joints)/parking at every stage, Available/correct',
  '20) Grade of concrete/material used at site, Good/Bad/Acceptable',
  '21) If any other points',
];

// ─────────────────────────────────────────────────────────────────────────────
// Native PDF Builder
// ─────────────────────────────────────────────────────────────────────────────

class _ChecklistPdfBuilder {
  static const _cyan = PdfColor.fromInt(0xFF0891B2);
  static const _slate800 = PdfColor.fromInt(0xFF1E293B);
  static const _slate500 = PdfColor.fromInt(0xFF64748B);
  static const _slate300 = PdfColor.fromInt(0xFFCBD5E1);
  static const _green = PdfColor.fromInt(0xFF22C55E);
  static const _red = PdfColor.fromInt(0xFFEF4444);
  static const _bgLight = PdfColor.fromInt(0xFFF8FAFC);
  static const _white = PdfColors.white;

  static String _fmtDate(String? d) {
    if (d == null || d.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(d);
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return d;
    }
  }

  static pw.Widget _sectionHeader(String title, pw.Font font) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFE0F2FE),
        border: pw.Border(
          left: pw.BorderSide(color: _cyan, width: 3),
        ),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          font: font,
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: _cyan,
        ),
      ),
    );
  }

  static pw.Widget _infoRow(String label, String? value, pw.Font font,
      pw.Font boldFont) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: pw.TextStyle(
                font: font, fontSize: 7, color: _slate500)),
        pw.SizedBox(height: 1),
        pw.Text(
          (value != null && value.isNotEmpty) ? value : 'N/A',
          style: pw.TextStyle(
              font: boldFont, fontSize: 9, color: _slate800),
        ),
      ],
    );
  }

  static pw.Widget _checkBadge(
      String label, bool val, pw.Font font, pw.Font boldFont) {
    final color = val ? _green : _slate300;
    return pw.Row(children: [
      pw.Container(
        width: 10,
        height: 10,
        decoration: pw.BoxDecoration(
          shape: pw.BoxShape.circle,
          color: color,
        ),
        child: pw.Center(
          child: pw.Text(
            val ? '✓' : '✗',
            style: pw.TextStyle(
                font: boldFont, fontSize: 6, color: _white),
          ),
        ),
      ),
      pw.SizedBox(width: 4),
      pw.Expanded(
        child: pw.Text(label,
            style: pw.TextStyle(
                font: font,
                fontSize: 8,
                color: val ? _green : _slate500)),
      ),
    ]);
  }

  static Future<Uint8List> build(
      ArchitectureChecklistModel c, String projectName) async {
    final doc = pw.Document();

    final regularFont =
        await PdfGoogleFonts.nunitoRegular();
    final boldFont =
        await PdfGoogleFonts.nunitoBold();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: _cyan, width: 1.5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('DEVISE DESIGN ARCHITECTS',
                      style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 11,
                          color: _cyan)),
                  pw.Text('SITE VISIT REPORT',
                      style: pw.TextStyle(
                          font: regularFont,
                          fontSize: 8,
                          color: _slate500)),
                  pw.Text(
                      'Office No.311,312 3rd Floor, Wing \'B\', Hermes Atrium,\n'
                      'Plot No.57, C.B.D. Belapur, Navi Mumbai-400614 India.',
                      style: pw.TextStyle(
                          font: regularFont,
                          fontSize: 7,
                          color: _slate500)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('WR-EXE-B-19',
                      style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 9,
                          color: _slate800)),
                  pw.Text('WISE REALTY',
                      style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 9,
                          color: _slate800)),
                ],
              ),
            ],
          ),
        ),
        build: (ctx) => [
          pw.SizedBox(height: 10),

          // ── Report Details ──────────────────────────────────────────
          _sectionHeader('Report Details', boldFont),
          pw.SizedBox(height: 6),
          pw.Row(children: [
            pw.Expanded(
                child: _infoRow('No.', c.checklistNo, regularFont, boldFont)),
            pw.Expanded(
                child: _infoRow(
                    'Date', _fmtDate(c.checklistDate), regularFont, boldFont)),
            pw.Expanded(
                child: _infoRow('Job No', c.jobNo, regularFont, boldFont)),
            pw.Expanded(
                child: _infoRow(
                    'Project', c.projectName ?? projectName, regularFont, boldFont)),
          ]),
          pw.SizedBox(height: 12),

          // ── Section 1: Concrete Members ─────────────────────────────
          _sectionHeader('1) Concrete Members Inspected', boldFont),
          pw.SizedBox(height: 6),
          pw.Row(children: [
            pw.Expanded(
              child: _checkBadge(
                  'a) Beam not in line & level No.',
                  c.beamNotInLine,
                  regularFont,
                  boldFont),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: _checkBadge(
                  'b) Column not in Plumb/Alignment',
                  c.columnNotPlumb,
                  regularFont,
                  boldFont),
            ),
          ]),
          pw.SizedBox(height: 6),
          pw.Row(children: [
            pw.Expanded(
                child: _infoRow(
                    'c) Honeycomb in Column', c.honeycombColumn, regularFont, boldFont)),
            pw.SizedBox(width: 8),
            pw.Expanded(
                child: _infoRow('& Beam No.', c.beamNo, regularFont, boldFont)),
          ]),
          pw.SizedBox(height: 12),

          // ── Section 2: Inspection Table ─────────────────────────────
          _sectionHeader('2) Inspection At Site & Checking', boldFont),
          pw.SizedBox(height: 4),
          pw.Table(
            border: pw.TableBorder.all(
                color: _slate300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(5),
              1: const pw.FixedColumnWidth(35),
              2: const pw.FixedColumnWidth(35),
              3: const pw.FlexColumnWidth(2),
            },
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE0F2FE)),
                children: [
                  _tableCell('DESCRIPTION', boldFont, isHeader: true),
                  _tableCell('CHK', boldFont, isHeader: true, center: true),
                  _tableCell('N/CHK', boldFont, isHeader: true, center: true),
                  _tableCell('REMARKS', boldFont, isHeader: true),
                ],
              ),
              // Data rows
              ...List.generate(_kInspectionItems.length, (i) {
                final item = i < c.inspectionItems.length
                    ? c.inspectionItems[i]
                    : <String, dynamic>{};
                final checked =
                    item['checked'] == true || item['checked'] == 'true';
                final notChecked = item['not_checked'] == true ||
                    item['not_checked'] == 'true';
                final remark = item['remarks']?.toString() ?? '';
                final bg = i % 2 == 0
                    ? PdfColors.white
                    : const PdfColor.fromInt(0xFFF8FAFC);
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bg),
                  children: [
                    _tableCell(_kInspectionItems[i], regularFont),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Center(
                        child: pw.Container(
                          width: 12,
                          height: 12,
                          decoration: pw.BoxDecoration(
                            shape: pw.BoxShape.circle,
                            color: checked ? _green : PdfColors.white,
                            border: pw.Border.all(
                                color: checked ? _green : _slate300,
                                width: 1),
                          ),
                          child: checked
                              ? pw.Center(
                                  child: pw.Text('✓',
                                      style: pw.TextStyle(
                                          font: boldFont,
                                          fontSize: 7,
                                          color: _white)))
                              : pw.SizedBox(),
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Center(
                        child: pw.Container(
                          width: 12,
                          height: 12,
                          decoration: pw.BoxDecoration(
                            shape: pw.BoxShape.circle,
                            color: notChecked ? _red : PdfColors.white,
                            border: pw.Border.all(
                                color: notChecked ? _red : _slate300,
                                width: 1),
                          ),
                          child: notChecked
                              ? pw.Center(
                                  child: pw.Text('✗',
                                      style: pw.TextStyle(
                                          font: boldFont,
                                          fontSize: 7,
                                          color: _white)))
                              : pw.SizedBox(),
                        ),
                      ),
                    ),
                    _tableCell(remark, regularFont),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 12),

          // ── Section 3: Graphical Representation ────────────────────
          _sectionHeader(
              '3) Graphical Representation Of Work And Time', boldFont),
          pw.SizedBox(height: 6),
          pw.Row(children: [
            pw.Expanded(
                child: _infoRow(
                    'A) Bar Chart Available', c.barChartAvailable, regularFont, boldFont)),
          ]),
          pw.SizedBox(height: 4),
          pw.Row(children: [
            pw.Expanded(
              child: _checkBadge(
                  'B) Work Progressing as per Schedule',
                  c.workInProgress,
                  regularFont,
                  boldFont),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: _checkBadge(
                  'C) Time Limit available to balance work',
                  c.timeLimitAvailable,
                  regularFont,
                  boldFont),
            ),
          ]),
          pw.SizedBox(height: 4),
          pw.Row(children: [
            pw.Expanded(
                child: _infoRow(
                    'Months', c.balanceWorkMonths, regularFont, boldFont)),
            pw.SizedBox(width: 8),
            pw.Expanded(
                child: _infoRow(
                    'D) Last Date of Time period as per sanction',
                    c.lastDateTimePeriod,
                    regularFont,
                    boldFont)),
            pw.SizedBox(width: 8),
            pw.Expanded(
                child: _infoRow(
                    'Sanction Date', _fmtDate(c.sanctionDate), regularFont, boldFont)),
          ]),
          pw.SizedBox(height: 12),

          // ── Section 4: Open Space Statement ────────────────────────
          _sectionHeader('4) Open Space Statement', boldFont),
          pw.SizedBox(height: 4),
          if (c.openSpaceData.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text('No open space data recorded.',
                  style:
                      pw.TextStyle(font: regularFont, fontSize: 8, color: _slate500)),
            )
          else
            pw.Table(
              border: pw.TableBorder.all(color: _slate300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1),
                5: const pw.FlexColumnWidth(1),
                6: const pw.FlexColumnWidth(1),
                7: const pw.FlexColumnWidth(1),
                8: const pw.FlexColumnWidth(1),
                9: const pw.FlexColumnWidth(1),
                10: const pw.FlexColumnWidth(1),
                11: const pw.FlexColumnWidth(1),
                12: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFE0F2FE)),
                  children: [
                    for (final h in [
                      'SP1','SP2','SP3','SP4',
                      'WD1','WD2','WD3','WD4',
                      'S1','S2','S3','S4','Remarks'
                    ])
                      _tableCell(h, boldFont, isHeader: true, center: true),
                  ],
                ),
                ...c.openSpaceData.map((space) => pw.TableRow(
                  children: [
                    _tableCell(space['sanction_plan_1'] ?? '', regularFont, center: true),
                    _tableCell(space['sanction_plan_2'] ?? '', regularFont, center: true),
                    _tableCell(space['sanction_plan_3'] ?? '', regularFont, center: true),
                    _tableCell(space['sanction_plan_4'] ?? '', regularFont, center: true),
                    _tableCell(space['working_drawing_1'] ?? '', regularFont, center: true),
                    _tableCell(space['working_drawing_2'] ?? '', regularFont, center: true),
                    _tableCell(space['working_drawing_3'] ?? '', regularFont, center: true),
                    _tableCell(space['working_drawing_4'] ?? '', regularFont, center: true),
                    _tableCell(space['site_1'] ?? '', regularFont, center: true),
                    _tableCell(space['site_2'] ?? '', regularFont, center: true),
                    _tableCell(space['site_3'] ?? '', regularFont, center: true),
                    _tableCell(space['site_4'] ?? '', regularFont, center: true),
                    _tableCell(space['remarks'] ?? '', regularFont),
                  ],
                )),
              ],
            ),
          pw.SizedBox(height: 12),

          // ── Section 5: Construction Statement ──────────────────────
          if (c.constructionStatement != null &&
              c.constructionStatement!.isNotEmpty) ...[
            _sectionHeader('5) Construction Statement', boldFont),
            pw.SizedBox(height: 4),
            pw.Text(c.constructionStatement!,
                style: pw.TextStyle(
                    font: regularFont, fontSize: 8, color: _slate800)),
            pw.SizedBox(height: 4),
            pw.Text(
              '1. Architect is not responsible for safety of shuttering centering and its supporting props.\n'
              '2. Architect is not responsible for any accident due to defective shuttering or RCC design.',
              style: pw.TextStyle(
                  font: regularFont,
                  fontSize: 7,
                  color: _slate500,
                  fontStyle: pw.FontStyle.italic),
            ),
            pw.SizedBox(height: 12),
          ],

          // ── Section 6: Additional Instructions ─────────────────────
          if (c.additionalInstructions != null &&
              c.additionalInstructions!.isNotEmpty) ...[
            _sectionHeader('6) Additional Instructions', boldFont),
            pw.SizedBox(height: 4),
            pw.Text(c.additionalInstructions!,
                style: pw.TextStyle(
                    font: regularFont, fontSize: 8, color: _slate800)),
            pw.SizedBox(height: 12),
          ],

          // ── Signatures ──────────────────────────────────────────────
          _sectionHeader('Signatures', boldFont),
          pw.SizedBox(height: 6),
          pw.Row(children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Architect / Engineer',
                      style: pw.TextStyle(
                          font: regularFont, fontSize: 7, color: _slate500)),
                  pw.SizedBox(height: 16),
                  pw.Container(
                      height: 1,
                      color: _slate800),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    (c.architectSignature != null &&
                            c.architectSignature!.isNotEmpty)
                        ? c.architectSignature!
                        : '',
                    style:
                        pw.TextStyle(font: boldFont, fontSize: 8, color: _slate800),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 24),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Client / Contractor',
                      style: pw.TextStyle(
                          font: regularFont, fontSize: 7, color: _slate500)),
                  pw.SizedBox(height: 16),
                  pw.Container(height: 1, color: _slate800),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    (c.clientSignature != null && c.clientSignature!.isNotEmpty)
                        ? c.clientSignature!
                        : '',
                    style:
                        pw.TextStyle(font: boldFont, fontSize: 8, color: _slate800),
                  ),
                ],
              ),
            ),
          ]),
        ],
        footer: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: const pw.BoxDecoration(
              border: pw.Border(
                  top: pw.BorderSide(color: _slate300, width: 0.5))),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Architecture Checklist — ${c.checklistNo}',
                  style: pw.TextStyle(
                      font: regularFont, fontSize: 7, color: _slate500)),
              pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: pw.TextStyle(
                      font: regularFont, fontSize: 7, color: _slate500)),
            ],
          ),
        ),
      ),
    );

    return doc.save();
  }

  static pw.Widget _tableCell(
    String text,
    pw.Font font, {
    bool isHeader = false,
    bool center = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: center
          ? pw.Center(
              child: pw.Text(text,
                  style: pw.TextStyle(
                      font: font,
                      fontSize: isHeader ? 7 : 7,
                      fontWeight: isHeader
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                      color: isHeader ? _cyan : _slate800)),
            )
          : pw.Text(text,
              style: pw.TextStyle(
                  font: font,
                  fontSize: isHeader ? 7 : 7,
                  fontWeight:
                      isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: isHeader ? _cyan : _slate800)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Print / Download helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Prints the checklist using the system print dialog (Android/iOS/Desktop).
Future<void> _printChecklist(
  BuildContext context,
  ArchitectureChecklistModel c,
  String projectName,
) async {
  try {
    _showLoadingSnackBar(context, 'Preparing print preview…');
    final pdfBytes = await _ChecklistPdfBuilder.build(c, projectName);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: '${c.checklistNo} — Architecture Checklist',
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Print failed: $e'),
        backgroundColor: const Color(0xFFEF4444),
      ));
  }
}

/// Saves the checklist as a PDF file and opens the system share/save sheet.
Future<void> _downloadChecklist(
  BuildContext context,
  ArchitectureChecklistModel c,
  String projectName,
) async {
  try {
    _showLoadingSnackBar(context, 'Generating PDF…');
    final pdfBytes = await _ChecklistPdfBuilder.build(c, projectName);

    // Save to temp directory
    final dir = await getTemporaryDirectory();
    final fileName =
        '${c.checklistNo.replaceAll('/', '_')}_architecture_checklist.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(pdfBytes);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    // Share / save via system sheet
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: '${c.checklistNo} — Architecture Checklist',
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Download failed: $e'),
        backgroundColor: const Color(0xFFEF4444),
      ));
  }
}

void _showLoadingSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Text(message),
      ]),
      duration: const Duration(seconds: 30),
      backgroundColor: const Color(0xFF64748B),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Main page widget
// ─────────────────────────────────────────────────────────────────────────────

class ArchitectureChecklistPage extends StatefulWidget {
  final int projectId;
  final String projectName;

  const ArchitectureChecklistPage({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<ArchitectureChecklistPage> createState() =>
      _ArchitectureChecklistPageState();
}

class _ArchitectureChecklistPageState
    extends State<ArchitectureChecklistPage> {
  List<ArchitectureChecklistModel> _checklists = [];
  bool _isLoading = true;
  String? _error;

  static const _accentColor = Color(0xFF0891B2);

  @override
  void initState() {
    super.initState();
    _loadChecklists();
  }

  Future<void> _loadChecklists() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list =
          await ApiService.fetchArchitectureChecklists(widget.projectId);

      final sorted = List<ArchitectureChecklistModel>.from(list)
        ..sort((a, b) => a.id.compareTo(b.id));

      if (!mounted) return;
      setState(() {
        _checklists = sorted;
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

  Future<void> _openForm({ArchitectureChecklistModel? existing}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _ArchitectureChecklistFormPage(
          projectId: widget.projectId,
          projectName: widget.projectName,
          existing: existing,
        ),
        fullscreenDialog: true,
      ),
    );
    if (result == true) _loadChecklists();
  }

  Future<void> _confirmDelete(ArchitectureChecklistModel c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Delete Checklist',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text(
            'Delete checklist ${c.checklistNo}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Deleting checklist…'),
            ],
          ),
          duration: Duration(seconds: 10),
          backgroundColor: Color(0xFF64748B),
        ),
      );
    }

    try {
      await ApiService.deleteArchitectureChecklist(
          widget.projectId, c.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Checklist deleted successfully'),
          backgroundColor: Color(0xFF22C55E),
        ));
      _loadChecklists();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(
              'Delete failed: ${e is ApiException ? e.message : e.toString()}'),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 4),
        ));
    }
  }

  void _openView(ArchitectureChecklistModel c) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ArchitectureChecklistViewPage(
          checklist: c,
          projectName: widget.projectName,
        ),
      ),
    );
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: _accentColor))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadChecklists,
                  color: _accentColor,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _buildHeader()),
                      _checklists.isEmpty
                          ? SliverFillRemaining(child: _buildEmpty())
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (_, i) => _buildCard(_checklists[i], i),
                                childCount: _checklists.length,
                              ),
                            ),
                      const SliverToBoxAdapter(
                          child: SizedBox(height: 90)),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Checklist',
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
          border: Border.all(
              color: _accentColor.withValues(alpha: 0.2)),
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
              color: _accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.apartment_outlined,
                color: _accentColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text('Architecture Checklists',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _accentColor)),
              const SizedBox(height: 2),
              Text('WR-EXE-B-19 — ${widget.projectName}',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _accentColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_checklists.length}',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13),
            ),
          ),
        ]),
      );

  Widget _buildCard(ArchitectureChecklistModel c, int index) {
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
        // Header strip
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            color: _accentColor.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12)),
          ),
          child: Row(children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _accentColor,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  c.checklistNo,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _accentColor),
                ),
                Text(
                  _formatDate(c.checklistDate),
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF64748B)),
                ),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Architecture',
                style: TextStyle(
                    fontSize: 10,
                    color: _accentColor,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),

        // Body
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              _infoItem(Icons.work_outline, 'Job No', c.jobNo),
              const SizedBox(width: 16),
              _infoItem(
                  Icons.business_outlined, 'Project', c.projectName),
            ]),

            if (c.creator != null && c.creator!.name.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.account_circle_outlined,
                    size: 13, color: Color(0xFF94A3B8)),
                const SizedBox(width: 5),
                Text(
                  'Created by ${c.creator!.name}',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF64748B)),
                ),
              ]),
            ],

            const SizedBox(height: 10),
            _buildSection1Indicators(c),
            const SizedBox(height: 8),
            _buildSection3Indicators(c),

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),

            // Action buttons
            Wrap(spacing: 8, runSpacing: 8, children: [
              _actionBtn(
                label: 'View',
                icon: Icons.visibility_outlined,
                color: const Color(0xFF0EA5E9),
                onTap: () => _openView(c),
              ),
              _actionBtn(
                label: 'Edit',
                icon: Icons.edit_outlined,
                color: const Color(0xFFF59E0B),
                onTap: () => _openForm(existing: c),
              ),
              // Native print via pdf + printing packages
              _actionBtn(
                label: 'Print',
                icon: Icons.print_outlined,
                color: const Color(0xFF22C55E),
                onTap: () => _printChecklist(
                    context, c, widget.projectName),
              ),
              // Native PDF save + share
              _actionBtn(
                label: 'PDF',
                icon: Icons.download_outlined,
                color: const Color(0xFF8B5CF6),
                onTap: () => _downloadChecklist(
                    context, c, widget.projectName),
              ),
              _actionBtn(
                label: 'Delete',
                icon: Icons.delete_outline,
                color: const Color(0xFFEF4444),
                onTap: () => _confirmDelete(c),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _buildSection1Indicators(ArchitectureChecklistModel c) {
    return Wrap(spacing: 6, runSpacing: 6, children: [
      _boolChip('Beam Not In Line', c.beamNotInLine),
      _boolChip('Column Not Plumb', c.columnNotPlumb),
    ]);
  }

  Widget _buildSection3Indicators(ArchitectureChecklistModel c) {
    return Wrap(spacing: 6, runSpacing: 6, children: [
      if (c.barChartAvailable != null && c.barChartAvailable!.isNotEmpty)
        _labelChip(
            'Bar Chart: ${c.barChartAvailable}', const Color(0xFF3B82F6)),
      _boolChip('Work In Progress', c.workInProgress),
      _boolChip('Time Limit', c.timeLimitAvailable),
    ]);
  }

  Widget _boolChip(String label, bool val) {
    final color =
        val ? const Color(0xFF22C55E) : const Color(0xFF94A3B8);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          val ? Icons.check_circle_outline : Icons.cancel_outlined,
          size: 10,
          color: color,
        ),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 9,
                color: color,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _labelChip(String label, Color color) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 9,
                color: color,
                fontWeight: FontWeight.w600)),
      );

  Widget _infoItem(IconData icon, String label, String? value) =>
      Expanded(
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
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 7),
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
                color: _accentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.apartment_outlined,
                  size: 56, color: _accentColor),
            ),
            const SizedBox(height: 20),
            const Text('No Architecture Checklists',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            const Text(
              'Tap the button below to create your first architecture checklist.',
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
              onPressed: _loadChecklists,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.white),
            ),
          ]),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// View Page
// ─────────────────────────────────────────────────────────────────────────────

class _ArchitectureChecklistViewPage extends StatelessWidget {
  final ArchitectureChecklistModel checklist;
  final String projectName;

  const _ArchitectureChecklistViewPage({
    required this.checklist,
    required this.projectName,
  });

  static const _accent = Color(0xFF0891B2);

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
        title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          const Text('Architecture Checklist',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B))),
          Text(checklist.checklistNo,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF64748B))),
        ]),
        actions: [
          // Print button in view page
          IconButton(
            icon: const Icon(Icons.print_outlined, color: Color(0xFF22C55E)),
            tooltip: 'Print',
            onPressed: () =>
                _printChecklist(context, checklist, projectName),
          ),
          // Download PDF button in view page
          IconButton(
            icon: const Icon(Icons.download_outlined, color: Color(0xFF8B5CF6)),
            tooltip: 'Download PDF',
            onPressed: () =>
                _downloadChecklist(context, checklist, projectName),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          _sectionCard(
            title: 'DEVISE DESIGN ARCHITECTS',
            icon: Icons.business_outlined,
            children: [
              const Center(
                child: Text(
                  'SITE VISIT REPORT',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 4),
              const Center(
                child: Text(
                  'Office No.311,312 3rd Floor, Wing \'B\', Hermes Atrium,\nPlot No.57, C.B.D. Belapur, Navi Mumbai-400614 India.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _sectionCard(
            title: 'Report Details',
            icon: Icons.info_outline,
            children: [
              _row2('No.', checklist.checklistNo, 'Date',
                  _fmtDate(checklist.checklistDate)),
              const SizedBox(height: 10),
              _row2('Job No', checklist.jobNo, 'Project',
                  checklist.projectName ?? projectName),
            ],
          ),
          const SizedBox(height: 10),
          _sectionCard(
            title: '1) Concrete Members Inspected',
            icon: Icons.construction_outlined,
            children: [
              _checkBadge(
                  'a) Beam not in line & level No.',
                  checklist.beamNotInLine),
              const SizedBox(height: 8),
              _checkBadge('b) Column not in Plumb/Alignment',
                  checklist.columnNotPlumb),
              const SizedBox(height: 10),
              _infoRow('c) Honeycomb in Column',
                  checklist.honeycombColumn),
              const SizedBox(height: 6),
              _infoRow('& Beam No.', checklist.beamNo),
            ],
          ),
          const SizedBox(height: 10),
          _sectionCard(
            title: '2) Inspection At Site & Checking',
            icon: Icons.checklist_outlined,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6)),
                child: const Row(children: [
                  Expanded(
                      flex: 5,
                      child: Text('DESCRIPTION',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B)))),
                  SizedBox(
                      width: 50,
                      child: Text('CHK',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B)))),
                  SizedBox(
                      width: 50,
                      child: Text('N/CHK',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B)))),
                  SizedBox(
                      width: 80,
                      child: Text('REMARKS',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B)))),
                ]),
              ),
              const SizedBox(height: 4),
              ...List.generate(_kInspectionItems.length, (i) {
                final item = i < checklist.inspectionItems.length
                    ? checklist.inspectionItems[i]
                    : <String, dynamic>{};
                final checked = item['checked'] == true ||
                    item['checked'] == 'true';
                final notChecked = item['not_checked'] == true ||
                    item['not_checked'] == 'true';
                final remark =
                    item['remarks']?.toString() ?? '';

                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 7),
                  decoration: BoxDecoration(
                    color: i % 2 == 0
                        ? Colors.white
                        : const Color(0xFFFAFAFB),
                    border: Border(
                        bottom: BorderSide(
                            color: const Color(0xFFF1F5F9),
                            width: 1)),
                  ),
                  child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                    Expanded(
                      flex: 5,
                      child: Text(_kInspectionItems[i],
                          style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF1E293B),
                              height: 1.3)),
                    ),
                    SizedBox(
                      width: 50,
                      child: Center(
                        child: Icon(
                          checked
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 16,
                          color: checked
                              ? const Color(0xFF22C55E)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      child: Center(
                        child: Icon(
                          notChecked
                              ? Icons.cancel
                              : Icons.radio_button_unchecked,
                          size: 16,
                          color: notChecked
                              ? const Color(0xFFEF4444)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child: Text(remark,
                          style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF64748B)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                );
              }),
            ],
          ),
          const SizedBox(height: 10),
          _sectionCard(
            title: '3) Graphical Representation Of Work And Time',
            icon: Icons.bar_chart_outlined,
            children: [
              _infoRow('A) Bar Chart Available',
                  checklist.barChartAvailable),
              const SizedBox(height: 6),
              _checkBadge(
                  'B) Work is Progressing as per Schedule',
                  checklist.workInProgress),
              const SizedBox(height: 6),
              _checkBadge(
                  'C) Time Limit available to balance work',
                  checklist.timeLimitAvailable),
              const SizedBox(height: 6),
              _infoRow('Months', checklist.balanceWorkMonths),
              const SizedBox(height: 6),
              _infoRow(
                  'D) Last Date of Time period as per sanction',
                  checklist.lastDateTimePeriod),
              const SizedBox(height: 6),
              _infoRow('Date', _fmtDate(checklist.sanctionDate)),
            ],
          ),
          const SizedBox(height: 10),
          _sectionCard(
            title: '4) Open Space Statement',
            icon: Icons.grid_on_outlined,
            children: [
              if (checklist.openSpaceData.isEmpty)
                const Text('No open space data recorded.',
                    style: TextStyle(
                        fontSize: 12, color: Color(0xFF94A3B8)))
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 8,
                    headingRowHeight: 30,
                    dataRowMinHeight: 30,
                    dataRowMaxHeight: 40,
                    headingTextStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B)),
                    dataTextStyle: const TextStyle(
                        fontSize: 10, color: Color(0xFF1E293B)),
                    columns: const [
                      DataColumn(label: Text('SP1')),
                      DataColumn(label: Text('SP2')),
                      DataColumn(label: Text('SP3')),
                      DataColumn(label: Text('SP4')),
                      DataColumn(label: Text('WD1')),
                      DataColumn(label: Text('WD2')),
                      DataColumn(label: Text('WD3')),
                      DataColumn(label: Text('WD4')),
                      DataColumn(label: Text('S1')),
                      DataColumn(label: Text('S2')),
                      DataColumn(label: Text('S3')),
                      DataColumn(label: Text('S4')),
                      DataColumn(label: Text('Remarks')),
                    ],
                    rows: checklist.openSpaceData.map((space) {
                      return DataRow(cells: [
                        DataCell(
                            Text(space['sanction_plan_1'] ?? '')),
                        DataCell(
                            Text(space['sanction_plan_2'] ?? '')),
                        DataCell(
                            Text(space['sanction_plan_3'] ?? '')),
                        DataCell(
                            Text(space['sanction_plan_4'] ?? '')),
                        DataCell(
                            Text(space['working_drawing_1'] ?? '')),
                        DataCell(
                            Text(space['working_drawing_2'] ?? '')),
                        DataCell(
                            Text(space['working_drawing_3'] ?? '')),
                        DataCell(
                            Text(space['working_drawing_4'] ?? '')),
                        DataCell(Text(space['site_1'] ?? '')),
                        DataCell(Text(space['site_2'] ?? '')),
                        DataCell(Text(space['site_3'] ?? '')),
                        DataCell(Text(space['site_4'] ?? '')),
                        DataCell(Text(space['remarks'] ?? '')),
                      ]);
                    }).toList(),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (checklist.constructionStatement != null &&
              checklist.constructionStatement!.isNotEmpty)
            _sectionCard(
              title: '5) Construction Statement',
              icon: Icons.description_outlined,
              children: [
                Text(checklist.constructionStatement!,
                    style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                        height: 1.5)),
                const SizedBox(height: 8),
                const Text(
                  '1. Architect is not responsible for safety of shuttering centering and its supporting props.\n'
                  '2. Architect is not responsible for any accident due to defective shuttering or RCC design.',
                  style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF94A3B8),
                      fontStyle: FontStyle.italic),
                ),
              ],
            ),
          if (checklist.constructionStatement != null &&
              checklist.constructionStatement!.isNotEmpty)
            const SizedBox(height: 10),
          if (checklist.additionalInstructions != null &&
              checklist.additionalInstructions!.isNotEmpty)
            _sectionCard(
              title: '6) Additional Instructions',
              icon: Icons.notes_outlined,
              children: [
                Text(checklist.additionalInstructions!,
                    style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                        height: 1.5)),
              ],
            ),
          if (checklist.additionalInstructions != null &&
              checklist.additionalInstructions!.isNotEmpty)
            const SizedBox(height: 10),
          _sectionCard(
            title: 'Signatures',
            icon: Icons.draw_outlined,
            children: [
              Row(children: [
                Expanded(
                    child: _infoRow('Architect / Engineer',
                        checklist.architectSignature)),
                const SizedBox(width: 12),
                Expanded(
                    child: _infoRow('Client / Contractor',
                        checklist.clientSignature)),
              ]),
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
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Container(
            padding:
                const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10)),
            ),
            child: Row(children: [
              Icon(icon, size: 15, color: _accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _accent)),
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

  Widget _checkBadge(String label, bool val) {
    final color =
        val ? const Color(0xFF22C55E) : const Color(0xFF94A3B8);
    return Row(children: [
      Icon(
          val
              ? Icons.check_circle_outline
              : Icons.radio_button_unchecked,
          size: 14,
          color: color),
      const SizedBox(width: 6),
      Expanded(
          child: Text(label,
              style: TextStyle(fontSize: 12, color: color))),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Form Page (Create / Edit) — unchanged from original
// ─────────────────────────────────────────────────────────────────────────────

class _ArchitectureChecklistFormPage extends StatefulWidget {
  final int projectId;
  final String projectName;
  final ArchitectureChecklistModel? existing;

  const _ArchitectureChecklistFormPage({
    required this.projectId,
    required this.projectName,
    this.existing,
  });

  @override
  State<_ArchitectureChecklistFormPage> createState() =>
      _ArchitectureChecklistFormPageState();
}

class _ArchitectureChecklistFormPageState
    extends State<_ArchitectureChecklistFormPage> {
  static const _accent = Color(0xFF0891B2);

  String _checklistNo = '';
  bool _isLoadingNo = false;

  DateTime? _checklistDate;
  DateTime? _sanctionDate;

  final _jobNoCtrl = TextEditingController();
  final _honeycombColumnCtrl = TextEditingController();
  final _beamNoCtrl = TextEditingController();

  bool _beamNotInLine = false;
  bool _columnNotPlumb = false;

  late List<Map<String, dynamic>> _inspectionState;
  late List<TextEditingController> _inspectionRemarkControllers;

  String? _barChartAvailable;
  bool _workInProgress = false;
  bool _timeLimitAvailable = false;
  final _balanceWorkMonthsCtrl = TextEditingController();
  final _lastDateTimePeriodCtrl = TextEditingController();

  late List<Map<String, TextEditingController>> _openSpaceRows;

  final _constructionStatementCtrl = TextEditingController();
  final _additionalInstructionsCtrl = TextEditingController();
  final _architectSignatureCtrl = TextEditingController();
  final _clientSignatureCtrl = TextEditingController();

  bool _isSaving = false;
  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    _inspectionState = List.generate(
      _kInspectionItems.length,
      (_) => {'checked': false, 'not_checked': false},
    );

    _inspectionRemarkControllers = List.generate(
      _kInspectionItems.length,
      (_) => TextEditingController(),
    );

    _openSpaceRows = List.generate(
      4,
      (_) => {
        'sanction_plan_1': TextEditingController(),
        'sanction_plan_2': TextEditingController(),
        'sanction_plan_3': TextEditingController(),
        'sanction_plan_4': TextEditingController(),
        'working_drawing_1': TextEditingController(),
        'working_drawing_2': TextEditingController(),
        'working_drawing_3': TextEditingController(),
        'working_drawing_4': TextEditingController(),
        'site_1': TextEditingController(),
        'site_2': TextEditingController(),
        'site_3': TextEditingController(),
        'site_4': TextEditingController(),
        'remarks': TextEditingController(),
      },
    );

    if (_isEditing) {
      _populateFromExisting();
    } else {
      _checklistDate = DateTime.now();
      _loadChecklistNumber();
    }
  }

  void _populateFromExisting() {
    final c = widget.existing!;
    _checklistNo = c.checklistNo;
    try {
      _checklistDate = DateTime.parse(c.checklistDate);
    } catch (_) {
      _checklistDate = DateTime.now();
    }
    if (c.sanctionDate != null && c.sanctionDate!.isNotEmpty) {
      try {
        _sanctionDate = DateTime.parse(c.sanctionDate!);
      } catch (_) {}
    }
    _jobNoCtrl.text = c.jobNo ?? '';
    _honeycombColumnCtrl.text = c.honeycombColumn ?? '';
    _beamNoCtrl.text = c.beamNo ?? '';
    _beamNotInLine = c.beamNotInLine;
    _columnNotPlumb = c.columnNotPlumb;
    _barChartAvailable = c.barChartAvailable;
    _workInProgress = c.workInProgress;
    _timeLimitAvailable = c.timeLimitAvailable;
    _balanceWorkMonthsCtrl.text = c.balanceWorkMonths ?? '';
    _lastDateTimePeriodCtrl.text = c.lastDateTimePeriod ?? '';
    _constructionStatementCtrl.text = c.constructionStatement ?? '';
    _additionalInstructionsCtrl.text = c.additionalInstructions ?? '';
    _architectSignatureCtrl.text = c.architectSignature ?? '';
    _clientSignatureCtrl.text = c.clientSignature ?? '';

    for (int i = 0; i < _kInspectionItems.length; i++) {
      if (i < c.inspectionItems.length) {
        final item = c.inspectionItems[i];
        _inspectionState[i] = {
          'checked':
              item['checked'] == true || item['checked'] == 'true',
          'not_checked': item['not_checked'] == true ||
              item['not_checked'] == 'true',
        };
        _inspectionRemarkControllers[i].text =
            item['remarks']?.toString() ?? '';
      }
    }

    for (int i = 0; i < 4; i++) {
      if (i < c.openSpaceData.length) {
        final space = c.openSpaceData[i];
        _openSpaceRows[i]['sanction_plan_1']!.text =
            space['sanction_plan_1'] ?? '';
        _openSpaceRows[i]['sanction_plan_2']!.text =
            space['sanction_plan_2'] ?? '';
        _openSpaceRows[i]['sanction_plan_3']!.text =
            space['sanction_plan_3'] ?? '';
        _openSpaceRows[i]['sanction_plan_4']!.text =
            space['sanction_plan_4'] ?? '';
        _openSpaceRows[i]['working_drawing_1']!.text =
            space['working_drawing_1'] ?? '';
        _openSpaceRows[i]['working_drawing_2']!.text =
            space['working_drawing_2'] ?? '';
        _openSpaceRows[i]['working_drawing_3']!.text =
            space['working_drawing_3'] ?? '';
        _openSpaceRows[i]['working_drawing_4']!.text =
            space['working_drawing_4'] ?? '';
        _openSpaceRows[i]['site_1']!.text = space['site_1'] ?? '';
        _openSpaceRows[i]['site_2']!.text = space['site_2'] ?? '';
        _openSpaceRows[i]['site_3']!.text = space['site_3'] ?? '';
        _openSpaceRows[i]['site_4']!.text = space['site_4'] ?? '';
        _openSpaceRows[i]['remarks']!.text = space['remarks'] ?? '';
      }
    }
  }

  Future<void> _loadChecklistNumber() async {
    if (!mounted) return;
    setState(() => _isLoadingNo = true);
    try {
      final no = await ApiService.generateArchitectureChecklistNumber(
          widget.projectId);
      if (mounted) setState(() => _checklistNo = no);
    } catch (_) {}
    if (mounted) setState(() => _isLoadingNo = false);
  }

  @override
  void dispose() {
    _jobNoCtrl.dispose();
    _honeycombColumnCtrl.dispose();
    _beamNoCtrl.dispose();
    _balanceWorkMonthsCtrl.dispose();
    _lastDateTimePeriodCtrl.dispose();
    _constructionStatementCtrl.dispose();
    _additionalInstructionsCtrl.dispose();
    _architectSignatureCtrl.dispose();
    _clientSignatureCtrl.dispose();
    for (final ctrl in _inspectionRemarkControllers) {
      ctrl.dispose();
    }
    for (final row in _openSpaceRows) {
      for (final ctrl in row.values) {
        ctrl.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _pickDate(bool isChecklist) async {
    final initial = isChecklist
        ? (_checklistDate ?? DateTime.now())
        : (_sanctionDate ?? DateTime.now());

    final lastDate = DateTime.now().add(const Duration(days: 365 * 5));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: lastDate,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
                primary: Color(0xFF0891B2))),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isChecklist) {
          _checklistDate = picked;
        } else {
          _sanctionDate = picked;
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

  List<Map<String, dynamic>> _buildInspectionPayload() {
    return List.generate(_kInspectionItems.length, (i) {
      final state = _inspectionState[i];
      return {
        'description': _kInspectionItems[i],
        'checked': (state['checked'] as bool) ? 'true' : null,
        'not_checked': (state['not_checked'] as bool) ? 'true' : null,
        'remarks': _inspectionRemarkControllers[i].text,
      };
    });
  }

  List<Map<String, dynamic>> _buildOpenSpacePayload() {
    return _openSpaceRows.map((row) {
      return <String, dynamic>{
        'sanction_plan_1': row['sanction_plan_1']!.text,
        'sanction_plan_2': row['sanction_plan_2']!.text,
        'sanction_plan_3': row['sanction_plan_3']!.text,
        'sanction_plan_4': row['sanction_plan_4']!.text,
        'working_drawing_1': row['working_drawing_1']!.text,
        'working_drawing_2': row['working_drawing_2']!.text,
        'working_drawing_3': row['working_drawing_3']!.text,
        'working_drawing_4': row['working_drawing_4']!.text,
        'site_1': row['site_1']!.text,
        'site_2': row['site_2']!.text,
        'site_3': row['site_3']!.text,
        'site_4': row['site_4']!.text,
        'remarks': row['remarks']!.text,
      };
    }).toList();
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (_checklistDate == null) {
      _showError('Please select a checklist date.');
      return;
    }
    setState(() => _isSaving = true);
    try {
      if (_isEditing) {
        await ApiService.updateArchitectureChecklist(
          projectId: widget.projectId,
          id: widget.existing!.id,
          checklistDate: _isoDate(_checklistDate!),
          jobNo: _jobNoCtrl.text.trim(),
          projectName: widget.projectName,
          beamNotInLine: _beamNotInLine,
          columnNotPlumb: _columnNotPlumb,
          honeycombColumn: _honeycombColumnCtrl.text.trim(),
          beamNo: _beamNoCtrl.text.trim(),
          inspectionItems: _buildInspectionPayload(),
          barChartAvailable: _barChartAvailable,
          workInProgress: _workInProgress,
          timeLimitAvailable: _timeLimitAvailable,
          balanceWorkMonths: _balanceWorkMonthsCtrl.text.trim(),
          lastDateTimePeriod: _lastDateTimePeriodCtrl.text.trim(),
          sanctionDate:
              _sanctionDate != null ? _isoDate(_sanctionDate!) : null,
          openSpaceData: _buildOpenSpacePayload(),
          constructionStatement:
              _constructionStatementCtrl.text.trim(),
          additionalInstructions:
              _additionalInstructionsCtrl.text.trim(),
          architectSignature: _architectSignatureCtrl.text.trim(),
          clientSignature: _clientSignatureCtrl.text.trim(),
        );
      } else {
        await ApiService.createArchitectureChecklist(
          projectId: widget.projectId,
          checklistNo: _checklistNo,
          checklistDate: _isoDate(_checklistDate!),
          jobNo: _jobNoCtrl.text.trim(),
          projectName: widget.projectName,
          beamNotInLine: _beamNotInLine,
          columnNotPlumb: _columnNotPlumb,
          honeycombColumn: _honeycombColumnCtrl.text.trim(),
          beamNo: _beamNoCtrl.text.trim(),
          inspectionItems: _buildInspectionPayload(),
          barChartAvailable: _barChartAvailable,
          workInProgress: _workInProgress,
          timeLimitAvailable: _timeLimitAvailable,
          balanceWorkMonths: _balanceWorkMonthsCtrl.text.trim(),
          lastDateTimePeriod: _lastDateTimePeriodCtrl.text.trim(),
          sanctionDate:
              _sanctionDate != null ? _isoDate(_sanctionDate!) : null,
          openSpaceData: _buildOpenSpacePayload(),
          constructionStatement:
              _constructionStatementCtrl.text.trim(),
          additionalInstructions:
              _additionalInstructionsCtrl.text.trim(),
          architectSignature: _architectSignatureCtrl.text.trim(),
          clientSignature: _clientSignatureCtrl.text.trim(),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEditing
            ? 'Architecture Checklist updated successfully!'
            : 'Architecture Checklist created successfully!'),
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
        title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(
            _isEditing
                ? 'Edit Architecture Checklist'
                : 'New Architecture Checklist',
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B)),
          ),
          Text(widget.projectName,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF64748B)),
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(
                      _isEditing ? 'Update' : 'Save',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeaderSection()),
          SliverToBoxAdapter(child: _buildSection1()),
          SliverToBoxAdapter(child: _buildSection2()),
          SliverToBoxAdapter(child: _buildSection3()),
          SliverToBoxAdapter(child: _buildSection4()),
          SliverToBoxAdapter(child: _buildSection5()),
          SliverToBoxAdapter(child: _buildSection6()),
          SliverToBoxAdapter(child: _buildSignatureSection()),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() => _card(
        title: 'Header',
        icon: Icons.info_outline,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
            Text('WR-EXE-B-19',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B))),
            Text('WISE REALTY',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B))),
          ]),
          const SizedBox(height: 4),
          const Center(
            child: Text('DEVISE DESIGN ARCHITECTS',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          const Center(
            child: Text('SITE VISIT REPORT',
                style: TextStyle(
                    fontSize: 11, color: Color(0xFF64748B))),
          ),
          const SizedBox(height: 14),
          _label('No.'),
          _readOnlyField(
              _isLoadingNo ? 'Generating…' : _checklistNo),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _label('Date *'),
                _datePicker(
                    value: _checklistDate,
                    hint: 'Select date',
                    onTap: () => _pickDate(true)),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _inputField(_jobNoCtrl, 'Job No',
                  hint: 'Job number'),
            ),
          ]),
          const SizedBox(height: 14),
          _label('Project'),
          _readOnlyField(widget.projectName),
        ]),
      );

  Widget _buildSection1() => _card(
        title: '1) Concrete Members Inspected',
        icon: Icons.construction_outlined,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(children: [
            Expanded(
              child: _checkboxRow(
                'a) Beam not in line & level No.',
                _beamNotInLine,
                (v) => setState(() => _beamNotInLine = v ?? false),
              ),
            ),
            Expanded(
              child: _checkboxRow(
                'b) Column not in Plumb/Alignment',
                _columnNotPlumb,
                (v) => setState(() => _columnNotPlumb = v ?? false),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: _inputField(
                _honeycombColumnCtrl,
                'c) Honeycomb Column',
                hint: 'Good / Satisfactory / Improvement required',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _inputField(_beamNoCtrl, '& Beam No.',
                  hint: 'Beam number'),
            ),
          ]),
        ]),
      );

  Widget _buildSection2() => _card(
        title: '2) Inspection At Site & Checking',
        icon: Icons.checklist_outlined,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6)),
            child: const Row(children: [
              Expanded(
                  flex: 5,
                  child: Text('DESCRIPTION',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B)))),
              SizedBox(
                  width: 44,
                  child: Text('CHK',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B)))),
              SizedBox(
                  width: 44,
                  child: Text('N/CHK',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B)))),
              SizedBox(
                  width: 90,
                  child: Text('REMARKS',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B)))),
            ]),
          ),
          const SizedBox(height: 4),
          ...List.generate(_kInspectionItems.length, (i) {
            final state = _inspectionState[i];
            final isChecked = state['checked'] as bool;
            final isNotChecked = state['not_checked'] as bool;

            return Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: i % 2 == 0
                    ? Colors.white
                    : const Color(0xFFFAFAFB),
                border: Border(
                    bottom: BorderSide(
                        color: const Color(0xFFF1F5F9), width: 1)),
              ),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Expanded(
                  flex: 5,
                  child: Text(_kInspectionItems[i],
                      style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF1E293B),
                          height: 1.3)),
                ),
                SizedBox(
                  width: 44,
                  child: Center(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        final nowChecked = !isChecked;
                        _inspectionState[i] = {
                          'checked': nowChecked,
                          'not_checked': nowChecked ? false : isNotChecked,
                        };
                      }),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isChecked
                              ? const Color(0xFF22C55E)
                              : Colors.white,
                          border: Border.all(
                              color: isChecked
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFFD1D5DB),
                              width: 2),
                        ),
                        child: isChecked
                            ? const Icon(Icons.check,
                                size: 13, color: Colors.white)
                            : null,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Center(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        final nowNotChecked = !isNotChecked;
                        _inspectionState[i] = {
                          'not_checked': nowNotChecked,
                          'checked': nowNotChecked ? false : isChecked,
                        };
                      }),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isNotChecked
                              ? const Color(0xFFEF4444)
                              : Colors.white,
                          border: Border.all(
                              color: isNotChecked
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFFD1D5DB),
                              width: 2),
                        ),
                        child: isNotChecked
                            ? const Icon(Icons.close,
                                size: 13, color: Colors.white)
                            : null,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: SizedBox(
                    height: 32,
                    child: TextField(
                      controller: _inspectionRemarkControllers[i],
                      style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF1E293B)),
                      decoration: InputDecoration(
                        hintText: 'Remark',
                        hintStyle: const TextStyle(
                            fontSize: 9,
                            color: Color(0xFFCBD5E1)),
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(4),
                            borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(4),
                            borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(4),
                            borderSide: const BorderSide(
                                color: Color(0xFF0891B2),
                                width: 1.5)),
                        contentPadding:
                            const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                        isDense: true,
                      ),
                    ),
                  ),
                ),
              ]),
            );
          }),
        ]),
      );

  Widget _buildSection3() => _card(
        title: '3) Graphical Representation Of Work And Time',
        icon: Icons.bar_chart_outlined,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          _label('A) Bar Chart Available'),
          Row(children: [
            _radioChip('Yes', 'Yes', _barChartAvailable,
                (v) => setState(() => _barChartAvailable = v)),
            const SizedBox(width: 8),
            _radioChip('No', 'No', _barChartAvailable,
                (v) => setState(() => _barChartAvailable = v)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: _checkboxRow(
                'B) Work Progressing as per Schedule',
                _workInProgress,
                (v) => setState(() => _workInProgress = v ?? false),
              ),
            ),
            Expanded(
              child: _checkboxRow(
                'C) Time Limit available',
                _timeLimitAvailable,
                (v) =>
                    setState(() => _timeLimitAvailable = v ?? false),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          _inputField(_balanceWorkMonthsCtrl, 'Months',
              hint: 'Balance work months'),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: _inputField(
                  _lastDateTimePeriodCtrl,
                  'D) Last Date of Time Period',
                  hint: 'Enter last date'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _label('Sanction Date'),
                _datePicker(
                    value: _sanctionDate,
                    hint: 'Optional',
                    onTap: () => _pickDate(false)),
              ]),
            ),
          ]),
        ]),
      );

  Widget _buildSection4() => _card(
        title: '4) Open Space Statement',
        icon: Icons.grid_on_outlined,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          const Text(
            'SP = Sanction Plan  |  WD = Working Drawing  |  S = Site',
            style: TextStyle(
                fontSize: 10,
                color: Color(0xFF94A3B8),
                fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 10),
          ...List.generate(4, (rowIdx) {
            final row = _openSpaceRows[rowIdx];
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Row ${rowIdx + 1}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _accent)),
                const SizedBox(height: 8),
                const Text('As Per Sanction Plan',
                    style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(
                      child: _tinyInput(
                          row['sanction_plan_1']!, 'Col 1')),
                  const SizedBox(width: 4),
                  Expanded(
                      child: _tinyInput(
                          row['sanction_plan_2']!, 'Col 2')),
                  const SizedBox(width: 4),
                  Expanded(
                      child: _tinyInput(
                          row['sanction_plan_3']!, 'Col 3')),
                  const SizedBox(width: 4),
                  Expanded(
                      child: _tinyInput(
                          row['sanction_plan_4']!, 'Col 4')),
                ]),
                const SizedBox(height: 8),
                const Text('As Per Working Drawing',
                    style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(
                      child: _tinyInput(
                          row['working_drawing_1']!, 'Col 1')),
                  const SizedBox(width: 4),
                  Expanded(
                      child: _tinyInput(
                          row['working_drawing_2']!, 'Col 2')),
                  const SizedBox(width: 4),
                  Expanded(
                      child: _tinyInput(
                          row['working_drawing_3']!, 'Col 3')),
                  const SizedBox(width: 4),
                  Expanded(
                      child: _tinyInput(
                          row['working_drawing_4']!, 'Col 4')),
                ]),
                const SizedBox(height: 8),
                const Text('As Per Site',
                    style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(
                      child:
                          _tinyInput(row['site_1']!, 'Col 1')),
                  const SizedBox(width: 4),
                  Expanded(
                      child:
                          _tinyInput(row['site_2']!, 'Col 2')),
                  const SizedBox(width: 4),
                  Expanded(
                      child:
                          _tinyInput(row['site_3']!, 'Col 3')),
                  const SizedBox(width: 4),
                  Expanded(
                      child:
                          _tinyInput(row['site_4']!, 'Col 4')),
                ]),
                const SizedBox(height: 8),
                _inputField(row['remarks']!, 'Remarks',
                    hint: 'Remarks for this row'),
              ]),
            );
          }),
        ]),
      );

  Widget _buildSection5() => _card(
        title:
            '5) Construction carried out as per Approved Drawing. YES/NO',
        icon: Icons.description_outlined,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          TextField(
            controller: _constructionStatementCtrl,
            maxLines: 3,
            decoration: _inputDeco(hint: 'Enter statement'),
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 8),
          const Text(
            '1. Architect is not responsible for safety of shuttering centering and its supporting props.\n'
            '2. Architect is not responsible for any accident due to defective shuttering or RCC design.',
            style: TextStyle(
                fontSize: 10,
                color: Color(0xFF94A3B8),
                fontStyle: FontStyle.italic),
          ),
        ]),
      );

  Widget _buildSection6() => _card(
        title: '6) Additional Instructions If Any',
        icon: Icons.notes_outlined,
        child: TextField(
          controller: _additionalInstructionsCtrl,
          maxLines: 4,
          decoration:
              _inputDeco(hint: 'Enter additional instructions…'),
          style: const TextStyle(
              fontSize: 13, color: Color(0xFF1E293B)),
        ),
      );

  Widget _buildSignatureSection() => _card(
        title: 'Signatures',
        icon: Icons.draw_outlined,
        child: Row(children: [
          Expanded(
            child: _inputField(
                _architectSignatureCtrl,
                'Signature of Architect/Engineer',
                hint: 'Enter name'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _inputField(
                _clientSignatureCtrl,
                'Signature of Client/Contractor',
                hint: 'Enter name'),
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
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Container(
            padding:
                const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12)),
            ),
            child: Row(children: [
              Icon(icon, size: 15, color: _accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _accent)),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
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

  Widget _readOnlyField(String value) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(value,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF64748B))),
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
          decoration: _inputDeco(hint: hint),
          style: const TextStyle(
              fontSize: 13, color: Color(0xFF1E293B)),
        ),
      ]);

  Widget _tinyInput(TextEditingController ctrl, String hint) =>
      SizedBox(
        height: 34,
        child: TextField(
          controller: ctrl,
          style: const TextStyle(
              fontSize: 11, color: Color(0xFF1E293B)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
                fontSize: 10, color: Color(0xFFCBD5E1)),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide:
                    const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide:
                    const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(
                    color: Color(0xFF0891B2), width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 6, vertical: 4),
            isDense: true,
          ),
        ),
      );

  Widget _datePicker({
    required DateTime? value,
    required String hint,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 13),
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
                color: value != null
                    ? _accent
                    : const Color(0xFF94A3B8)),
          ]),
        ),
      );

  Widget _checkboxRow(
          String label, bool value, ValueChanged<bool?> onChanged) =>
      Row(children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: _accent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4)),
          side: const BorderSide(color: Color(0xFFD1D5DB)),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF374151))),
        ),
      ]);

  Widget _radioChip(String label, String val, String? current,
      ValueChanged<String?> onChanged) {
    final selected = current == val;
    const color = Color(0xFF0891B2);
    return GestureDetector(
      onTap: () => onChanged(selected ? null : val),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.1)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: selected ? color : const Color(0xFFE2E8F0),
              width: selected ? 1.5 : 1),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                color:
                    selected ? color : const Color(0xFF64748B),
                fontWeight: selected
                    ? FontWeight.w700
                    : FontWeight.w500)),
      ),
    );
  }

  InputDecoration _inputDeco({String? hint}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            fontSize: 13, color: Color(0xFFCBD5E1)),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
                color: Color(0xFF0891B2), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 11),
        isDense: true,
      );
}