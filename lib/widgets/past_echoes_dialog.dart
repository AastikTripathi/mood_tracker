import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/thought.dart';
import '../models/physical_log.dart';
import '../services/database_service.dart';
import 'day_timeline_dialog.dart';

class PastEchoesDialog extends StatefulWidget {
  final double currentMood;
  final double currentPain;
  final double currentSleep;
  final bool currentPeriod;
  final List<String> currentSeizures;
  final DatabaseService db;

  const PastEchoesDialog({
    super.key,
    required this.currentMood,
    required this.currentPain,
    required this.currentSleep,
    required this.currentPeriod,
    required this.currentSeizures,
    required this.db,
  });

  static void show(
    BuildContext context, {
    required double currentMood,
    required double currentPain,
    required double currentSleep,
    required bool currentPeriod,
    required List<String> currentSeizures,
    required DatabaseService db,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => PastEchoesDialog(
        currentMood: currentMood,
        currentPain: currentPain,
        currentSleep: currentSleep,
        currentPeriod: currentPeriod,
        currentSeizures: currentSeizures,
        db: db,
      ),
    );
  }

  @override
  State<PastEchoesDialog> createState() => _PastEchoesDialogState();
}

class _PastEchoesDialogState extends State<PastEchoesDialog> {
  String _searchQuery = '';
  DateTime? _filterDate;

  double _calculateSimilarity(Thought thought) {
    final date = thought.timestamp;

    // Get physical log for that day
    final pLogs = widget.db.getPhysicalLogs();
    final pLog = pLogs.cast<PhysicalLog?>().firstWhere(
      (p) => p!.date.year == date.year && p.date.month == date.month && p.date.day == date.day,
      orElse: () => null,
    );

    // Get all thoughts for that day to find mean mood
    final thoughts = widget.db.getThoughts().where(
      (t) => t.timestamp.year == date.year && t.timestamp.month == date.month && t.timestamp.day == date.day,
    ).toList();

    final double meanMood = thoughts.isEmpty 
        ? thought.moodScore.toDouble() 
        : thoughts.map((t) => t.moodScore).reduce((a, b) => a + b) / thoughts.length;

    // Get habit logs for that day
    final habits = widget.db.getHabitLogs().where(
      (l) => l.occurrenceDate.year == date.year && l.occurrenceDate.month == date.month && l.occurrenceDate.day == date.day,
    ).map((l) => l.habitId).toSet();

    double sumSquaredDiff = 0.0;

    // 1. Mood (Weight: 3.0)
    final diffMood = (meanMood - widget.currentMood) / 10.0;
    sumSquaredDiff += 3.0 * (diffMood * diffMood);

    // 2. Pain (Weight: 2.0)
    final double painVal = pLog?.customPainLevel ?? 0.0;
    final diffPain = (painVal - widget.currentPain) / 10.0;
    sumSquaredDiff += 2.0 * (diffPain * diffPain);

    // 3. Seizures (Weight: 2.0)
    final double hasSeizures = (pLog?.customSeizuresCount ?? 0) > 0 ? 1.0 : 0.0;
    final double currentHasSeizures = widget.currentSeizures.isNotEmpty ? 1.0 : 0.0;
    final diffSeizure = hasSeizures - currentHasSeizures;
    sumSquaredDiff += 2.0 * (diffSeizure * diffSeizure);

    // 4. Period (Weight: 1.5)
    final double hasPeriod = (pLog?.isPeriodDay == true || pLog?.flowLevel != 'None') ? 1.0 : 0.0;
    final double currentHasPeriod = widget.currentPeriod ? 1.0 : 0.0;
    final diffPeriod = hasPeriod - currentHasPeriod;
    sumSquaredDiff += 1.5 * (diffPeriod * diffPeriod);

    // 5. Habits (Weight: 1.0 per habit)
    final todayDate = DateTime.now();
    final currentHabits = widget.db.getHabitLogs().where(
      (l) => l.occurrenceDate.year == todayDate.year && l.occurrenceDate.month == todayDate.month && l.occurrenceDate.day == todayDate.day,
    ).map((l) => l.habitId).toSet();

    final allHabitIds = widget.db.getHabitDefinitions()
        .map((h) => h.id)
        .where((id) => id != 'seizure')
        .toList();
    for (final hid in allHabitIds) {
      final double hasA = habits.contains(hid) ? 1.0 : 0.0;
      final double hasB = currentHabits.contains(hid) ? 1.0 : 0.0;
      final diffH = hasA - hasB;
      sumSquaredDiff += 1.0 * (diffH * diffH);
    }

    final distance = math.sqrt(sumSquaredDiff);
    return 100.0 / (1.0 + distance);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    // Deduplicate thoughts by day so we only show one note echo per day
    final Map<String, Thought> dailyThoughts = {};
    for (var t in widget.db.getThoughts()) {
      final key = "${t.timestamp.year}-${t.timestamp.month}-${t.timestamp.day}";
      if (!dailyThoughts.containsKey(key)) {
        dailyThoughts[key] = t;
      }
    }

    final List<Thought> uniqueThoughts = dailyThoughts.values.toList();

    // Calculate similarities and sort
    final List<Map<String, dynamic>> items = uniqueThoughts.map((t) {
      final sim = _calculateSimilarity(t);
      return {'thought': t, 'similarity': sim};
    }).toList();

    items.sort((a, b) => (b['similarity'] as double).compareTo(a['similarity'] as double));

    final filtered = items.where((item) {
      final t = item['thought'] as Thought;
      
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final contentMatch = t.textContent.toLowerCase().contains(query);
        final tagMatch = t.categories.any((c) => c.toLowerCase().contains(query)) ||
                         t.userTags.any((ut) => ut.toLowerCase().contains(query));
        if (!contentMatch && !tagMatch) return false;
      }

      if (_filterDate != null) {
        if (t.timestamp.year != _filterDate!.year ||
            t.timestamp.month != _filterDate!.month ||
            t.timestamp.day != _filterDate!.day) {
          return false;
        }
      }

      return true;
    }).toList();

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 550),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Past Echoes Sanctuary",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      "Find similar headspace notes in your history",
                      style: TextStyle(fontSize: 10.5, color: Colors.grey),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.withOpacity(0.1)),
                    ),
                    child: TextField(
                      style: const TextStyle(fontSize: 12.5),
                      decoration: const InputDecoration(
                        hintText: "Search notes or tags...",
                        border: InputBorder.none,
                        isDense: true,
                        icon: Icon(Icons.search, size: 16, color: Colors.teal),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    _filterDate != null ? Icons.calendar_today : Icons.calendar_month,
                    color: _filterDate != null ? Colors.teal : Colors.grey,
                    size: 20,
                  ),
                  onPressed: () async {
                    if (_filterDate != null) {
                      setState(() {
                        _filterDate = null;
                      });
                    } else {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() {
                          _filterDate = picked;
                        });
                      }
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.waves, size: 36, color: Colors.grey.withOpacity(0.3)),
                          const SizedBox(height: 10),
                          const Text(
                            "No similar echoes found.",
                            style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final t = item['thought'] as Thought;
                        final double sim = item['similarity'] as double;
                        final dateStr = "${t.timestamp.day}/${t.timestamp.month}/${t.timestamp.year}";

                        String truncated = t.textContent;
                        if (truncated.length > 70) {
                          truncated = '${truncated.substring(0, 70)}...';
                        }

                        final matchColor = sim >= 85
                            ? Colors.teal
                            : (sim >= 70 ? Colors.blueAccent : Colors.grey);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.01),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.withOpacity(0.08)),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.pop(context);
                              DayTimelineDialog.show(
                                context,
                                date: t.timestamp,
                                allThoughts: widget.db.getThoughts(),
                                allHabitLogs: widget.db.getHabitLogs(),
                                availableHabits: widget.db.getHabitDefinitions(),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        dateStr,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: matchColor.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          "${sim.toStringAsFixed(0)}% Alike",
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: matchColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    truncated,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                      height: 1.4,
                                    ),
                                  ),
                                  if (t.categories.isNotEmpty || t.userTags.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: [
                                        ...t.categories,
                                        ...t.userTags
                                      ].take(3).map((tag) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.teal.withOpacity(0.04),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            tag,
                                            style: const TextStyle(fontSize: 8.5, color: Colors.teal, fontWeight: FontWeight.bold),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
