import 'package:flutter/material.dart';
import '../models/habit.dart';

class HabitTrackerCard extends StatelessWidget {
  final List<HabitDefinition> availableHabits;
  final List<dynamic> allHabitLogs;
  final bool isTwilight;
  final VoidCallback onAddHabitRequested;
  final Function(HabitDefinition) onHabitLogged;
  final Function(String, DateTime) onHabitLogTimeUpdated;
  final Function(String) onHabitLogDeleted;
  final Function(HabitDefinition, DateTime) onHabitLoggedAtTime;
  final Function(HabitDefinition) onHabitDeletedPermanently;

  const HabitTrackerCard({
    super.key,
    required this.availableHabits,
    required this.allHabitLogs,
    required this.isTwilight,
    required this.onAddHabitRequested,
    required this.onHabitLogged,
    required this.onHabitLogTimeUpdated,
    required this.onHabitLogDeleted,
    required this.onHabitLoggedAtTime,
    required this.onHabitDeletedPermanently,
  });

  String _formatDateTime(DateTime dt) {
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final weekday = weekdays[dt.weekday - 1];
    final month = months[dt.month - 1];
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return "$weekday, $month ${dt.day} - $formattedHour:$minute $period";
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              " What did you do today ?",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isTwilight ? Colors.white70 : Colors.black87,
              ),
            ),
            TextButton.icon(
              onPressed: onAddHabitRequested,
              icon: const Icon(Icons.add_circle_outline, size: 16, color: Colors.teal),
              label: const Text("Custom", style: TextStyle(fontSize: 12, color: Colors.teal)),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
              ),
            )
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: availableHabits.map((habit) {
            // Find today's logs for count and time label
            final todayLogs = allHabitLogs.where((log) =>
              log.occurrenceDate.year == today.year &&
              log.occurrenceDate.month == today.month &&
              log.occurrenceDate.day == today.day &&
              (log.habitId == habit.id || log.habitId == habit.name)
            ).toList();

            final count = todayLogs.length;
            final isSelected = count > 0;

            String timeLabel = '';
            if (isSelected) {
              final lastLog = todayLogs.last;
              final hour = lastLog.occurrenceDate.hour;
              final minute = lastLog.occurrenceDate.minute.toString().padLeft(2, '0');
              final period = hour >= 12 ? 'PM' : 'AM';
              final formattedHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
              timeLabel = " ($count - $formattedHour:$minute $period)";
            }

            return GestureDetector(
              onTap: () => onHabitLogged(habit),
              onLongPress: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return StatefulBuilder(
                      builder: (context, setDialogState) {
                        final isDark = Theme.of(context).brightness == Brightness.dark;
                        
                        // Query all logs of this habit in the last 7 days
                        final cutoff = DateTime.now().subtract(const Duration(days: 7));
                        final recentLogs = allHabitLogs.where((log) =>
                          (log.habitId == habit.id || log.habitId == habit.name) &&
                          log.occurrenceDate.isAfter(cutoff)
                        ).toList()..sort((a, b) => b.occurrenceDate.compareTo(a.occurrenceDate));

                        final isDefault = ['eating', 'napping', 'studying', 'gardening', 'stepping_out', 'exercise', 'seizure'].contains(habit.id);

                        return AlertDialog(
                          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          title: Row(
                            children: [
                              Text(habit.iconEmoji, style: const TextStyle(fontSize: 22)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Manage ${habit.name}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          content: SizedBox(
                            width: double.maxFinite,
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      final pickedDate = await showDatePicker(
                                        context: context,
                                        initialDate: DateTime.now(),
                                        firstDate: DateTime.now().subtract(const Duration(days: 7)),
                                        lastDate: DateTime.now(),
                                      );
                                      if (pickedDate != null) {
                                        final pickedTime = await showTimePicker(
                                          context: context,
                                          initialTime: TimeOfDay.now(),
                                        );
                                        if (pickedTime != null) {
                                          final finalDateTime = DateTime(
                                            pickedDate.year,
                                            pickedDate.month,
                                            pickedDate.day,
                                            pickedTime.hour,
                                            pickedTime.minute,
                                          );
                                          onHabitLoggedAtTime(habit, finalDateTime);
                                          Navigator.pop(context);
                                        }
                                      }
                                    },
                                    icon: const Icon(Icons.more_time, size: 16),
                                    label: const Text("Log at Custom Time (Last 7 Days)"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal.shade500,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Text(
                                    "Recent Logs (Last 7 Days):",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: isDark ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (recentLogs.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      child: Text(
                                        "No logs recorded in the past week.",
                                        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey.shade500),
                                        textAlign: TextAlign.center,
                                      ),
                                    )
                                  else
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: recentLogs.length,
                                      itemBuilder: (context, index) {
                                        final log = recentLogs[index];
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  _formatDateTime(log.occurrenceDate),
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    color: isDark ? Colors.white70 : Colors.black87,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.edit, size: 15, color: Colors.teal),
                                                onPressed: () async {
                                                  final pickedDate = await showDatePicker(
                                                    context: context,
                                                    initialDate: log.occurrenceDate,
                                                    firstDate: DateTime.now().subtract(const Duration(days: 7)),
                                                    lastDate: DateTime.now(),
                                                  );
                                                  if (pickedDate != null) {
                                                    final pickedTime = await showTimePicker(
                                                      context: context,
                                                      initialTime: TimeOfDay.fromDateTime(log.occurrenceDate),
                                                    );
                                                    if (pickedTime != null) {
                                                      final finalDateTime = DateTime(
                                                        pickedDate.year,
                                                        pickedDate.month,
                                                        pickedDate.day,
                                                        pickedTime.hour,
                                                        pickedTime.minute,
                                                      );
                                                      onHabitLogTimeUpdated(log.id, finalDateTime);
                                                      Navigator.pop(context);
                                                    }
                                                  }
                                                },
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                              ),
                                              const SizedBox(width: 8),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                                onPressed: () {
                                                  onHabitLogDeleted(log.id);
                                                  Navigator.pop(context);
                                                },
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                          actions: [
                            if (!isDefault)
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  onHabitDeletedPermanently(habit);
                                },
                                child: const Text("Delete Custom Routine Permanently", style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Close", style: TextStyle(color: Colors.grey)),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (habit.id == 'seizure' ? Colors.redAccent.withOpacity(0.8) : Colors.teal.shade400.withOpacity(0.85))
                      : (isTwilight
                      ? Colors.white.withOpacity(0.03)
                      : Colors.white.withOpacity(0.8)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? (habit.id == 'seizure' ? Colors.redAccent : Colors.teal.shade300)
                        : (isTwilight
                        ? Colors.white.withOpacity(0.05)
                        : Colors.teal.withOpacity(0.1)),
                    width: 1.2,
                  ),
                ),
                child: Text(
                  "${habit.iconEmoji} ${habit.name}$timeLabel",
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? Colors.white
                        : (isTwilight ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}