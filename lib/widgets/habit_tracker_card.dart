import 'package:flutter/material.dart';
import '../models/habit.dart';

class HabitTrackerCard extends StatelessWidget {
  final List<HabitDefinition> availableHabits;
  final Set<String> completedHabits;
  final bool isTwilight;
  final VoidCallback onAddHabitRequested;
  final Function(HabitDefinition, bool) onHabitToggled;

  const HabitTrackerCard({
    super.key,
    required this.availableHabits,
    required this.completedHabits,
    required this.isTwilight,
    required this.onAddHabitRequested,
    required this.onHabitToggled,
  });

  @override
  Widget build(BuildContext context) {
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
            final isSelected = completedHabits.contains(habit.id) || completedHabits.contains(habit.name);
            return GestureDetector(
              onTap: () => onHabitToggled(habit, isSelected),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.teal.shade400.withOpacity(0.85)
                      : (isTwilight
                      ? Colors.white.withOpacity(0.03)
                      : Colors.white.withOpacity(0.8)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? Colors.teal.shade300
                        : (isTwilight
                        ? Colors.white.withOpacity(0.05)
                        : Colors.teal.withOpacity(0.1)),
                    width: 1.2,
                  ),
                ),
                child: Text(
                  "${habit.iconEmoji} ${habit.name}",
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