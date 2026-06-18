import 'package:flutter/material.dart';
import '../models/thought.dart';

class CozyAlmanacCard extends StatelessWidget {
  final List<Thought> historyThoughts;
  final List<dynamic> allHabitLogs;
  final List<dynamic> availableHabits;
  final DateTime selectedDate;
  final Thought? selectedThought;
  final List<String> selectedHabits;
  final Function(DateTime) onDateSelected;

  const CozyAlmanacCard({
    super.key,
    required this.historyThoughts,
    required this.allHabitLogs,
    required this.availableHabits,
    required this.selectedDate,
    required this.selectedThought,
    required this.selectedHabits,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.teal.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Monthly Sanctuary Almanac",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: -0.2),
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            children: List.generate(28, (index) {
              final targetDate = today.subtract(Duration(days: 27 - index));

              final dayThought = historyThoughts.cast<Thought?>().firstWhere(
                    (t) => t!.timestamp.year == targetDate.year && t.timestamp.month == targetDate.month && t.timestamp.day == targetDate.day,
                orElse: () => null,
              );

              final bool hasData = dayThought != null;
              final double moodRatio = hasData ? (dayThought.moodScore / 10.0) : 0.0;
              final bool isSelected = selectedDate.year == targetDate.year && selectedDate.month == targetDate.month && selectedDate.day == targetDate.day;

              Color blockColor = isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04);
              if (hasData) {
                blockColor = Color.lerp(Colors.teal.shade50, Colors.teal.shade600, moodRatio)!;
              }

              return GestureDetector(
                onTap: () => onDateSelected(targetDate),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: blockColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? Colors.amber.shade400
                          : (hasData ? Colors.teal.withOpacity(0.2) : Colors.transparent),
                      width: isSelected ? 2.0 : 1.0,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      "${targetDate.day}",
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: hasData
                            ? (moodRatio > 0.5 ? Colors.white : Colors.teal.shade900)
                            : (isDark ? Colors.white30 : Colors.black38),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.01) : Colors.teal.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Archive: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                if (selectedThought != null) ...[
                  Text(
                    "Mood: ${selectedThought!.moodScore}/10 - ${selectedThought!.textContent}",
                    style: TextStyle(
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ] else ...[
                  const Text(
                    "No journal thoughts saved on this day.",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
                if (selectedHabits.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: selectedHabits.map((tag) {
                      return Chip(
                        label: Text(tag, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.teal.withOpacity(0.08),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  )
                ]
              ],
            ),
          )
        ],
      ),
    );
  }
}