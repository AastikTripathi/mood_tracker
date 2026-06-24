import 'package:flutter/material.dart';
import '../models/thought.dart';
import '../models/habit.dart';
import '../models/physical_log.dart';
import '../services/database_service.dart';

const Color emerald = Color(0xFF10B981);

class DetailedAnalyticsScreen extends StatefulWidget {
  final List<Thought> historyThoughts;
  final List<HabitDefinition> availableHabits;
  final List<HabitLog> allHabitLogs;
  final List<PhysicalLog> physicalLogs;
  final bool isTwilight;

  const DetailedAnalyticsScreen({
    super.key,
    required this.historyThoughts,
    required this.availableHabits,
    required this.allHabitLogs,
    required this.physicalLogs,
    required this.isTwilight,
  });

  @override
  State<DetailedAnalyticsScreen> createState() => _DetailedAnalyticsScreenState();
}

class _DetailedAnalyticsScreenState extends State<DetailedAnalyticsScreen> {
  String _selectedTimeline = 'Week'; // Timeline filter: 'Week', 'Month', 'Year'
  DateTime? _selectedTimetableDate;
  final DatabaseService _db = DatabaseService();
  
  Map<String, dynamic>? _regressionResults;
  Map<String, dynamic>? _habitMetrics;
  Map<String, dynamic>? _resilienceRoadmap;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  void _loadMetrics() {
    _db.init().then((_) {
      if (mounted) {
        setState(() {
          _regressionResults = _db.performRidgeRegression();
          _habitMetrics = _db.calculateHabitMetrics();
          _resilienceRoadmap = _db.findResilienceRoadmap();
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark || widget.isTwilight;
    final cardBg = isDark ? Colors.white.withOpacity(0.04) : Colors.white;
    final textThemeColor = isDark ? Colors.white70 : Colors.black87;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Deep Sanctuary Insights", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Resilience Roadmap Card
                    _buildResilienceRoadmapCard(isDark, cardBg, textThemeColor),

                    // 2. Ridge Regression Isolated Drivers Card
                    _buildRidgeRegressionCard(isDark, cardBg, textThemeColor),

                    // 3. Routine Synergy & Decay Card
                    _buildHabitSynergyAndDecayCard(isDark, cardBg, textThemeColor),

                    // Timeline Selector Row
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.teal.withOpacity(0.12)),
                ),
                child: Row(
                  children: ['Week', 'Month', 'Year'].map((timeline) {
                    final isSelected = _selectedTimeline == timeline;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedTimeline = timeline;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.teal : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              timeline,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              _buildSectionHeader("Routine & Habit Consistency", Icons.loop, isDark),
              const SizedBox(height: 12),
              ...widget.availableHabits.map((habit) => _buildHabitDetailCard(habit, isDark, cardBg)),
              const SizedBox(height: 24),

              _buildSectionHeader("Symptom & Pattern Tracking", Icons.analytics, isDark),
              const SizedBox(height: 12),
              _buildSymptomTrackingCard(isDark, cardBg, textThemeColor),
              const SizedBox(height: 24),

              _buildSectionHeader("Menstrual & Pain Progression Timeline", Icons.timeline, isDark),
              const SizedBox(height: 12),
              _buildCyclePainProgressionGraph(isDark, cardBg),
              const SizedBox(height: 24),

              _buildSectionHeader("Habits & Check-in Timetable", Icons.schedule, isDark),
              const SizedBox(height: 12),
              _buildHabitTimetable(isDark, cardBg),
              const SizedBox(height: 40),
            ],
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

  Widget _buildHabitDetailCard(HabitDefinition habit, bool isDark, Color cardBg) {
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

    return Container(
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
            ],
          ),
          const SizedBox(height: 14),

          // Render the consistency timeline graph
          _buildHabitTimelineGraph(habit, isDark),

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
    );
  }

  Widget _buildHabitTimelineGraph(HabitDefinition habit, bool isDark) {
    final now = DateTime.now();

    if (_selectedTimeline == 'Week') {
      // Last 7 days columns
      final List<Widget> bars = [];
      final List<String> weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

      for (int i = 6; i >= 0; i--) {
        final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
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
    } else if (_selectedTimeline == 'Month') {
      // Last 4 weeks completion rates
      final List<Widget> bars = [];

      for (int w = 3; w >= 0; w--) {
        int completedCount = 0;
        final startOffset = w * 7;

        for (int i = 0; i < 7; i++) {
          final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: startOffset + i));
          if (widget.allHabitLogs.any((l) =>
              (l.habitId == habit.id || l.habitId == habit.name) &&
              l.occurrenceDate.year == day.year &&
              l.occurrenceDate.month == day.month &&
              l.occurrenceDate.day == day.day)) {
            completedCount++;
          }
        }

        final completionRate = completedCount / 7.0;

        bars.add(
          Expanded(
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(
                      height: 50,
                      width: 24,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    Container(
                      height: 50 * completionRate,
                      width: 24,
                      decoration: BoxDecoration(
                        color: emerald,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  w == 0 ? "Now" : "W-$w",
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
    } else {
      // Year: Last 12 months completion rates
      final List<Widget> bars = [];
      final monthsList = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

      for (int m = 11; m >= 0; m--) {
        final monthDate = DateTime(now.year, now.month - m, 1);
        int totalDaysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
        int completedCount = 0;

        for (int d = 1; d <= totalDaysInMonth; d++) {
          final day = DateTime(monthDate.year, monthDate.month, d);
          if (widget.allHabitLogs.any((l) =>
              (l.habitId == habit.id || l.habitId == habit.name) &&
              l.occurrenceDate.year == day.year &&
              l.occurrenceDate.month == day.month &&
              l.occurrenceDate.day == day.day)) {
            completedCount++;
          }
        }

        final completionRate = completedCount / totalDaysInMonth;
        final monthInitial = monthsList[monthDate.month - 1];

        bars.add(
          Expanded(
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(
                      height: 60,
                      width: 12,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      height: 60 * completionRate,
                      width: 12,
                      decoration: BoxDecoration(
                        color: emerald,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  monthInitial,
                  style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold),
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
  }

  Widget _buildSymptomTrackingCard(bool isDark, Color cardBg, Color textColor) {
    // Calculate pain statistics
    final painDays = widget.physicalLogs.where((l) => l.customPainLevel != null && l.customPainLevel! > 0).toList();
    double avgPain = 0.0;
    if (painDays.isNotEmpty) {
      avgPain = painDays.map((l) => l.customPainLevel!).reduce((a, b) => a + b) / painDays.length;
    }

    // Calculate seizure/pattern counts
    final seizureLogs = widget.physicalLogs.where((l) => l.customSeizuresCount != null && l.customSeizuresCount! > 0).toList();
    int totalSeizures = 0;
    for (var l in seizureLogs) {
      totalSeizures += l.customSeizuresCount!;
    }

    // Mood when pain is active vs inactive
    double moodHighPain = 0.0;
    int highPainCount = 0;
    double moodLowPain = 0.0;
    int lowPainCount = 0;

    for (var thought in widget.historyThoughts) {
      final d = thought.timestamp;
      final p = widget.physicalLogs.cast<PhysicalLog?>().firstWhere(
            (log) => log!.date.year == d.year && log.date.month == d.month && log.date.day == d.day,
        orElse: () => null,
      );
      if (p != null) {
        final pain = p.customPainLevel ?? 0.0;
        if (pain >= 4.0) {
          moodHighPain += thought.moodScore;
          highPainCount++;
        } else {
          moodLowPain += thought.moodScore;
          lowPainCount++;
        }
      }
    }

    if (highPainCount > 0) moodHighPain /= highPainCount;
    if (lowPainCount > 0) moodLowPain /= lowPainCount;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _buildMetricBlock(
                  "Avg Pain Index",
                  avgPain > 0 ? "${avgPain.toStringAsFixed(1)} / 10" : "None logged",
                  Icons.healing,
                  Colors.orangeAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricBlock(
                  "Seizure Events",
                  totalSeizures > 0 ? "$totalSeizures occurrences" : "None logged",
                  Icons.flash_on,
                  Colors.redAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Text(
            "Headspace under physical burden:",
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : Colors.grey),
          ),
          const SizedBox(height: 12),
          _buildMoodComparisonRow(
            title: "On high chronic pain days (Index >= 4.0)",
            score: moodHighPain,
            color: Colors.orangeAccent,
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _buildMoodComparisonRow(
            title: "On low/no chronic pain days",
            score: moodLowPain,
            color: emerald,
            isDark: isDark,
          ),
          if (totalSeizures > 0) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: Colors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "You logged $totalSeizures seizure checkins. Monitor these patterns against sleep loss and cycles below to notice triggers.",
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black87, height: 1.4),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }



  Widget _buildMetricBlock(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMoodComparisonRow({
    required String title,
    required double score,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white60 : Colors.black87)),
            Text(
              score > 0 ? "${score.toStringAsFixed(1)} / 10" : "N/A",
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: score > 0 ? color : Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (score > 0)
          Stack(
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              FractionallySizedBox(
                widthFactor: (score / 10.0).clamp(0.05, 1.0),
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }


  Widget _buildCyclePainProgressionGraph(bool isDark, Color cardBg) {
    final sortedLogs = List<PhysicalLog>.from(widget.physicalLogs)
      ..sort((a, b) => a.date.compareTo(b.date));
    
    // Take the last 7 entries
    final last7Logs = sortedLogs.length > 7 ? sortedLogs.sublist(sortedLogs.length - 7) : sortedLogs;

    if (last7Logs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.teal.withOpacity(0.08)),
        ),
        child: const Center(
          child: Text(
            "Log your daily mood and symptoms to plot progression graphs here 🌸",
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
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
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: last7Logs.map((log) {
              final painVal = log.customPainLevel ?? 0.0;
              final isPeriod = log.isPeriodDay || log.flowLevel != 'None';
              final double painHeight = 60.0 * (painVal / 10.0);
              final dateLabel = "${log.date.day}/${log.date.month}";

              return Column(
                children: [
                  if (painVal > 0)
                    Text(
                      painVal.toStringAsFixed(0),
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
                    )
                  else
                    const Text("-", style: TextStyle(fontSize: 9, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Container(
                        width: 16,
                        height: 60,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      if (painVal > 0)
                        Container(
                          width: 16,
                          height: painHeight == 0 ? 4 : painHeight,
                          decoration: BoxDecoration(
                            color: Colors.orangeAccent.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      if (isPeriod)
                        Positioned(
                          top: 4,
                          child: Icon(
                            Icons.water_drop,
                            size: 10,
                            color: log.flowLevel == 'Heavy' 
                                ? Colors.pink
                                : (log.flowLevel == 'Medium' ? Colors.pinkAccent : Colors.pink.shade200),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    dateLabel,
                    style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.85), borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4),
              const Text("Pain Severity", style: TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(width: 16),
              const Icon(Icons.water_drop, size: 10, color: Colors.pinkAccent),
              const SizedBox(width: 4),
              const Text("Active Cycle", style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          )
        ],
      ),
    );
  }

  String _formatFullDate(DateTime dt) {
    final weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final weekdayStr = weekdays[dt.weekday % 7];
    final monthStr = months[dt.month - 1];
    return "$weekdayStr, $monthStr ${dt.day}, ${dt.year}";
  }

  Widget _buildHabitTimetable(bool isDark, Color cardBg) {
    final today = DateTime.now();
    // We want to show a 7x13 grid representing the last 13 weeks of habit check-ins.
    // Ensure the last column ends on Saturday of the current week to align rows (Sunday to Saturday).
    final endOfGrid = today.add(Duration(days: 6 - (today.weekday % 7)));
    final startDate = endOfGrid.subtract(const Duration(days: 13 * 7 - 1));

    // Group habit logs by normalized date yyyy-MM-dd
    final Map<String, List<HabitLog>> logsByDate = {};
    for (var log in widget.allHabitLogs) {
      final dateKey = "${log.occurrenceDate.year}-${log.occurrenceDate.month.toString().padLeft(2, '0')}-${log.occurrenceDate.day.toString().padLeft(2, '0')}";
      logsByDate.putIfAbsent(dateKey, () => []).add(log);
    }

    final activeSelectedDate = _selectedTimetableDate ?? today;
    final selectedDateKey = "${activeSelectedDate.year}-${activeSelectedDate.month.toString().padLeft(2, '0')}-${activeSelectedDate.day.toString().padLeft(2, '0')}";
    final selectedDateLogs = logsByDate[selectedDateKey] ?? [];

    // Columns of weeks (13 weeks)
    final List<List<DateTime>> gridWeeks = [];
    for (int w = 0; w < 13; w++) {
      final List<DateTime> weekDays = [];
      for (int d = 0; d < 7; d++) {
        final dayOffset = w * 7 + d;
        weekDays.add(startDate.add(Duration(days: dayOffset)));
      }
      gridWeeks.add(weekDays);
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
          // The Contribution Grid Layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day of week labels on the left
              Column(
                children: const [
                  SizedBox(height: 3),
                  Text("S", style: TextStyle(fontSize: 8.5, color: Colors.grey, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text("M", style: TextStyle(fontSize: 8.5, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text("T", style: TextStyle(fontSize: 8.5, color: Colors.grey, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text("W", style: TextStyle(fontSize: 8.5, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text("T", style: TextStyle(fontSize: 8.5, color: Colors.grey, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text("F", style: TextStyle(fontSize: 8.5, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text("S", style: TextStyle(fontSize: 8.5, color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(width: 8),
              // Weeks Grid
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: gridWeeks.map((week) {
                      return Column(
                        children: week.map((day) {
                          final dateKey = "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
                          final logsForDay = logsByDate[dateKey] ?? [];
                          final count = logsForDay.length;

                          // Color intensity based on checks
                          Color cellColor;
                          if (count == 0) {
                            cellColor = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05);
                          } else if (count == 1) {
                            cellColor = isDark ? Colors.teal.shade900.withOpacity(0.5) : Colors.teal.shade100;
                          } else if (count == 2) {
                            cellColor = isDark ? Colors.teal.shade700 : Colors.teal.shade200;
                          } else if (count == 3) {
                            cellColor = isDark ? Colors.teal.shade500 : Colors.teal.shade400;
                          } else {
                            cellColor = isDark ? Colors.teal.shade300 : Colors.teal.shade700;
                          }

                          final isSelected = day.year == activeSelectedDate.year &&
                              day.month == activeSelectedDate.month &&
                              day.day == activeSelectedDate.day;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedTimetableDate = day;
                              });
                            },
                            child: Container(
                              width: 14,
                              height: 14,
                              margin: const EdgeInsets.all(2.0),
                              decoration: BoxDecoration(
                                color: cellColor,
                                borderRadius: BorderRadius.circular(3),
                                border: isSelected
                                    ? Border.all(color: Colors.orangeAccent, width: 2)
                                    : (isDark ? null : Border.all(color: Colors.black12, width: 0.5)),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Legend Row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text("Less", style: TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(width: 4),
              _buildLegendBox(isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05), isDark),
              _buildLegendBox(isDark ? Colors.teal.shade900.withOpacity(0.5) : Colors.teal.shade100, isDark),
              _buildLegendBox(isDark ? Colors.teal.shade700 : Colors.teal.shade200, isDark),
              _buildLegendBox(isDark ? Colors.teal.shade500 : Colors.teal.shade400, isDark),
              _buildLegendBox(isDark ? Colors.teal.shade300 : Colors.teal.shade700, isDark),
              const SizedBox(width: 4),
              const Text("More", style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          const Divider(height: 24),
          // Selected Day Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _formatFullDate(activeSelectedDate),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${selectedDateLogs.length} logged",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: Colors.teal),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Selected Day Details list
          if (selectedDateLogs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  "No routines checked on this day 💤",
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: isDark ? Colors.white38 : Colors.black38),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: selectedDateLogs.length,
              itemBuilder: (context, index) {
                final log = selectedDateLogs[index];
                final date = log.occurrenceDate;
                final hour = date.hour;
                final minute = date.minute.toString().padLeft(2, '0');
                final period = hour >= 12 ? 'PM' : 'AM';
                final formattedHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
                final timeStr = "$formattedHour:$minute $period";

                dynamic matchedHabit;
                for (var h in widget.availableHabits) {
                  if (h.id == log.habitId || h.name == log.habitId) {
                    matchedHabit = h;
                    break;
                  }
                }
                final name = matchedHabit != null ? matchedHabit.name : log.habitId;
                final emoji = matchedHabit != null ? matchedHabit.iconEmoji : '⚡';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Text(
                        emoji,
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          timeStr,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.teal,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildLegendBox(Color color, bool isDark) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
        border: isDark ? null : Border.all(color: Colors.black12, width: 0.5),
      ),
    );
  }

  Widget _buildResilienceRoadmapCard(bool isDark, Color cardBg, Color textColor) {
    if (_resilienceRoadmap == null) return const SizedBox.shrink();

    final roadmap = _resilienceRoadmap!;
    final startDate = roadmap['startDate'] as DateTime;
    final endDate = roadmap['endDate'] as DateTime;
    final startMood = roadmap['startMood'] as double;
    final endMood = roadmap['endMood'] as double;
    final habits = roadmap['habits'] as List<dynamic>;

    final List<HabitDefinition> matchedHabits = [];
    for (var hid in habits) {
      final match = widget.availableHabits.cast<HabitDefinition?>().firstWhere(
        (h) => h!.id == hid || h.name == hid,
        orElse: () => null,
      );
      if (match != null) matchedHabits.add(match);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.04),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.teal.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 20, color: Colors.teal),
              const SizedBox(width: 8),
              Text(
                "Your Resilience Roadmap",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "The sanctuary matched your current 2-day physical/emotional state transition to a recovery cycle from the past:",
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildRoadmapPin(startDate, startMood.toInt(), isDark),
              Expanded(
                child: Container(
                  height: 2,
                  color: Colors.teal.withOpacity(0.3),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
              _buildRoadmapPin(endDate, endMood.toInt(), isDark, isEnd: true),
            ],
          ),
          const SizedBox(height: 16),
          if (matchedHabits.isNotEmpty) ...[
            Text(
              "Here are the core routines you focused on to bounce back:",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : Colors.grey),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: matchedHabits.map((habit) {
                return Chip(
                  avatar: Text(habit.iconEmoji),
                  label: Text(
                    habit.name,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.teal.shade900),
                  ),
                  backgroundColor: isDark ? Colors.white.withOpacity(0.08) : Colors.teal.withOpacity(0.08),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Text(
              "Returning to these anchors today could help restore your balance. 🌿",
              style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white70 : Colors.black87, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRoadmapPin(DateTime date, int mood, bool isDark, {bool isEnd = false}) {
    final label = "${date.day}/${date.month}";
    final moodLabel = "$mood/10";
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isEnd ? emerald.withOpacity(0.15) : Colors.orangeAccent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isEnd ? emerald.withOpacity(0.4) : Colors.orangeAccent.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Text(
            isEnd ? "Recovered" : "Low Point",
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: isEnd ? emerald : Colors.orangeAccent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "$label ($moodLabel)",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRidgeRegressionCard(bool isDark, Color cardBg, Color textColor) {
    if (_regressionResults == null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.teal.withOpacity(0.08)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.psychology_outlined, size: 20, color: Colors.teal),
                const SizedBox(width: 8),
                Text(
                  "Isolating Your Mood Drivers",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "Tending the garden... Advanced regression analytics unlock after 10 days of entries with both thoughts and routine checks to filter out confounding variables.",
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final coeffs = _regressionResults!['coefficients'] as Map<String, double>;
    final sampleSize = _regressionResults!['sampleSize'] as int;

    final double inertia = coeffs['mood_lag'] ?? 0.0;
    final double sleepCoeff = coeffs['sleep'] ?? 0.0;
    final double sleepLagCoeff = coeffs['sleep_lag'] ?? 0.0;
    final double painCoeff = coeffs['pain'] ?? 0.0;
    final double painLagCoeff = coeffs['pain_lag'] ?? 0.0;
    final double seizuresCoeff = coeffs['seizures'] ?? 0.0;
    final double seizuresLagCoeff = coeffs['seizures_lag'] ?? 0.0;
    final double periodCoeff = coeffs['period'] ?? 0.0;

    final List<Widget> habitRows = [];
    coeffs.forEach((key, val) {
      if (key.startsWith('habit_') && val.abs() > 0.05) {
        final hid = key.replaceFirst('habit_', '');
        final match = widget.availableHabits.cast<HabitDefinition?>().firstWhere(
          (h) => h!.id == hid || h.name == hid,
          orElse: () => null,
        );
        if (match != null) {
          habitRows.add(_buildRegressionRow(
            label: "${match.iconEmoji} ${match.name}",
            value: val,
            isDark: isDark,
          ));
        }
      }
    });

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.psychology_outlined, size: 20, color: Colors.teal),
                  const SizedBox(width: 8),
                  Text(
                    "Isolating Your Mood Drivers",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.teal.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
                child: Text("N=$sampleSize days", style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.teal)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "These metrics use Ridge Regression to control for confounding parameters, separating the independent effect of each factor on your mood.",
            style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey, height: 1.4),
          ),
          const SizedBox(height: 16),
          Text(
            "Emotional & Physical Parameters",
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : Colors.grey),
          ),
          const SizedBox(height: 10),
          _buildRegressionRow(
            label: "Mood Inertia (Yesterday's Mood carryover)",
            value: inertia,
            isDark: isDark,
            helpText: "Positive means mood naturally persists; negative means rapid fluctuation.",
          ),
          _buildRegressionRow(
            label: "Today's Rest (Sleep hours today)",
            value: sleepCoeff,
            isDark: isDark,
          ),
          _buildRegressionRow(
            label: "Yesterday's Rest (Sleep lag impact)",
            value: sleepLagCoeff,
            isDark: isDark,
            helpText: "Measures carry-over effect of sleep.",
          ),
          _buildRegressionRow(
            label: "Today's Chronic Pain Index",
            value: painCoeff,
            isDark: isDark,
          ),
          _buildRegressionRow(
            label: "Yesterday's Pain Index (Pain lag impact)",
            value: painLagCoeff,
            isDark: isDark,
          ),
          if (seizuresCoeff.abs() > 0.05)
            _buildRegressionRow(
              label: "Today's Seizure Incident Count",
              value: seizuresCoeff,
              isDark: isDark,
            ),
          if (seizuresLagCoeff.abs() > 0.05)
            _buildRegressionRow(
              label: "Yesterday's Seizure count (Lag impact)",
              value: seizuresLagCoeff,
              isDark: isDark,
            ),
          if (periodCoeff.abs() > 0.05)
            _buildRegressionRow(
              label: "Active Cycle Day (Menstruation)",
              value: periodCoeff,
              isDark: isDark,
            ),
          if (habitRows.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Text(
              "Confounder-Free Routine Impacts",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : Colors.grey),
            ),
            const SizedBox(height: 10),
            ...habitRows,
          ],
        ],
      ),
    );
  }

  Widget _buildRegressionRow({
    required String label,
    required double value,
    required bool isDark,
    String? helpText,
  }) {
    final bool isPositive = value > 0;
    final color = isPositive ? emerald : Colors.redAccent;
    final valueText = (isPositive ? "+" : "") + value.toStringAsFixed(2);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                valueText,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          if (helpText != null) ...[
            const SizedBox(height: 2),
            Text(
              helpText,
              style: const TextStyle(fontSize: 9.5, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHabitSynergyAndDecayCard(bool isDark, Color cardBg, Color textColor) {
    if (_habitMetrics == null) return const SizedBox.shrink();

    final metrics = _habitMetrics!;
    final synergies = metrics['synergies'] as Map<String, double>;
    final decays = metrics['decays'] as Map<String, double>;

    if (synergies.isEmpty && decays.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
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
                "Synergy & Routine Stagnation",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Identifies compound routines that boost you when done together, and flags when routines begin to lose baseline impact.",
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
                      decoration: BoxDecoration(color: emerald.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text("+${entry.value.toStringAsFixed(1)} boost", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: emerald)),
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
