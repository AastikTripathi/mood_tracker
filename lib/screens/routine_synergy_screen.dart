import 'package:flutter/material.dart';
import '../models/thought.dart';
import '../models/habit.dart';
import '../models/physical_log.dart';
import '../services/database_service.dart';
import '../widgets/habit_history_calendar_dialog.dart';

const Color emerald = Color(0xFF10B981);

class RoutineSynergyScreen extends StatefulWidget {
  final List<Thought> historyThoughts;
  final List<HabitDefinition> availableHabits;
  final List<HabitLog> allHabitLogs;
  final List<PhysicalLog> physicalLogs;
  final bool isTwilight;

  const RoutineSynergyScreen({
    super.key,
    required this.historyThoughts,
    required this.availableHabits,
    required this.allHabitLogs,
    required this.physicalLogs,
    required this.isTwilight,
  });

  @override
  State<RoutineSynergyScreen> createState() => _RoutineSynergyScreenState();
}

class _RoutineSynergyScreenState extends State<RoutineSynergyScreen> {
  final DatabaseService _db = DatabaseService();
  Map<String, dynamic>? _habitMetrics;
  bool _isLoading = true;
  DateTime _activeDate = DateTime.now(); // Currently selected date to view week for

  @override
  void initState() {
    super.initState();
    _db.init().then((_) {
      if (mounted) {
        setState(() {
          _habitMetrics = _db.calculateHabitMetrics();
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _selectWeekCalendar(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark || widget.isTwilight;
    final textThemeColor = isDark ? Colors.white : Colors.black87;

    final picked = await showDatePicker(
      context: context,
      initialDate: _activeDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.teal.shade400,
              onPrimary: Colors.white,
              surface: isDark ? const Color(0xFF1E293B) : Colors.white,
              onSurface: textThemeColor,
            ),
            dialogBackgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _activeDate = picked;
      });
    }
  }

  String _formatWeekRange(DateTime start, DateTime end) {
    final List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return "${start.day} ${months[start.month - 1]} - ${end.day} ${months[end.month - 1]}";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark || widget.isTwilight;
    final cardBg = isDark ? Colors.white.withOpacity(0.04) : Colors.white;
    final textThemeColor = isDark ? Colors.white70 : Colors.black87;

    // Calculate Monday and Sunday for the active week (Monday = day 1, Sunday = day 7)
    int daysToSubtract = _activeDate.weekday - 1;
    DateTime monday = DateTime(_activeDate.year, _activeDate.month, _activeDate.day).subtract(Duration(days: daysToSubtract));
    DateTime sunday = monday.add(const Duration(days: 6));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Routine & Synergy Insights", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.teal))
            : GestureDetector(
                onLongPress: () => _selectWeekCalendar(context),
                behavior: HitTestBehavior.opaque,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Synergy & Routine Stagnation Card
                      _buildHabitSynergyAndDecayCard(isDark, cardBg, textThemeColor),
                      const SizedBox(height: 24),

                      // 2. Routine & Habit Consistency Section Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionHeader("Routine & Habit Consistency", Icons.loop, isDark),
                          GestureDetector(
                            onTap: () => _selectWeekCalendar(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.teal.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.teal.withOpacity(0.2)),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    _formatWeekRange(monday, sunday),
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.calendar_month, size: 12, color: Colors.teal),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      ...widget.availableHabits.where((h) => h.id != 'seizure').map((habit) => _buildHabitDetailCard(habit, monday, isDark, cardBg)),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.teal),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildHabitDetailCard(HabitDefinition habit, DateTime monday, bool isDark, Color cardBg) {
    final logsForHabit = widget.allHabitLogs.where((l) => l.habitId == habit.id || l.habitId == habit.name).toList();
    final totalCheckins = logsForHabit.length;

    // Calculate average mood on completed vs skipped days
    double moodWhenCompleted = 0.0;
    int completedDaysCount = 0;
    double moodWhenSkipped = 0.0;
    int skippedDaysCount = 0;

    for (var thought in widget.historyThoughts) {
      final d = thought.timestamp;
      final completed = widget.allHabitLogs.any((l) =>
          (l.habitId == habit.id || l.habitId == habit.name) &&
          l.occurrenceDate.year == d.year &&
          l.occurrenceDate.month == d.month &&
          l.occurrenceDate.day == d.day);

      if (completed) {
        moodWhenCompleted += thought.moodScore;
        completedDaysCount++;
      } else {
        moodWhenSkipped += thought.moodScore;
        skippedDaysCount++;
      }
    }

    if (completedDaysCount > 0) moodWhenCompleted /= completedDaysCount;
    if (skippedDaysCount > 0) moodWhenSkipped /= skippedDaysCount;
    final moodLift = moodWhenCompleted - moodWhenSkipped;

    return GestureDetector(
      onTap: () {
        HabitHistoryCalendarDialog.show(
          context,
          habit: habit,
          allHabitLogs: widget.allHabitLogs,
          isTwilight: widget.isTwilight,
        );
      },
      onLongPress: () {
        HabitHistoryCalendarDialog.show(
          context,
          habit: habit,
          allHabitLogs: widget.allHabitLogs,
          isTwilight: widget.isTwilight,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.teal.withOpacity(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(habit.iconEmoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    habit.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                Icon(Icons.calendar_month, size: 16, color: Colors.teal.shade300),
              ],
            ),
            const SizedBox(height: 14),

            // Render the consistency timeline graph
            _buildHabitTimelineGraph(habit, monday, isDark),

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Completed", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text("$totalCheckins times total", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("Mood impact", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      moodLift == 0
                          ? "Neutral"
                          : (moodLift > 0 ? "+${moodLift.toStringAsFixed(1)} mood score" : "${moodLift.toStringAsFixed(1)} mood score"),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: moodLift > 0 ? emerald : (moodLift < 0 ? Colors.redAccent : Colors.grey),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (moodLift > 0.5) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: emerald.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.favorite, size: 12, color: emerald),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Completing this routine boosts your mood on average.",
                        style: TextStyle(fontSize: 10.5, color: emerald, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHabitTimelineGraph(HabitDefinition habit, DateTime monday, bool isDark) {
    final List<Widget> bars = [];
    final List<String> weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    for (int i = 0; i < 7; i++) {
      final day = monday.add(Duration(days: i));
      final completed = widget.allHabitLogs.any((l) =>
          (l.habitId == habit.id || l.habitId == habit.name) &&
          l.occurrenceDate.year == day.year &&
          l.occurrenceDate.month == day.month &&
          l.occurrenceDate.day == day.day);

      final weekdayName = weekdays[day.weekday - 1];

      bars.add(
        Expanded(
          child: Column(
            children: [
              Container(
                height: 30,
                width: 14,
                decoration: BoxDecoration(
                  color: completed ? emerald : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: completed ? const Center(child: Icon(Icons.check, size: 10, color: Colors.white)) : null,
              ),
              const SizedBox(height: 6),
              Text(
                weekdayName,
                style: const TextStyle(fontSize: 9.5, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: bars,
    );
  }

  Widget _buildHabitSynergyAndDecayCard(bool isDark, Color cardBg, Color textColor) {
    if (_habitMetrics == null) return const SizedBox.shrink();

    final metrics = _habitMetrics!;
    final synergies = metrics['synergies'] as Map<String, double>;
    final decays = metrics['decays'] as Map<String, double>;

    if (synergies.isEmpty && decays.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.teal.withOpacity(0.08)),
        ),
        child: const Center(
          child: Text(
            "Routine patterns will appear once you have logged 10+ days of entries.",
            style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.teal.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.hub_outlined, size: 20, color: Colors.teal),
              const SizedBox(width: 8),
              Text(
                "Synergy & Stagnation Warnings",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Compound routines that boost you when completed together, and flags when routines begin to lose baseline impact.",
            style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey, height: 1.4),
          ),
          if (synergies.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              "Synergistic Combinations",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : Colors.grey),
            ),
            const SizedBox(height: 10),
            ...synergies.entries.map((entry) {
              final parts = entry.key.split('+');
              final h1 = widget.availableHabits.cast<HabitDefinition?>().firstWhere((h) => h!.id == parts[0] || h.name == parts[0], orElse: () => null);
              final h2 = widget.availableHabits.cast<HabitDefinition?>().firstWhere((h) => h!.id == parts[1] || h.name == parts[1], orElse: () => null);
              if (h1 == null || h2 == null) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        "${h1.iconEmoji} ${h1.name} + ${h2.iconEmoji} ${h2.name}",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text("+${entry.value.toStringAsFixed(1)} boost", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
          if (decays.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Text(
              "Routine Stagnation Warnings",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orangeAccent.shade200),
            ),
            const SizedBox(height: 8),
            ...decays.entries.map((entry) {
              final h = widget.availableHabits.cast<HabitDefinition?>().firstWhere((habit) => habit!.id == entry.key || habit.name == entry.key, orElse: () => null);
              if (h == null) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orangeAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Your response to ${h.iconEmoji} ${h.name} has cooled down recently. Consider updating this habit to refresh its emotional benefits.",
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87, height: 1.4),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }
}
