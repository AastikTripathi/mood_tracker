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
    );
    if (json['embedding'] != null) {
      thought.embedding = List<double>.from(
          (json['embedding'] as List).map((x) => (x as num).toDouble()));
    }
    return thought;
  }
}







