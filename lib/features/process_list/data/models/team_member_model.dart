// lib/features/process_list/data/models/team_member_model.dart

class TeamMemberModel {
  final int id;
  final String name;
  final String? email;
  final String role; // 'leader' or 'member'

  const TeamMemberModel({
    required this.id,
    required this.name,
    this.email,
    required this.role,
  });

  bool get isLeader => role == 'leader';

  factory TeamMemberModel.fromJson(Map<String, dynamic> json) {
    return TeamMemberModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString(),
      role: json['role']?.toString() ?? 'member',
    );
  }

  @override
  String toString() => name;
}