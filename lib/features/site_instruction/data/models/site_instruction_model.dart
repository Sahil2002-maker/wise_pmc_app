// lib/features/site_instruction/data/models/site_instruction_model.dart

class SiteInstructionModel {
  final int id;
  final int projectId;
  final String instructionNo;
  final String? projectName;
  final String? projectNumber;
  final String? issuedBy;
  final String? issuedTo;
  final String? reference;
  final String date;
  final String? instructions;
  final String? actionTaken;
  final String? contractorAcceptanceDate;
  final String? authorityAcceptanceDate;
  final int? createdBy;
  final SiteInstructionCreator? creator;

  const SiteInstructionModel({
    required this.id,
    required this.projectId,
    required this.instructionNo,
    this.projectName,
    this.projectNumber,
    this.issuedBy,
    this.issuedTo,
    this.reference,
    required this.date,
    this.instructions,
    this.actionTaken,
    this.contractorAcceptanceDate,
    this.authorityAcceptanceDate,
    this.createdBy,
    this.creator,
  });

  factory SiteInstructionModel.fromJson(Map<String, dynamic> json) {
    return SiteInstructionModel(
      id: _parseInt(json['id']),
      projectId: _parseInt(json['project_id']),
      instructionNo: json['instruction_no']?.toString() ?? '',
      projectName: json['project_name']?.toString(),
      projectNumber: json['project_number']?.toString(),
      issuedBy: json['issued_by']?.toString(),
      issuedTo: json['issued_to']?.toString(),
      reference: json['reference']?.toString(),
      date: json['date']?.toString() ?? '',
      instructions: json['instructions']?.toString(),
      actionTaken: json['action_taken']?.toString(),
      contractorAcceptanceDate:
          json['contractor_acceptance_date']?.toString(),
      authorityAcceptanceDate:
          json['authority_acceptance_date']?.toString(),
      createdBy: json['created_by'] != null
          ? _parseInt(json['created_by'])
          : null,
      creator: json['creator'] != null && json['creator'] is Map
          ? SiteInstructionCreator.fromJson(
              Map<String, dynamic>.from(json['creator'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'project_id': projectId,
        'instruction_no': instructionNo,
        'project_name': projectName,
        'project_number': projectNumber,
        'issued_by': issuedBy,
        'issued_to': issuedTo,
        'reference': reference,
        'date': date,
        'instructions': instructions,
        'action_taken': actionTaken,
        'contractor_acceptance_date': contractorAcceptanceDate,
        'authority_acceptance_date': authorityAcceptanceDate,
        'created_by': createdBy,
      };

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }
}

class SiteInstructionCreator {
  final int id;
  final String name;
  final String? email;

  const SiteInstructionCreator({
    required this.id,
    required this.name,
    this.email,
  });

  factory SiteInstructionCreator.fromJson(Map<String, dynamic> json) {
    return SiteInstructionCreator(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString(),
    );
  }
}