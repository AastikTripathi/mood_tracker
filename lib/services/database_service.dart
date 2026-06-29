import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/thought.dart';
import '../models/physical_log.dart';
import '../models/habit.dart';
import 'nlp_service.dart';
import 'matrix_math.dart';

class DailyRecord {
  final DateTime date;
  final double mood;
  final double sleep;
  final double pain;
  final double seizures;
  final double period;
  final Set<String> habits;

  DailyRecord({
    required this.date,
    required this.mood,
    required this.sleep,
    required this.pain,
    required this.seizures,
    required this.period,
    required this.habits,
  });
}

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

  /// Clears all thoughts, physical logs, and habit logs from memory and disk.
  Future<void> clearData() async {
    _thoughts.clear();
    _physicalLogs.clear();
    _habitLogs.clear();
    await _saveAllData();
  }

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

    _thoughts.removeWhere((t) => t.id == thought.id);
    _thoughts.add(thought);
    await _saveAllData();
  }

  /// Instantly scans history using precompiled vector math without reprocessing text
  List<Thought> semanticSearch(String query, {double targetThreshold = 0.35}) {
    final queryVector = _nlp.vectorize(query);
    final bool isModelFailed = !_nlp.isModelLoaded;
    
    final List<MapEntry<Thought, double>> scoredEntries = [];

    for (final thought in _thoughts) {
      double similarity = 0.0;
      if (isModelFailed) {
        similarity = _calculateTextJaccard(query, thought.textContent);
      } else {
        final pastVector = thought.embedding ?? _nlp.vectorize(thought.textContent);
        if (thought.embedding == null) {
          thought.embedding = pastVector;
        }
        similarity = _nlp.calculateSimilarity(queryVector, pastVector);
      }

      if (similarity >= targetThreshold) {
        scoredEntries.add(MapEntry(thought, similarity));
      }
    }

    scoredEntries.sort((a, b) => b.value.compareTo(a.value));
    return scoredEntries.map((e) => e.key).toList();
  }

  double _calculateTextJaccard(String s1, String s2) {
    final w1 = s1.toLowerCase().replaceAll(RegExp(r"[.,\/#!$%\^&\*;:{}=\-_`~()]"), " ").split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet();
    final w2 = s2.toLowerCase().replaceAll(RegExp(r"[.,\/#!$%\^&\*;:{}=\-_`~()]"), " ").split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet();
    if (w1.isEmpty && w2.isEmpty) return 1.0;
    if (w1.isEmpty || w2.isEmpty) return 0.0;
    final intersection = w1.intersection(w2).length;
    final union = w1.union(w2).length;
    return intersection / union;
  }

  /// Retrieves the set of habit IDs logged on a specific day.
  Set<String> getHabitsForDay(DateTime date) {
    return _habitLogs
        .where((log) =>
            log.occurrenceDate.year == date.year &&
            log.occurrenceDate.month == date.month &&
            log.occurrenceDate.day == date.day)
        .map((log) => log.habitId)
        .toSet();
  }

  /// Calculates a detailed multi-modal similarity breakdown between two thoughts/days.
  Map<String, double> getHybridSimilarityBreakdown(Thought a, Thought b) {
    final double actualMoodDiff = (a.moodScore - b.moodScore).abs().toDouble();
    final double moodSim = actualMoodDiff <= 1.0 ? 1.0 : 0.0;

    // 2. Semantic Text Similarity (Weight: 0.3)
    final vectorA = a.embedding ?? _nlp.vectorize(a.textContent);
    final vectorB = b.embedding ?? _nlp.vectorize(b.textContent);
    if (a.embedding == null) a.embedding = vectorA;
    if (b.embedding == null) b.embedding = vectorB;
    final double semanticSim = _nlp.calculateSimilarity(vectorA, vectorB);

    // 3. Habitual Similarity (Weight: 0.3)
    final habitsA = getHabitsForDay(a.timestamp);
    final habitsB = getHabitsForDay(b.timestamp);

    double habitSim = 1.0;
    if (habitsA.isNotEmpty || habitsB.isNotEmpty) {
      final intersection = habitsA.intersection(habitsB).length;
      final union = habitsA.union(habitsB).length;
      habitSim = intersection / union;
    }

    final double total = (moodSim * 0.4) + (semanticSim * 0.3) + (habitSim * 0.3);

    return {
      'moodSim': moodSim,
      'semanticSim': semanticSim,
      'habitSim': habitSim,
      'total': total,
    };
  }

  /// Calculates unified hybrid similarity between two thoughts/days.
  double calculateHybridSimilarity(Thought a, Thought b) {
    return getHybridSimilarityBreakdown(a, b)['total']!;
  }

  /// Groups historical thought data dynamically into organic mood spaces using hybrid similarity.
  List<List<Thought>> clusterHistory({double clusterThreshold = 0.55}) {
    final List<List<Thought>> clusters = [];

    for (final doc in _thoughts) {
      bool assigned = false;

      for (final currentCluster in clusters) {
        // Average-Linkage: Compute the average unified similarity to all existing members of the cluster
        double sumSimilarity = 0.0;
        for (final existingDoc in currentCluster) {
          sumSimilarity += calculateHybridSimilarity(doc, existingDoc);
        }
        double avgSimilarity = sumSimilarity / currentCluster.length;

        if (avgSimilarity >= clusterThreshold) {
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

    _habitLogs.removeWhere((l) => l.id == log.id);
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
    List<double> seizureSeries = [];
    List<double> painSeries = [];

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

        seizureSeries.add((pLog.customSeizuresCount ?? 0).toDouble());
        painSeries.add(pLog.customPainLevel ?? 0.0);
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
    double seizureCorrelation = _calculatePearson(moodSeries, seizureSeries);
    double painCorrelation = _calculatePearson(moodSeries, painSeries);

    String status = "Your sanctuary baseline is balanced.";
    String insight = "No heavy physical fatigue or symptom correlations are breaking through today.";

    if (seizureCorrelation <= -0.3) {
      status = "Seizure Cluster Impact Detected ⚡";
      insight = "A negative correlation is visible between seizures and mood. Seizure days significantly depress baseline mood scores.";
    } else if (painCorrelation <= -0.4) {
      status = "Chronic Pain Sensitivity Detected 🩺";
      insight = "Elevated pain scores show a strong correlation with decreased daily mood averages. Focus on soothing habits on high-pain days.";
    } else if (sleepCorrelation >= 0.5) {
      status = "Deep Sleep Buffer Detected 🛌";
      insight = "Your history shows a strong link between restful nights and calm days. Getting more than 8 hours of sleep acts as a reliable emotional cushion for you.";
    } else if (cycleCorrelation <= -0.4) {
      status = "Cycle Shift Sensitivity detected 🌸";
      insight = "A quiet pattern suggests you feel a bit more overwhelmed on active period days. Settle in today with extra warmth, and give yourself permission to move slowly.";
    } else if (sleepCorrelation <= -0.4) {
      status = "Fatigue Link Found ☁️";
      insight = "Lower energy days frequently align with nights of restless sleep loss. Prioritize wind-down routines early tonight.";
    }

    return {
      'status': status,
      'insight': insight,
      'sleepCorrelation': sleepCorrelation.toStringAsFixed(2),
      'cycleCorrelation': cycleCorrelation.toStringAsFixed(2),
      'seizureCorrelation': seizureCorrelation.toStringAsFixed(2),
      'painCorrelation': painCorrelation.toStringAsFixed(2),
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

  List<DailyRecord> _compileDailyRecords() {
    final Map<String, List<Thought>> thoughtsByDate = {};
    for (var t in _thoughts) {
      final key = "${t.timestamp.year}-${t.timestamp.month}-${t.timestamp.day}";
      thoughtsByDate.putIfAbsent(key, () => []).add(t);
    }

    final Map<String, PhysicalLog> physicalByDate = {};
    for (var p in _physicalLogs) {
      final key = "${p.date.year}-${p.date.month}-${p.date.day}";
      physicalByDate[key] = p;
    }

    final Map<String, Set<String>> habitsByDate = {};
    for (var hl in _habitLogs) {
      final key = "${hl.occurrenceDate.year}-${hl.occurrenceDate.month}-${hl.occurrenceDate.day}";
      habitsByDate.putIfAbsent(key, () => {}).add(hl.habitId);
    }

    final List<DailyRecord> records = [];
    for (final dateKey in thoughtsByDate.keys) {
      final dayThoughts = thoughtsByDate[dateKey]!;
      if (dayThoughts.isEmpty) continue;

      double avgMood = dayThoughts.map((t) => t.moodScore.toDouble()).reduce((a, b) => a + b) / dayThoughts.length;

      final pLog = physicalByDate[dateKey];
      final double sleep = pLog?.sleepHours ?? 7.0;
      final double pain = pLog?.customPainLevel ?? 0.0;
      final double seizures = (pLog?.customSeizuresCount ?? 0).toDouble();
      final double period = (pLog?.isPeriodDay == true || pLog?.flowLevel != 'None') ? 1.0 : 0.0;

      final dayHabits = habitsByDate[dateKey] ?? {};

      final parts = dateKey.split('-');
      final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));

      records.add(DailyRecord(
        date: date,
        mood: avgMood,
        sleep: sleep,
        pain: pain,
        seizures: seizures,
        period: period,
        habits: dayHabits,
      ));
    }

    records.sort((a, b) => a.date.compareTo(b.date));
    return records;
  }

  /// Runs multi-variable regularized Ridge Regression to isolate independent effects on mood.
  Map<String, dynamic>? performRidgeRegression() {
    final records = _compileDailyRecords();
    if (records.length < 10) return null;

    final List<String> habitIds = _habitDefinitions.map((h) => h.id).where((id) => id != 'seizure').toList();

    final List<String> featureNames = [
      'intercept',
      'mood_lag',
      'sleep',
      'sleep_lag',
      'pain',
      'pain_lag',
      'seizures',
      'seizures_lag',
      'period',
    ];
    for (var hid in habitIds) {
      featureNames.add('habit_$hid');
    }

    int numFeatures = featureNames.length;
    List<List<double>> X = [];
    List<double> y = [];

    for (int t = 1; t < records.length; t++) {
      final today = records[t];
      final yesterday = records[t - 1];

      if (today.date.difference(yesterday.date).inDays > 3) continue;

      List<double> row = List.filled(numFeatures, 0.0);
      row[0] = 1.0;
      row[1] = yesterday.mood;
      row[2] = today.sleep;
      row[3] = yesterday.sleep;
      row[4] = today.pain;
      row[5] = yesterday.pain;
      row[6] = today.seizures;
      row[7] = yesterday.seizures;
      row[8] = today.period;

      for (int i = 0; i < habitIds.length; i++) {
        row[9 + i] = today.habits.contains(habitIds[i]) ? 1.0 : 0.0;
      }

      X.add(row);
      y.add(today.mood);
    }

    if (X.length < 5) return null;

    final Xt = MatrixMath.transpose(X);
    final XtX = MatrixMath.multiply(Xt, X);

    double lambda = 1.0;
    for (int i = 0; i < numFeatures; i++) {
      XtX[i][i] += lambda;
    }

    final invXtX = MatrixMath.invert(XtX);
    if (invXtX == null) return null;

    List<double> Xty = List.filled(numFeatures, 0.0);
    for (int i = 0; i < numFeatures; i++) {
      double sum = 0.0;
      for (int j = 0; j < X.length; j++) {
        sum += Xt[i][j] * y[j];
      }
      Xty[i] = sum;
    }

    final List<double> beta = MatrixMath.multiplyVector(invXtX, Xty);

    final Map<String, double> coefficients = {};
    for (int i = 0; i < numFeatures; i++) {
      coefficients[featureNames[i]] = beta[i];
    }

    return {
      'coefficients': coefficients,
      'sampleSize': X.length,
    };
  }

  /// Calculates dynamic habit deviations, compound synergies, and novelty decay (habituation).
  Map<String, dynamic> calculateHabitMetrics() {
    final thoughts = _thoughts;
    if (thoughts.isEmpty) {
      return {
        'baselineWeights': <String, double>{},
        'synergies': <String, double>{},
        'decays': <String, double>{},
      };
    }

    final double baselineMood = thoughts.map((t) => t.moodScore.toDouble()).reduce((a, b) => a + b) / thoughts.length;

    final Map<String, Set<String>> habitsByDate = {};
    for (var hl in _habitLogs) {
      if (hl.habitId == 'seizure') continue; // Exclude seizure incidents from routine habit metrics
      final key = "${hl.occurrenceDate.year}-${hl.occurrenceDate.month}-${hl.occurrenceDate.day}";
      habitsByDate.putIfAbsent(key, () => {}).add(hl.habitId);
    }

    final Map<String, double> moodByDate = {};
    final Map<String, List<Thought>> thoughtsByDate = {};
    for (var t in thoughts) {
      final key = "${t.timestamp.year}-${t.timestamp.month}-${t.timestamp.day}";
      thoughtsByDate.putIfAbsent(key, () => []).add(t);
    }
    for (var dateKey in thoughtsByDate.keys) {
      final list = thoughtsByDate[dateKey]!;
      moodByDate[dateKey] = list.map((t) => t.moodScore.toDouble()).reduce((a, b) => a + b) / list.length;
    }

    final Map<String, List<double>> moodForHabit = {};
    final Map<String, List<double>> recentMoodForHabit = {};
    final DateTime now = DateTime.now();

    for (var dateKey in moodByDate.keys) {
      final double mood = moodByDate[dateKey]!;
      final activeHabits = habitsByDate[dateKey] ?? {};

      final parts = dateKey.split('-');
      final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      final isRecent = now.difference(date).inDays <= 14;

      for (var hid in activeHabits) {
        moodForHabit.putIfAbsent(hid, () => []).add(mood);
        if (isRecent) {
          recentMoodForHabit.putIfAbsent(hid, () => []).add(mood);
        }
      }
    }

    final Map<String, double> habitWeights = {};
    for (var hid in moodForHabit.keys) {
      final avg = moodForHabit[hid]!.reduce((a, b) => a + b) / moodForHabit[hid]!.length;
      habitWeights[hid] = avg - baselineMood;
    }

    final Map<String, double> decays = {};
    for (var hid in recentMoodForHabit.keys) {
      if (moodForHabit[hid]!.length >= 4 && recentMoodForHabit[hid]!.length >= 2) {
        final avgRecent = recentMoodForHabit[hid]!.reduce((a, b) => a + b) / recentMoodForHabit[hid]!.length;
        final recentWeight = avgRecent - baselineMood;
        final lifetimeWeight = habitWeights[hid] ?? 0.0;

        if (lifetimeWeight > 0.3 && recentWeight < (lifetimeWeight * 0.5)) {
          decays[hid] = recentWeight - lifetimeWeight;
        }
      }
    }

    final Map<String, List<double>> moodForPairs = {};
    for (var dateKey in moodByDate.keys) {
      final double mood = moodByDate[dateKey]!;
      final activeHabits = (habitsByDate[dateKey] ?? {}).toList();

      for (int i = 0; i < activeHabits.length; i++) {
        for (int j = i + 1; j < activeHabits.length; j++) {
          final pairKey = activeHabits[i].compareTo(activeHabits[j]) < 0
              ? "${activeHabits[i]}+${activeHabits[j]}"
              : "${activeHabits[j]}+${activeHabits[i]}";
          moodForPairs.putIfAbsent(pairKey, () => []).add(mood);
        }
      }
    }

    final Map<String, double> synergies = {};
    for (var pairKey in moodForPairs.keys) {
      if (moodForPairs[pairKey]!.length >= 2) {
        final avgPair = moodForPairs[pairKey]!.reduce((a, b) => a + b) / moodForPairs[pairKey]!.length;
        final pairWeight = avgPair - baselineMood;

        final parts = pairKey.split('+');
        final w1 = habitWeights[parts[0]] ?? 0.0;
        final w2 = habitWeights[parts[1]] ?? 0.0;

        if (pairWeight > (w1 + w2) + 0.3) {
          synergies[pairKey] = pairWeight - (w1 + w2);
        }
      }
    }

    return {
      'baselineWeights': habitWeights,
      'synergies': synergies,
      'decays': decays,
    };
  }

  /// RPG-Style transition matching to find a resilience roadmap based on 2-day historical cycles.
  Map<String, dynamic>? findResilienceRoadmap() {
    final records = _compileDailyRecords();
    if (records.length < 5) return null;

    final today = records.last;
    final yesterday = records[records.length - 2];

    if (today.date.difference(yesterday.date).inDays > 2) return null;

    final double currentDeltaMood = today.mood - yesterday.mood;
    final double currentDeltaPain = today.pain - yesterday.pain;
    final double currentDeltaSeizures = today.seizures - yesterday.seizures;
    final double currentDeltaSleep = today.sleep - yesterday.sleep;

    if (today.mood > 5) return null;

    double bestDistance = 9999.0;
    DailyRecord? matchStart;
    DailyRecord? matchEnd;

    for (int i = 1; i < records.length - 2; i++) {
      final pastStart = records[i - 1];
      final pastEnd = records[i];

      if (pastEnd.date.difference(pastStart.date).inDays > 2) continue;

      final pastDeltaMood = pastEnd.mood - pastStart.mood;
      if (pastDeltaMood < 1.5) continue;

      final dMood = (yesterday.mood - pastStart.mood) / 9.0;
      final dPain = (currentDeltaPain - (pastEnd.pain - pastStart.pain)) / 10.0;
      final dSeizures = (currentDeltaSeizures - (pastEnd.seizures - pastStart.seizures)) / 5.0;
      final dSleep = (currentDeltaSleep - (pastEnd.sleep - pastStart.sleep)) / 10.0;

      final distance = math.sqrt(dMood * dMood + dPain * dPain + dSeizures * dSeizures + dSleep * dSleep);

      if (distance < bestDistance) {
        bestDistance = distance;
        matchStart = pastStart;
        matchEnd = pastEnd;
      }
    }

    if (matchStart != null && matchEnd != null) {
      return {
        'startDate': matchStart.date,
        'endDate': matchEnd.date,
        'startMood': matchStart.mood,
        'endMood': matchEnd.mood,
        'distance': bestDistance,
        'habits': matchEnd.habits.toList(),
      };
    }

    return null;
  }
}