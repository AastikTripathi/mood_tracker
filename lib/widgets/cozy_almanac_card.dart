import 'package:flutter/material.dart';
import '../models/thought.dart';
import '../models/habit.dart';
import '../screens/routine_synergy_screen.dart';
import 'day_timeline_dialog.dart';

class CozyAlmanacCard extends StatefulWidget {
  final List<Thought> historyThoughts;
  final List<dynamic> allHabitLogs;
  final List<dynamic> availableHabits;
  final DateTime selectedDate;
  final Thought? selectedThought;
  final List<String> selectedHabits;
  final Function(DateTime) onDateSelected;
  final bool isTwilight;

  const CozyAlmanacCard({
    super.key,
    required this.historyThoughts,
    required this.allHabitLogs,
    required this.availableHabits,
    required this.selectedDate,
    required this.selectedThought,
    required this.selectedHabits,
    required this.onDateSelected,
    required this.isTwilight,
  });

  @override
  State<CozyAlmanacCard> createState() => _CozyAlmanacCardState();
}

class _CozyAlmanacCardState extends State<CozyAlmanacCard> {
  late int _displayYear;
  late int _displayMonth;

  final List<String> _monthsNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    _displayYear = widget.selectedDate.year;
    _displayMonth = widget.selectedDate.month;
  }

  @override
  Widget build(BuildContext context) {
    final bool isCardDark = widget.isTwilight;
    final cardBg = isCardDark ? const Color(0xFF1E293B) : Colors.white;

    // 1. Calculate Calendar parameters
    final firstDayOfMonth = DateTime(_displayYear, _displayMonth, 1);
    final daysInMonth = DateTime(_displayYear, _displayMonth + 1, 0).day;
    
    // Adjust weekday mapping to start week on Monday (1 = Mon, 7 = Sun)
    final int emptyPrefixDays = firstDayOfMonth.weekday - 1;

    // Build the grid list items
    final List<Widget> gridItems = [];

    // Weekday headers
    final List<String> weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    for (var dayName in weekdays) {
      gridItems.add(
        Center(
          child: Text(
            dayName,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isCardDark ? Colors.white38 : Colors.grey.shade500,
            ),
          ),
        ),
      );
    }

    // Add empty spacer placeholders before day 1
    for (int i = 0; i < emptyPrefixDays; i++) {
      gridItems.add(const SizedBox.shrink());
    }

    // Add day cells
    for (int dayNumber = 1; dayNumber <= daysInMonth; dayNumber++) {
      final targetDate = DateTime(_displayYear, _displayMonth, dayNumber);

      final dayThoughts = widget.historyThoughts.where(
            (t) => t.timestamp.year == targetDate.year && t.timestamp.month == targetDate.month && t.timestamp.day == targetDate.day,
      ).toList();

      final dayHabits = widget.allHabitLogs.where(
            (l) => l.occurrenceDate.year == targetDate.year && l.occurrenceDate.month == targetDate.month && l.occurrenceDate.day == targetDate.day,
      ).toList();

      final bool hasData = dayThoughts.isNotEmpty || dayHabits.isNotEmpty;
      final bool isSelected = widget.selectedDate.year == targetDate.year && 
                             widget.selectedDate.month == targetDate.month && 
                             widget.selectedDate.day == targetDate.day;

      Color blockColor = isCardDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03);
      if (dayThoughts.isNotEmpty) {
        final sum = dayThoughts.map((t) => t.moodScore).reduce((a, b) => a + b);
        final score = (sum / dayThoughts.length).round();
        if (score <= 2) {
          blockColor = const Color(0xFF3F51B5).withOpacity(isCardDark ? 0.5 : 0.25); // Overwhelmed (Indigo)
        } else if (score <= 4) {
          blockColor = const Color(0xFF1E88E5).withOpacity(isCardDark ? 0.6 : 0.35); // Low (Ocean Blue)
        } else if (score <= 6) {
          blockColor = const Color(0xFF009688).withOpacity(isCardDark ? 0.65 : 0.4); // Okay (Teal)
        } else if (score <= 8) {
          blockColor = const Color(0xFF4CAF50).withOpacity(isCardDark ? 0.7 : 0.45); // Grounded (Green)
        } else {
          blockColor = const Color(0xFFFFC107).withOpacity(isCardDark ? 0.8 : 0.55); // Radiant (Gold/Amber)
        }
      } else if (dayHabits.isNotEmpty) {
        blockColor = Colors.teal.withOpacity(isCardDark ? 0.15 : 0.08); // Activity only
      }

      gridItems.add(
        GestureDetector(
          onTap: () {
            widget.onDateSelected(targetDate);
            if (hasData) {
              DayTimelineDialog.show(
                context,
                date: targetDate,
                allThoughts: widget.historyThoughts,
                allHabitLogs: widget.allHabitLogs,
                availableHabits: widget.availableHabits,
              );
            }
          },
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: blockColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? Colors.amber.shade400
                    : (hasData ? Colors.teal.withOpacity(0.15) : Colors.transparent),
                width: isSelected ? 1.8 : 1.0,
              ),
            ),
            child: Text(
              "$dayNumber",
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: hasData
                    ? (isCardDark ? Colors.white : Colors.black87)
                    : (isCardDark ? Colors.white54 : Colors.black54),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.teal.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row with Title and Icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Sanctuary Almanac",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                  color: isCardDark ? Colors.white : Colors.black87,
                ),
              ),
              Icon(
                Icons.calendar_month,
                size: 16,
                color: isCardDark ? Colors.white38 : Colors.black38,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Center Pill Styled Dropdowns Selector
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              decoration: BoxDecoration(
                color: isCardDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isCardDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Month Dropdown
                  DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _displayMonth,
                      isDense: true,
                      dropdownColor: isCardDark ? const Color(0xFF1E293B) : Colors.white,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: isCardDark ? Colors.teal.shade300 : Colors.teal.shade700,
                      ),
                      icon: const Icon(Icons.arrow_drop_down, size: 18, color: Colors.teal),
                      items: List.generate(12, (index) {
                        return DropdownMenuItem<int>(
                          value: index + 1,
                          child: Text(_monthsNames[index]),
                        );
                      }),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _displayMonth = val;
                          });
                        }
                      },
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 12,
                    color: isCardDark ? Colors.white24 : Colors.black12,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  // Year Dropdown
                  DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _displayYear,
                      isDense: true,
                      dropdownColor: isCardDark ? const Color(0xFF1E293B) : Colors.white,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: isCardDark ? Colors.teal.shade300 : Colors.teal.shade700,
                      ),
                      icon: const Icon(Icons.arrow_drop_down, size: 18, color: Colors.teal),
                      items: List.generate(11, (index) {
                        final yearVal = DateTime.now().year - 5 + index; // e.g. 2021 to 2031
                        return DropdownMenuItem<int>(
                          value: yearVal,
                          child: Text("$yearVal"),
                        );
                      }),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _displayYear = val;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Gregorian Grid View Layout
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: gridItems.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemBuilder: (context, index) => gridItems[index],
          ),
          const SizedBox(height: 16),

          // Latest Entry Summary
          if (widget.historyThoughts.isNotEmpty) ...[
            () {
              final sorted = List<Thought>.from(widget.historyThoughts)
                ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
              final latestThought = sorted.first;

              final List<String> latestHabits = [];
              final date = latestThought.timestamp;
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
                    latestHabits.add(matchedHabit.iconEmoji);
                  }
                }
              }
              final cleanLatestHabits = latestHabits.toSet().toList();

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCardDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.teal.withOpacity(0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Latest check-in: ${latestThought.timestamp.day}/${latestThought.timestamp.month}/${latestThought.timestamp.year}",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isCardDark ? Colors.white38 : Colors.grey.shade500,
                          ),
                        ),
                        Text(
                          "Mood: ${latestThought.moodScore}/10",
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      latestThought.textContent,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontStyle: FontStyle.italic,
                        color: isCardDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    if (cleanLatestHabits.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: cleanLatestHabits.map((emoji) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(emoji, style: const TextStyle(fontSize: 16)),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              );
            }(),
          ],

          // Action button to open Routine & Synergy Insights
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RoutineSynergyScreen(
                    historyThoughts: widget.historyThoughts,
                    availableHabits: List<HabitDefinition>.from(widget.availableHabits),
                    allHabitLogs: List<HabitLog>.from(widget.allHabitLogs),
                    physicalLogs: const [],
                    isTwilight: widget.isTwilight,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.hub_outlined, size: 14, color: Colors.teal),
            label: const Text(
              "Routine & Synergy Insights",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.teal.withOpacity(0.2)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              minimumSize: const Size.fromHeight(40),
            ),
          ),
        ],
      ),
    );
  }
}