import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/thought.dart';
import '../models/physical_log.dart';
import '../models/habit.dart';
import 'nlp_service.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  final NlpService _nlp = NlpService();

  List<Thought> _thoughts = [];
  List<PhysicalLog> _physicalLogs = [];
  List<HabitDefinition> _habitDefinitions = [];
  List<HabitLog> _habitLogs = [];

  bool _isInitialized = false;

  Future<File> _getSaveFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/garden_save.json');
  }

  /// Boots storage system and initializes on-device neural networking assets
  Future<void> init() async {
    if (_isInitialized) return;
    
    // Initialize NLP service using the TFLite engine
    await _nlp.initialize();

    final file = await _getSaveFile();

    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        final Map<String, dynamic> data = jsonDecode(content);

        final List<dynamic> thoughtsJson = data['thoughts'] ?? [];
        _thoughts = thoughtsJson.map((t) => Thought.fromJson(t)).toList();

        final List<dynamic> physicalJson = data['physical_logs'] ?? [];
        _physicalLogs = physicalJson.map((p) => PhysicalLog.fromJson(p)).toList();

        final List<dynamic> habitDefsJson = data['habit_definitions'] ?? [];
        _habitDefinitions = habitDefsJson.map((h) => HabitDefinition.fromJson(h)).toList();

        final List<dynamic> habitLogsJson = data['habit_logs'] ?? [];
        _habitLogs = habitLogsJson.map((hl) => HabitLog.fromJson(hl)).toList();
      } catch (e) {
        print("Error reading garden save file: $e");
      }
    } else {
      // Legacy SharedPreferences Migration
      final prefs = await SharedPreferences.getInstance();
      final thoughtsRaw = prefs.getStringList('thoughts') ?? [];
      final physicalRaw = prefs.getStringList('physical_logs') ?? [];
      final habitDefsRaw = prefs.getStringList('habit_definitions') ?? [];
      final habitLogsRaw = prefs.getStringList('habit_logs') ?? [];

      if (thoughtsRaw.isNotEmpty || physicalRaw.isNotEmpty || habitDefsRaw.isNotEmpty || habitLogsRaw.isNotEmpty) {
        _thoughts = thoughtsRaw.map((t) => Thought.fromJson(jsonDecode(t))).toList();
        _physicalLogs = physicalRaw.map((p) => PhysicalLog.fromJson(jsonDecode(p))).toList();
        _habitDefinitions = habitDefsRaw.map((h) => HabitDefinition.fromJson(jsonDecode(h))).toList();
        _habitLogs = habitLogsRaw.map((hl) => HabitLog.fromJson(jsonDecode(hl))).toList();
        
        // Save to the new JSON save file immediately
        await _saveAllData();
      }
    }

    // Prune legacy default habits
    final oldIds = ['1', '2', '3', '4', '5', 'pain_flare', 'fog', 'nausea'];
    _habitDefinitions.removeWhere((h) => oldIds.contains(h.id));

    final defaults = [
      HabitDefinition(id: 'eating', name: 'Eating 🍽️', iconEmoji: '🍽️'),
      HabitDefinition(id: 'napping', name: 'Napping 💤', iconEmoji: '💤'),
      HabitDefinition(id: 'studying', name: 'Studying 📚', iconEmoji: '📚'),
      HabitDefinition(id: 'gardening', name: 'Gardening 🪴', iconEmoji: '🪴'),
      HabitDefinition(id: 'stepping_out', name: 'Stepping Out ☀️', iconEmoji: '☀️'),
      HabitDefinition(id: 'exercise', name: 'Exercise 🏃', iconEmoji: '🏃'),
      HabitDefinition(id: 'seizure', name: 'Seizure Incident ⚡', iconEmoji: '⚡'),
    ];

    for (var def in defaults) {
      if (!_habitDefinitions.any((h) => h.id == def.id)) {
        _habitDefinitions.add(def);
      }
    }
    await _saveAllData();

    _isInitialized = true;
  }

  List<Thought> getThoughts() => List.from(_thoughts..sort((a, b) => b.timestamp.compareTo(a.timestamp)));
  List<PhysicalLog> getPhysicalLogs() => _physicalLogs;
  List<HabitDefinition> getHabitDefinitions() => _habitDefinitions;
  List<HabitLog> getHabitLogs() => _habitLogs;

  /// Processes a new journal input, builds its vector footprint, and saves to disk
  Future<void> saveThought(Thought thought) async {
    // Generate the 384D mathematical vector profile exactly once and save it in the object
    final currentVector = _nlp.vectorize(thought.textContent);
    thought.embedding = currentVector;

    Thought? bestMatch;
    double highestSimilarity = 0.0;

    for (var pastThought in _thoughts) {
      if (pastThought.id == thought.id) continue;
      
      // Lazily calculate and cache vector if missing (e.g. legacy migrated thoughts)
      final pastVector = pastThought.embedding ?? _nlp.vectorize(pastThought.textContent);
      if (pastThought.embedding == null) {
        pastThought.embedding = pastVector;
      }

      final similarity = _nlp.calculateSimilarity(currentVector, pastVector);

      if (similarity > highestSimilarity) {
        highestSimilarity = similarity;
        bestMatch = pastThought;
      }
    }

    if (highestSimilarity >= 0.5 && bestMatch != null) {
      thought.linkedThoughtId = bestMatch.id;
      final curMood = thought.moodScore;
      final pastMood = bestMatch.moodScore;
      
      if (curMood <= 4 && pastMood <= 4) {
        thought.connectionReason = "You experienced a similar quiet headspace on ${_formatDate(bestMatch.timestamp)}. You made your way through it then.";
      } else if (curMood >= 7 && pastMood >= 7) {
        thought.connectionReason = "This connects with the bright energy you felt on ${_formatDate(bestMatch.timestamp)}.";
      } else if (curMood <= 4 && pastMood >= 7) {
        thought.connectionReason = "A reminder of the bright moment you captured on ${_formatDate(bestMatch.timestamp)}: \"${bestMatch.textContent}\"";
      } else {
        thought.connectionReason = "Semantically connected to your reflection from ${_formatDate(bestMatch.timestamp)}.";
      }
    }

    _thoughts.add(thought);
    await _saveAllData();
  }

  /// Instantly scans history using precompiled vector math without reprocessing text
  List<Thought> semanticSearch(String query, {double targetThreshold = 0.35}) {
    // Convert current query text string into a baseline matching vector
    final queryVector = _nlp.vectorize(query);
    
    final List<MapEntry<Thought, double>> scoredEntries = [];

    for (final thought in _thoughts) {
      final pastVector = thought.embedding ?? _nlp.vectorize(thought.textContent);
      if (thought.embedding == null) {
        thought.embedding = pastVector;
      }
      final similarity = _nlp.calculateSimilarity(queryVector, pastVector);
      if (similarity >= targetThreshold) {
        scoredEntries.add(MapEntry(thought, similarity));
      }
    }

    // Sort descending by highest proximity score
    scoredEntries.sort((a, b) => b.value.compareTo(a.value));
    return scoredEntries.map((e) => e.key).toList();
  }

  /// Groups historical thought data dynamically into organic mood spaces
  List<List<Thought>> clusterHistory({double clusterThreshold = 0.55}) {
    final List<List<Thought>> clusters = [];

    for (final doc in _thoughts) {
      bool assigned = false;
      final docVector = doc.embedding ?? _nlp.vectorize(doc.textContent);
      if (doc.embedding == null) {
        doc.embedding = docVector;
      }

      for (final currentCluster in clusters) {
        final firstVector = currentCluster.first.embedding ?? _nlp.vectorize(currentCluster.first.textContent);
        if (currentCluster.first.embedding == null) {
          currentCluster.first.embedding = firstVector;
        }
        double similarity = _nlp.calculateSimilarity(docVector, firstVector);
        if (similarity >= clusterThreshold) {
          currentCluster.add(doc);
          assigned = true;
          break;
        }
      }

      if (!assigned) {
        clusters.add([doc]);
      }
    }
    return clusters;
  }

  Future<void> savePhysicalLog(PhysicalLog log) async {
    _physicalLogs.removeWhere((p) => p.date.year == log.date.year && p.date.month == log.date.month && p.date.day == log.date.day);
    _physicalLogs.add(log);
    await _saveAllData();
  }

  Future<void> saveHabitDefinition(HabitDefinition def) async {
    _habitDefinitions.add(def);
    await _saveAllData();
  }

  Future<void> saveHabitLog(HabitLog log) async {
    final hoursDiff = log.createdAt.difference(log.occurrenceDate).inHours;
    double memoryWeight = math.exp(-0.02 * hoursDiff);

    if (memoryWeight < 0.3) {
      print("Warning: Log heavily back-dated. Memory reliability: ${(memoryWeight * 100).toStringAsFixed(0)}%");
    }

    _habitLogs.add(log);
    await _saveAllData();
  }

  Future<void> updateHabitLogTime(String logId, DateTime newTime) async {
    final idx = _habitLogs.indexWhere((l) => l.id == logId);
    if (idx != -1) {
      final oldLog = _habitLogs[idx];
      _habitLogs[idx] = HabitLog(
        id: oldLog.id,
        habitId: oldLog.habitId,
        occurrenceDate: newTime,
        createdAt: oldLog.createdAt,
      );
      await _saveAllData();
    }
  }

  Future<void> deleteHabitLog(String logId) async {
    _habitLogs.removeWhere((l) => l.id == logId);
    await _saveAllData();
  }

  Future<void> removeHabitLogToday(String habitId) async {
    final today = DateTime.now();
    _habitLogs.removeWhere((log) =>
        log.habitId == habitId &&
        log.occurrenceDate.year == today.year &&
        log.occurrenceDate.month == today.month &&
        log.occurrenceDate.day == today.day);
    await _saveAllData();
  }

  Future<void> deleteHabitDefinition(String habitId) async {
    _habitDefinitions.removeWhere((h) => h.id == habitId || h.name == habitId);
    _habitLogs.removeWhere((log) => log.habitId == habitId);
    await _saveAllData();
  }

  Future<void> _saveAllData() async {
    final file = await _getSaveFile();
    final Map<String, dynamic> data = {
      'thoughts': _thoughts.map((t) => t.toJson()).toList(),
      'physical_logs': _physicalLogs.map((p) => p.toJson()).toList(),
      'habit_definitions': _habitDefinitions.map((h) => h.toJson()).toList(),
      'habit_logs': _habitLogs.map((hl) => hl.toJson()).toList(),
    };
    await file.writeAsString(jsonEncode(data));
  }

  Map<String, String> calculateLocalCausalCorrelations() {
    if (_thoughts.isEmpty || _physicalLogs.isEmpty) {
      return {
        'status': 'Insights',
        'insight': 'Log more notes alongside your physical routine checks to discover automated correlations.'
      };
    }

    List<double> moodSeries = [];
    List<double> sleepSeries = [];
    List<double> cycleDaySeries = [];

    for (var pLog in _physicalLogs) {
      final matchingThoughts = _thoughts.where((t) =>
      t.timestamp.year == pLog.date.year &&
          t.timestamp.month == pLog.date.month &&
          t.timestamp.day == pLog.date.day);

      if (matchingThoughts.isNotEmpty) {
        double avgMood = matchingThoughts.map((t) => t.moodScore.toDouble()).reduce((a, b) => a + b) / matchingThoughts.length;
        moodSeries.add(avgMood);
        sleepSeries.add(pLog.sleepHours);

        if (pLog.isPeriodDay) {
          cycleDaySeries.add(1.0);
        } else {
          cycleDaySeries.add(0.0);
        }
      }
    }

    if (moodSeries.length < 3) {
      return {
        'status': 'Connecting dots...',
        'insight': 'Insights unlock once 3 matching days with both mood notes and sleep checks are saved.'
      };
    }

    double sleepCorrelation = _calculatePearson(moodSeries, sleepSeries);
    double cycleCorrelation = _calculatePearson(moodSeries, cycleDaySeries);

    String status = "Your sanctuary baseline is balanced.";
    String insight = "No heavy physical fatigue patterns are breaking through your wellness index today.";

    if (sleepCorrelation >= 0.5) {
      status = "Deep Sleep Buffer Detected 🛌";
      insight = "Your history shows a strong link between restful nights and calm days. Getting more than 8 hours of sleep acts as a reliable emotional cushion for you.";
    }
    else if (cycleCorrelation <= -0.4) {
      status = "Cycle Shift Sensitivity detected 🌸";
      insight = "A quiet pattern suggests you feel a bit more overwhelmed on active period days. Settle in today with extra warmth, and give yourself permission to move slowly.";
    }
    else if (sleepCorrelation <= -0.4) {
      status = "Fatigue Link Found ☁️";
      insight = "Lower energy days frequently align with nights of restless sleep loss. Prioritize wind-down routines early tonight with a warm, comforting tea.";
    }

    return {
      'status': status,
      'insight': insight,
      'sleepCorrelation': sleepCorrelation.toStringAsFixed(2),
      'cycleCorrelation': cycleCorrelation.toStringAsFixed(2),
    };
  }

  double _calculatePearson(List<double> x, List<double> y) {
    int n = x.length;
    double meanX = x.reduce((a, b) => a + b) / n;
    double meanY = y.reduce((a, b) => a + b) / n;

    double num = 0.0;
    double denX = 0.0;
    double denY = 0.0;

    for (int i = 0; i < n; i++) {
      double dx = x[i] - meanX;
      double dy = y[i] - meanY;
      num += dx * dy;
      denX += dx * dx;
      denY += dy * dy;
    }

    if (denX == 0 || denY == 0) return 0.0;
    return num / math.sqrt(denX * denY);
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return "${months[date.month - 1]} ${date.day.toString().padLeft(2, '0')}";
  }
}