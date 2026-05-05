// lib/features/general_tasks/presentation/pages/general_tasks_page.dart

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/auth_storage_service.dart';
import '../../data/models/general_task_model.dart';

// Supported formats — mirrors web server list exactly
const List<String> _kAllowedExtensions = [
  'pdf', 'doc', 'docx', 'ppt', 'pptx',
  'mp4', 'avi',
  'jpeg', 'jpg', 'png', 'gif',
  'dwg', 'dxf', 'zip',                                                                                                                                                                                                                                                                                                                                          
];

const String _kSupportedFormatsLabel =
    'Supported formats: PDF, DOC, DOCX, PPT, PPTX, MP4, AVI, JPEG, JPG, PNG, GIF, DWG, DXF, ZIP';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens
// ─────────────────────────────────────────────────────────────────────────────
abstract class _D {
  static const Color bg        = Color(0xFFF0F4F8);
  static const Color surface   = Colors.white;
  static const Color border    = Color(0xFFE2E8F0);

  static const Color textPri   = Color(0xFF0F172A);
  static const Color textSec   = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  static const Color green     = Color(0xFF059669);
  static const Color greenBg   = Color(0xFFD1FAE5);
  static const Color greenFg   = Color(0xFF047857);
  static const Color greenDark = Color(0xFF065F46);

  static const Color amber     = Color(0xFFF59E0B);
  static const Color amberBg   = Color(0xFFFEF3C7);
  static const Color amberFg   = Color(0xFFB45309);

  static const Color red       = Color(0xFFEF4444);
  static const Color redBg     = Color(0xFFFEE2E2);
  static const Color redFg     = Color(0xFFB91C1C);

  static const Color blue      = Color(0xFF3B82F6);
  static const Color blueBg    = Color(0xFFEFF6FF);
  static const Color blueFg    = Color(0xFF1D4ED8);

  static const Color purple    = Color(0xFF8B5CF6);
  static const Color purpleBg  = Color(0xFFF5F3FF);
  static const Color purpleFg  = Color(0xFF6D28D9);

  static const Color indigo    = Color(0xFF6366F1);
  static const Color indigoBg  = Color(0xFFEEF2FF);

  static const Color slate     = Color(0xFF475569);
  static const Color slateBg   = Color(0xFFF1F5F9);

  static const Color orange    = Color(0xFFF97316);
  static const Color orangeBg  = Color(0xFFFFF7ED);
  static const Color orangeFg  = Color(0xFFEA580C);

  // Stat card gradient colors
  static const Color statAllFrom   = Color(0xFF1E40AF);
  static const Color statAllTo     = Color(0xFF3B82F6);
  static const Color statDoneFrom  = Color(0xFF065F46);
  static const Color statDoneTo    = Color(0xFF059669);
  static const Color statPendFrom  = Color(0xFFC2410C);
  static const Color statPendTo    = Color(0xFFF97316);

  static const double r6  = 6;
  static const double r8  = 8;
  static const double r10 = 10;
  static const double r12 = 12;
  static const double r16 = 16;
  static const double r20 = 20;
  static const double r24 = 24;
  static const double r99 = 99;

  static const TextStyle titleLg = TextStyle(
    fontSize: 18, fontWeight: FontWeight.w800,
    color: textPri, letterSpacing: -0.5, height: 1.25,
  );
  static const TextStyle titleMd = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w700,
    color: textPri, letterSpacing: -0.3, height: 1.3,
  );
  static const TextStyle body = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w400,
    color: textSec, height: 1.5,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w500,
    color: textMuted, letterSpacing: 0.1,
  );
  static const TextStyle label = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w600,
    color: textPri, letterSpacing: 0.1,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Status metadata helper
// ─────────────────────────────────────────────────────────────────────────────
class _StatusMeta {
  final Color bg, fg, dot;
  final String label;
  const _StatusMeta({
    required this.bg, required this.fg,
    required this.dot, required this.label,
  });

  static _StatusMeta of(GeneralTaskModel t) {
    if (t.isCompleted) {
      return const _StatusMeta(
          bg: _D.greenBg, fg: _D.greenFg, dot: _D.green, label: 'Completed');
    }
    if (t.status == 'in_process') {
      return const _StatusMeta(
          bg: _D.amberBg, fg: _D.amberFg, dot: _D.amber, label: 'In Progress');
    }
    return const _StatusMeta(
        bg: _D.orangeBg, fg: _D.orangeFg, dot: _D.orange, label: 'Pending');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary stat card widget (new)
// ─────────────────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color fromColor;
  final Color toColor;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.count,
    required this.fromColor,
    required this.toColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [fromColor, toColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(_D.r16),
          boxShadow: [
            BoxShadow(
              color: toColor.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(_D.r8),
                  ),
                  child: Icon(icon, size: 16, color: Colors.white),
                ),
                // Small decorative circle
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.85),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared styled input
// ─────────────────────────────────────────────────────────────────────────────
class _Input extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final bool readOnly;
  final Widget? suffix;

  const _Input({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.readOnly = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    maxLines: maxLines,
    readOnly: readOnly,
    style: const TextStyle(
        fontSize: 14, color: _D.textPri, fontWeight: FontWeight.w500),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: _D.body.copyWith(fontSize: 14),
      suffixIcon: suffix,
      filled: true,
      fillColor: _D.bg,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: _D.border, width: 1.5),
        borderRadius: BorderRadius.circular(_D.r10),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: _D.green, width: 1.8),
        borderRadius: BorderRadius.circular(_D.r10),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared field label
// ─────────────────────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _FieldLabel(this.text, {this.required = false});

  @override
  Widget build(BuildContext context) => RichText(
    text: TextSpan(
      text: text,
      style: _D.label,
      children: required
          ? const [TextSpan(
              text: ' *',
              style: TextStyle(color: _D.red, fontSize: 12))]
          : null,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Create / Edit bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _TaskFormSheet extends StatefulWidget {
  final GeneralTaskModel? existing;
  final Future<void> Function({
    required String taskName,
    required String taskDescription,
    String? taskDeadline,
  }) onSubmit;

  const _TaskFormSheet({this.existing, required this.onSubmit});

  @override
  State<_TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends State<_TaskFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _deadlineCtrl;
  DateTime? _pickedDate;
  bool _submitting = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    _nameCtrl     = TextEditingController(text: t?.taskName ?? '');
    _descCtrl     = TextEditingController(text: t?.taskDescription ?? '');
    _deadlineCtrl = TextEditingController();

    if (t != null && (t.taskDeadline ?? '').isNotEmpty) {
      try {
        final p = t.taskDeadline!.split('-');
        if (p.length == 3) {
          _pickedDate = DateTime(
              int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
          _deadlineCtrl.text = _displayDate(_pickedDate!);
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _deadlineCtrl.dispose();
    super.dispose();
  }

  String _displayDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} / '
      '${d.month.toString().padLeft(2, '0')} / '
      '${d.year}';

  String? _apiDate() {
    final raw = _deadlineCtrl.text.replaceAll(' ', '');
    if (raw.isEmpty) return null;
    final p = raw.split('/');
    if (p.length == 3) return '${p[2]}-${p[1]}-${p[0]}';
    return null;
  }

  Future<void> _pick() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _pickedDate ?? DateTime.now(),
      firstDate: _isEdit ? DateTime(1900) : DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
              primary: _D.green, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (d != null && mounted) setState(() {
      _pickedDate = d;
      _deadlineCtrl.text = _displayDate(d);
    });
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) { _toast('Task name is required'); return; }
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        taskName: name,
        taskDescription: _descCtrl.text.trim(),
        taskDeadline: _apiDate(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) { setState(() => _submitting = false); _toast(e.toString()); }
    }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg), backgroundColor: _D.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: _D.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(_D.r24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + mq.viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dragHandle(),
          Row(children: [
            _iconBox(Icons.task_alt_rounded, _D.greenBg, _D.green),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_isEdit ? 'Edit Task' : 'New Task', style: _D.titleLg),
                Text(
                  _isEdit
                      ? 'Update task details below'
                      : 'Fill in the details to create a task',
                  style: _D.caption.copyWith(fontSize: 12),
                ),
              ],
            )),
            _closeBtn(_submitting ? null : () => Navigator.pop(context)),
          ]),
          const SizedBox(height: 22),
          const _FieldLabel('Task Name', required: true),
          const SizedBox(height: 6),
          _Input(controller: _nameCtrl, hint: 'Enter task name'),
          const SizedBox(height: 16),
          const _FieldLabel('Description'),
          const SizedBox(height: 6),
          _Input(
            controller: _descCtrl,
            hint: 'Add a short description...',
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          const _FieldLabel('Deadline'),
          const SizedBox(height: 6),
          _Input(
            controller: _deadlineCtrl, hint: 'Select a date', readOnly: true,
            suffix: GestureDetector(
              onTap: _pick,
              child: _calendarIcon(_D.greenBg, _D.greenFg),
            ),
          ),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: _submitting ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _D.slate,
                  side: const BorderSide(color: _D.border, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_D.r12)),
                ),
                child: const Text('Cancel',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ),
            )),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: _D.green,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _D.green.withValues(alpha: 0.55),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_D.r12)),
                ),
                child: _submitting
                    ? _spinner()
                    : Text(_isEdit ? 'Save Changes' : 'Create Task',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            )),
          ]),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Upload bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _UploadSheet extends StatefulWidget {
  final GeneralTaskModel task;
  final Future<void> Function({
    required int    taskId,
    required File   file,
    required String fileName,
    required String uploadedDate,
  }) onUpload;

  const _UploadSheet({required this.task, required this.onUpload});

  @override
  State<_UploadSheet> createState() => _UploadSheetState();
}

class _UploadSheetState extends State<_UploadSheet> {
  File?   _pickedFile;
  String? _pickedFileName;
  late final TextEditingController _dateCtrl;
  bool _submitting = false;

  bool get _isReupload => (widget.task.filePath ?? '').isNotEmpty;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateCtrl = TextEditingController(
      text: '${now.year}-'
            '${now.month.toString().padLeft(2, '0')}-'
            '${now.day.toString().padLeft(2, '0')}',
    );
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _kAllowedExtensions,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final pf = result.files.first;
    if (pf.path == null) return;
    setState(() {
      _pickedFile     = File(pf.path!);
      _pickedFileName = pf.name;
    });
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
              primary: _D.purple, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (d != null && mounted) {
      setState(() {
        _dateCtrl.text = '${d.year}-'
            '${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _submit() async {
    if (_pickedFile == null) {
      _toast('Please choose a file to upload');
      return;
    }
    if (_dateCtrl.text.trim().isEmpty) {
      _toast('Please select an upload date');
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.onUpload(
        taskId:       widget.task.taskId,
        file:         _pickedFile!,
        fileName:     _pickedFileName!,
        uploadedDate: _dateCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        _toast(e.toString());
      }
    }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: _D.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: _D.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(_D.r24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + mq.viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dragHandle(),

          Row(children: [
            _iconBox(Icons.upload_rounded, _D.purpleBg, _D.purple),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_isReupload ? 'Reupload Document' : 'Upload Document',
                    style: _D.titleLg),
                Text(widget.task.taskName,
                    style: _D.caption.copyWith(fontSize: 12),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            )),
            _closeBtn(_submitting ? null : () => Navigator.pop(context)),
          ]),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _D.purpleBg,
              borderRadius: BorderRadius.circular(_D.r10),
              border: Border.all(color: _D.purple.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, size: 15, color: _D.purple),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Submitting a document will mark this task as Completed.',
                style: _D.caption.copyWith(color: _D.purpleFg, fontSize: 11),
              )),
            ]),
          ),
          const SizedBox(height: 16),

          const _FieldLabel('Select Document', required: true),
          const SizedBox(height: 6),

          GestureDetector(
            onTap: _submitting ? null : _pickFile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: _D.bg,
                borderRadius: BorderRadius.circular(_D.r10),
                border: Border.all(
                  color: _pickedFile != null ? _D.purple : _D.border,
                  width: 1.5,
                ),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: _pickedFile != null ? _D.purpleBg : _D.slateBg,
                    borderRadius: BorderRadius.circular(_D.r8),
                    border: Border.all(
                      color: _pickedFile != null
                          ? _D.purple.withValues(alpha: 0.3)
                          : _D.border,
                    ),
                  ),
                  child: Text(
                    'Choose File',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _pickedFile != null ? _D.purpleFg : _D.slate,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _pickedFileName ?? 'No file chosen',
                    style: TextStyle(
                      fontSize: 13,
                      color: _pickedFileName != null ? _D.textPri : _D.textMuted,
                      fontWeight: _pickedFileName != null
                          ? FontWeight.w500 : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_pickedFile != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() {
                      _pickedFile     = null;
                      _pickedFileName = null;
                    }),
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: _D.textMuted),
                  ),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 6),
          Text(_kSupportedFormatsLabel,
              style: _D.caption.copyWith(fontSize: 10.5, color: _D.textMuted)),
          const SizedBox(height: 16),

          const _FieldLabel('Upload Date', required: true),
          const SizedBox(height: 6),
          _Input(
            controller: _dateCtrl,
            hint: 'YYYY-MM-DD',
            readOnly: true,
            suffix: GestureDetector(
              onTap: _pickDate,
              child: _calendarIcon(_D.purpleBg, _D.purpleFg),
            ),
          ),
          const SizedBox(height: 24),

          Row(children: [
            Expanded(child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: _submitting ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _D.slate,
                  side: const BorderSide(color: _D.border, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_D.r12)),
                ),
                child: const Text('Close',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ),
            )),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? _spinner(size: 18)
                    : const Icon(Icons.upload_rounded, size: 18),
                label: Text(
                  _submitting ? 'Uploading…' : (_isReupload ? 'Reupload' : 'Upload'),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: _D.purple,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _D.purple.withValues(alpha: 0.55),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_D.r12)),
                ),
              ),
            )),
          ]),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// View document bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _ViewDocSheet extends StatelessWidget {
  final GeneralTaskModel task;
  const _ViewDocSheet({required this.task});

  @override
  Widget build(BuildContext context) {
    final filePath   = task.filePath   ?? '';
    final uploadDate = task.uploadedDate ?? '';

    return Container(
      decoration: const BoxDecoration(
        color: _D.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(_D.r24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dragHandle(),
          Row(children: [
            _iconBox(Icons.check_circle_rounded, _D.greenBg, _D.green),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Document Submitted', style: _D.titleLg),
                Text(task.taskName,
                    style: _D.caption.copyWith(fontSize: 12),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            )),
            _closeBtn(() => Navigator.pop(context)),
          ]),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _D.bg,
              borderRadius: BorderRadius.circular(_D.r12),
              border: Border.all(color: _D.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.insert_drive_file_outlined,
                      size: 13, color: _D.textMuted),
                  const SizedBox(width: 5),
                  Text('Uploaded File', style: _D.caption.copyWith(fontSize: 11)),
                ]),
                const SizedBox(height: 6),
                Text(
                  filePath,
                  style: const TextStyle(
                    fontSize: 13, color: _D.blue,
                    decoration: TextDecoration.underline,
                    decorationColor: _D.blue,
                  ),
                  maxLines: 3, overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (uploadDate.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _D.greenBg,
                borderRadius: BorderRadius.circular(_D.r10),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle_outline_rounded,
                    size: 14, color: _D.greenFg),
                const SizedBox(width: 8),
                Text('Completed on $uploadDate',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: _D.greenFg)),
              ]),
            ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity, height: 48,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: _D.slate,
                side: const BorderSide(color: _D.border, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_D.r12)),
              ),
              child: const Text('Close',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Assign dialog
// ─────────────────────────────────────────────────────────────────────────────
class _AssignDialog extends StatefulWidget {
  final GeneralTaskModel task;
  final Future<List<dynamic>> Function() fetchUsers;
  final Future<void> Function({
    required int       taskId,
    required List<int> assignedTo,
    required String    assignedDate,
  }) onAssign;

  const _AssignDialog({
    required this.task,
    required this.fetchUsers,
    required this.onAssign,
  });

  @override
  State<_AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends State<_AssignDialog> {
  final _selected = <int>{};
  final _dateCtrl = TextEditingController(
      text: DateTime.now().toIso8601String().split('T').first);
  List<dynamic> _users = [];
  bool _loading    = true;
  bool _submitting = false;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _dateCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final u = await widget.fetchUsers();
      if (mounted) setState(() { _users = u; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_D.r16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: 480,
            maxHeight: MediaQuery.of(context).size.height * 0.82),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
              decoration: const BoxDecoration(
                color: _D.blueBg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(_D.r16)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _D.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(_D.r8),
                  ),
                  child: const Icon(Icons.person_add_alt_1_rounded,
                      color: _D.blue, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Assign Task',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700,
                            color: _D.textPri)),
                    Text(widget.task.taskName,
                        style: _D.caption,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                )),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(_D.r6)),
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: _D.slate),
                  ),
                ),
              ]),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Assign Date'),
                    const SizedBox(height: 6),
                    _Input(controller: _dateCtrl, hint: 'YYYY-MM-DD'),
                    const SizedBox(height: 16),
                    const _FieldLabel('Select Team Members'),
                    const SizedBox(height: 8),
                    if (_loading)
                      const Center(child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _D.green),
                      ))
                    else if (_users.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _D.bg,
                          borderRadius: BorderRadius.circular(_D.r10),
                          border: Border.all(color: _D.border),
                        ),
                        child: const Row(children: [
                          Icon(Icons.info_outline_rounded,
                              size: 16, color: _D.textMuted),
                          SizedBox(width: 8),
                          Text('No users available', style: _D.body),
                        ]),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: _D.border),
                          borderRadius: BorderRadius.circular(_D.r10),
                        ),
                        child: Column(
                          children: _users.asMap().entries.map((e) {
                            final i    = e.key;
                            final user = e.value;
                            final last = i == _users.length - 1;
                            return Column(children: [
                              CheckboxListTile(
                                value: _selected.contains(user.id),
                                activeColor: _D.green,
                                checkColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 2),
                                title: Text(user.name,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: _D.textPri)),
                                subtitle: Text(user.email,
                                    style: _D.caption),
                                onChanged: (v) => setState(() {
                                  if (v == true) _selected.add(user.id);
                                  else _selected.remove(user.id);
                                }),
                              ),
                              if (!last)
                                const Divider(height: 1, color: _D.border),
                            ]);
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: _D.border))),
              child: Row(children: [
                Expanded(child: SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    onPressed: _submitting ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _D.slate,
                      side: const BorderSide(color: _D.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_D.r10)),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                )),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    icon: _submitting
                        ? _spinner(size: 16)
                        : const Icon(Icons.check_rounded, size: 16),
                    label: Text(
                        _submitting ? 'Assigning…' : 'Assign Task',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                    onPressed: _submitting ? null : () async {
                      setState(() => _submitting = true);
                      try {
                        await widget.onAssign(
                          taskId:       widget.task.taskId,
                          assignedTo:   _selected.toList(),
                          assignedDate: _dateCtrl.text.trim(),
                        );
                        if (mounted) Navigator.pop(context, true);
                      } catch (e) {
                        if (mounted) {
                          setState(() => _submitting = false);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(e.toString()),
                              backgroundColor: _D.red));
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: _D.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_D.r10)),
                    ),
                  ),
                )),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main page
// ─────────────────────────────────────────────────────────────────────────────
class GeneralTasksPage extends StatefulWidget {
  const GeneralTasksPage({super.key});

  @override
  State<GeneralTasksPage> createState() => _GeneralTasksPageState();
}

class _GeneralTasksPageState extends State<GeneralTasksPage> {
  List<GeneralTaskModel> allTasks      = [];
  List<GeneralTaskModel> filteredTasks = [];

  bool isLoadingTasks = true;
  bool isLoadingRole  = true;

  String? errorMessage;
  String  userRole = '';

  final _searchCtrl  = TextEditingController();
  final _searchFocus = FocusNode();
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_applySearch);
    _initialLoad();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _initialLoad() async {
    try {
      final role = (await AuthStorageService.getUserRole()) ?? '';
      if (mounted) setState(() { userRole = role; isLoadingRole = false; });
    } catch (_) {
      if (mounted) setState(() => isLoadingRole = false);
    }
    try {
      final tasks = await ApiService.fetchGeneralTasks();
      if (!mounted) return;
      setState(() {
        allTasks = tasks;
        _applySearchToList(tasks);
        isLoadingTasks = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { errorMessage = e.toString(); isLoadingTasks = false; });
    }
  }

  Future<void> _loadTasks() async {
    if (!mounted) return;
    final gen = ++_loadGeneration;
    setState(() { isLoadingTasks = true; errorMessage = null; });
    try {
      final tasks = await ApiService.fetchGeneralTasks();
      if (!mounted || gen != _loadGeneration) return;
      setState(() {
        allTasks = tasks;
        _applySearchToList(tasks);
        isLoadingTasks = false;
      });
    } catch (e) {
      if (!mounted || gen != _loadGeneration) return;
      setState(() { errorMessage = e.toString(); isLoadingTasks = false; });
    }
  }

  void _applySearchToList(List<GeneralTaskModel> tasks) {
    final q = _searchCtrl.text.trim().toLowerCase();
    filteredTasks = q.isEmpty
        ? List.of(tasks)
        : tasks.where((t) =>
            t.taskName.toLowerCase().contains(q) ||
            t.taskDescription.toLowerCase().contains(q) ||
            t.createdByName.toLowerCase().contains(q)).toList();
  }

  void _applySearch() {
    if (mounted) setState(() => _applySearchToList(allTasks));
  }

  bool get canCreateTask =>
      userRole.toLowerCase() == 'admin' ||
      userRole.toLowerCase() == 'teamleader';

  // ── Computed stats ────────────────────────────────────────────────────────

  int get _totalCount     => allTasks.length;
  int get _completedCount => allTasks.where((t) => t.isCompleted).length;
  int get _pendingCount   => allTasks.where((t) => !t.isCompleted).length;

  // ── Snackbar ──────────────────────────────────────────────────────────────

  void _snack(String msg,
      {Color bg = _D.green, Duration dur = const Duration(seconds: 3)}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
          bg == _D.red
              ? Icons.error_outline_rounded
              : Icons.check_circle_outline_rounded,
          color: Colors.white, size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
      ]),
      backgroundColor: bg, duration: dur,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
    ));
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _showCreateSheet() async {
    final ok = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskFormSheet(
        onSubmit: ({required taskName, required taskDescription, taskDeadline}) =>
            ApiService.createGeneralTask(
              taskName: taskName,
              taskDescription: taskDescription,
              taskDeadline: taskDeadline,
            ),
      ),
    );
    if (ok == true && mounted) {
      await _loadTasks();
      _snack('Task created successfully');
    }
  }

  Future<void> _showEditSheet(GeneralTaskModel task) async {
    final ok = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskFormSheet(
        existing: task,
        onSubmit: ({required taskName, required taskDescription, taskDeadline}) =>
            ApiService.updateGeneralTask(
              taskId: task.taskId,
              taskName: taskName,
              taskDescription: taskDescription,
              taskDeadline: taskDeadline,
            ),
      ),
    );
    if (ok == true && mounted) {
      await _loadTasks();
      _snack('Task updated successfully');
    }
  }

  Future<void> _showUploadSheet(GeneralTaskModel task) async {
    final ok = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UploadSheet(
        task: task,
        onUpload: ({
          required int    taskId,
          required File   file,
          required String fileName,
          required String uploadedDate,
        }) =>
            ApiService.uploadGeneralTaskFile(
              taskId:      taskId,
              file:        file,
              fileName:    fileName,
              uploadedDate: uploadedDate,
            ),
      ),
    );
    if (ok == true && mounted) {
      await _loadTasks();
      _snack('Document uploaded. Task marked as Completed!');
    }
  }

  Future<void> _showViewDocSheet(GeneralTaskModel task) async {
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ViewDocSheet(task: task),
    );
  }

  Future<void> _showAssignDialog(GeneralTaskModel task) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _AssignDialog(
        task: task,
        fetchUsers: ApiService.fetchAssignableUsers,
        onAssign: ({required taskId, required assignedTo, required assignedDate}) =>
            ApiService.assignGeneralTask(
              taskId: taskId,
              assignedTo: assignedTo,
              assignedDate: assignedDate,
            ),
      ),
    );
    if (ok == true && mounted) {
      await _loadTasks();
      _snack('Task assigned successfully');
    }
  }

  Future<void> _changeStatus(GeneralTaskModel task, String status) async {
    try {
      await ApiService.updateGeneralTaskStatus(
          taskId: task.taskId, status: status);
      await _loadTasks();
      _snack('Status updated successfully');
    } catch (e) {
      _snack(e.toString(), bg: _D.red);
    }
  }

  Future<void> _deleteTask(GeneralTaskModel task) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_D.r16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54, height: 54,
                decoration: BoxDecoration(
                    color: _D.redBg,
                    borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.delete_outline_rounded,
                    color: _D.red, size: 28),
              ),
              const SizedBox(height: 14),
              const Text('Delete Task',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700,
                      color: _D.textPri)),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to delete "${task.taskName}"? '
                'This cannot be undone.',
                textAlign: TextAlign.center, style: _D.body,
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _D.slate,
                      side: const BorderSide(color: _D.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_D.r10)),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                )),
                const SizedBox(width: 10),
                Expanded(child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: _D.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_D.r10)),
                    ),
                    child: const Text('Delete',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                )),
              ]),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.deleteGeneralTask(task.taskId);
      await _loadTasks();
      _snack('Task deleted');
    } catch (e) {
      _snack(e.toString(), bg: _D.red);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final hPad   = isWide ? 20.0 : 14.0;

    return Scaffold(
      backgroundColor: _D.bg,
      appBar: AppBar(
        backgroundColor: _D.surface,
        elevation: 0,
        surfaceTintColor: _D.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 19, color: _D.textPri),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('General Tasks',
            style: TextStyle(
                color: _D.textPri,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: -0.4)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _D.border),
        ),
        actions: [
          if (isLoadingTasks)
            const Center(child: Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _D.green)),
            ))
          else
            IconButton(
              onPressed: _loadTasks,
              icon: const Icon(Icons.refresh_rounded, color: _D.textSec),
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Top controls container ────────────────────────────────────
          Container(
            color: _D.surface,
            padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Create button
                if (!isLoadingRole && canCreateTask) ...[
                  SizedBox(
                    width: double.infinity, height: 48,
                    child: ElevatedButton(
                      onPressed: _showCreateSheet,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: _D.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(_D.r12)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded, size: 22),
                          SizedBox(width: 7),
                          Text('Create General Task',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  letterSpacing: 0.1)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // ── Stats cards row (NEW) ──────────────────────────────
                if (!isLoadingTasks && errorMessage == null) ...[
                  Row(
                    children: [
                      _StatCard(
                        label: 'All Tasks',
                        count: _totalCount,
                        fromColor: _D.statAllFrom,
                        toColor: _D.statAllTo,
                        icon: Icons.format_list_bulleted_rounded,
                      ),
                      const SizedBox(width: 10),
                      _StatCard(
                        label: 'Completed',
                        count: _completedCount,
                        fromColor: _D.statDoneFrom,
                        toColor: _D.statDoneTo,
                        icon: Icons.check_circle_outline_rounded,
                      ),
                      const SizedBox(width: 10),
                      _StatCard(
                        label: 'Pending',
                        count: _pendingCount,
                        fromColor: _D.statPendFrom,
                        toColor: _D.statPendTo,
                        icon: Icons.hourglass_bottom_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],

                // ── Search field ───────────────────────────────────────
                TextField(
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                  style: const TextStyle(fontSize: 14, color: _D.textPri),
                  decoration: InputDecoration(
                    hintText: 'Search tasks...',
                    hintStyle: _D.body.copyWith(fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: _D.textMuted, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded,
                                color: _D.textMuted, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              _searchFocus.unfocus();
                            },
                          )
                        : null,
                    filled: true, fillColor: _D.bg,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: _D.border, width: 1.5),
                      borderRadius: BorderRadius.circular(_D.r10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: _D.green, width: 1.8),
                      borderRadius: BorderRadius.circular(_D.r10),
                    ),
                  ),
                ),

                // Result count label
                if (!isLoadingTasks && errorMessage == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      filteredTasks.length == allTasks.length
                          ? '${allTasks.length} task${allTasks.length == 1 ? '' : 's'}'
                          : '${filteredTasks.length} of ${allTasks.length} tasks',
                      style: _D.caption,
                    ),
                  ),
              ],
            ),
          ),

          Container(height: 1, color: _D.border),

          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (isLoadingTasks) {
      return const Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _D.green, strokeWidth: 2.5),
          SizedBox(height: 14),
          Text('Loading tasks…', style: _D.body),
        ],
      ));
    }

    if (errorMessage != null) {
      return Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: _D.redBg,
                borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.wifi_off_rounded, size: 34, color: _D.red),
          ),
          const SizedBox(height: 14),
          const Text('Something went wrong',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _D.textPri)),
          const SizedBox(height: 6),
          Text(errorMessage!, textAlign: TextAlign.center,
              style: _D.body.copyWith(fontSize: 12)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadTasks,
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              elevation: 0, backgroundColor: _D.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_D.r10)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ));
    }

    if (filteredTasks.isEmpty) {
      return Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.task_alt_rounded, size: 38, color: _D.green),
          ),
          const SizedBox(height: 14),
          Text(allTasks.isEmpty ? 'No tasks yet' : 'No results found',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _D.textPri)),
          const SizedBox(height: 6),
          Text(
            allTasks.isEmpty
                ? 'Create your first task to get started'
                : 'Try a different search term',
            style: _D.body, textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          if (allTasks.isEmpty && canCreateTask)
            ElevatedButton.icon(
              onPressed: _showCreateSheet,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Create Task'),
              style: ElevatedButton.styleFrom(
                elevation: 0, backgroundColor: _D.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_D.r10)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: _loadTasks,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _D.green,
                side: const BorderSide(color: _D.green),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_D.r10)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
            ),
        ],
      ));
    }

    return RefreshIndicator(
      onRefresh: _loadTasks,
      color: _D.green,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 14),
        itemCount: filteredTasks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final task = filteredTasks[i];
          return _TaskCard(
            task:       task,
            status:     _StatusMeta.of(task),
            onEdit:     () => _showEditSheet(task),
            onAssign:   () => _showAssignDialog(task),
            onComplete: () => _changeStatus(task, 'completed'),
            onDelete:   () => _deleteTask(task),
            onUpload:   () => _showUploadSheet(task),
            onViewDoc:  () => _showViewDocSheet(task),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Task card — enhanced design
// ─────────────────────────────────────────────────────────────────────────────
class _TaskCard extends StatelessWidget {
  final GeneralTaskModel task;
  final _StatusMeta status;
  final VoidCallback onEdit, onAssign, onComplete, onDelete;
  final VoidCallback onUpload, onViewDoc;

  const _TaskCard({
    required this.task,
    required this.status,
    required this.onEdit,
    required this.onAssign,
    required this.onComplete,
    required this.onDelete,
    required this.onUpload,
    required this.onViewDoc,
  });

  String _fmtDeadline(String raw) {
    try {
      final p = raw.split('-');
      if (p.length == 3) {
        const mo = ['Jan','Feb','Mar','Apr','May','Jun',
            'Jul','Aug','Sep','Oct','Nov','Dec'];
        return '${p[2]} ${mo[int.parse(p[1]) - 1]} ${p[0]}';
      }
    } catch (_) {}
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final hasDoc = (task.filePath ?? '').isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: _D.surface,
        borderRadius: BorderRadius.circular(_D.r16),
        border: Border.all(color: _D.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Colour accent bar (thicker + rounded-only-top) ────────────
          Container(
            height: 5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  status.dot.withValues(alpha: 0.7),
                  status.dot,
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(_D.r16)),
            ),
          ),

          // ── Title row + status pill ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status dot indicator
                Padding(
                  padding: const EdgeInsets.only(top: 3, right: 8),
                  child: Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: status.dot,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: status.dot.withValues(alpha: 0.4),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(child: Text(task.taskName, style: _D.titleMd)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: status.bg,
                    borderRadius: BorderRadius.circular(_D.r99),
                    border: Border.all(
                        color: status.dot.withValues(alpha: 0.25),
                        width: 1),
                  ),
                  child: Text(status.label,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: status.fg,
                          letterSpacing: 0.2)),
                ),
              ],
            ),
          ),

          // ── Description ───────────────────────────────────────────────
          if (task.taskDescription.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 5, 16, 0),
              child: Text(task.taskDescription,
                  style: _D.body.copyWith(fontSize: 13),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ),

          // ── Meta chips ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
              spacing: 6, runSpacing: 6,
              children: [
                _chip(Icons.person_outline_rounded, task.createdByName),
                if ((task.taskDeadline ?? '').isNotEmpty)
                  _chip(
                    Icons.event_rounded,
                    _fmtDeadline(task.taskDeadline!),
                    textColor: task.isOverdue && !task.isCompleted
                        ? _D.redFg : null,
                    chipBg: task.isOverdue && !task.isCompleted
                        ? _D.redBg : null,
                    iconColor: task.isOverdue && !task.isCompleted
                        ? _D.red : null,
                  ),
                if (task.assignedUsersNames.isNotEmpty &&
                    task.assignedUsersNames != 'Not Assigned')
                  _chip(Icons.group_outlined, task.assignedUsersNames,
                      maxWidth: 150),
              ],
            ),
          ),

          // ── Completion badge ──────────────────────────────────────────
          if (hasDoc && (task.uploadedDate ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD1FAE5), Color(0xFFECFDF5)],
                  ),
                  borderRadius: BorderRadius.circular(_D.r8),
                  border: Border.all(
                      color: _D.green.withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 13, color: _D.greenFg),
                  const SizedBox(width: 5),
                  Text('Completed on ${task.uploadedDate}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _D.greenFg)),
                ]),
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(height: 1, color: _D.border),
          ),

          // ── Action area ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Wrap(
                    spacing: 6, runSpacing: 6,
                    children: [
                      if (task.canAssign)
                        _btn(
                          label: task.isAssigned ? 'Reassign' : 'Assign',
                          icon: Icons.person_add_alt_rounded,
                          bg: _D.blueBg, fg: _D.blueFg, onTap: onAssign,
                        ),
                      if (task.canEdit && !hasDoc)
                        _btn(
                          label: 'Edit',
                          icon: Icons.edit_rounded,
                          bg: _D.slateBg, fg: _D.slate, onTap: onEdit,
                        ),
                      if (!task.isCompleted && !hasDoc &&
                          !task.canUpload && task.canEdit)
                        _btn(
                          label: 'Complete',
                          icon: Icons.check_circle_outline_rounded,
                          bg: _D.greenBg, fg: _D.greenFg, onTap: onComplete,
                        ),
                    ],
                  )),
                  if (task.canDelete)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: GestureDetector(
                        onTap: onDelete,
                        child: Container(
                          height: 34, width: 34,
                          decoration: BoxDecoration(
                              color: _D.redBg,
                              borderRadius: BorderRadius.circular(_D.r8)),
                          child: const Icon(Icons.delete_outline_rounded,
                              size: 17, color: _D.redFg),
                        ),
                      ),
                    ),
                ]),

                if (task.canUpload || task.canViewDoc) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: [
                      if (task.canViewDoc)
                        _btn(
                          label: 'View',
                          icon: Icons.visibility_outlined,
                          bg: _D.indigoBg, fg: _D.indigo, onTap: onViewDoc,
                        ),
                      if (task.canUpload)
                        _btn(
                          label: hasDoc ? 'Reupload' : 'Upload',
                          icon: hasDoc
                              ? Icons.refresh_rounded
                              : Icons.upload_rounded,
                          bg: _D.purpleBg, fg: _D.purpleFg, onTap: onUpload,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label,
      {Color? iconColor, Color? textColor,
       Color? chipBg, double? maxWidth}) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: chipBg ?? _D.bg,
          borderRadius: BorderRadius.circular(_D.r6),
          border: Border.all(color: _D.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: iconColor ?? _D.textMuted),
          const SizedBox(width: 4),
          Flexible(child: Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w500,
                  color: textColor ?? _D.textSec),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }

  Widget _btn({
    required String label,
    required IconData icon,
    required Color bg, required Color fg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(_D.r8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

Widget _dragHandle() => Center(
  child: Container(
    width: 36, height: 4,
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
        color: const Color(0xFFDDE1E7),
        borderRadius: BorderRadius.circular(2)),
  ),
);

Widget _iconBox(IconData icon, Color bg, Color fg) => Container(
  width: 40, height: 40,
  decoration: BoxDecoration(
      color: bg, borderRadius: BorderRadius.circular(_D.r10)),
  child: Icon(icon, color: fg, size: 20),
);

Widget _closeBtn(VoidCallback? onTap) => GestureDetector(
  onTap: onTap,
  child: Container(
    width: 32, height: 32,
    decoration: BoxDecoration(
        color: _D.slateBg,
        borderRadius: BorderRadius.circular(_D.r8)),
    child: const Icon(Icons.close_rounded, size: 17, color: _D.slate),
  ),
);

Widget _calendarIcon(Color bg, Color fg) => Container(
  margin: const EdgeInsets.all(8),
  padding: const EdgeInsets.all(7),
  decoration: BoxDecoration(
      color: bg, borderRadius: BorderRadius.circular(_D.r8)),
  child: Icon(Icons.calendar_month_rounded, size: 16, color: fg),
);

SizedBox _spinner({double size = 20}) => SizedBox(
  width: size, height: size,
  child: CircularProgressIndicator(
      strokeWidth: size < 20 ? 2 : 2.5, color: Colors.white),
);