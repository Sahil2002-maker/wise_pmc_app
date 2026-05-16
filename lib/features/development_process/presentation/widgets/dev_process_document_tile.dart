// lib/features/development_process/presentation/widgets/dev_process_document_tile.dart
//
// Reusable widget shown inside the project-scoped Development Process view.
// It renders the current document state for one process assignment and lets
// the user:
//   • Upload a new document (file picker → S3 via the backend controller).
//   • View / open an already-uploaded document (pre-signed S3 URL).
//
// Usage:
//   DevProcessDocumentTile(
//     projectId:  widget.projectId,
//     processId:  process.processId,
//     orderNo:    process.orderNo,
//     assignment: assignment,          // DevProcessAssignmentModel? — may be null
//     onUploaded: (updatedAssignment) { … refresh state … },
//   )

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/dev_process_model.dart';
import '../../data/services/dev_process_upload_service.dart';
import '../../../../core/utils/api_exception.dart';

class DevProcessDocumentTile extends StatefulWidget {
  final int projectId;
  final int processId;
  final int orderNo;

  /// Current assignment for this process (may be null if not yet assigned).
  final DevProcessAssignmentModel? assignment;

  /// Called after a successful upload with the updated assignment data
  /// (includes the new document_path / document_name).
  final ValueChanged<DevProcessAssignmentModel>? onUploaded;

  const DevProcessDocumentTile({
    super.key,
    required this.projectId,
    required this.processId,
    required this.orderNo,
    this.assignment,
    this.onUploaded,
  });

  @override
  State<DevProcessDocumentTile> createState() =>
      _DevProcessDocumentTileState();
}

class _DevProcessDocumentTileState extends State<DevProcessDocumentTile> {
  bool    _uploading    = false;
  bool    _fetchingUrl  = false;
  String? _errorMessage;

  // ── Derived state ──────────────────────────────────────────────────────────

  bool get _hasDocument =>
      widget.assignment != null && widget.assignment!.hasDocument;

  String get _documentName =>
      widget.assignment?.documentName ??
      _baseName(widget.assignment?.documentPath ?? '') ??
      'Document';

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _pickAndUpload() async {
    setState(() {
      _uploading    = false;
      _errorMessage = null;
    });

    // 1. Open file picker
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf', 'doc', 'docx', 'xls', 'xlsx',
          'jpg', 'jpeg', 'png', 'txt',
        ],
        allowMultiple: false,
      );
    } catch (e) {
      _setError('Could not open file picker: $e');
      return;
    }

    if (result == null || result.files.isEmpty) return; // user cancelled
    final picked = result.files.first;

    if (picked.path == null) {
      _setError('Could not read the selected file. Please try again.');
      return;
    }

    // 2. Validate size (10 MB limit matches backend max:10240 KB)
    final file     = File(picked.path!);
    final fileSize = await file.length();
    if (fileSize > 10 * 1024 * 1024) {
      _setError('File is too large. Maximum allowed size is 10 MB.');
      return;
    }

    setState(() => _uploading = true);

    try {
      // 3. Upload to S3 via backend
      final response = await DevProcessUploadService.uploadDocument(
        projectId: widget.projectId,
        processId: widget.processId,
        orderNo:   widget.orderNo,
        file:      file,
        fileName:  picked.name,
      );

      // 4. Build updated assignment model from the response
      final updatedAssignment = (widget.assignment ?? const DevProcessAssignmentModel())
          .copyWith(
            processId:    widget.processId,
            orderNo:      widget.orderNo,
            documentPath: response['file_path']?.toString(),
            documentName: response['file_name']?.toString() ?? picked.name,
          );

      if (mounted) {
        setState(() => _uploading = false);
        widget.onUploaded?.call(updatedAssignment);
        _showSuccess('Document uploaded successfully.');
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        _setError(e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        _setError('Unexpected error: $e');
      }
    }
  }

  Future<void> _openDocument() async {
    final s3Path = widget.assignment?.documentPath;
    if (s3Path == null || s3Path.isEmpty) return;

    setState(() {
      _fetchingUrl  = true;
      _errorMessage = null;
    });

    try {
      final signedUrl = await DevProcessUploadService.getFileUrl(s3Path);
      final uri       = Uri.parse(signedUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _setError('Cannot open the file. Please try a different app.');
      }
    } on ApiException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('Could not open document: $e');
    } finally {
      if (mounted) setState(() => _fetchingUrl = false);
    }
  }

  void _setError(String msg) {
    if (!mounted) return;
    setState(() => _errorMessage = msg);
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ]),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Error banner ───────────────────────────────────────────────
        if (_errorMessage != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Color(0xFFEF4444), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                        color: Color(0xFFEF4444), fontSize: 12),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _errorMessage = null),
                  child: const Icon(Icons.close_rounded,
                      color: Color(0xFFEF4444), size: 16),
                ),
              ],
            ),
          ),

        // ── Main tile ──────────────────────────────────────────────────
        _hasDocument ? _buildDocumentRow() : _buildUploadButton(),
      ],
    );
  }

  // ── No document — show upload button ──────────────────────────────────────

  Widget _buildUploadButton() {
    return GestureDetector(
      onTap: _uploading ? null : _pickAndUpload,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F9FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFFBAE6FD),
            style: BorderStyle.solid,
          ),
        ),
        child: _uploading
            ? _buildProgressRow()
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.upload_file_rounded,
                      color: Color(0xFF0EA5E9), size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Upload Document',
                    style: TextStyle(
                      color: Color(0xFF0369A1),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(PDF, DOC, XLS, IMG)',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ── Has document — show file name + view + re-upload ─────────────────────

  Widget _buildDocumentRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Row(
        children: [
          // File icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.insert_drive_file_rounded,
                color: Color(0xFF16A34A), size: 20),
          ),
          const SizedBox(width: 10),

          // File name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _documentName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF15803D),
                  ),
                ),
                const Text(
                  'Tap to view',
                  style: TextStyle(
                      fontSize: 10, color: Color(0xFF4ADE80)),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // View button
          _fetchingUrl
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF16A34A)),
                )
              : IconButton(
                  icon: const Icon(Icons.open_in_new_rounded,
                      color: Color(0xFF16A34A), size: 20),
                  tooltip: 'Open document',
                  onPressed: _openDocument,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                      minWidth: 32, minHeight: 32),
                ),

          // Re-upload button
          _uploading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF0EA5E9)),
                )
              : IconButton(
                  icon: const Icon(Icons.upload_rounded,
                      color: Color(0xFF0EA5E9), size: 20),
                  tooltip: 'Replace document',
                  onPressed: _pickAndUpload,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                      minWidth: 32, minHeight: 32),
                ),
        ],
      ),
    );
  }

  Widget _buildProgressRow() {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Color(0xFF0EA5E9)),
        ),
        SizedBox(width: 10),
        Text(
          'Uploading…',
          style: TextStyle(
            color: Color(0xFF0369A1),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String? _baseName(String path) {
    if (path.isEmpty) return null;
    return path.split('/').last.split('\\').last;
  }
}