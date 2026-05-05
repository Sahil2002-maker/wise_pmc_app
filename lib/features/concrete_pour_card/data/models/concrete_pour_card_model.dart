// lib/features/concrete_pour_card/data/models/concrete_pour_card_model.dart

class ConcreteCreator {
  final int id;
  final String name;

  const ConcreteCreator({required this.id, required this.name});

  factory ConcreteCreator.fromJson(Map<String, dynamic> json) =>
      ConcreteCreator(
        id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
        name: json['name']?.toString() ?? '',
      );
}

class ConcretePourCardModel {
  final int id;
  final int projectId;
  final String cardNo;
  final String date;
  final String? time;
  final String? grade;
  final String? startTime;
  final String? endTime;
  final String? workName;
  final List<Map<String, dynamic>> checklistItems;
  final String? checkedBy;
  final ConcreteCreator? creator;
  final String? createdAt;
  final String? updatedAt;

  const ConcretePourCardModel({
    required this.id,
    required this.projectId,
    required this.cardNo,
    required this.date,
    this.time,
    this.grade,
    this.startTime,
    this.endTime,
    this.workName,
    required this.checklistItems,
    this.checkedBy,
    this.creator,
    this.createdAt,
    this.updatedAt,
  });

  factory ConcretePourCardModel.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> items = [];
    final raw = json['checklist_items'];
    if (raw is List) {
      items = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    ConcreteCreator? creator;
    if (json['creator'] is Map) {
      creator = ConcreteCreator.fromJson(
          Map<String, dynamic>.from(json['creator'] as Map));
    }

    return ConcretePourCardModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      projectId:
          int.tryParse(json['project_id']?.toString() ?? '0') ?? 0,
      cardNo: json['card_no']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      time: json['time']?.toString(),
      grade: json['grade']?.toString(),
      startTime: json['start_time']?.toString(),
      endTime: json['end_time']?.toString(),
      workName: json['work_name']?.toString(),
      checklistItems: items,
      checkedBy: json['checked_by']?.toString(),
      creator: creator,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }
}

// Default checklist items matching the web blade template
const List<Map<String, String>> kDefaultChecklistItems = [
  {'sr_no': '1', 'description': 'Alignment'},
  {'sr_no': '2', 'description': 'Level'},
  {'sr_no': '3', 'description': 'Plumb'},
  {'sr_no': '4', 'description': 'Shuttering'},
  {'sr_no': '5', 'description': 'Reinforcement'},
  {'sr_no': '6', 'description': 'Concrete Quantity'},
  {'sr_no': '7', 'description': 'Theoretical cement consumption'},
  {'sr_no': '8', 'description': 'Actual cement consumption'},
  {'sr_no': '9', 'description': 'Slump'},
  {'sr_no': '10', 'description': 'Water Quantity'},
  {'sr_no': '11', 'description': 'Mixing time'},
  {'sr_no': '12', 'description': 'No. of cube for testing'},
  {'sr_no': '13', 'description': 'Cube test result'},
];

// Items that use textarea (multi-line) instead of single-line text
const Set<int> kMultiLineItems = {8, 9, 12}; // 0-indexed: Slump, Water Quantity, Cube test result