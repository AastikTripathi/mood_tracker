import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
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

  Future<void> init() async {
    if (_isInitialized) return;
    final prefs = await SharedPreferences.getInstance();

    final thoughtsRaw = prefs.getStringList('thoughts') ?? [];
    _thoughts = thoughtsRaw
        .map((t) => Thought.fromJson(jsonDecode(t)))
        .toList();

    final physicalRaw = prefs.getStringList('physical_logs') ?? [];
    _physicalLogs = physicalRaw
        .map((p) => PhysicalLog.fromJson(jsonDecode(p)))
        .toList();

    final habitDefsRaw = prefs.getStringList('habit_definitions') ?? [];
    _habitDefinitions = habitDefsRaw
        .map((h) => HabitDefinition.fromJson(jsonDecode(h)))
        .toList();

    final habitLogsRaw = prefs.getStringList('habit_logs') ?? [];
    _habitLogs = habitLogsRaw
        .map((hl) => HabitLog.fromJson(jsonDecode(hl)))
        .toList();

    if (_habitDefinitions.isEmpty) {
      await saveHabitDefinition(HabitDefinition(id: '1', name: 'Stepped Outside ☀️', iconEmoji: '☀️'));
      await saveHabitDefinition(HabitDefinition(id: '2', name: 'Rested Well 🛌', iconEmoji: '🛌'));
      await saveHabitDefinition(HabitDefinition(id: '3', name: 'Drank Water 💧', iconEmoji: '💧'));
      await saveHabitDefinition(HabitDefinition(id: '4', name: 'Stretched / Walked 🌿', iconEmoji: '🌿'));
      await saveHabitDefinition(HabitDefinition(id: '5', name: 'Read a Book 📖', iconEmoji: '📖'));
    }

    _isInitialized = true;
  }

  List<Thought> getThoughts() => List.from(_thoughts..sort((a, b) => b.timestamp.compareTo(a.timestamp)));
  List<PhysicalLog> getPhysicalLogs() => _physicalLogs;
  List<HabitDefinition> getHabitDefinitions() => _habitDefinitions;
  List<HabitLog> getHabitLogs() => _habitLogs;

  Future<void> saveThought(Thought thought) async {
    final currentVector = _nlp.vectorize(thought.textContent);
    Thought? bestMatch;
    double highestSimilarity = 0.0;

    for (var pastThought in _thoughts) {
      if (pastThought.id == thought.id) continue;
      final pastVector = _nlp.vectorize(pastThought.textContent);
      final similarity = _nlp.calculateSimilarity(currentVector, pastVector);

      if (similarity > highestSimilarity) {
        highestSimilarity = similarity;
        bestMatch = pastThought;
      }
    }

    if (highestSimilarity >= 0.5 && bestMatch != null) {
      thought.linkedThoughtId = bestMatch.id;
      thought.connectionReason = "You felt very similarly on ${_formatDate(bestMatch.timestamp)}. Take a breath; you got through that storm.";
    }

    _thoughts.add(thought);
    await _syncThoughts();
  }

  Future<void> savePhysicalLog(PhysicalLog log) async {
    _physicalLogs.removeWhere((p) => p.date.year == log.date.year && p.date.month == log.date.month && p.date.day == log.date.day);
    _physicalLogs.add(log);
    final prefs = await SharedPreferences.getInstance();
    final data = _physicalLogs.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList('physical_logs', data);
  }

  Future<void> saveHabitDefinition(HabitDefinition def) async {
    _habitDefinitions.add(def);
    final prefs = await SharedPreferences.getInstance();
    final data = _habitDefinitions.map((h) => jsonEncode(h.toJson())).toList();
    await prefs.setStringList('habit_definitions', data);
  }

  Future<void> saveHabitLog(HabitLog log) async {
    final hoursDiff = log.createdAt.difference(log.occurrenceDate).inHours;
    double memoryWeight = math.exp(-0.02 * hoursDiff);

    if (memoryWeight < 0.3) {
      print("Warning: Log heavily back-dated. Memory reliability: ${(memoryWeight * 100).toStringAsFixed(0)}%");
    }

    _habitLogs.add(log);
    final prefs = await SharedPreferences.getInstance();
    final data = _habitLogs.map((hl) => jsonEncode(hl.toJson())).toList();
    await prefs.setStringList('habit_logs', data);
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

  Future<void> _syncThoughts() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _thoughts.map((t) => jsonEncode(t.toJson())).toList();
    await prefs.setStringList('thoughts', data);
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return "${months[date.month - 1]} ${date.day.toString().padLeft(2, '0')}";
  }
}