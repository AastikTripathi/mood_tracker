class HabitDefinition {
  final String id;
  final String name;
  final String iconEmoji;

  HabitDefinition({
    required this.id,
    required this.name,
    required this.iconEmoji,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'iconEmoji': iconEmoji,
  };

  factory HabitDefinition.fromJson(Map<String, dynamic> json) => HabitDefinition(
    id: json['id'],
    name: json['name'],
    iconEmoji: json['iconEmoji'] ?? '🌿',
  );
}

class HabitLog {
  final String id;
  final String habitId;
  final DateTime occurrenceDate;
  final DateTime createdAt;

  HabitLog({
    required this.id,
    required this.habitId,
    required this.occurrenceDate,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'habitId': habitId,
    'occurrenceDate': occurrenceDate.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory HabitLog.fromJson(Map<String, dynamic> json) => HabitLog(
    id: json['id'],
    habitId: json['habitId'],
    occurrenceDate: DateTime.parse(json['occurrenceDate']),
    createdAt: DateTime.parse(json['createdAt']),
  );
}