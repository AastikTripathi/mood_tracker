import 'package:flutter/material.dart';
import '../models/thought.dart';
import '../models/physical_log.dart';
import '../services/database_service.dart';
import '../services/nlp_service.dart';

class JournalEntryScreen extends StatefulWidget {
  const JournalEntryScreen({super.key});

  @override
  State<JournalEntryScreen> createState() => _JournalEntryScreenState();
}

class _JournalEntryScreenState extends State<JournalEntryScreen> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  final DatabaseService _db = DatabaseService();
  final NlpService _nlp = NlpService();

  double _moodValue = 6.0;
  double _sleepHours = 7.5;
  bool _isPeriodDay = false;
  List<String> _autoCategories = ['Reflection'];
  final List<String> _userTags = [];

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final text = _textController.text;
    setState(() {
      _autoCategories = _nlp.extractCategories(text);
    });
  }

  void _addTag() {
    final text = _tagController.text.trim();
    if (text.isNotEmpty && !_userTags.contains(text)) {
      setState(() {
        _userTags.add(text);
      });
      _tagController.clear();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  String _getMoodLabel() {
    if (_moodValue <= 2) return "completely overwhelmed 🌊";
    if (_moodValue <= 4) return "feeling low / quiet ☁️";
    if (_moodValue <= 6) return "doing okay 🌿";
    if (_moodValue <= 8) return "rested & grounded ☀️";
    return "radiant & peaceful ✨";
  }

  void _saveEntry() async {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write a little thought before saving 🌿')),
      );
      return;
    }

    final now = DateTime.now();
    // Normalize time to midnight to maintain clean daily calendar alignment bounds
    final normalizedDate = DateTime(now.year, now.month, now.day);

    // 1. Save Physical Logs
    final physicalLog = PhysicalLog(
      date: normalizedDate,
      sleepHours: _sleepHours,
      isPeriodDay: _isPeriodDay,
      skippedMeal: false,
      lateCaffeine: false,
    );
    await _db.savePhysicalLog(physicalLog);

    // 2. Save Mental Logs
    final newThought = Thought(
      id: now.millisecondsSinceEpoch.toString(),
      timestamp: now,
      moodScore: _moodValue.round(),
      textContent: _textController.text,
      categories: _autoCategories,
      userTags: _userTags,
    );
    await _db.saveThought(newThought);

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Colors.white.withOpacity(0.03) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Venting Space", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Headspace Control Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.teal.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    Text(_getMoodLabel(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
                    Slider(
                      value: _moodValue,
                      min: 1.0,
                      max: 10.0,
                      divisions: 9,
                      onChanged: (val) => setState(() => _moodValue = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // NEW: High-Polished Physical Analytics Logging Subsystem
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.teal.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Physical Context", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Sleep Rhythm: ${_sleepHours.toStringAsFixed(1)} hrs", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const Icon(Icons.bedtime_outlined, size: 18, color: Colors.indigoAccent),
                      ],
                    ),
                    Slider(
                      value: _sleepHours,
                      min: 3.0,
                      max: 12.0,
                      divisions: 18,
                      activeColor: Colors.indigoAccent.shade100,
                      onChanged: (val) => setState(() => _sleepHours = val),
                    ),
                    const Divider(height: 20),
                    SwitchListTile(
                      title: const Text("Active Cycle/Period Day", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: const Text("Maps emotional patterns against physical changes", style: TextStyle(fontSize: 11, color: Colors.grey)),
                      secondary: const Icon(Icons.water_drop, color: Colors.pinkAccent, size: 20),
                      value: _isPeriodDay,
                      activeColor: Colors.pinkAccent,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setState(() => _isPeriodDay = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Text Workspace Container
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey.withOpacity(0.15)),
                  ),
                  child: TextField(
                    controller: _textController,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                    decoration: const InputDecoration(
                      hintText: "Unburden your thoughts here...",
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Tags Input Field & User Tags Display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.teal.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _tagController,
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              hintText: "Add your own tag (e.g. cozy, stress)...",
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onSubmitted: (_) => _addTag(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.teal, size: 20),
                          onPressed: _addTag,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    if (_userTags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _userTags.map((tag) {
                          return Chip(
                            label: Text(tag, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal)),
                            backgroundColor: Colors.teal.withOpacity(0.08),
                            deleteIcon: const Icon(Icons.close, size: 10, color: Colors.teal),
                            onDeleted: () {
                              setState(() {
                                _userTags.remove(tag);
                              });
                            },
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Categories Tag Row
              Row(
                children: [
                  const Text("NLP Extraction: ", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(width: 8),
                  Wrap(
                    spacing: 6,
                    children: _autoCategories.map((tag) {
                      return Chip(
                        label: Text(tag, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.teal.withOpacity(0.08),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  )
                ],
              ),
              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: _saveEntry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text("Gently Save to Garden", style: TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ),
    );
  }
}