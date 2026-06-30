import 'package:flutter/material.dart';
import '../models/thought.dart';
import '../models/habit.dart';
import '../models/physical_log.dart';
import '../screens/detailed_analytics_screen.dart';
import '../services/database_service.dart';

class CausalCorrelationCard extends StatelessWidget {
  final List<Thought> historyThoughts;
  final List<HabitDefinition> availableHabits;
  final List<HabitLog> allHabitLogs;
  final List<PhysicalLog> physicalLogs;
  final bool isTwilight;
  final DatabaseService db;

  const CausalCorrelationCard({
    super.key,
    required this.historyThoughts,
    required this.availableHabits,
    required this.allHabitLogs,
    required this.physicalLogs,
    required this.isTwilight,
    required this.db,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCardDark = isTwilight;
    final cardBg = isCardDark ? const Color(0xFF1E293B) : Colors.white;

    final report = db.describeStrongestFactor();
    final bool isColdStart = report['coldStart'] as bool;

    return Container(
      padding: const EdgeInsets.all(22),
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
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 18, color: Colors.teal),
              const SizedBox(width: 8),
              Text(
                "Patterns of the Heart",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                  color: isCardDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Gentle connections your sanctuary notices across your thoughts and routines.",
            style: TextStyle(
              fontSize: 11,
              color: isCardDark ? Colors.white38 : Colors.grey,
            ),
          ),
          const SizedBox(height: 18),

          if (isColdStart)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                "Tending to the garden... ${report['message']}",
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: isCardDark ? Colors.white38 : Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isCardDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.teal.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        report['emoji'] as String,
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "${report['name']} — ${report['label']}",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isCardDark ? Colors.teal[200] : Colors.teal[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    report['description'] as String,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isCardDark ? Colors.white70 : Colors.black87,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetailedAnalyticsScreen(
                      historyThoughts: historyThoughts,
                      availableHabits: availableHabits,
                      allHabitLogs: allHabitLogs,
                      physicalLogs: physicalLogs,
                      isTwilight: isTwilight,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.arrow_forward, size: 14, color: Colors.teal),
              label: const Text(
                "Go Deeper",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.teal.withOpacity(0.3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ]
        ],
      ),
    );
  }
}