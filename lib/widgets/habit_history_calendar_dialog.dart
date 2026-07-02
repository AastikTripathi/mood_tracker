import 'package:flutter/material.dart';
import '../models/habit.dart';

class HabitHistoryCalendarDialog extends StatefulWidget {
  final HabitDefinition habit;
  final List<HabitLog> allHabitLogs;
  final bool isTwilight;

  const HabitHistoryCalendarDialog({
    super.key,
    required this.habit,
    required this.allHabitLogs,
    required this.isTwilight,
  });

  static void show(
    BuildContext context, {
    required HabitDefinition habit,
    required List<HabitLog> allHabitLogs,
    required bool isTwilight,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => HabitHistoryCalendarDialog(
        habit: habit,
        allHabitLogs: allHabitLogs,
        isTwilight: isTwilight,
      ),
    );
  }

  @override
  State<HabitHistoryCalendarDialog> createState() => _HabitHistoryCalendarDialogState();
}

class _HabitHistoryCalendarDialogState extends State<HabitHistoryCalendarDialog> {
  late int _displayYear;
  late int _displayMonth;

  final List<String> _monthsNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _displayYear = today.year;
    _displayMonth = today.month;
  }

  void _prevMonth() {
    setState(() {
      if (_displayMonth == 1) {
        _displayMonth = 12;
        _displayYear--;
      } else {
        _displayMonth--;
      }
    });
  }

  void _nextMonth() {
    setState(() {
      if (_displayMonth == 12) {
        _displayMonth = 1;
        _displayYear++;
      } else {
        _displayMonth++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark || widget.isTwilight;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textThemeColor = isDark ? Colors.white : Colors.black87;

    // 1. Calendar generation logic
    final firstDayOfMonth = DateTime(_displayYear, _displayMonth, 1);
    final daysInMonth = DateTime(_displayYear, _displayMonth + 1, 0).day;
    final int emptyPrefixDays = firstDayOfMonth.weekday - 1; // Mon = 1, Sun = 7

    final List<Widget> dayWidgets = [];

    // Weekday headers
    final List<String> weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    for (var dayName in weekdays) {
      dayWidgets.add(
        Center(
          child: Text(
            dayName,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
            ),
          ),
        ),
      );
    }

    // Empty spaces before first day of month
    for (int i = 0; i < emptyPrefixDays; i++) {
      dayWidgets.add(const SizedBox.shrink());
    }

    int completedThisMonth = 0;

    // Actual calendar days
    for (int day = 1; day <= daysInMonth; day++) {
      final dayDate = DateTime(_displayYear, _displayMonth, day);
      final bool isCompleted = widget.allHabitLogs.any((log) =>
          (log.habitId == widget.habit.id || log.habitId == widget.habit.name) &&
          log.occurrenceDate.year == dayDate.year &&
          log.occurrenceDate.month == dayDate.month &&
          log.occurrenceDate.day == dayDate.day);

      if (isCompleted) {
        completedThisMonth++;
      }

      dayWidgets.add(
        Center(
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isCompleted ? Colors.teal.shade400 : Colors.transparent,
              shape: BoxShape.circle,
              boxShadow: isCompleted
                  ? [
                      BoxShadow(
                        color: Colors.teal.withOpacity(0.3),
                        blurRadius: 6,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                "$day",
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                  color: isCompleted
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final today = DateTime.now();
    int denominator = daysInMonth;
    if (_displayYear == today.year && _displayMonth == today.month) {
      denominator = today.day;
    } else if (_displayYear > today.year || (_displayYear == today.year && _displayMonth > today.month)) {
      denominator = 0;
    }

    final double consistencyRate = denominator > 0 ? (completedThisMonth / denominator) * 100 : 0.0;

    return Dialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380, maxHeight: 480),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with icon
            Row(
              children: [
                Text(widget.habit.iconEmoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${widget.habit.name} Tracker",
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Monthly visual calendar view",
                        style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              ],
            ),
            const SizedBox(height: 20),

            // Month navigation row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 14),
                  onPressed: _prevMonth,
                ),
                Text(
                  "${_monthsNames[_displayMonth - 1]} $_displayYear",
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: textThemeColor,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, size: 14),
                  onPressed: _nextMonth,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Calendar grid
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.0,
                ),
                itemCount: dayWidgets.length,
                itemBuilder: (context, index) => dayWidgets[index],
              ),
            ),
            const SizedBox(height: 16),

            // Consistency stats
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.teal.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text("Logged Days", style: TextStyle(fontSize: 9.5, color: Colors.grey, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        "$completedThisMonth days",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 24, color: Colors.teal.withOpacity(0.12)),
                  Column(
                    children: [
                      const Text("Consistency", style: TextStyle(fontSize: 9.5, color: Colors.grey, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        "${consistencyRate.toStringAsFixed(0)}%",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
