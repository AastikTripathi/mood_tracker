import 'package:flutter/material.dart';
import '../models/thought.dart';
import '../models/habit.dart';
import '../services/database_service.dart';
import '../widgets/thought_detail_dialog.dart';

/// Renders a fully searchable chronological catalog showing NLP categorizations
/// and intelligent "past echoes" connections.
class JournalHistoryScreen extends StatefulWidget {
  const JournalHistoryScreen({super.key});

  @override
  State<JournalHistoryScreen> createState() => JournalHistoryScreenState();
}

class JournalHistoryScreenState extends State<JournalHistoryScreen> {
  final DatabaseService _db = DatabaseService();
  List<Thought> _allThoughts = [];
  List<dynamic> _allHabitLogs = [];
  List<dynamic> _availableHabits = [];
  List<dynamic> _allTimelineItems = [];
  List<dynamic> _filteredItems = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filterResults);
  }

  /// Exposed public reload method called by the NavigationShell
  void refreshData() {
    _loadData();
  }

  void _loadData() {
    final list = _db.getThoughts();
    final habitDefs = _db.getHabitDefinitions();
    final allLogs = _db.getHabitLogs();

    final List<dynamic> combined = [];
    combined.addAll(list);
    combined.addAll(allLogs);

    // Sort chronologically (newest to oldest)
    combined.sort((a, b) {
      final DateTime timeA = a is Thought ? a.timestamp : (a as HabitLog).occurrenceDate;
      final DateTime timeB = b is Thought ? b.timestamp : (b as HabitLog).occurrenceDate;
      return timeB.compareTo(timeA);
    });

    setState(() {
      _allThoughts = list;
      _availableHabits = habitDefs;
      _allHabitLogs = allLogs;
      _allTimelineItems = combined;
      _filteredItems = combined;
    });
  }

  void _filterResults() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredItems = _allTimelineItems;
      } else {
        _filteredItems = _allTimelineItems.where((item) {
          if (item is Thought) {
            return item.textContent.toLowerCase().contains(query) ||
                item.categories.any((c) => c.toLowerCase().contains(query)) ||
                item.userTags.any((ut) => ut.toLowerCase().contains(query));
          } else if (item is HabitLog) {
            final def = _availableHabits.cast<HabitDefinition?>().firstWhere(
              (h) => h!.id == item.habitId || h.name == item.habitId,
              orElse: () => null,
            );
            final name = def != null ? def.name : item.habitId;
            return name.toLowerCase().contains(query);
          }
          return false;
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Search Past Echoes", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // Search Bar input
              TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Search thoughts, categories, or routines...",
                  prefixIcon: const Icon(Icons.search, color: Colors.teal, size: 20),
                  filled: true,
                  fillColor: isDark ? Colors.white.withOpacity(0.02) : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.teal),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Total count badge
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "${_filteredItems.length} records saved in sanctuary",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 12),

              // Stream of historical entries
              Expanded(
                child: _filteredItems.isEmpty
                    ? const Center(
                  child: Text(
                    "No check-ins match that search... 🌿",
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                )
                    : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = _filteredItems[index];
                    if (item is Thought) {
                      return _buildHistoryCard(item, isDark);
                    } else {
                      return _buildHabitHistoryCard(item as HabitLog, isDark);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Thought thought, bool isDark) {
    return GestureDetector(
      onTap: () {
        ThoughtDetailDialog.show(
          context,
          thought: thought,
          allThoughts: _allThoughts,
          allHabitLogs: _allHabitLogs,
          availableHabits: _availableHabits,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.02) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.teal.withOpacity(0.06)),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${thought.timestamp.day}/${thought.timestamp.month}/${thought.timestamp.year}",
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "Mood: ${thought.moodScore}/10",
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            thought.textContent,
            style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: isDark ? Colors.white70 : Colors.black87
            ),
          ),
          const SizedBox(height: 14),

          // Render NLP categories attached to this entry
          if (thought.categories.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: thought.categories.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withOpacity(0.1)),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                );
              }).toList(),
            ),
          ],

          if (thought.userTags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: thought.userTags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.withOpacity(0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.label_outline, size: 10, color: Colors.teal),
                      const SizedBox(width: 4),
                      Text(
                        tag,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],

          // Intelligent Companion Linked Thought Box ("Past Echoes")
          if (thought.linkedThoughtId != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.withOpacity(0.18)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.link_rounded, color: Colors.amber, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      thought.connectionReason ?? "Linked with a similar memory.",
                      style: TextStyle(
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                        color: isDark ? Colors.amber[200] : Colors.amber[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),);
  }

  Widget _buildHabitHistoryCard(HabitLog log, bool isDark) {
    dynamic matchedHabit;
    for (var h in _availableHabits) {
      if (h.id == log.habitId || h.name == log.habitId) {
        matchedHabit = h;
        break;
      }
    }
    final icon = matchedHabit != null ? matchedHabit.iconEmoji : '🌿';
    final name = matchedHabit != null ? matchedHabit.name : log.habitId;

    final hour = log.occurrenceDate.hour;
    final minute = log.occurrenceDate.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final timeStr = "$formattedHour:$minute $period";
    final dateStr = "${log.occurrenceDate.day}/${log.occurrenceDate.month}/${log.occurrenceDate.year}";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.015) : Colors.black.withOpacity(0.015),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Text(icon, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Completed on $dateStr at $timeStr",
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}