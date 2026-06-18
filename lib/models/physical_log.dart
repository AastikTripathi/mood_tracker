class PhysicalLog {
  final DateTime date;
  final double sleepHours;
  final bool isPeriodDay;
  final bool skippedMeal;
  final bool lateCaffeine;

  PhysicalLog({
    required this.date,
    required this.sleepHours,
    required this.isPeriodDay,
    required this.skippedMeal,
    required this.lateCaffeine,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'sleepHours': sleepHours,
    'isPeriodDay': isPeriodDay,
    'skippedMeal': skippedMeal,
    'lateCaffeine': lateCaffeine,
  };

  factory PhysicalLog.fromJson(Map<String, dynamic> json) => PhysicalLog(
    date: DateTime.parse(json['date']),
    sleepHours: (json['sleepHours'] as num).toDouble(),
    isPeriodDay: json['isPeriodDay'] ?? false,
    skippedMeal: json['skippedMeal'] ?? false,
    lateCaffeine: json['lateCaffeine'] ?? false,
  );
}