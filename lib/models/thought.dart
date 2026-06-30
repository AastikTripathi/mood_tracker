class Thought {
  final String id;
  final DateTime timestamp;
  final int moodScore;
  final String textContent;
  final List<String> categories;
  final List<String> userTags;
  String? linkedThoughtId;
  String? connectionReason;
  List<double>? embedding;
  
  // New intraday metrics tracking fields
  String? prevNoteId; // stores immediate prior note from the same day
  List<String> habitsSincePrev; // stores habit ids executed in the window between notes
  double? minutesSincePrev; // stores precise time elapsed between notes
  bool externalShockShield; // Acts as our unmeasured stress gatekeeper

  Thought({
    required this.id,
    required this.timestamp,
    required this.moodScore,
    required this.textContent,
    required this.categories,
    this.userTags = const [],
    this.linkedThoughtId,
    this.connectionReason,
    this.embedding,
    this.prevNoteId,
    this.habitsSincePrev = const [],
    this.minutesSincePrev,
    this.externalShockShield = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'moodScore': moodScore,
    'textContent': textContent,
    'categories': categories,
    'userTags': userTags,
    'linkedThoughtId': linkedThoughtId,
    'connectionReason': connectionReason,
    'embedding': embedding,
    'prevNoteId': prevNoteId,
    'habitsSincePrev': habitsSincePrev,
    'minutesSincePrev': minutesSincePrev,
    'externalShockShield': externalShockShield,
  };

  factory Thought.fromJson(Map<String, dynamic> json) {
    final thought = Thought(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
      moodScore: json['moodScore'],
      textContent: json['textContent'],
      categories: List<String>.from(json['categories'] ?? []),
      userTags: List<String>.from(json['userTags'] ?? []),
      linkedThoughtId: json['linkedThoughtId'],
      connectionReason: json['connectionReason'],
      prevNoteId: json['prevNoteId'],
      habitsSincePrev: json['habitsSincePrev'] != null
          ? List<String>.from(json['habitsSincePrev'])
          : const [],
      minutesSincePrev: json['minutesSincePrev'] != null
          ? (json['minutesSincePrev'] as num).toDouble()
          : null,
      externalShockShield: json['externalShockShield'] ?? false,
    );
    if (json['embedding'] != null) {
      thought.embedding = List<double>.from(
          (json['embedding'] as List).map((x) => (x as num).toDouble()));
    }
    return thought;
  }
}







