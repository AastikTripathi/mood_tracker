class PhysicalLog {
  final DateTime date;
  double sleepHours;
  bool isPeriodDay;
  bool skippedMeal;
  bool lateCaffeine;
  double? customPainLevel;      // Optional: 0.0 to 10.0 for tracking chronic pain levels
  int? customSeizuresCount;    // Optional: count of occurrences to keep track of seizures or other patterns
  List<String> seizureTimes;   // List of specific seizure times (e.g., "10:30 AM")
  List<String> painLogs;       // List of pain events with level and time (e.g., "02:15 PM - Level 5")
  String? _flowLevel;          // Flow: Light, Medium, Heavy, None
  String get flowLevel => _flowLevel ?? 'None';
  set flowLevel(String value) => _flowLevel = value;
  List<String> cycleSymptoms;  // Symptoms: Cramps, Bloating, Headache, Fatigue, etc.
  int? cycleDay;               // Optional track mapping for the 28-day hormonal cycle

  PhysicalLog({
    required this.date,
    required this.sleepHours,
    required this.isPeriodDay,
    required this.skippedMeal,
    required this.lateCaffeine,
    this.customPainLevel,
    this.customSeizuresCount,
    List<String>? seizureTimes,
    List<String>? painLogs,
    String? flowLevel = 'None',
    List<String>? cycleSymptoms,
    this.cycleDay,
  }) : seizureTimes = seizureTimes ?? [],
       painLogs = painLogs ?? [],
       _flowLevel = flowLevel ?? 'None',
       cycleSymptoms = cycleSymptoms ?? [];

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'sleepHours': sleepHours,
    'isPeriodDay': isPeriodDay,
    'skippedMeal': skippedMeal,
    'lateCaffeine': lateCaffeine,
    'customPainLevel': customPainLevel,
    'customSeizuresCount': customSeizuresCount,
    'seizureTimes': seizureTimes,
    'painLogs': painLogs,
    'flowLevel': flowLevel,
    'cycleSymptoms': cycleSymptoms,
    'cycleDay': cycleDay,
  };

  factory PhysicalLog.fromJson(Map<String, dynamic> json) => PhysicalLog(
    date: DateTime.parse(json['date']),
    sleepHours: (json['sleepHours'] as num).toDouble(),
    isPeriodDay: json['isPeriodDay'] ?? false,
    skippedMeal: json['skippedMeal'] ?? false,
    lateCaffeine: json['lateCaffeine'] ?? false,
    customPainLevel: json['customPainLevel'] != null ? (json['customPainLevel'] as num).toDouble() : null,
    customSeizuresCount: json['customSeizuresCount'] as int?,
    seizureTimes: json['seizureTimes'] != null ? List<String>.from(json['seizureTimes']) : [],
    painLogs: json['painLogs'] != null ? List<String>.from(json['painLogs']) : [],
    flowLevel: json['flowLevel'] ?? 'None',
    cycleSymptoms: json['cycleSymptoms'] != null ? List<String>.from(json['cycleSymptoms']) : [],
    cycleDay: json['cycleDay'] as int?,
  );
}