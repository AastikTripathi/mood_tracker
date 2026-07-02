import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/thought.dart';
import '../models/habit.dart';
import '../models/physical_log.dart';
import '../services/database_service.dart';
import 'developer_view_screen.dart';

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

class _DetailedAnalyticsScreenState extends State<DetailedAnalyticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedClusterIndex = 0;
  String _activeCalendarView = 'Cluster Alignment';

  final DatabaseService _db = DatabaseService();
  
  Map<String, dynamic>? _regressionResults;
  Map<String, dynamic>? _resilienceRoadmap;
  bool _isLoading = true;




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
        actions: [
          IconButton(
            icon: const Icon(Icons.terminal_rounded, color: Colors.teal),
            tooltip: "Engine Diagnostics",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DeveloperViewScreen(
                    historyThoughts: widget.historyThoughts,
                    availableHabits: widget.availableHabits,
                    allHabitLogs: widget.allHabitLogs,
                    physicalLogs: widget.physicalLogs,
                    isTwilight: widget.isTwilight,
                  ),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.teal,
          unselectedLabelColor: isDark ? Colors.white38 : Colors.black45,
          indicatorColor: Colors.teal,
          tabs: const [
            Tab(text: "Headspace Analytics"),
            Tab(text: "Cluster Cycles"),
          ],
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.teal))
            : TabBarView(
                controller: _tabController,
                children: [
                  SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Resilience Roadmap Card
                        _buildResilienceRoadmapCard(isDark, cardBg, textThemeColor),

                        // 2. Ridge Regression Isolated Drivers Card
                        _buildRidgeRegressionCard(isDark, cardBg, textThemeColor),

                        _buildSectionHeader("Symptom & Pattern Tracking", Icons.analytics, isDark),
                        const SizedBox(height: 12),
                        _buildSymptomTrackingCard(isDark, cardBg, textThemeColor),
                        const SizedBox(height: 24),

                        _buildSectionHeader("Cycle Forecasting & Phase Mapping", Icons.calendar_month, isDark),
                        const SizedBox(height: 12),
                        _buildCycleForecastingCard(isDark, cardBg, textThemeColor),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                  _buildClusterCyclesTab(isDark, cardBg, textThemeColor),
                ],
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

    final double painCoeff = coeffs['pain'] ?? 0.0;
    final double seizuresCoeff = coeffs['seizures'] ?? 0.0;
    final double periodCoeff = coeffs['isPeriodDay'] ?? coeffs['period'] ?? 0.0;
    final double shockCoeff = coeffs['externalShockShield'] ?? 0.0;

    // Sum habits across lags to represent the actual cumulative effect
    final Map<String, double> habitSums = {};
    coeffs.forEach((key, val) {
      if (key.startsWith('habit_')) {
        String hid = key.replaceFirst('habit_', '');
        if (hid.endsWith('_lag0') || hid.endsWith('_lag1') || hid.endsWith('_lag2') || hid.endsWith('_lag3')) {
          hid = hid.substring(0, hid.length - 5);
        }
        habitSums[hid] = (habitSums[hid] ?? 0.0) + val;
      }
    });

    final List<Widget> habitRows = [];
    habitSums.forEach((hid, val) {
      if (val.abs() > 0.01) {
        final match = widget.availableHabits.cast<HabitDefinition?>().firstWhere(
          (h) => h!.id == hid || h.name == hid,
          orElse: () => null,
        );
        if (match != null) {
          habitRows.add(_buildDivergingImpactRow(
            label: match.name,
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
            "These metrics help isolate the independent connection of each factor on your mood.",
            style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey, height: 1.4),
          ),
          const SizedBox(height: 16),
          Text(
            "Environmental & Physical Parameters",
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : Colors.grey),
          ),
          const SizedBox(height: 10),
          if (painCoeff.abs() > 0.01)
            _buildDivergingImpactRow(
              label: "Chronic Pain Index",
              value: painCoeff,
              isDark: isDark,
            ),
          if (seizuresCoeff.abs() > 0.01)
            _buildDivergingImpactRow(
              label: "Seizure Incident Count",
              value: seizuresCoeff,
              isDark: isDark,
            ),
          if (periodCoeff.abs() > 0.01)
            _buildDivergingImpactRow(
              label: "Menstrual Cycle Impact",
              value: periodCoeff,
              isDark: isDark,
            ),
          if (shockCoeff.abs() > 0.01)
            _buildDivergingImpactRow(
              label: "Stress Shield Active",
              value: shockCoeff,
              isDark: isDark,
            ),
          if (habitRows.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Text(
              "Routine Impacts",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : Colors.grey),
            ),
            const SizedBox(height: 10),
            ...habitRows,
          ],

          // Conversational Copilot Insights Action Plan
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Text(
            "Personalized Copilot Action Plan",
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: isDark ? Colors.teal.shade200 : Colors.teal.shade700),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.teal.withOpacity(0.08)),
            ),
            child: Column(
              children: _generateConversationalInsights(coeffs).map((insight) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.circle, size: 4.5, color: Colors.teal),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          insight,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? Colors.white70 : Colors.black87,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _generateConversationalInsights(Map<String, double> coeffs) {
    final List<String> insights = [];

    final double pain = coeffs['pain'] ?? 0.0;
    final double seizures = coeffs['seizures'] ?? 0.0;
    final double period = coeffs['isPeriodDay'] ?? coeffs['period'] ?? 0.0;
    final double shock = coeffs['externalShockShield'] ?? 0.0;

    if (pain.abs() > 0.1) {
      insights.add("Pain Impact: Chronic pain pulls down your mood. On high-pain days, reduce physical demands early.");
    }

    if (seizures.abs() > 0.1) {
      insights.add("Seizure Recovery: Seizure episodes drag your daily energy reserves. Prioritize immediate sensory rest post-incident.");
    }

    if (period.abs() > 0.1) {
      if (period < 0) {
        insights.add("Menstrual Sensitivity: Active period days drop your daily baseline. Give yourself extra permission to slow down.");
      } else {
        insights.add("Cycle Baseline: Active cycle days exhibit a minor positive link to your daily baseline.");
      }
    }

    if (shock.abs() > 0.1) {
      insights.add("Stress Shield: The active stress shield successfully keeps chaotic external events isolated from your core mood.");
    }

    // Sum habits across lags to represent the actual cumulative effect
    final Map<String, double> habitSums = {};
    coeffs.forEach((key, val) {
      if (key.startsWith('habit_')) {
        String hid = key.replaceFirst('habit_', '');
        if (hid.endsWith('_lag0') || hid.endsWith('_lag1') || hid.endsWith('_lag2') || hid.endsWith('_lag3')) {
          hid = hid.substring(0, hid.length - 5);
        }
        habitSums[hid] = (habitSums[hid] ?? 0.0) + val;
      }
    });

    habitSums.forEach((hid, val) {
      if (val.abs() > 0.1) {
        final match = widget.availableHabits.cast<HabitDefinition?>().firstWhere(
          (h) => h!.id == hid || h.name == hid,
          orElse: () => null,
        );
        if (match != null) {
          final String nameLower = match.name.toLowerCase();
          final bool isNegativeStressor = nameLower.contains('caffeine') || 
                                          nameLower.contains('skipped') || 
                                          nameLower.contains('late') || 
                                          nameLower.contains('skip') ||
                                          nameLower.contains('junk');

          if (val > 0) {
            insights.add("Boosting Routine: Completing '${match.name}' acts as an independent mood booster (+${val.toStringAsFixed(1)} overall).");
          } else {
            if (isNegativeStressor) {
              insights.add("Routine Strain: '${match.name}' shows a negative pull (${val.toStringAsFixed(1)} overall) on your mood.");
            } else {
              insights.add("Support Routine: You naturally turn to '${match.name}' (${val.toStringAsFixed(1)} overall) on lower-mood days to ground yourself.");
            }
          }
        }
      }
    });

    if (insights.isEmpty) {
      insights.add("Keep Logging: Collect more days of routine logs and symptom ratings to unlock personalized coping actions.");
    }

    return insights;
  }

  Widget _buildDivergingImpactRow({
    required String label,
    required double value,
    required bool isDark,
    String? helpText,
  }) {
    final bool isPositive = value > 0;
    final color = isPositive ? emerald : Colors.redAccent.shade200;
    
    // Normalize value for the bar (cap at +/- 3.0 for scaling)
    final double maxAbs = 3.0;
    final double normalized = (value.abs() / maxAbs).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // 1. Label
              Expanded(
                flex: 4,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // 2. Diverging Bar Infographic
              Container(
                width: 110,
                height: 7,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(3.5),
                ),
                child: Stack(
                  children: [
                    // Center line divider
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 1.2,
                        height: 7,
                        color: isDark ? Colors.white30 : Colors.black26,
                      ),
                    ),
                    // Extending Bar
                    Positioned(
                      left: isPositive ? 55 : null,
                      right: !isPositive ? 55 : null,
                      width: 55 * normalized,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(3.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              
              // 3. Numeric Indicator
              SizedBox(
                width: 45,
                child: Text(
                  (isPositive ? "+" : "") + value.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  textAlign: TextAlign.right,
                ),
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



  // Dynamic stats calculation
  double _avgCycleLength = 28.0;
  double _avgPeriodDuration = 5.0;
  int _cyclesTrackedCount = 0;

  // Calendar month views
  DateTime _currentMonthView = DateTime.now();
  DateTime? _selectedCalendarDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedCalendarDate = DateTime.now();
    _loadMetrics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadMetrics() {
    _db.init().then((_) {
      if (mounted) {
        setState(() {
          _regressionResults = _db.performRidgeRegression();
          _resilienceRoadmap = _db.findResilienceRoadmap();
          _calculateCycleStats();
          _isLoading = false;
        });
      }
    });
  }

  void _calculateCycleStats() {
    final logs = List<PhysicalLog>.from(widget.physicalLogs)
      ..sort((a, b) => a.date.compareTo(b.date));

    final List<List<DateTime>> streaks = [];
    List<DateTime> currentStreak = [];

    for (final log in logs) {
      if (log.isPeriodDay) {
        if (currentStreak.isEmpty) {
          currentStreak.add(log.date);
        } else {
          final diff = log.date.difference(currentStreak.last).inDays;
          if (diff <= 1.5) {
            currentStreak.add(log.date);
          } else {
            streaks.add(currentStreak);
            currentStreak = [log.date];
          }
        }
      }
    }
    if (currentStreak.isNotEmpty) {
      streaks.add(currentStreak);
    }

    if (streaks.length >= 2) {
      double sumDuration = 0.0;
      for (final streak in streaks) {
        sumDuration += streak.length;
      }
      _avgPeriodDuration = sumDuration / streaks.length;

      double sumCycle = 0.0;
      int gapCount = 0;
      for (int i = 0; i < streaks.length - 1; i++) {
        final startCurrent = streaks[i].first;
        final startNext = streaks[i + 1].first;
        sumCycle += startNext.difference(startCurrent).inDays;
        gapCount++;
      }
      if (gapCount > 0) {
        _avgCycleLength = sumCycle / gapCount;
      }
      _cyclesTrackedCount = streaks.length;
    }
  }

  Set<String> _getPredictedPeriodDates() {
    final Set<String> predicted = {};
    DateTime? lastPeriodStart;
    
    final sortedLogs = List<PhysicalLog>.from(widget.physicalLogs)
      ..sort((a, b) => a.date.compareTo(b.date));

    for (int i = sortedLogs.length - 1; i >= 0; i--) {
      if (sortedLogs[i].isPeriodDay) {
        DateTime start = sortedLogs[i].date;
        int j = i;
        while (j > 0 && sortedLogs[j - 1].isPeriodDay && 
               sortedLogs[j].date.difference(sortedLogs[j - 1].date).inDays <= 1) {
          start = sortedLogs[j - 1].date;
          j--;
        }
        lastPeriodStart = start;
        break;
      }
    }

    if (lastPeriodStart != null) {
      final int cycleLength = _avgCycleLength.round();
      final int duration = _avgPeriodDuration.round();
      for (int cycle = 1; cycle <= 3; cycle++) {
        final projectedStart = lastPeriodStart.add(Duration(days: cycle * cycleLength));
        for (int offset = 0; offset < duration; offset++) {
          final pDay = projectedStart.add(Duration(days: offset));
          predicted.add("${pDay.year}-${pDay.month}-${pDay.day}");
        }
      }
    }
    return predicted;
  }

  int _calculateCycleDay(DateTime date) {
    DateTime? lastPeriodStart;
    final sortedLogs = List<PhysicalLog>.from(widget.physicalLogs)
      ..sort((a, b) => a.date.compareTo(b.date));

    for (int i = sortedLogs.length - 1; i >= 0; i--) {
      if (sortedLogs[i].isPeriodDay && sortedLogs[i].date.isBefore(date.add(const Duration(days: 1)))) {
        DateTime start = sortedLogs[i].date;
        int j = i;
        while (j > 0 && sortedLogs[j - 1].isPeriodDay && 
               sortedLogs[j].date.difference(sortedLogs[j - 1].date).inDays <= 1) {
          start = sortedLogs[j - 1].date;
          j--;
        }
        lastPeriodStart = start;
        break;
      }
    }

    if (lastPeriodStart == null) {
      return 1;
    }

    final diffDays = date.difference(lastPeriodStart).inDays;
    final int cycleLengthInt = _avgCycleLength.round();
    final cycleDay = (diffDays % cycleLengthInt) + 1;
    return cycleDay;
  }

  String _getCyclePhaseName(int cycleDay) {
    if (cycleDay >= 1 && cycleDay <= 5) return 'Menses';
    if (cycleDay >= 6 && cycleDay <= 13) return 'Follicular';
    if (cycleDay == 14) return 'Ovulatory';
    return 'Luteal';
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  List<DateTime> _generateMonthDays(DateTime monthDate) {
    final firstDayOfMonth = DateTime(monthDate.year, monthDate.month, 1);
    final lastDayOfMonth = DateTime(monthDate.year, monthDate.month + 1, 0);
    
    int startOffset = firstDayOfMonth.weekday - 1;
    
    final List<DateTime> days = [];
    for (int i = startOffset; i > 0; i--) {
      days.add(firstDayOfMonth.subtract(Duration(days: i)));
    }
    for (int i = 1; i <= lastDayOfMonth.day; i++) {
      days.add(DateTime(monthDate.year, monthDate.month, i));
    }
    
    final totalCells = ((days.length / 7).ceil() * 7);
    final nextMonthPad = totalCells - days.length;
    for (int i = 1; i <= nextMonthPad; i++) {
      days.add(lastDayOfMonth.add(Duration(days: i)));
    }
    return days;
  }

  Widget _buildCycleForecastingCard(bool isDark, Color cardBg, Color textColor) {
    if (widget.physicalLogs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(24)),
        child: const Center(child: Text("No physical logs available for cycle tracking.", style: TextStyle(color: Colors.grey))),
      );
    }

    final now = DateTime.now();
    final todayTruncated = DateTime(now.year, now.month, now.day);
    
    final days = _generateMonthDays(_currentMonthView);
    final predictedPeriods = _getPredictedPeriodDates();

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
          // 1. Centered Month Navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  setState(() {
                    _currentMonthView = DateTime(_currentMonthView.year, _currentMonthView.month - 1, 1);
                  });
                },
              ),
              const SizedBox(width: 16),
              Text(
                "${_getMonthName(_currentMonthView.month)} ${_currentMonthView.year}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  setState(() {
                    _currentMonthView = DateTime(_currentMonthView.year, _currentMonthView.month + 1, 1);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Centered Subtitle Stats Tracker
          Center(
            child: Text(
              _cyclesTrackedCount >= 2 
                  ? "Personalized predictions based on $_cyclesTrackedCount tracked cycles"
                  : "Predictions based on clinical average 28d cycle",
              style: const TextStyle(fontSize: 9.5, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 18),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
              return SizedBox(
                width: 32,
                child: Center(
                  child: Text(
                    day,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.0,
            ),
            itemCount: days.length,
            itemBuilder: (context, idx) {
              final date = days[idx];
              final dateKey = "${date.year}-${date.month}-${date.day}";
              final isFuture = date.isAfter(todayTruncated);
              final isToday = date.isAtSameMomentAs(todayTruncated);
              final isSelected = _selectedCalendarDate != null && 
                                 _selectedCalendarDate!.year == date.year && 
                                 _selectedCalendarDate!.month == date.month && 
                                 _selectedCalendarDate!.day == date.day;
              
              final isCurrentMonth = date.month == _currentMonthView.month;

              final physicalLog = widget.physicalLogs.firstWhere(
                (p) => p.date.year == date.year && p.date.month == date.month && p.date.day == date.day,
                orElse: () => PhysicalLog(date: date, sleepHours: 7.5, isPeriodDay: false, skippedMeal: false, lateCaffeine: false),
              );

              final isPeriodDay = isFuture 
                  ? predictedPeriods.contains(dateKey)
                  : physicalLog.isPeriodDay;

              final cycleDay = _calculateCycleDay(date);
              final phase = _getCyclePhaseName(cycleDay);

              Color phaseColor;
              switch (phase) {
                case 'Menses':
                  phaseColor = const Color(0xFFE11D48);
                  break;
                case 'Follicular':
                  phaseColor = const Color(0xFFFDA4AF);
                  break;
                case 'Ovulatory':
                  phaseColor = const Color(0xFFF43F5E);
                  break;
                default:
                  phaseColor = const Color(0xFFFECDD3);
              }

              Color cellBg;
              Border border;
              Color dayTextColor = isToday ? Colors.teal : (isDark ? Colors.white70 : Colors.black87);

              if (isPeriodDay) {
                if (isFuture) {
                  cellBg = const Color(0xFFE11D48).withOpacity(0.1);
                  border = Border.all(color: const Color(0xFFE11D48).withOpacity(0.6), width: 1.5);
                } else {
                  cellBg = const Color(0xFFE11D48);
                  dayTextColor = Colors.white;
                  border = Border.all(color: Colors.transparent);
                }
              } else {
                cellBg = Colors.transparent;
                if (isToday) {
                  border = Border.all(color: Colors.teal.withOpacity(0.5), width: 1.5);
                } else {
                  border = Border.all(color: isCurrentMonth ? Colors.grey.withOpacity(0.08) : Colors.transparent, width: 0.5);
                }
              }

              if (isSelected) {
                border = Border.all(color: Colors.teal, width: 2.0);
              }

              double opacity = isCurrentMonth ? (isFuture ? 0.65 : 1.0) : 0.25;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCalendarDate = date;
                  });
                },
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    decoration: BoxDecoration(
                      color: cellBg,
                      shape: BoxShape.circle,
                      border: border,
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            "${date.day}",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                              color: dayTextColor,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 4,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              width: 3.5,
                              height: 3.5,
                              decoration: BoxDecoration(
                                color: phaseColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          _buildForecastLegend(isDark),

          _buildSelectedDayDetailsCard(isDark, cardBg),
        ],
      ),
    );
  }

  Widget _buildSelectedDayDetailsCard(bool isDark, Color cardBg) {
    if (_selectedCalendarDate == null) return const SizedBox.shrink();
    
    final date = _selectedCalendarDate!;
    final now = DateTime.now();
    final todayTruncated = DateTime(now.year, now.month, now.day);
    final isFuture = date.isAfter(todayTruncated);
    
    final cycleDay = _calculateCycleDay(date);
    final phase = _getCyclePhaseName(cycleDay);
    
    final physicalLog = widget.physicalLogs.firstWhere(
      (p) => p.date.year == date.year && p.date.month == date.month && p.date.day == date.day,
      orElse: () => PhysicalLog(date: date, sleepHours: 7.5, isPeriodDay: false, skippedMeal: false, lateCaffeine: false),
    );
    
    final isPeriod = isFuture 
        ? _getPredictedPeriodDates().contains("${date.year}-${date.month}-${date.day}")
        : physicalLog.isPeriodDay;

    String phaseDescription = '';
    switch (phase) {
      case 'Menses':
        phaseDescription = "Your progesterone and estrogen levels are at their lowest. Focus on rest, warm hydration, and light stretching. Be extra gentle with yourself.";
        break;
      case 'Follicular':
        phaseDescription = "Estrogen levels begin to rise, boosting your physical energy, mental clarity, and social confidence. Great time for starting new projects.";
        break;
      case 'Ovulatory':
        phaseDescription = "Estrogen peaks, triggering egg release. Fertility, skin radiance, and communication skills are at their natural cycle peak.";
        break;
      default: // Luteal
        phaseDescription = "Progesterone dominates. Energy may decrease, and pre-menstrual physical/emotional symptoms can surface. Prioritize self-care and quiet routines.";
    }

    String periodText = "Cycle Day $cycleDay";
    if (isPeriod) {
      periodText = isFuture ? "Predicted Period" : "Period Logged";
    }

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.01),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${date.day} ${_getMonthName(date.month)} ${date.year}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isPeriod ? const Color(0xFFE11D48).withOpacity(0.15) : Colors.teal.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  periodText,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    color: isPeriod ? const Color(0xFFE11D48) : Colors.teal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(color: Colors.pinkAccent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                "Phase: $phase",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            phaseDescription,
            style: const TextStyle(fontSize: 10, color: Colors.grey, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastLegend(bool isDark) {
    Widget legendChip(Widget indicator, String text) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          indicator,
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 9, color: Colors.grey)),
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        legendChip(
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: Color(0xFFE11D48),
              shape: BoxShape.circle,
            ),
          ),
          "Period",
        ),
        legendChip(
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: const Color(0xFFE11D48).withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE11D48).withOpacity(0.6), width: 1.2),
            ),
          ),
          "Predicted",
        ),
        legendChip(
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.teal, width: 2.0),
            ),
          ),
          "Selected",
        ),
        legendChip(
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.teal.withOpacity(0.5), width: 1.5),
            ),
          ),
          "Today",
        ),
      ],
    );
  }

  Widget _buildClusterCyclesTab(bool isDark, Color cardBg, Color textColor) {
    final List<List<Thought>> clusters = _db.clusterHistory(clusterThreshold: 0.55);

    if (clusters.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.psychology_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                "Need at least 2 saved thoughts",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                "Seed the database sandbox or enter notes to visualize clusters.",
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Safety check for index bounds
    if (_selectedClusterIndex >= clusters.length) {
      _selectedClusterIndex = 0;
    }

    final points = _computeClusterPoints(clusters);
    final activeCluster = clusters[_selectedClusterIndex];

    // Calculate cluster statistics
    double sumMood = 0;
    for (final t in activeCluster) {
      sumMood += t.moodScore;
    }
    final double avgMood = sumMood / activeCluster.length;
    final allClusterTags = activeCluster.expand((t) => {...t.categories, ...t.userTags}).toSet().take(5);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Emotional Wagon Wheel Graph", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      const Text("Tap cluster dots directly on the graph to inspect different groups.", style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Graph custom paint with tap listener
                Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.teal.withOpacity(0.15)),
                    ),
                    child: GestureDetector(
                      onTapDown: (details) {
                        final center = const Offset(130, 130);
                        final maxRadius = 130 * 0.85;
                        final localPos = details.localPosition;
                        
                        final double clickX = (localPos.dx - center.dx) / maxRadius;
                        final double clickY = -(localPos.dy - center.dy) / maxRadius;

                        int closestIdx = -1;
                        double closestDist = double.maxFinite;

                        for (final pt in points) {
                          final dx = pt.x - clickX;
                          final dy = pt.y - clickY;
                          final dist = math.sqrt(dx * dx + dy * dy);
                          if (dist < closestDist) {
                            closestDist = dist;
                            closestIdx = pt.index;
                          }
                        }

                        if (closestIdx != -1 && closestDist < 0.18) {
                          setState(() {
                            _selectedClusterIndex = closestIdx;
                          });
                        }
                      },
                      child: CustomPaint(
                        size: const Size(260, 260),
                        painter: WagonWheelPainter(
                          points: points,
                          selectedIndex: _selectedClusterIndex,
                          isDark: isDark,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Cycle Calendar Panel
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20)),
            child: _buildCycleCalendarGrid(activeCluster, isDark, cardBg),
          ),
          const SizedBox(height: 16),

          // Thoughts in Selected Cluster Panel
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Cluster ${_selectedClusterIndex + 1} Entries (${activeCluster.length} thoughts)",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      "Average Mood: ${avgMood.toStringAsFixed(1)}/10  •  ",
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: allClusterTags.map((tag) => Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.teal),
                            ),
                          )).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: activeCluster.length,
                  itemBuilder: (context, index) {
                    final thought = activeCluster[index];
                    final habits = _db.getHabitsForDay(thought.timestamp);
                    final habitDefs = _db.getHabitDefinitions();
                    final habitMap = { for (var d in habitDefs) d.id: d.iconEmoji };
                    final activeEmojis = habits.map((h) => habitMap[h] ?? '🌿').toList();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.01),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.teal.withOpacity(0.08)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "${thought.timestamp.day}/${thought.timestamp.month}/${thought.timestamp.year}",
                                style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                "Mood: ${thought.moodScore}/10",
                                style: const TextStyle(fontSize: 10, color: Colors.teal, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            thought.textContent,
                            style: TextStyle(fontSize: 11.5, color: textColor),
                          ),
                          if (activeEmojis.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              children: activeEmojis.map((emoji) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(emoji, style: const TextStyle(fontSize: 12)),
                              )).toList(),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  List<ClusterPoint> _computeClusterPoints(List<List<Thought>> clusters) {
    final List<ClusterPoint> points = [];
    final Map<String, double> angles = {
      'Joy': math.pi / 2,
      'Energy': math.pi / 6,
      'Gratitude': math.pi / 3,
      'Calm': 2 * math.pi / 3,
      'Focus': 5 * math.pi / 6,
      'Sadness': 3 * math.pi / 2,
      'Discomfort': 4 * math.pi / 3,
      'Stress': 5 * math.pi / 3,
      'Frustration': 11 * math.pi / 6,
    };

    for (int idx = 0; idx < clusters.length; idx++) {
      final cluster = clusters[idx];
      double sumX = 0.0;
      double sumY = 0.0;
      int count = 0;

      for (final t in cluster) {
        final tags = {...t.categories, ...t.userTags};
        for (final tag in tags) {
          if (angles.containsKey(tag)) {
            final double theta = angles[tag]!;
            sumX += math.cos(theta);
            sumY += math.sin(theta);
            count++;
          }
        }
      }

      double angle = 0.0;
      if (count > 0) {
        final double avgX = sumX / count;
        final double avgY = sumY / count;
        angle = math.atan2(avgY, avgX);
      } else {
        double sumMood = 0.0;
        for (final t in cluster) {
          sumMood += t.moodScore;
        }
        final double avgMood = sumMood / cluster.length;
        angle = avgMood >= 5.0 ? math.pi / 2 : 3 * math.pi / 2;
      }

      double sumMood = 0.0;
      for (final t in cluster) {
        sumMood += t.moodScore;
      }
      final double avgMood = sumMood / cluster.length;
      final double radius = 0.15 + (avgMood - 1.0) / 9.0 * 0.70;

      final double posX = radius * math.cos(angle);
      final double posY = radius * math.sin(angle);

      final centroid = cluster.first;
      final words = centroid.textContent.split(' ');
      final label = words.take(4).join(' ') + (words.length > 4 ? '...' : '');

      points.add(ClusterPoint(
        index: idx,
        angle: angle,
        radius: radius,
        label: label,
        x: posX,
        y: posY,
        avgMood: avgMood,
      ));
    }

    return points;
  }

  Widget _buildCycleCalendarGrid(List<Thought> clusterThoughts, bool isDark, Color cardBg) {
    final clusterDates = clusterThoughts.map((t) => "${t.timestamp.year}-${t.timestamp.month}-${t.timestamp.day}").toSet();

    final now = DateTime.now();
    final List<DateTime> dates = [];
    for (int i = 45; i >= 1; i--) {
      dates.add(now.subtract(Duration(days: i)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Dynamic Cycle Alignment Calendar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _activeCalendarView,
              dropdownColor: cardBg,
              iconSize: 18,
              isExpanded: true,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87),
              items: ['Cluster Alignment', 'Chronic Pain', 'Seizure Incidents'].map((view) {
                return DropdownMenuItem<String>(
                  value: view,
                  child: Text(view),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _activeCalendarView = val;
                  });
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _activeCalendarView == 'Cluster Alignment'
              ? "Highlighted days belong to the active cluster. Look for correlations with period (🩸) phases."
              : (_activeCalendarView == 'Chronic Pain'
                  ? "Color gradient maps pain intensity (red). Bold teal outlines indicate active cluster intersection."
                  : "Highlights days with seizure events (⚡). Bold teal outlines indicate active cluster intersection."),
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
        const SizedBox(height: 12),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1.0,
          ),
          itemCount: dates.length,
          itemBuilder: (context, idx) {
            final date = dates[idx];
            final dateKey = "${date.year}-${date.month}-${date.day}";
            final isInCluster = clusterDates.contains(dateKey);

            final physicalLog = widget.physicalLogs.firstWhere(
              (p) => p.date.year == date.year && p.date.month == date.month && p.date.day == date.day,
              orElse: () => PhysicalLog(date: date, sleepHours: 7.5, isPeriodDay: false, skippedMeal: false, lateCaffeine: false),
            );

            final int loopI = 45 - idx;
            final int cycleDay = loopI % 28 == 0 ? 28 : loopI % 28;

            final isPeriod = physicalLog.isPeriodDay;

            Color cellColor;
            Border border;
            Widget infoWidget;

            if (_activeCalendarView == 'Chronic Pain') {
              final double pain = physicalLog.customPainLevel ?? 0.0;
              if (pain > 0.0) {
                cellColor = Colors.red.withOpacity((pain / 10.0).clamp(0.08, 0.85));
              } else {
                cellColor = isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.01);
              }
              
              if (isInCluster) {
                border = Border.all(color: Colors.teal, width: 2.0);
              } else {
                border = Border.all(
                  color: pain > 0.0 ? Colors.redAccent.withOpacity(0.5) : Colors.grey.withOpacity(0.1),
                  width: pain > 0.0 ? 1.0 : 0.5,
                );
              }

              infoWidget = Text(
                pain > 0.0 ? "P:${pain.toStringAsFixed(1)}" : "No Pain",
                style: TextStyle(
                  fontSize: 7.5,
                  fontWeight: pain > 0.0 ? FontWeight.bold : FontWeight.normal,
                  color: pain > 0.0 ? (isDark ? Colors.white70 : Colors.red[900]) : Colors.grey,
                ),
              );
            } else if (_activeCalendarView == 'Seizure Incidents') {
              final int count = physicalLog.customSeizuresCount ?? 0;
              if (count > 0) {
                cellColor = Colors.amber.withOpacity(0.4);
              } else {
                cellColor = isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.01);
              }

              if (isInCluster) {
                border = Border.all(color: Colors.teal, width: 2.0);
              } else {
                border = Border.all(
                  color: count > 0 ? Colors.amber : Colors.grey.withOpacity(0.1),
                  width: count > 0 ? 1.5 : 0.5,
                );
              }

              infoWidget = Text(
                count > 0 ? "⚡ $count" : "None",
                style: TextStyle(
                  fontSize: 7.5,
                  fontWeight: count > 0 ? FontWeight.bold : FontWeight.normal,
                  color: count > 0 ? (isDark ? Colors.amberAccent : Colors.orange[800]) : Colors.grey,
                ),
              );
            } else {
              String phase = 'Luteal';
              if (cycleDay >= 1 && cycleDay <= 5) {
                phase = 'Menses';
              } else if (cycleDay >= 6 && cycleDay <= 13) {
                phase = 'Follicular';
              } else if (cycleDay == 14) {
                phase = 'Ovulatory';
              }

              Color phaseColor;
              switch (phase) {
                case 'Menses':
                  phaseColor = const Color(0xFFE11D48);
                  break;
                case 'Follicular':
                  phaseColor = const Color(0xFFFDA4AF);
                  break;
                case 'Ovulatory':
                  phaseColor = const Color(0xFFF43F5E);
                  break;
                default:
                  phaseColor = const Color(0xFFFECDD3);
              }

              cellColor = phaseColor.withOpacity(isDark ? 0.35 : 0.2);

              if (isInCluster) {
                border = Border.all(color: Colors.teal, width: 2.0);
              } else {
                border = Border.all(
                  color: isPeriod ? Colors.redAccent.withOpacity(0.4) : Colors.grey.withOpacity(0.1),
                  width: isPeriod ? 1.2 : 0.5,
                );
              }

              infoWidget = Text(
                phase,
                style: TextStyle(
                  fontSize: 7.0,
                  fontWeight: FontWeight.bold,
                  color: phaseColor,
                ),
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: cellColor,
                borderRadius: BorderRadius.circular(10),
                border: border,
              ),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "${date.day}",
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: isInCluster ? Colors.teal : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                        const SizedBox(height: 1),
                        infoWidget,
                      ],
                    ),
                  ),
                  if (isPeriod)
                    const Positioned(
                      top: 2,
                      right: 3,
                      child: Text(
                        "🩸",
                        style: TextStyle(fontSize: 7),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),

        _buildCalendarLegend(isDark),
      ],
    );
  }

  Widget _buildCalendarLegend(bool isDark) {
    final List<Widget> legendItems = [];

    legendItems.add(
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: Colors.teal, width: 1.5),
            ),
          ),
          const SizedBox(width: 4),
          const Text("In Cluster (Teal Border)", style: TextStyle(fontSize: 9, color: Colors.grey)),
        ],
      ),
    );
    legendItems.add(const SizedBox(width: 12));

    if (_activeCalendarView == 'Chronic Pain') {
      legendItems.addAll([
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.15),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
          ),
        ),
        const SizedBox(width: 4),
        const Text("Mild Pain", style: TextStyle(fontSize: 9, color: Colors.grey)),
        const SizedBox(width: 12),
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.65),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.redAccent),
          ),
        ),
        const SizedBox(width: 4),
        const Text("Severe Pain", style: TextStyle(fontSize: 9, color: Colors.grey)),
      ]);
    } else if (_activeCalendarView == 'Seizure Incidents') {
      legendItems.addAll([
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.4),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.amber),
          ),
        ),
        const SizedBox(width: 4),
        const Text("Seizure (⚡ Count)", style: TextStyle(fontSize: 9, color: Colors.grey)),
      ]);
    } else {
      Widget phaseBox(Color color, String text) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color.withOpacity(isDark ? 0.35 : 0.2),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: color.withOpacity(0.5)),
              ),
            ),
            const SizedBox(width: 3),
            Text(text, style: const TextStyle(fontSize: 8.5, color: Colors.grey)),
          ],
        );
      }

      legendItems.addAll([
        phaseBox(const Color(0xFFE11D48), "Menses"),
        const SizedBox(width: 4),
        phaseBox(const Color(0xFFFDA4AF), "Follicular"),
        const SizedBox(width: 4),
        phaseBox(const Color(0xFFF43F5E), "Ovulatory"),
        const SizedBox(width: 4),
        phaseBox(const Color(0xFFFECDD3), "Luteal"),
      ]);
    }

    legendItems.addAll([
      const SizedBox(width: 12),
      const Text("🩸", style: TextStyle(fontSize: 10)),
      const SizedBox(width: 4),
      const Text("Period Day", style: TextStyle(fontSize: 9, color: Colors.grey)),
    ]);

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: legendItems,
    );
  }
}

class ClusterPoint {
  final int index;
  final double angle;
  final double radius;
  final String label;
  final double x;
  final double y;
  final double avgMood;

  ClusterPoint({
    required this.index,
    required this.angle,
    required this.radius,
    required this.label,
    required this.x,
    required this.y,
    required this.avgMood,
  });
}

class WagonWheelPainter extends CustomPainter {
  final List<ClusterPoint> points;
  final int selectedIndex;
  final bool isDark;

  WagonWheelPainter({
    required this.points,
    required this.selectedIndex,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2 * 0.82;

    final gridPaint = Paint()
      ..color = isDark ? Colors.white10 : Colors.black.withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final axisPaint = Paint()
      ..color = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final double steps = 4;
    for (int i = 1; i <= steps; i++) {
      final r = maxRadius * (i / steps);
      canvas.drawCircle(center, r, gridPaint);
    }

    final Map<String, double> angles = {
      'Joy': math.pi / 2,
      'Energy': math.pi / 6,
      'Gratitude': math.pi / 3,
      'Calm': 2 * math.pi / 3,
      'Focus': 5 * math.pi / 6,
      'Sadness': 3 * math.pi / 2,
      'Discomfort': 4 * math.pi / 3,
      'Stress': 5 * math.pi / 3,
      'Frustration': 11 * math.pi / 6,
    };

    angles.forEach((name, theta) {
      final dx = maxRadius * math.cos(theta);
      final dy = -maxRadius * math.sin(theta);
      canvas.drawLine(center, center + Offset(dx, dy), axisPaint);
    });

    for (final pt in points) {
      final dx = center.dx + pt.x * maxRadius;
      final dy = center.dy - pt.y * maxRadius;
      final ptOffset = Offset(dx, dy);

      final isSelected = pt.index == selectedIndex;
      
      Color dotColor;
      if (pt.avgMood >= 6.0) {
        dotColor = pt.avgMood >= 7.5 ? const Color(0xFFFFB000) : const Color(0xFF8DE845);
      } else if (pt.avgMood <= 4.0) {
        dotColor = Colors.indigoAccent;
      } else {
        dotColor = Colors.teal;
      }

      if (isSelected) {
        canvas.drawCircle(
          ptOffset,
          10,
          Paint()
            ..color = dotColor.withOpacity(0.3)
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          ptOffset,
          10,
          Paint()
            ..color = dotColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }

      canvas.drawCircle(
        ptOffset,
        5.5,
        Paint()
          ..color = dotColor
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
