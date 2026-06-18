import 'package:flutter/material.dart';
import '../models/thought.dart';
import '../models/habit.dart';
import '../models/physical_log.dart';

class CausalCorrelationCard extends StatelessWidget {
  final List<Thought> historyThoughts;
  final List<HabitDefinition> availableHabits;
  final List<HabitLog> allHabitLogs;
  final List<PhysicalLog> physicalLogs;

  const CausalCorrelationCard({
    super.key,
    required this.historyThoughts,
    required this.availableHabits,
    required this.allHabitLogs,
    required this.physicalLogs,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Colors.white.withOpacity(0.02) : Colors.white;

    final brightDays = historyThoughts.where((t) => t.moodScore >= 7).toList();
    final heavyDays = historyThoughts.where((t) => t.moodScore <= 4).toList();

    Map<String, int> heavyEmotionCounts = {};
    Map<String, int> brightEmotionCounts = {};

    for (var t in heavyDays) {
      for (var cat in t.categories) {
        heavyEmotionCounts[cat] = (heavyEmotionCounts[cat] ?? 0) + 1;
      }
    }
    for (var t in brightDays) {
      for (var cat in t.categories) {
        brightEmotionCounts[cat] = (brightEmotionCounts[cat] ?? 0) + 1;
      }
    }

    String dominantHeavyTheme = "Unburdening";
    int maxHeavyCount = 0;
    heavyEmotionCounts.forEach((key, value) {
      if (value > maxHeavyCount) {
        maxHeavyCount = value;
        dominantHeavyTheme = key;
      }
    });

    double sleepBright = 0.0;
    double sleepHeavy = 0.0;
    int periodHeavyCount = 0;

    for (var thought in brightDays) {
      final d = thought.timestamp;
      final p = physicalLogs.cast<PhysicalLog?>().firstWhere(
            (log) => log!.date.year == d.year && log.date.month == d.month && log.date.day == d.day,
        orElse: () => null,
      );
      if (p != null) sleepBright += p.sleepHours;
    }
    if (brightDays.isNotEmpty) sleepBright /= brightDays.length;

    for (var thought in heavyDays) {
      final d = thought.timestamp;
      final p = physicalLogs.cast<PhysicalLog?>().firstWhere(
            (log) => log!.date.year == d.year && log.date.month == d.month && log.date.day == d.day,
        orElse: () => null,
      );
      if (p != null) {
        sleepHeavy += p.sleepHours;
        if (p.isPeriodDay) periodHeavyCount++;
      }
    }
    if (heavyDays.isNotEmpty) sleepHeavy /= heavyDays.length;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.teal.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: Colors.teal),
              SizedBox(width: 8),
              Text(
                "Patterns of the Heart",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: -0.3),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            "Gentle connections your sanctuary notices across your thoughts and routines.",
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 18),

          if (historyThoughts.length < 3)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                "Tending to the garden... Your personal connections will reveal themselves here as you write and save entries.",
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.teal.withOpacity(0.08)),
              ),
              child: Text(
                _compileHumanInsight(sleepBright, sleepHeavy, periodHeavyCount, dominantHeavyTheme),
                style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white70 : Colors.black87, height: 1.5),
              ),
            ),
            const SizedBox(height: 20),

            const Text("What builds your brighter days:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),

            _buildInsightRow(
              label: "Getting restorative rest",
              detail: "${sleepBright.toStringAsFixed(1)}h avg",
              progress: (sleepBright / 10.0).clamp(0.1, 1.0),
              color: const Color(0xFF10B981),
              isDark: isDark,
            ),

            ...availableHabits.take(2).map((habit) {
              int matches = 0;
              for (var t in brightDays) {
                final d = t.timestamp;
                if (allHabitLogs.any((l) => (l.habitId == habit.id || l.habitId == habit.name) && l.occurrenceDate.year == d.year && l.occurrenceDate.month == d.month && l.occurrenceDate.day == d.day)) {
                  matches++;
                }
              }
              double density = brightDays.isNotEmpty ? (matches / brightDays.length) : 0.0;
              return _buildInsightRow(
                label: "Routine: ${habit.name}",
                detail: "${(density * 100).toStringAsFixed(0)}% of days",
                progress: density.clamp(0.05, 1.0),
                color: const Color(0xFF10B981),
                isDark: isDark,
              );
            }),

            const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1)),
            const Text("What commonly tracks with heavier days:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),

            _buildInsightRow(
              label: "Thoughts centering on '$dominantHeavyTheme'",
              detail: "$maxHeavyCount entries",
              progress: heavyDays.isNotEmpty ? (maxHeavyCount / heavyDays.length).clamp(0.1, 1.0) : 0.1,
              color: Colors.redAccent.shade100,
              isDark: isDark,
            ),

            if (periodHeavyCount > 0)
              _buildInsightRow(
                label: "Active cycle windows",
                detail: "$periodHeavyCount days noticed",
                progress: heavyDays.isNotEmpty ? (periodHeavyCount / heavyDays.length).clamp(0.1, 1.0) : 0.1,
                color: Colors.pinkAccent.withOpacity(0.7),
                isDark: isDark,
              ),
          ]
        ],
      ),
    );
  }

  String _compileHumanInsight(double brightSleep, double heavySleep, int periodHeavy, String theme) {
    if (periodHeavy >= 2) {
      return "Your sanctuary notices that your quieter, heavier days often softly align with your physical cycle windows. When thoughts about '$theme' feel amplified during these times, remember it's okay to slow down. Be extra gentle with your headspace today. 🌸";
    }
    if ((brightSleep - heavySleep) >= 1.2) {
      return "There's a beautiful connection in your records: getting a full night of rest acts as a powerful emotional cushion for you. On days you feel bright, you average ${brightSleep.toStringAsFixed(1)} hours of sleep, compared to just ${heavySleep.toStringAsFixed(1)} hours when your headspace feels crowded. Let's aim for an early rest tonight. 🛌";
    }
    return "Your diary shows that when your headspace feels a bit overwhelmed, thoughts regarding '$theme' are usually close to the surface. Notice it without judgment—every wave passes, and your garden is right here holding space for you. 🌿";
  }

  Widget _buildInsightRow({
    required String label,
    required String detail,
    required double progress,
    required Color color,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              Text(detail, style: const TextStyle(fontSize: 10.5, color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Stack(
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              )
            ],
          )
        ],
      ),
    );
  }
}