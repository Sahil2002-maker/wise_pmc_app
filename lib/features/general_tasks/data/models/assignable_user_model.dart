class AssignableUserModel {
  final int id;
  final String name;
  final String email;

  const AssignableUserModel({
    required this.id,
    required this.name,
    required this.email,
  });

  factory AssignableUserModel.fromJson(Map<String, dynamic> json) {
    return AssignableUserModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
    );
  }
}