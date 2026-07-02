import 'package:flutter/material.dart';
import '../models/thought.dart';
import '../models/physical_log.dart';
import '../models/habit.dart';
import '../services/database_service.dart';
import 'day_timeline_dialog.dart';

class RecoveryComparisonDialog extends StatelessWidget {
  final double currentMood;
  final double currentPain;
  final double currentSleep;
  final bool currentPeriod;
  final List<String> currentSeizures;
  final List<String> currentHabits;
  final Thought echoThought;
  final DatabaseService db;

  const RecoveryComparisonDialog({
    super.key,
    required this.currentMood,
    required this.currentPain,
    required this.currentSleep,
    required this.currentPeriod,
    required this.currentSeizures,
    required this.currentHabits,
    required this.echoThought,
    required this.db,
  });

  static void show(
    BuildContext context, {
    required double currentMood,
    required double currentPain,
    required double currentSleep,
    required bool currentPeriod,
    required List<String> currentSeizures,
    required List<String> currentHabits,
    required Thought echoThought,
    required DatabaseService db,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => RecoveryComparisonDialog(
        currentMood: currentMood,
        currentPain: currentPain,
        currentSleep: currentSleep,
        currentPeriod: currentPeriod,
        currentSeizures: currentSeizures,
        currentHabits: currentHabits,
        echoThought: echoThought,
        db: db,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textThemeColor = isDark ? Colors.white70 : Colors.black87;

    // 1. Gather circumstances for Echo Day (the matched similar day)
    final DateTime echoDate = echoThought.timestamp;
    
    final echoPLog = db.getPhysicalLogs().cast<PhysicalLog?>().firstWhere(
      (p) => p!.date.year == echoDate.year && p.date.month == echoDate.month && p.date.day == echoDate.day,
      orElse: () => null,
    );

    final echoThoughts = db.getThoughts().where(
      (t) => t.timestamp.year == echoDate.year && t.timestamp.month == echoDate.month && t.timestamp.day == echoDate.day,
    ).toList();

    final double echoMeanMood = echoThoughts.isEmpty
        ? echoThought.moodScore.toDouble()
        : echoThoughts.map((t) => t.moodScore).reduce((a, b) => a + b) / echoThoughts.length;

    // 2. Gather circumstances for Recovery Day (Day + 1 after Echo Day)
    final DateTime recoveryDate = echoDate.add(const Duration(days: 1));

    final recoveryPLog = db.getPhysicalLogs().cast<PhysicalLog?>().firstWhere(
      (p) => p!.date.year == recoveryDate.year && p.date.month == recoveryDate.month && p.date.day == recoveryDate.day,
      orElse: () => null,
    );

    final recoveryThoughts = db.getThoughts().where(
      (t) => t.timestamp.year == recoveryDate.year && t.timestamp.month == recoveryDate.month && t.timestamp.day == recoveryDate.day,
    ).toList();

    final double? recoveryMeanMood = recoveryThoughts.isEmpty
        ? null
        : recoveryThoughts.map((t) => t.moodScore).reduce((a, b) => a + b) / recoveryThoughts.length;

    final List<String> recoveryHabits = db.getHabitLogs().where(
      (l) => l.occurrenceDate.year == recoveryDate.year && l.occurrenceDate.month == recoveryDate.month && l.occurrenceDate.day == recoveryDate.day,
    ).map((l) => l.habitId).toList();

    // Map habit IDs to human readable definitions
    final availableHabits = db.getHabitDefinitions();
    String getHabitName(String id) {
      final match = availableHabits.cast<HabitDefinition?>().firstWhere((h) => h!.id == id, orElse: () => null);
      return match != null ? "${match.iconEmoji} ${match.name}" : id;
    }

    final double currentPainVal = currentPain;
    final double echoPainVal = echoPLog?.customPainLevel ?? 0.0;
    final double recoveryPainVal = recoveryPLog?.customPainLevel ?? 0.0;

    final int currentSeizureCount = currentSeizures.length;
    final int echoSeizureCount = echoPLog?.customSeizuresCount ?? 0;
    final int recoverySeizureCount = recoveryPLog?.customSeizuresCount ?? 0;

    return Dialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 600),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Recovery Pathfinder",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Circumstances comparison & recovery timeline",
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              ],
            ),
            const SizedBox(height: 16),

            // Comparison grid (Side by Side circumstances)
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "Baseline Circumstance Matching",
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.teal.shade400),
                    ),
                    const SizedBox(height: 10),
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2),
                        1: FlexColumnWidth(2.5),
                        2: FlexColumnWidth(2.5),
                      },
                      border: TableBorder(
                        horizontalInside: BorderSide(color: Colors.grey.withOpacity(0.08), width: 1),
                      ),
                      children: [
                        _buildTableHeaderRow(isDark),
                        _buildComparisonRow("Headspace", "${currentMood.toStringAsFixed(1)}/10", "${echoMeanMood.toStringAsFixed(1)}/10", textThemeColor),
                        _buildComparisonRow("Pain Level", currentPainVal > 0 ? "${currentPainVal.toStringAsFixed(1)}/10" : "None", echoPainVal > 0 ? "${echoPainVal.toStringAsFixed(1)}/10" : "None", textThemeColor),
                        _buildComparisonRow("Seizures", currentSeizureCount > 0 ? "$currentSeizureCount incidents" : "None", echoSeizureCount > 0 ? "$echoSeizureCount incidents" : "None", textThemeColor),
                        _buildComparisonRow("Period", currentPeriod ? "Active" : "None", (echoPLog?.isPeriodDay == true || echoPLog?.flowLevel != 'None') ? "Active" : "None", textThemeColor),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Past Note snippet
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Past Reflection (${echoDate.day}/${echoDate.month}/${echoDate.year}):",
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "\"${echoThought.textContent}\"",
                            style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: textThemeColor),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Proof of Recovery Segment
                    Text(
                      "Proof of Recovery (The Following Day)",
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.teal.shade400),
                    ),
                    const SizedBox(height: 10),

                    if (recoveryMeanMood == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          "No tracking data logged for the day following this past echo.",
                          style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                        ),
                      )
                    else ...[
                      // Mood Change Visual Indicator
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.teal.withOpacity(0.12)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Headspace Progression",
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      "${echoMeanMood.toStringAsFixed(1)}/10",
                                      style: const TextStyle(fontSize: 11.5, color: Colors.grey, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.arrow_forward, size: 12, color: Colors.teal),
                                    const SizedBox(width: 6),
                                    Text(
                                      "${recoveryMeanMood.toStringAsFixed(1)}/10",
                                      style: const TextStyle(fontSize: 12.5, color: Colors.teal, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (recoveryMeanMood > echoMeanMood)
                              Text(
                                "Headspace recovered by +${(recoveryMeanMood - echoMeanMood).toStringAsFixed(1)} points the next day.",
                                style: const TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.bold),
                              )
                            else
                              const Text(
                                "Headspace levels remained stable or quiet.",
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Recovery physical changes & habits
                      Text(
                        "Actions logged on recovery day:",
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      if (recoveryHabits.isEmpty)
                        const Text(
                          "No specific routines logged on the recovery day.",
                          style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: recoveryHabits.where((id) => id != 'seizure').map((id) {
                            return Chip(
                              label: Text(
                                getHabitName(id),
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.teal),
                              ),
                              backgroundColor: Colors.teal.withOpacity(0.08),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 14),

                      // Symptom Resolution Check
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSymptomStat("Pain", echoPainVal, recoveryPainVal, isDark),
                          _buildSymptomStat("Seizures", echoSeizureCount.toDouble(), recoverySeizureCount.toDouble(), isDark),
                          _buildSymptomStat("Sleep", echoPLog?.sleepHours ?? 7.0, recoveryPLog?.sleepHours ?? 7.0, isDark, isSleep: true),
                        ],
                      ),

                      if (recoveryThoughts.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.withOpacity(0.08)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Next Day Note:",
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "\"${recoveryThoughts.first.textContent}\"",
                                style: TextStyle(fontSize: 11, color: textThemeColor),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Footer Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close this dialog
                    // Open full DayTimelineDialog for the echo day
                    DayTimelineDialog.show(
                      context,
                      date: echoDate,
                      allThoughts: db.getThoughts(),
                      allHabitLogs: db.getHabitLogs(),
                      availableHabits: db.getHabitDefinitions(),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text("View Day Timeline", style: TextStyle(fontSize: 11.5)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade400,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text("Got It", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  TableRow _buildTableHeaderRow(bool isDark) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            "Metric",
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : Colors.grey),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            "Today",
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : Colors.grey),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            "Echo Day",
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : Colors.grey),
          ),
        ),
      ],
    );
  }

  TableRow _buildComparisonRow(String label, String todayVal, String echoVal, Color textColor) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(todayVal, style: TextStyle(fontSize: 11.5, color: textColor)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(echoVal, style: TextStyle(fontSize: 11.5, color: textColor)),
        ),
      ],
    );
  }

  Widget _buildSymptomStat(String label, double from, double to, bool isDark, {bool isSleep = false}) {
    final bool isImprovement = isSleep ? to > from : to < from;
    final bool isNoChange = to == from;
    final color = isNoChange
        ? Colors.grey
        : (isImprovement ? Colors.teal : Colors.orangeAccent);

    String valueString = "";
    if (isSleep) {
      valueString = "${from.toStringAsFixed(1)}h ➔ ${to.toStringAsFixed(1)}h";
    } else {
      valueString = "${from.toStringAsFixed(0)} ➔ ${to.toStringAsFixed(0)}";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.01),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            valueString,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
