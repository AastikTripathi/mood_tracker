import 'package:flutter/material.dart';
import '../models/thought.dart';
import '../models/habit.dart';

class TimelineItem {
  final DateTime time;
  final String type; // 'thought' or 'habit'
  final dynamic data; // Thought or HabitLog

  TimelineItem({required this.time, required this.type, required this.data});
}

class DayTimelineDialog extends StatelessWidget {
  final DateTime date;
  final List<Thought> allThoughts;
  final List<dynamic> allHabitLogs;
  final List<dynamic> availableHabits;

  const DayTimelineDialog({
    super.key,
    required this.date,
    required this.allThoughts,
    required this.allHabitLogs,
    required this.availableHabits,
  });

  static void show(
    BuildContext context, {
    required DateTime date,
    required List<Thought> allThoughts,
    required List<dynamic> allHabitLogs,
    required List<dynamic> availableHabits,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => DayTimelineDialog(
        date: date,
        allThoughts: allThoughts,
        allHabitLogs: allHabitLogs,
        availableHabits: availableHabits,
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return "$formattedHour:$minute $period";
  }

  Color _getMoodColor(int mood) {
    if (mood <= 2) return const Color(0xFF3F51B5); // Deep Indigo
    if (mood <= 4) return const Color(0xFF673AB7); // Purple
    if (mood <= 6) return const Color(0xFF009688); // Teal
    if (mood <= 8) return const Color(0xFF4CAF50); // Green
    return const Color(0xFFFFC107); // Gold
  }

  String _getMoodEmoji(int mood) {
    if (mood <= 2) return "🌊";
    if (mood <= 4) return "☁️";
    if (mood <= 6) return "🌿";
    if (mood <= 8) return "☀️";
    return "✨";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    // Filter day's thoughts
    final thoughtsForDay = allThoughts.where((t) =>
      t.timestamp.year == date.year &&
      t.timestamp.month == date.month &&
      t.timestamp.day == date.day
    ).toList();

    // Filter day's habit logs
    final habitsForDay = allHabitLogs.where((log) =>
      log.occurrenceDate.year == date.year &&
      log.occurrenceDate.month == date.month &&
      log.occurrenceDate.day == date.day
    ).toList();

    // Combine and sort chronologically
    final List<TimelineItem> items = [];
    for (var t in thoughtsForDay) {
      items.add(TimelineItem(time: t.timestamp, type: 'thought', data: t));
    }
    for (var hl in habitsForDay) {
      items.add(TimelineItem(time: hl.occurrenceDate, type: 'habit', data: hl));
    }
    items.sort((a, b) => a.time.compareTo(b.time));

    final titleDate = "${date.day}/${date.month}/${date.year}";

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 10,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360, maxHeight: 500),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Sanctuary Timeline",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      titleDate,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 16),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Timeline stream list
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_toggle_off, size: 36, color: Colors.grey.withOpacity(0.4)),
                          const SizedBox(height: 8),
                          const Text(
                            "No check-ins recorded for this day.",
                            style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final isLast = index == items.length - 1;
                        return _buildTimelineRow(item, isLast, isDark);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineRow(TimelineItem item, bool isLast, bool isDark) {
    final timeStr = _formatTime(item.time);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: Timestamp Column
          SizedBox(
            width: 65,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                timeStr,
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.grey),
                textAlign: TextAlign.right,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Middle: Timeline Line & Dotted Node
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: item.type == 'thought' ? _getMoodColor((item.data as Thought).moodScore) : Colors.teal.shade400,
                  shape: BoxShape.circle,
                  border: Border.all(color: isDark ? Colors.white24 : Colors.white, width: 1.5),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5,
                    color: Colors.grey.withOpacity(0.2),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),

          // Right: Content Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: item.type == 'thought'
                  ? _buildThoughtCard(item.data as Thought, isDark)
                  : _buildHabitCard(item.data as HabitLog, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThoughtCard(Thought thought, bool isDark) {
    final moodColor = _getMoodColor(thought.moodScore);
    String truncatedContent = thought.textContent;
    if (truncatedContent.length > 55) {
      truncatedContent = '${truncatedContent.substring(0, 55)}...';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: moodColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: moodColor.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Note logged ${_getMoodEmoji(thought.moodScore)}",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: moodColor),
              ),
              Text(
                "${thought.moodScore}/10",
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: moodColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            truncatedContent,
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87, height: 1.35),
          ),
          const SizedBox(height: 8),
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(3),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: thought.moodScore / 10.0,
              child: Container(
                decoration: BoxDecoration(
                  color: moodColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitCard(HabitLog log, bool isDark) {
    dynamic matchedHabit;
    for (var h in availableHabits) {
      if (h.id == log.habitId || h.name == log.habitId) {
        matchedHabit = h;
        break;
      }
    }
    final icon = matchedHabit != null ? matchedHabit.iconEmoji : '🌿';
    final name = matchedHabit != null ? matchedHabit.name : log.habitId;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
