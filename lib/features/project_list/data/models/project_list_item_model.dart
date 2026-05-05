class ProjectListItemModel {
  final int id;
  final String societyName;
  final String projectType;
  final String status;
  final String createdAt;

  const ProjectListItemModel({
    required this.id,
    required this.societyName,
    required this.projectType,
    required this.status,
    required this.createdAt,
  });

  factory ProjectListItemModel.fromJson(Map<String, dynamic> json) {
    return ProjectListItemModel(
      id: _toInt(json['id']),
      societyName: json['society_name']?.toString() ?? '',
      projectType: json['project_type']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  bool get isRedevelopment => projectType.toLowerCase() == 'redevelopment';
  bool get isDevelopment => projectType.toLowerCase() == 'development';

  static int _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }
}