// lib/features/approval_form/data/models/approval_form_model.dart

class ApprovalFormCreator {
  final int id;
  final String name;

  ApprovalFormCreator({required this.id, required this.name});

  factory ApprovalFormCreator.fromJson(Map<String, dynamic> json) {
    return ApprovalFormCreator(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }
}

class ApprovalFormModel {
  final int id;
  final int projectId;
  final String formNo;
  final String? contractor;
  final String? contractorSubmittalNumber;
  final String? tradePackage;
  final String? dateOfSubmission;
  final String? sampleMaterial;
  final String? sampleNo;
  final String? sampleSize;
  final String? areaOfUsage;
  final String? modelNumber;
  final String? make;
  final String? colour;
  final String? finish;
  final String? thickness;
  final String? otherSpecs;
  final String? comments;
  final String approvalStatus; // 'approved', 'not_approved', 'pending'
  final String? consultantComments;
  final String? consultantSignatureDate;
  final int? createdBy;
  final ApprovalFormCreator? creator;
  final String? createdAt;
  final String? updatedAt;

  ApprovalFormModel({
    required this.id,
    required this.projectId,
    required this.formNo,
    this.contractor,
    this.contractorSubmittalNumber,
    this.tradePackage,
    this.dateOfSubmission,
    this.sampleMaterial,
    this.sampleNo,
    this.sampleSize,
    this.areaOfUsage,
    this.modelNumber,
    this.make,
    this.colour,
    this.finish,
    this.thickness,
    this.otherSpecs,
    this.comments,
    this.approvalStatus = 'pending',
    this.consultantComments,
    this.consultantSignatureDate,
    this.createdBy,
    this.creator,
    this.createdAt,
    this.updatedAt,
  });

  factory ApprovalFormModel.fromJson(Map<String, dynamic> json) {
    return ApprovalFormModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      projectId: int.tryParse(json['project_id']?.toString() ?? '0') ?? 0,
      formNo: json['form_no']?.toString() ?? '',
      contractor: json['contractor']?.toString(),
      contractorSubmittalNumber:
          json['contractor_submittal_number']?.toString(),
      tradePackage: json['trade_package']?.toString(),
      dateOfSubmission: json['date_of_submission']?.toString(),
      sampleMaterial: json['sample_material']?.toString(),
      sampleNo: json['sample_no']?.toString(),
      sampleSize: json['sample_size']?.toString(),
      areaOfUsage: json['area_of_usage']?.toString(),
      modelNumber: json['model_number']?.toString(),
      make: json['make']?.toString(),
      colour: json['colour']?.toString(),
      finish: json['finish']?.toString(),
      thickness: json['thickness']?.toString(),
      otherSpecs: json['other_specs']?.toString(),
      comments: json['comments']?.toString(),
      approvalStatus: json['approval_status']?.toString() ?? 'pending',
      consultantComments: json['consultant_comments']?.toString(),
      consultantSignatureDate: json['consultant_signature_date']?.toString(),
      createdBy: int.tryParse(json['created_by']?.toString() ?? ''),
      creator: json['creator'] is Map<String, dynamic>
          ? ApprovalFormCreator.fromJson(
              json['creator'] as Map<String, dynamic>)
          : null,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'project_id': projectId,
        'form_no': formNo,
        'contractor': contractor,
        'contractor_submittal_number': contractorSubmittalNumber,
        'trade_package': tradePackage,
        'date_of_submission': dateOfSubmission,
        'sample_material': sampleMaterial,
        'sample_no': sampleNo,
        'sample_size': sampleSize,
        'area_of_usage': areaOfUsage,
        'model_number': modelNumber,
        'make': make,
        'colour': colour,
        'finish': finish,
        'thickness': thickness,
        'other_specs': otherSpecs,
        'comments': comments,
        'approval_status': approvalStatus,
        'consultant_comments': consultantComments,
        'consultant_signature_date': consultantSignatureDate,
        'created_by': createdBy,
      };
}