// lib/features/project_list/presentation/pages/add_project_page.dart

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/utils/api_exception.dart';

class AddProjectPage extends StatefulWidget {
  final String initialProjectType;
  final int? projectId;
  final bool isEditMode;

  const AddProjectPage({
    super.key,
    required this.initialProjectType,
    this.projectId,
    this.isEditMode = false,
  });

  @override
  State<AddProjectPage> createState() => _AddProjectPageState();
}

class _AddProjectPageState extends State<AddProjectPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool isInitialLoading = false;
  late String projectType;
  String ownershipType = 'leasehold';
  String existingInfo = 'regular';

  final societyNameController = TextEditingController();
  final contactNoController = TextEditingController();
  final societyEmailController = TextEditingController();
  final addressController = TextEditingController();
  final chairmanNameController = TextEditingController();
  final chairmanEmailController = TextEditingController();
  final chairmanNoController = TextEditingController();
  final secretaryNameController = TextEditingController();
  final secretaryEmailController = TextEditingController();
  final secretaryNoController = TextEditingController();
  final treasurerNameController = TextEditingController();
  final treasurerEmailController = TextEditingController();
  final treasurerNoController = TextEditingController();
  final plotAreaController = TextEditingController();
  final surveyNoController = TextEditingController();
  final ownerNameController = TextEditingController();
  final deductionController = TextEditingController();
  final deductionCommentController = TextEditingController();
  final locationController = TextEditingController();
  final locationLinkController = TextEditingController();
  final fsiAvailableController = TextEditingController();
  final fsiCommentController = TextEditingController();
  final totalMembersController = TextEditingController();

  List<PlatformFile> ownershipDocuments = [];
  List<PlatformFile> surveyDrawings = [];
  List<PlatformFile> titleSurveys = [];

  List<Map<String, dynamic>> unitTypes = [
    {'type': '', 'number_of_units': '', 'carpet_area': ''},
  ];

  @override
  void initState() {
    super.initState();
    projectType = widget.initialProjectType;
    if (projectType == 'redevelopment') existingInfo = 'redevelopment';
    if (widget.isEditMode && widget.projectId != null) {
      _loadProjectForEdit();
    }
  }

  @override
  void dispose() {
    societyNameController.dispose();
    contactNoController.dispose();
    societyEmailController.dispose();
    addressController.dispose();
    chairmanNameController.dispose();
    chairmanEmailController.dispose();
    chairmanNoController.dispose();
    secretaryNameController.dispose();
    secretaryEmailController.dispose();
    secretaryNoController.dispose();
    treasurerNameController.dispose();
    treasurerEmailController.dispose();
    treasurerNoController.dispose();
    plotAreaController.dispose();
    surveyNoController.dispose();
    ownerNameController.dispose();
    deductionController.dispose();
    deductionCommentController.dispose();
    locationController.dispose();
    locationLinkController.dispose();
    fsiAvailableController.dispose();
    fsiCommentController.dispose();
    totalMembersController.dispose();
    super.dispose();
  }

  Future<void> _loadProjectForEdit() async {
    setState(() => isInitialLoading = true);
    try {
      final data = await ApiService.fetchProjectForEdit(widget.projectId!);
      societyNameController.text = data['society_name']?.toString() ?? '';
      contactNoController.text = data['contact_no']?.toString() ?? '';
      societyEmailController.text = data['society_email']?.toString() ?? '';
      addressController.text = data['address']?.toString() ?? '';
      chairmanNameController.text = data['chairman_name']?.toString() ?? '';
      chairmanEmailController.text = data['chairman_email']?.toString() ?? '';
      chairmanNoController.text = data['chairman_no']?.toString() ?? '';
      secretaryNameController.text = data['secretary_name']?.toString() ?? '';
      secretaryEmailController.text = data['secretary_email']?.toString() ?? '';
      secretaryNoController.text = data['secretary_no']?.toString() ?? '';
      treasurerNameController.text = data['treasurer_name']?.toString() ?? '';
      treasurerEmailController.text = data['treasurer_email']?.toString() ?? '';
      treasurerNoController.text = data['treasurer_no']?.toString() ?? '';

      final info = data['project_info'] is Map
          ? Map<String, dynamic>.from(data['project_info'] as Map)
          : <String, dynamic>{};

      plotAreaController.text = info['plot_area']?.toString() ?? '';
      surveyNoController.text = info['survey_no']?.toString() ?? '';
      ownerNameController.text = info['owner_name']?.toString() ?? '';
      deductionController.text = info['deduction']?.toString() ?? '';
      deductionCommentController.text = info['deduction_comment']?.toString() ?? '';
      locationController.text = info['location']?.toString() ?? '';
      locationLinkController.text = info['location_link']?.toString() ?? '';
      fsiAvailableController.text = info['fsi_available']?.toString() ?? '';
      fsiCommentController.text = info['fsi_comment']?.toString() ?? '';
      totalMembersController.text = info['total_members']?.toString() ?? '';
      ownershipType = info['ownership_type']?.toString() == 'freehold' ? 'freehold' : 'leasehold';
      existingInfo = info['existing_info']?.toString() == 'redevelopment'
          ? 'redevelopment'
          : (projectType == 'redevelopment' ? 'redevelopment' : 'regular');

      if (info['unit_types'] is List && (info['unit_types'] as List).isNotEmpty) {
        unitTypes = (info['unit_types'] as List)
            .map((e) => {
                  'id': e['id']?.toString() ?? '',
                  'type': e['type']?.toString() ?? '',
                  'number_of_units': e['number_of_units']?.toString() ?? '',
                  'carpet_area': e['carpet_area']?.toString() ?? '',
                })
            .toList();
      }

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFEF4444),
          content: Text(msg, style: const TextStyle(color: Colors.white)),
        ),
      );
    } finally {
      if (mounted) setState(() => isInitialLoading = false);
    }
  }

  String? requiredValidator(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  String? optionalEmailValidator(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
      return 'Enter a valid email';
    }
    return null;
  }

  String? optionalMobileValidator(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (!RegExp(r'^[5-9][0-9]{9}$').hasMatch(value.trim())) {
      return 'Mobile must start with 5-9 and be 10 digits';
    }
    return null;
  }

  String? optionalUrlValidator(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final uri = Uri.tryParse(value.trim());
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return 'Enter a valid URL';
    }
    return null;
  }

  Future<void> pickFiles(String type) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
    );
    if (result == null) return;
    setState(() {
      if (type == 'ownership') ownershipDocuments = [...ownershipDocuments, ...result.files];
      else if (type == 'survey') surveyDrawings = [...surveyDrawings, ...result.files];
      else if (type == 'title') titleSurveys = [...titleSurveys, ...result.files];
    });
  }

  void removePickedFile(String type, int index) {
    setState(() {
      if (type == 'ownership') ownershipDocuments.removeAt(index);
      else if (type == 'survey') surveyDrawings.removeAt(index);
      else if (type == 'title') titleSurveys.removeAt(index);
    });
  }

  void addUnitTypeRow() {
    setState(() {
      unitTypes.add({'type': '', 'number_of_units': '', 'carpet_area': ''});
    });
  }

  void removeUnitTypeRow(int index) {
    if (unitTypes.length == 1) {
      setState(() {
        unitTypes[0] = {'type': '', 'number_of_units': '', 'carpet_area': ''};
      });
      return;
    }
    setState(() => unitTypes.removeAt(index));
  }

  Future<void> openMapsLink() async {
    final link = locationLinkController.text.trim();
    if (link.isEmpty) return;
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> submitAll() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    _isSubmitting = true;
    if (mounted) setState(() {});
    FocusScope.of(context).unfocus();

    try {
      final Map<String, dynamic> projectResult;

      if (widget.isEditMode && widget.projectId != null) {
        projectResult = await ApiService.updateProject(
          projectId: widget.projectId!,
          projectType: projectType,
          societyName: societyNameController.text,
          address: addressController.text,
          contactNo: contactNoController.text,
          societyEmail: societyEmailController.text,
          chairmanName: chairmanNameController.text,
          chairmanEmail: chairmanEmailController.text,
          chairmanNo: chairmanNoController.text,
          secretaryName: secretaryNameController.text,
          secretaryEmail: secretaryEmailController.text,
          secretaryNo: secretaryNoController.text,
          treasurerName: treasurerNameController.text,
          treasurerEmail: treasurerEmailController.text,
          treasurerNo: treasurerNoController.text,
        );
      } else {
        projectResult = await ApiService.createProject(
          projectType: projectType,
          societyName: societyNameController.text,
          address: addressController.text,
          contactNo: contactNoController.text,
          societyEmail: societyEmailController.text,
          chairmanName: chairmanNameController.text,
          chairmanEmail: chairmanEmailController.text,
          chairmanNo: chairmanNoController.text,
          secretaryName: secretaryNameController.text,
          secretaryEmail: secretaryEmailController.text,
          secretaryNo: secretaryNoController.text,
          treasurerName: treasurerNameController.text,
          treasurerEmail: treasurerEmailController.text,
          treasurerNo: treasurerNoController.text,
        );
      }

      final int projectId = _resolveProjectId(projectResult);

      final cleanedUnitTypes = unitTypes
          .where((e) => (e['type']?.toString().trim() ?? '').isNotEmpty)
          .map((e) => {
                if ((e['id']?.toString() ?? '').isNotEmpty) 'id': e['id'].toString(),
                'type': e['type']?.toString().trim(),
                'number_of_units': int.tryParse(e['number_of_units']?.toString() ?? '') ?? 0,
                'carpet_area': double.tryParse(e['carpet_area']?.toString() ?? '') ?? 0.0,
              })
          .toList();

      final infoMessage = await ApiService.createProjectInfo(
        projectId: projectId,
        ownershipType: ownershipType,
        existingInfo: existingInfo,
        plotArea: plotAreaController.text,
        surveyNo: surveyNoController.text,
        ownerName: ownerNameController.text,
        deduction: deductionController.text,
        deductionComment: deductionCommentController.text,
        location: locationController.text,
        locationLink: locationLinkController.text,
        fsiAvailable: fsiAvailableController.text,
        fsiComment: fsiCommentController.text,
        totalMembers: totalMembersController.text,
        unitTypes: cleanedUnitTypes,
        ownershipDocuments: ownershipDocuments,
        surveyDrawings: surveyDrawings,
        titleSurveys: titleSurveys,
      );

      if (!mounted) return;

      final bool emailNotified = projectResult['emailNotified'] == true;
      String successMessage = infoMessage;
      if (!widget.isEditMode && emailNotified) {
        successMessage += '\nTeam leaders have been notified by email.';
      } else if (!widget.isEditMode && !emailNotified) {
        successMessage += '\n(Email notifications could not be sent.)';
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          backgroundColor: const Color(0xFF22C55E),
          duration: const Duration(seconds: 4),
          content: Text(successMessage,
              style: const TextStyle(color: Colors.white)),
        ));

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : e.toString();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          backgroundColor: const Color(0xFFEF4444),
          content: Text(message, style: const TextStyle(color: Colors.white)),
        ));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      } else {
        _isSubmitting = false;
      }
    }
  }

  int _resolveProjectId(Map<String, dynamic> result) {
    final raw = result['projectId'];
    if (raw != null) {
      final id = int.tryParse(raw.toString());
      if (id != null && id > 0) return id;
    }
    if (widget.isEditMode && widget.projectId != null) return widget.projectId!;
    throw ApiException(
      'Project saved but the server did not return a Project ID.',
    );
  }

  // ── UI Helpers ────────────────────────────────────────────────────────────

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color accentColor,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                bottom: BorderSide(color: accentColor.withOpacity(0.15)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accentColor, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 7),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            validator: validator,
            style: const TextStyle(
                fontSize: 14, color: Color(0xFF111827)),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                  color: Color(0xFFD1D5DB), fontSize: 14),
              suffixIcon: suffix,
              filled: true,
              fillColor: const Color(0xFFFAFAFC),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(
                    color: AppColors.primaryGreen, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(color: Color(0xFFEF4444)),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(
                    color: Color(0xFFEF4444), width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _radioRow({
    required String label,
    required List<Map<String, String>> options,
    required String groupValue,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151))),
          const SizedBox(height: 8),
          Row(
            children: options.map((option) {
              final isSelected = groupValue == option['value'];
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(option['value']!),
                  child: Container(
                    margin: EdgeInsets.only(
                        right: option == options.last ? 0 : 10),
                    padding: const EdgeInsets.symmetric(
                        vertical: 11, horizontal: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryGreen.withOpacity(0.08)
                          : const Color(0xFFFAFAFC),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryGreen
                            : const Color(0xFFE5E7EB),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryGreen
                                  : const Color(0xFFD1D5DB),
                              width: 2,
                            ),
                            color: isSelected
                                ? AppColors.primaryGreen
                                : Colors.transparent,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  size: 10, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          option['label']!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? AppColors.primaryGreen
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _fileUploadSection({
    required String title,
    required IconData icon,
    required List<PlatformFile> files,
    required VoidCallback onPick,
    required void Function(int) onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151))),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onPick,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  style: BorderStyle.solid),
            ),
            child: Column(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon,
                      color: const Color(0xFF3B82F6), size: 20),
                ),
                const SizedBox(height: 8),
                const Text('Tap to choose files',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3B82F6))),
                const SizedBox(height: 2),
                const Text('PDF, DOC, JPG, PNG supported',
                    style: TextStyle(
                        fontSize: 11, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
        ),
        if (files.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...List.generate(
            files.length,
            (index) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file_outlined,
                      size: 16, color: Color(0xFF22C55E)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(files[index].name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF166534),
                            fontWeight: FontWeight.w500)),
                  ),
                  GestureDetector(
                    onTap: () => onRemove(index),
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildUnitTypeCard(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Column(
        children: [
          // Card header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text('${index + 1}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 10),
                const Text('Unit Type',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151))),
                const Spacer(),
                GestureDetector(
                  onTap: () => removeUnitTypeRow(index),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: Color(0xFFEF4444), size: 15),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                TextFormField(
                  initialValue: unitTypes[index]['type']?.toString() ?? '',
                  onChanged: (v) => unitTypes[index]['type'] = v,
                  style: const TextStyle(fontSize: 14),
                  decoration: _inputDecoration('Type (e.g. 1BHK, 2BHK)'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue:
                            unitTypes[index]['number_of_units']?.toString() ??
                                '',
                        keyboardType: TextInputType.number,
                        onChanged: (v) =>
                            unitTypes[index]['number_of_units'] = v,
                        style: const TextStyle(fontSize: 14),
                        decoration: _inputDecoration('No. of Units'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        initialValue:
                            unitTypes[index]['carpet_area']?.toString() ?? '',
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (v) => unitTypes[index]['carpet_area'] = v,
                        style: const TextStyle(fontSize: 14),
                        decoration: _inputDecoration('Carpet Area (sq.m)'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRedevelopment = projectType == 'redevelopment';
    final showTotalMembers = existingInfo == 'redevelopment';
    final title = widget.isEditMode
        ? 'Edit Project'
        : (projectType == 'development'
            ? 'Add Development Project'
            : 'Add Redevelopment Project');

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            Text(
              isRedevelopment ? 'Redevelopment Project' : 'Development Project',
              style: TextStyle(
                  fontSize: 12,
                  color: isRedevelopment
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF8B5CF6),
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Color(0xFF374151)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF1F5F9)),
        ),
      ),
      body: isInitialLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    // ── Email Banner ─────────────────────────────────────
                    if (!widget.isEditMode)
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF22C55E).withOpacity(0.08),
                              const Color(0xFF16A34A).withOpacity(0.04),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF22C55E).withOpacity(0.25)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: const Icon(Icons.mark_email_read_rounded,
                                  size: 18, color: Color(0xFF16A34A)),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Team leaders will be automatically notified by email when this project is created.',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF166534),
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ── Society Details ──────────────────────────────────
                    _buildSectionCard(
                      title: 'Society Details',
                      icon: Icons.apartment_rounded,
                      accentColor: const Color(0xFF3B82F6),
                      child: Column(
                        children: [
                          _textField(
                            controller: societyNameController,
                            label: 'Society Name *',
                            hint: 'Enter society name',
                            validator: (v) =>
                                requiredValidator(v, 'Society Name'),
                          ),
                          _textField(
                            controller: contactNoController,
                            label: 'Contact Number',
                            hint: '10-digit mobile number',
                            keyboardType: TextInputType.phone,
                            validator: optionalMobileValidator,
                          ),
                          _textField(
                            controller: societyEmailController,
                            label: 'Email Address',
                            hint: 'society@example.com',
                            keyboardType: TextInputType.emailAddress,
                            validator: optionalEmailValidator,
                          ),
                          _textField(
                            controller: addressController,
                            label: 'Address *',
                            hint: 'Full address',
                            maxLines: 3,
                            validator: (v) => requiredValidator(v, 'Address'),
                          ),
                        ],
                      ),
                    ),

                    // ── Redevelopment Roles ──────────────────────────────
                    if (isRedevelopment) ...[
                      _buildSectionCard(
                        title: 'Chairman Details',
                        icon: Icons.person_rounded,
                        accentColor: const Color(0xFF8B5CF6),
                        child: Column(children: [
                          _textField(
                              controller: chairmanNameController,
                              label: 'Chairman Name'),
                          _textField(
                            controller: chairmanEmailController,
                            label: 'Chairman Email',
                            keyboardType: TextInputType.emailAddress,
                            validator: optionalEmailValidator,
                          ),
                          _textField(
                            controller: chairmanNoController,
                            label: 'Chairman Contact No',
                            keyboardType: TextInputType.phone,
                            validator: optionalMobileValidator,
                          ),
                        ]),
                      ),
                      _buildSectionCard(
                        title: 'Secretary Details',
                        icon: Icons.manage_accounts_rounded,
                        accentColor: const Color(0xFF06B6D4),
                        child: Column(children: [
                          _textField(
                              controller: secretaryNameController,
                              label: 'Secretary Name'),
                          _textField(
                            controller: secretaryEmailController,
                            label: 'Secretary Email',
                            keyboardType: TextInputType.emailAddress,
                            validator: optionalEmailValidator,
                          ),
                          _textField(
                            controller: secretaryNoController,
                            label: 'Secretary Contact No',
                            keyboardType: TextInputType.phone,
                            validator: optionalMobileValidator,
                          ),
                        ]),
                      ),
                      _buildSectionCard(
                        title: 'Treasurer Details',
                        icon: Icons.account_balance_wallet_rounded,
                        accentColor: const Color(0xFFF59E0B),
                        child: Column(children: [
                          _textField(
                              controller: treasurerNameController,
                              label: 'Treasurer Name'),
                          _textField(
                            controller: treasurerEmailController,
                            label: 'Treasurer Email',
                            keyboardType: TextInputType.emailAddress,
                            validator: optionalEmailValidator,
                          ),
                          _textField(
                            controller: treasurerNoController,
                            label: 'Treasurer Contact No',
                            keyboardType: TextInputType.phone,
                            validator: optionalMobileValidator,
                          ),
                        ]),
                      ),
                    ],

                    // ── Property Details ─────────────────────────────────
                    _buildSectionCard(
                      title: 'Property Details',
                      icon: Icons.home_work_rounded,
                      accentColor: const Color(0xFF10B981),
                      child: Column(children: [
                        _textField(
                          controller: plotAreaController,
                          label: 'Plot Area (sq. meters)',
                          hint: 'e.g. 1200.50',
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                        _textField(
                          controller: surveyNoController,
                          label: 'Survey Number',
                          hint: 'Survey / CTS No.',
                        ),
                        _textField(
                          controller: ownerNameController,
                          label: 'Owner Name',
                          hint: 'Land owner name',
                        ),
                        _radioRow(
                          label: 'Ownership Type',
                          options: const [
                            {'value': 'leasehold', 'label': 'Leasehold'},
                            {'value': 'freehold', 'label': 'Freehold'},
                          ],
                          groupValue: ownershipType,
                          onChanged: (v) => setState(() => ownershipType = v),
                        ),
                        _textField(
                          controller: deductionController,
                          label: 'Deduction (sq. meters)',
                          hint: 'e.g. 50.00',
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                        _textField(
                          controller: deductionCommentController,
                          label: 'Deduction Comment',
                          hint: 'Reason for deduction',
                          maxLines: 2,
                        ),
                      ]),
                    ),

                    // ── Location Details ─────────────────────────────────
                    _buildSectionCard(
                      title: 'Location Details',
                      icon: Icons.location_on_rounded,
                      accentColor: const Color(0xFFEF4444),
                      child: Column(children: [
                        _textField(
                          controller: locationController,
                          label: 'Location',
                          hint: 'Area, city or landmark',
                        ),
                        _textField(
                          controller: locationLinkController,
                          label: 'Google Maps Link',
                          hint: 'https://maps.google.com/...',
                          keyboardType: TextInputType.url,
                          validator: optionalUrlValidator,
                          suffix: IconButton(
                            icon: const Icon(Icons.open_in_new_rounded,
                                size: 18, color: Color(0xFF6B7280)),
                            onPressed: openMapsLink,
                          ),
                        ),
                      ]),
                    ),

                    // ── Documents ────────────────────────────────────────
                    _buildSectionCard(
                      title: 'Documents',
                      icon: Icons.folder_open_rounded,
                      accentColor: const Color(0xFF6366F1),
                      child: Column(
                        children: [
                          _fileUploadSection(
                            title: 'Ownership Documents',
                            icon: Icons.description_rounded,
                            files: ownershipDocuments,
                            onPick: () => pickFiles('ownership'),
                            onRemove: (i) => removePickedFile('ownership', i),
                          ),
                          const SizedBox(height: 16),
                          _fileUploadSection(
                            title: 'Survey Drawings',
                            icon: Icons.architecture_rounded,
                            files: surveyDrawings,
                            onPick: () => pickFiles('survey'),
                            onRemove: (i) => removePickedFile('survey', i),
                          ),
                          const SizedBox(height: 16),
                          _fileUploadSection(
                            title: 'Title Surveys',
                            icon: Icons.article_rounded,
                            files: titleSurveys,
                            onPick: () => pickFiles('title'),
                            onRemove: (i) => removePickedFile('title', i),
                          ),
                        ],
                      ),
                    ),

                    // ── FSI Details ──────────────────────────────────────
                    _buildSectionCard(
                      title: 'FSI Details',
                      icon: Icons.layers_rounded,
                      accentColor: const Color(0xFF0EA5E9),
                      child: Column(children: [
                        _textField(
                          controller: fsiAvailableController,
                          label: 'FSI Available',
                          hint: 'e.g. 2.50',
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                        _textField(
                          controller: fsiCommentController,
                          label: 'FSI Comment',
                          hint: 'Additional notes on FSI',
                          maxLines: 2,
                        ),
                      ]),
                    ),

                    // ── Existing Information ─────────────────────────────
                    _buildSectionCard(
                      title: 'Existing Information',
                      icon: Icons.info_outline_rounded,
                      accentColor: const Color(0xFFF97316),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _radioRow(
                            label: 'Existing Info Type',
                            options: const [
                              {'value': 'regular', 'label': 'Regular'},
                              {
                                'value': 'redevelopment',
                                'label': 'Redevelopment'
                              },
                            ],
                            groupValue: existingInfo,
                            onChanged: (v) =>
                                setState(() => existingInfo = v),
                          ),
                          if (showTotalMembers)
                            _textField(
                              controller: totalMembersController,
                              label: 'Total Members',
                              hint: 'Number of members',
                              keyboardType: TextInputType.number,
                            ),
                        ],
                      ),
                    ),

                    // ── Unit Types ───────────────────────────────────────
                    _buildSectionCard(
                      title: 'Unit Types',
                      icon: Icons.grid_view_rounded,
                      accentColor: const Color(0xFF8B5CF6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...List.generate(
                              unitTypes.length, _buildUnitTypeCard),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: addUnitTypeRow,
                              icon: const Icon(Icons.add_circle_rounded,
                                  size: 16),
                              label: const Text('Add Another Unit Type'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryGreen,
                                side: const BorderSide(
                                    color: AppColors.primaryGreen,
                                    width: 1.5),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(11)),
                                textStyle: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

      // ── Floating Submit Button ───────────────────────────────────────────
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : submitAll,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  AppColors.primaryGreen.withOpacity(0.5),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.isEditMode
                            ? Icons.save_rounded
                            : Icons.check_circle_rounded,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.isEditMode
                            ? 'Update Project'
                            : 'Create Project',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}