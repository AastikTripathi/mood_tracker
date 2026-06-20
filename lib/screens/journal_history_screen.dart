import 'package:flutter/material.dart';
import '../models/thought.dart';
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
  List<Thought> _filteredThoughts = [];
  List<dynamic> _allHabitLogs = [];
  List<dynamic> _availableHabits = [];
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
    setState(() {
      _allThoughts = list;
      _filteredThoughts = list;
      _availableHabits = habitDefs;
      _allHabitLogs = allLogs;
    });
  }

  void _filterResults() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredThoughts = _allThoughts;
      } else {
        _filteredThoughts = _allThoughts.where((t) {
          return t.textContent.toLowerCase().contains(query) ||
              t.categories.any((c) => c.toLowerCase().contains(query)) ||
              t.userTags.any((ut) => ut.toLowerCase().contains(query));
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
                  hintText: "Search thoughts or automatic categories...",
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
                  "${_filteredThoughts.length} moments saved in sanctuary",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 12),

              // Stream of historical entries
              Expanded(
                child: _filteredThoughts.isEmpty
                    ? const Center(
                  child: Text(
                    "No quiet moments match that search... 🌿",
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                )
                    : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _filteredThoughts.length,
                  itemBuilder: (context, index) {
                    final item = _filteredThoughts[index];
                    return _buildHistoryCard(item, isDark);
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
}