import 'dart:math' as math;

class NlpService {
  static const Map<String, List<String>> _conceptStems = {
    'work': ['work', 'task', 'deadline', 'boss', 'office', 'project', 'client', 'screen', 'code', 'presentation', 'meeting', 'school', 'exam', 'grade', 'study', 'class', 'homework', 'professor', 'job', 'interview', 'career', 'resume'],
    'anxiety': ['anxious', 'scared', 'nervous', 'heart', 'headache', 'tight', 'stuck', 'panic', 'shaking', 'overwhelmed', 'paralyzed', 'worry', 'stressed', 'stress', 'fear', 'tension', 'dread', 'fret', 'uneasy', 'apprehensive'],
    'fatigue': ['tired', 'exhausted', 'energy', 'sleep', 'sleepy', 'drained', 'heavy', 'lazy', 'bed', 'restless', 'groggy', 'fatigued', 'burnout', 'yawning', 'weary', 'dull', 'lethargic'],
    'interpersonal': ['argument', 'fight', 'family', 'relationship', 'said', 'told', 'angry', 'irritated', 'lonely', 'sad', 'friend', 'partner', 'chat', 'talk', 'social', 'call', 'isolate', 'ignored', 'misunderstood', 'loneliness'],
    'peace': ['nature', 'walk', 'tea', 'coffee', 'sunlight', 'breathe', 'music', 'calm', 'peaceful', 'happy', 'lighter', 'garden', 'relax', 'serene', 'cozy', 'warm', 'read', 'quiet', 'meditate', 'gratitude', 'joy', 'smile'],
    'health': ['sick', 'pain', 'headache', 'stomach', 'flu', 'cold', 'sore', 'ache', 'cramp', 'nausea', 'unwell', 'healthy', 'exercise', 'run', 'gym', 'stretch', 'yoga', 'nutrition', 'medicine']
  };

  static const List<String> _negationTokens = ['not', 'no', 'dont', 'didnt', 'never', 'cant', 'without', 'nothing', 'havent'];

  List<double> vectorize(String text) {
    final cleanText = text.toLowerCase().replaceAll(RegExp(r"[.,\/#!$%\^&\*;:{}=\-_`~()]"), " ");
    final words = cleanText.split(RegExp(r'\s+'));

    List<double> vector = List.filled(_conceptStems.keys.length, 0.0);

    int index = 0;
    for (var entry in _conceptStems.entries) {
      double score = 0.0;
      final categoryKeys = entry.value;

      for (int i = 0; i < words.length; i++) {
        final currentWord = words[i];

        if (categoryKeys.contains(currentWord)) {
          bool isNegated = false;
          int checkStart = math.max(0, i - 2);
          for (int j = checkStart; j < i; j++) {
            if (_negationTokens.contains(words[j])) {
              isNegated = true;
              break;
            }
          }

          if (isNegated) {
            score -= 0.5;
          } else {
            score += 1.0;
          }
        }
      }
      vector[index] = math.max(0.0, score);
      index++;
    }

    double magnitude = 0.0;
    for (var val in vector) {
      magnitude += val * val;
    }
    magnitude = math.sqrt(magnitude);

    if (magnitude > 0) {
      return vector.map((v) => v / magnitude).toList();
    }
    return List.filled(_conceptStems.keys.length, 0.0);
  }

  double calculateSimilarity(List<double> v1, List<double> v2) {
    if (v1.length != v2.length || v1.isEmpty) return 0.0;
    double dotProduct = 0.0;
    for (int i = 0; i < v1.length; i++) {
      dotProduct += v1[i] * v2[i];
    }
    return dotProduct;
  }

  List<String> extractCategories(String text) {
    final clean = text.toLowerCase();
    List<String> results = [];

    if (clean.contains('work') || clean.contains('task') || clean.contains('deadline')) {
      results.add('Work');
    }
    if (clean.contains('anxious') || clean.contains('stressed') || clean.contains('overwhelmed')) {
      if (!clean.contains('not stressed') && !clean.contains('not anxious') && !clean.contains('dont feel anxious')) {
        results.add('Stress');
      }
    }
    if (clean.contains('tired') || clean.contains('sleep') || clean.contains('exhausted')) {
      results.add('Energy');
    }
    if (clean.contains('walk') || clean.contains('nature') || clean.contains('garden') || clean.contains('sun')) {
      results.add('Nature');
    }

    if (results.isEmpty) results.add('Reflection');
    return results;
  }
}