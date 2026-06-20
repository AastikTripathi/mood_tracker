import 'package:flutter/material.dart';
import '../models/thought.dart';

class ThoughtDetailDialog extends StatefulWidget {
  final Thought initialThought;
  final List<Thought> allThoughts;
  final List<dynamic> allHabitLogs;
  final List<dynamic> availableHabits;

  const ThoughtDetailDialog({
    super.key,
    required this.initialThought,
    required this.allThoughts,
    required this.allHabitLogs,
    required this.availableHabits,
  });

  static void show(
    BuildContext context, {
    required Thought thought,
    required List<Thought> allThoughts,
    required List<dynamic> allHabitLogs,
    required List<dynamic> availableHabits,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ThoughtDetailDialog(
        initialThought: thought,
        allThoughts: allThoughts,
        allHabitLogs: allHabitLogs,
        availableHabits: availableHabits,
      ),
    );
  }

  @override
  State<ThoughtDetailDialog> createState() => _ThoughtDetailDialogState();
}

class _ThoughtDetailDialogState extends State<ThoughtDetailDialog> {
  late Thought _currentThread;
  late List<Thought> _sortedThoughts;

  @override
  void initState() {
    super.initState();
    _currentThread = widget.initialThought;
    // Sort thoughts chronologically (oldest to newest) to make nav arrows logical
    _sortedThoughts = List.from(widget.allThoughts)..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  // Get index of current thought in the sorted list
  int get _currentIndex => _sortedThoughts.indexWhere((t) => t.id == _currentThread.id);

  // Navigate to previous chronological thought
  void _navigateToPrevious() {
    final idx = _currentIndex;
    if (idx > 0) {
      setState(() {
        _currentThread = _sortedThoughts[idx - 1];
      });
    }
  }

  // Navigate to next chronological thought
  void _navigateToNext() {
    final idx = _currentIndex;
    if (idx != -1 && idx < _sortedThoughts.length - 1) {
      setState(() {
        _currentThread = _sortedThoughts[idx + 1];
      });
    }
  }

  Color _getMoodColor(int mood) {
    if (mood <= 2) return const Color(0xFF3F51B5); // Deep Indigo / Overwhelmed
    if (mood <= 4) return const Color(0xFF673AB7); // Purple / Low
    if (mood <= 6) return const Color(0xFF009688); // Teal / Okay
    if (mood <= 8) return const Color(0xFF4CAF50); // Green / Grounded
    return const Color(0xFFFFC107); // Gold / Radiant
  }

  String _getMoodEmoji(int mood) {
    if (mood <= 2) return "🌊";
    if (mood <= 4) return "☁️";
    if (mood <= 6) return "🌿";
    if (mood <= 8) return "☀️";
    return "✨";
  }

  String _calculateMoodProgression() {
    final idx = _currentIndex;
    if (idx > 0) {
      final prevThought = _sortedThoughts[idx - 1];
      final delta = _currentThread.moodScore - prevThought.moodScore;
      if (delta > 0) {
        return "+$delta mood progression 📈";
      } else if (delta < 0) {
        return "$delta mood shift 📉";
      } else {
        return "Steady baseline ⚖️";
      }
    }
    return "First log of progression 🌸";
  }

  List<String> _getHabitEmojisForDay(DateTime date) {
    final List<String> emojis = [];
    for (var log in widget.allHabitLogs) {
      if (log.occurrenceDate.year == date.year &&
          log.occurrenceDate.month == date.month &&
          log.occurrenceDate.day == date.day) {
        dynamic matchedHabit;
        for (var h in widget.availableHabits) {
          if (h.id == log.habitId || h.name == log.habitId) {
            matchedHabit = h;
            break;
          }
        }
        if (matchedHabit != null) {
          emojis.add(matchedHabit.iconEmoji);
        }
      }
    }
    return emojis.toSet().toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final moodColor = _getMoodColor(_currentThread.moodScore);
    
    final idx = _currentIndex;
    final hasPrev = idx > 0;
    final hasNext = idx != -1 && idx < _sortedThoughts.length - 1;

    final habitEmojis = _getHabitEmojisForDay(_currentThread.timestamp);
    final progressionText = _calculateMoodProgression();

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 10,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: Date & Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${_currentThread.timestamp.day}/${_currentThread.timestamp.month}/${_currentThread.timestamp.year}",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white38 : Colors.grey,
                  ),
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
            const SizedBox(height: 10),

            // Emotional Progression Indicator Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: moodColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: moodColor.withOpacity(0.2)),
              ),
              child: Text(
                progressionText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: moodColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 18),

            // Mood Score Display Block
            Center(
              child: Column(
                children: [
                  Text(
                    _getMoodEmoji(_currentThread.moodScore),
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Mood Score: ${_currentThread.moodScore}/10",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: moodColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // The Journal Message Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
              ),
              child: Text(
                _currentThread.textContent,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Emoji-coded Habits Display
            if (habitEmojis.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: habitEmojis.map((emoji) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(emoji, style: const TextStyle(fontSize: 20)),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 24),

            // Navigation Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: hasPrev ? Colors.teal : Colors.grey.shade400),
                  onPressed: hasPrev ? _navigateToPrevious : null,
                  tooltip: "Previous Log",
                ),
                Text(
                  "${_currentIndex + 1} of ${_sortedThoughts.length}",
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                IconButton(
                  icon: Icon(Icons.arrow_forward, color: hasNext ? Colors.teal : Colors.grey.shade400),
                  onPressed: hasNext ? _navigateToNext : null,
                  tooltip: "Next Log",
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
