// lib/features/project_list/presentation/pages/add_project_info_page.dart

import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/utils/api_exception.dart';

class AddProjectInfoPage extends StatefulWidget {
  final int projectId;
  final String projectType;

  const AddProjectInfoPage({
    super.key,
    required this.projectId,
    required this.projectType,
  });

  @override
  State<AddProjectInfoPage> createState() => _AddProjectInfoPageState();
}

class _AddProjectInfoPageState extends State<AddProjectInfoPage> {
  final _formKey = GlobalKey<FormState>();

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

  String ownershipType = 'leasehold';
  String existingInfo = 'regular';
  bool _isSubmitting = false;

  List<Map<String, dynamic>> unitTypes = [
    {'type': '', 'number_of_units': '', 'carpet_area': ''},
  ];

  @override
  void dispose() {
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

  String? optionalUrlValidator(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final uri = Uri.tryParse(value.trim());
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return 'Enter a valid URL';
    }
    return null;
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

  Future<void> saveProjectInfo() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    _isSubmitting = true;
    if (mounted) setState(() {});

    try {
      final cleanedUnitTypes = unitTypes
          .where((e) => (e['type']?.toString().trim() ?? '').isNotEmpty)
          .map((e) => {
                'type': e['type']?.toString().trim(),
                'number_of_units':
                    int.tryParse(e['number_of_units']?.toString() ?? '') ?? 0,
                'carpet_area':
                    double.tryParse(e['carpet_area']?.toString() ?? '') ?? 0,
              })
          .toList();

      final message = await ApiService.createProjectInfo(
        projectId: widget.projectId,
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
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          backgroundColor: const Color(0xFF22C55E),
          duration: const Duration(seconds: 2),
          content: Text(message, style: const TextStyle(color: Colors.white)),
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

  // ── UI Helpers ─────────────────────────────────────────────────────────────

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
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                  bottom: BorderSide(color: accentColor.withOpacity(0.15))),
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
          const SizedBox(height: 7),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            validator: validator,
            style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  const TextStyle(color: Color(0xFFD1D5DB), fontSize: 14),
              filled: true,
              fillColor: const Color(0xFFFAFAFC),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 13),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(
                      color: AppColors.primaryGreen, width: 2)),
              errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(color: Color(0xFFEF4444))),
              focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(
                      color: Color(0xFFEF4444), width: 2)),
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
                        Flexible(
                          child: Text(
                            option['label']!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? AppColors.primaryGreen
                                  : const Color(0xFF6B7280),
                            ),
                            overflow: TextOverflow.ellipsis,
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
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                        initialValue: unitTypes[index]['number_of_units']
                                ?.toString() ??
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
                        onChanged: (v) =>
                            unitTypes[index]['carpet_area'] = v,
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
          borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide:
              const BorderSide(color: AppColors.primaryGreen, width: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showTotalMembers = existingInfo == 'redevelopment';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Project Information',
                style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            Text('Fill in the project details',
                style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w400)),
          ],
        ),
        iconTheme: const IconThemeData(color: Color(0xFF374151)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF1F5F9)),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              // ── Property Details ───────────────────────────────────────
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
                    label: 'Ownership Type *',
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

              // ── Location Details ───────────────────────────────────────
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
                  ),
                ]),
              ),

              // ── FSI Details ────────────────────────────────────────────
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

              // ── Existing Information ───────────────────────────────────
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
                        {'value': 'redevelopment', 'label': 'Redevelopment'},
                      ],
                      groupValue: existingInfo,
                      onChanged: (v) => setState(() => existingInfo = v),
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

              // ── Unit Types ─────────────────────────────────────────────
              _buildSectionCard(
                title: 'Unit Types',
                icon: Icons.grid_view_rounded,
                accentColor: const Color(0xFF8B5CF6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...List.generate(unitTypes.length, _buildUnitTypeCard),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: addUnitTypeRow,
                        icon: const Icon(Icons.add_circle_rounded, size: 16),
                        label: const Text('Add Another Unit Type'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryGreen,
                          side: const BorderSide(
                              color: AppColors.primaryGreen, width: 1.5),
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11)),
                          textStyle: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
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

      // ── Floating Save Button ─────────────────────────────────────────────
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
            onPressed: _isSubmitting ? null : saveProjectInfo,
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
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Save Project Information',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}