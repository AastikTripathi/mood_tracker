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
  final int intensity; // represents subjective quality/effort on a 1 to 5 scale
  final DateTime? actualOccurrenceTime; // allows backfilling real-time execution

  HabitLog({
    required this.id,
    required this.habitId,
    required this.occurrenceDate,
    required this.createdAt,
    this.intensity = 5,
    this.actualOccurrenceTime,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'habitId': habitId,
    'occurrenceDate': occurrenceDate.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'intensity': intensity,
    'actualOccurrenceTime': actualOccurrenceTime?.toIso8601String(),
  };

  factory HabitLog.fromJson(Map<String, dynamic> json) {
    final DateTime createdAtVal = DateTime.parse(json['createdAt']);
    return HabitLog(
      id: json['id'],
      habitId: json['habitId'],
      occurrenceDate: DateTime.parse(json['occurrenceDate']),
      createdAt: createdAtVal,
      intensity: json['intensity'] as int? ?? 5,
      actualOccurrenceTime: json['actualOccurrenceTime'] != null
          ? DateTime.parse(json['actualOccurrenceTime'])
          : createdAtVal,
    );
  }
}