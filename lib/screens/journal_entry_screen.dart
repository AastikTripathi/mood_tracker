import 'package:flutter/material.dart';
import '../models/thought.dart';
import '../models/physical_log.dart';
import '../models/habit.dart';
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
  final ScrollController _scrollController = ScrollController();
  final FocusNode _textFocusNode = FocusNode();
  final DatabaseService _db = DatabaseService();
  final NlpService _nlp = NlpService();

  double _moodValue = 6.0;
  double _sleepHours = 7.5;
  bool _isPeriodDay = false;
  double _painLevel = 0.0;

  String _flowLevel = 'None';
  final List<String> _cycleSymptoms = [];
  final List<String> _seizureTimes = [];
  DateTime _entryDateTime = DateTime.now();
  String? _perseveranceMessage;

  // Track initial values to detect modifications
  double _initialPainLevel = 0.0;
  String _initialFlowLevel = 'None';
  final List<String> _initialSymptoms = [];

  List<String> _autoCategories = ['Reflection'];
  final List<String> _userTags = [];
  List<String> _suggestedTags = [];
  bool _isAnalyzed = false;

  @override
  void initState() {
    super.initState();
    _db.init().then((_) {
      _checkPastRecovery();
      _loadLastPhysicalSettings();
    });
    _textController.addListener(_onTextChanged);
    _textFocusNode.addListener(_onFocusChanged);
  }

  void _loadLastPhysicalSettings() {
    final physicalLogs = _db.getPhysicalLogs();
    if (physicalLogs.isNotEmpty) {
      final sorted = List<PhysicalLog>.from(physicalLogs)..sort((a, b) => b.date.compareTo(a.date));
      final lastLog = sorted.first;
      setState(() {
        _painLevel = lastLog.customPainLevel ?? 0.0;
        _flowLevel = lastLog.flowLevel;
        _isPeriodDay = lastLog.isPeriodDay;
        _cycleSymptoms.clear();
        _cycleSymptoms.addAll(lastLog.cycleSymptoms);

        _initialPainLevel = _painLevel;
        _initialFlowLevel = _flowLevel;
        _initialSymptoms.clear();
        _initialSymptoms.addAll(_cycleSymptoms);
      });
    }
  }

  void _checkPastRecovery() {
    if (_moodValue > 4) {
      setState(() {
        _perseveranceMessage = null;
      });
      return;
    }

    final thoughts = _db.getThoughts();
    if (thoughts.length < 2) {
      setState(() {
        _perseveranceMessage = "Hey! Just a reminder that you've handled difficult days before. Your strength is quiet but steady. 🌸";
      });
      return;
    }

    // Sort chronologically (oldest to newest) to detect recovery paths
    final sorted = List<Thought>.from(thoughts)..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    DateTime? lowDate;
    DateTime? recoveredDate;
    int? recoveredScore;

    // Search backwards for the most recent low point that has a subsequent recovery
    for (int i = sorted.length - 1; i >= 0; i--) {
      if (sorted[i].moodScore <= 4) {
        for (int j = i + 1; j < sorted.length; j++) {
          if (sorted[j].moodScore >= 7) {
            lowDate = sorted[i].timestamp;
            recoveredDate = sorted[j].timestamp;
            recoveredScore = sorted[j].moodScore;
            break;
          }
        }
        if (lowDate != null && recoveredDate != null) {
          break;
        }
      }
    }

    if (lowDate != null && recoveredDate != null) {
      final formattedLow = "${lowDate.day}/${lowDate.month}";
      final formattedRec = "${recoveredDate.day}/${recoveredDate.month}";
      setState(() {
        _perseveranceMessage = "Hey, just a gentle reminder: around $formattedLow you were feeling quite low, but by $formattedRec you bounced back to a $recoveredScore/10. Your resilience is amazing, and you will get through this too. 🌿";
      });
    } else {
      setState(() {
        _perseveranceMessage = "Remember, you've handled difficult days before. Your strength is quiet but steady. 🌸";
      });
    }
  }

  void _onFocusChanged() {
    if (_textFocusNode.hasFocus) {
      // Smoothly scroll the container up when keyboard opens to prevent viewport occlusion
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _onTextChanged() {
    if (_isAnalyzed) {
      setState(() {
        _isAnalyzed = false;
        _suggestedTags = [];
      });
    }
  }

  void _runAnalysis() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // 1. Query history using semantic vector proximity search (low threshold to rank all entries)
    final similarThoughts = _db.semanticSearch(text, targetThreshold: 0.10);

    // 2. Gather unique tags & categories from the top 3 most semantically similar past notes
    final Set<String> historicalSuggestions = {};
    for (var thought in similarThoughts.take(3)) {
      historicalSuggestions.addAll(thought.categories);
      historicalSuggestions.addAll(thought.userTags);
    }

    // Filter out tags already added by the user or general defaults
    historicalSuggestions.removeWhere((tag) => _userTags.contains(tag) || tag == 'Reflection');

    setState(() {
      _autoCategories = historicalSuggestions.toList();
      _suggestedTags = historicalSuggestions.toList();
      _isAnalyzed = true;
    });

    // Scroll up to ensure the recommended tags section is fully visible
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _addTag() {
    final text = _tagController.text.trim();
    if (text.isNotEmpty && !_userTags.contains(text)) {
      setState(() {
        _userTags.add(text);
        if (_suggestedTags.contains(text)) {
          _suggestedTags.remove(text);
        }
      });
      _tagController.clear();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _tagController.dispose();
    _scrollController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  String _getMoodLabel() {
    if (_moodValue <= 2) return "completely overwhelmed 🌊";
    if (_moodValue <= 4) return "feeling low / quiet ☁️";
    if (_moodValue <= 6) return "doing okay 🌿";
    if (_moodValue <= 8) return "rested & grounded ☀️";
    return "radiant & peaceful ✨";
  }

  DateTime _parseTimeString(String timeStr, DateTime baseDate) {
    try {
      final parts = timeStr.split(' ');
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final period = parts[1].toUpperCase();

      if (period == 'PM' && hour < 12) {
        hour += 12;
      } else if (period == 'AM' && hour == 12) {
        hour = 0;
      }
      return DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
    } catch (e) {
      return baseDate;
    }
  }

  String _formatDateTime(DateTime dt) {
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final weekday = weekdays[dt.weekday - 1];
    final month = months[dt.month - 1];
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return "$weekday, $month ${dt.day} at $formattedHour:$minute $period";
  }

  bool _areSettingsUnchanged() {
    final painSame = _painLevel == _initialPainLevel;
    final flowSame = _flowLevel == _initialFlowLevel;
    final symptomsSame = _cycleSymptoms.length == _initialSymptoms.length &&
        _cycleSymptoms.every((s) => _initialSymptoms.contains(s));
    return painSame && flowSame && symptomsSame;
  }

  void _showVerifySettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text(
            "Verify Physical Status 🌸",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Are you happy with your physical settings for this check-in?",
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
              ),
              const SizedBox(height: 14),
              Text(
                "• Chronic Pain: ${_painLevel > 0 ? '${_painLevel.toInt()}/10' : 'None'}",
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              Text(
                "• Period Flow: $_flowLevel",
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              if (_cycleSymptoms.isNotEmpty)
                Text(
                  "• Symptoms: ${_cycleSymptoms.join(', ')}",
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("No, Modify Settings", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _performSave();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Yes, Save Note"),
            ),
          ],
        );
      },
    );
  }

  void _saveEntry() {
    if (_areSettingsUnchanged()) {
      _showVerifySettingsDialog();
    } else {
      _performSave();
    }
  }

  void _performSave() async {
    final text = _textController.text.trim();
    final textContent = text.isEmpty ? "Quiet check-in 🌿" : text;

    final normalizedDate = DateTime(_entryDateTime.year, _entryDateTime.month, _entryDateTime.day);

    // 1. Save Physical Logs
    final physicalLog = PhysicalLog(
      date: normalizedDate,
      sleepHours: _sleepHours,
      isPeriodDay: _isPeriodDay || _flowLevel != 'None',
      skippedMeal: false,
      lateCaffeine: false,
      customPainLevel: _painLevel > 0 ? _painLevel : null,
      customSeizuresCount: _seizureTimes.length,
      seizureTimes: _seizureTimes,
      painLogs: const [],
      flowLevel: _flowLevel,
      cycleSymptoms: _cycleSymptoms,
    );
    await _db.savePhysicalLog(physicalLog);

    // 2. Save Mental Logs
    final newThought = Thought(
      id: _entryDateTime.millisecondsSinceEpoch.toString(),
      timestamp: _entryDateTime,
      moodScore: _moodValue.round(),
      textContent: textContent,
      categories: _autoCategories,
      userTags: _userTags,
    );
    await _db.saveThought(newThought);

    // 3. Sync Seizures as HabitLogs so they populate the timetable & charts
    for (final timeStr in _seizureTimes) {
      final dt = _parseTimeString(timeStr, _entryDateTime);
      await _db.saveHabitLog(HabitLog(
        id: "${dt.millisecondsSinceEpoch}_seizure",
        habitId: 'seizure',
        occurrenceDate: dt,
        createdAt: DateTime.now(),
      ));
    }

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
        title: const Text("Mood Tracker", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
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
                      onChanged: (val) {
                        setState(() {
                          _moodValue = val;
                        });
                        _checkPastRecovery();
                      },
                    ),
                    if (_perseveranceMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.teal.withOpacity(0.15)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.favorite_border, color: Colors.teal, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(
                                  _perseveranceMessage!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: Colors.teal,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Date/Time selector row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.teal.withOpacity(0.08)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Entry Date & Time:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      onPressed: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _entryDateTime,
                          firstDate: DateTime.now().subtract(const Duration(days: 7)),
                          lastDate: DateTime.now(),
                        );
                        if (pickedDate != null) {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(_entryDateTime),
                          );
                          if (pickedTime != null) {
                            setState(() {
                              _entryDateTime = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );
                            });
                          }
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 14, color: Colors.teal),
                      label: Text(
                        _formatDateTime(_entryDateTime),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        backgroundColor: Colors.teal.withOpacity(0.05),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Text Workspace Container
              Container(
                height: 180,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.withOpacity(0.15)),
                ),
                child: Stack(
                  children: [
                    TextField(
                      controller: _textController,
                      focusNode: _textFocusNode,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      style: const TextStyle(fontSize: 14, height: 1.5),
                      decoration: const InputDecoration(
                        hintText: "What do you feel right now : ",
                        border: InputBorder.none,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: IconButton(
                        onPressed: _runAnalysis,
                        icon: Icon(
                          _isAnalyzed ? Icons.check_circle : Icons.check_circle_outline,
                          color: _isAnalyzed ? Colors.teal : Colors.grey,
                          size: 20,
                        ),
                        tooltip: "Check Note",
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Suggested Tags Box (Dynamic Semantic Recommendation System)
              if (_isAnalyzed && _suggestedTags.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.teal.withOpacity(0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Suggested tags (tap to add)",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _suggestedTags.map((tag) {
                          return ActionChip(
                            label: Text(tag, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal)),
                            backgroundColor: Colors.teal.withOpacity(0.04),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.teal.withOpacity(0.2)),
                            ),
                            onPressed: () {
                              setState(() {
                                if (!_userTags.contains(tag)) {
                                  _userTags.add(tag);
                                }
                                _suggestedTags.remove(tag);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

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

              // Physical Context Block
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
                    const Text("Sleep rhythm", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Sleep: ${_sleepHours.toStringAsFixed(1)} hrs", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
                    const SizedBox(height: 8),
                    
                    Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text(
                          "Cycle & body rhythm",
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.teal),
                        ),
                        subtitle: const Text(
                          "Log cycle flow, symptoms, and chronic pain",
                          style: TextStyle(fontSize: 10.5, color: Colors.grey),
                        ),
                        children: [
                          const Divider(),
                          // Period Cycle Selector
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Period Cycle Flow:", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                              DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _flowLevel,
                                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: _flowLevel != 'None' ? Colors.pinkAccent : Colors.teal,
                                  ),
                                  icon: const Icon(Icons.arrow_drop_down, size: 16, color: Colors.teal),
                                  items: ['None', 'Light', 'Medium', 'Heavy'].map((String level) {
                                    return DropdownMenuItem<String>(
                                      value: level,
                                      child: Text(level),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _flowLevel = val;
                                        _isPeriodDay = val != 'None';
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text("Cycle Symptoms:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: ['Cramps', 'Bloating', 'Headache', 'Fatigue', 'Backache'].map((symptom) {
                                final isSelected = _cycleSymptoms.contains(symptom);
                                return ChoiceChip(
                                  label: Text(symptom, style: const TextStyle(fontSize: 10.5)),
                                  selected: isSelected,
                                  selectedColor: Colors.pinkAccent.withOpacity(0.2),
                                  checkmarkColor: Colors.pinkAccent,
                                  labelStyle: TextStyle(
                                    color: isSelected ? Colors.pinkAccent : (isDark ? Colors.white70 : Colors.black87),
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _cycleSymptoms.add(symptom);
                                      } else {
                                        _cycleSymptoms.remove(symptom);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                          const Divider(height: 24),
                          // Pain logs
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Chronic Pain Severity: ${_painLevel > 0 ? _painLevel.toStringAsFixed(1) : 'None'}", style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                              const Icon(Icons.healing_outlined, size: 18, color: Colors.orangeAccent),
                            ],
                          ),
                          Slider(
                            value: _painLevel,
                            min: 0.0,
                            max: 10.0,
                            divisions: 10,
                            activeColor: Colors.orangeAccent.shade200,
                            onChanged: (val) => setState(() => _painLevel = val),
                          ),
                          const Divider(height: 24),
                          // Seizures logging inside Advanced logging
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Seizure Incidents ⚡", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final pickedTime = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.now(),
                                  );
                                  if (pickedTime != null) {
                                    final hour = pickedTime.hour;
                                    final minute = pickedTime.minute.toString().padLeft(2, '0');
                                    final period = hour >= 12 ? 'PM' : 'AM';
                                    final formattedHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
                                    setState(() {
                                      _seizureTimes.add("$formattedHour:$minute $period");
                                    });
                                  }
                                },
                                icon: const Icon(Icons.add, size: 14),
                                label: const Text("Add", style: TextStyle(fontSize: 11)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent.withOpacity(0.1),
                                  foregroundColor: Colors.redAccent,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_seizureTimes.isEmpty)
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "No seizure incidents logged for this check-in.",
                                style: TextStyle(fontSize: 11.5, color: Colors.grey, fontStyle: FontStyle.italic),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _seizureTimes.length,
                              itemBuilder: (context, index) {
                                final timeStr = _seizureTimes[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Incident at $timeStr",
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent),
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, size: 14, color: Colors.teal),
                                            onPressed: () async {
                                              final pickedTime = await showTimePicker(
                                                context: context,
                                                initialTime: TimeOfDay.now(),
                                              );
                                              if (pickedTime != null) {
                                                final hour = pickedTime.hour;
                                                final minute = pickedTime.minute.toString().padLeft(2, '0');
                                                final period = hour >= 12 ? 'PM' : 'AM';
                                                final formattedHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
                                                setState(() {
                                                  _seizureTimes[index] = "$formattedHour:$minute $period";
                                                });
                                              }
                                            },
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 14, color: Colors.redAccent),
                                            onPressed: () {
                                              setState(() {
                                                _seizureTimes.removeAt(index);
                                              });
                                            },
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                );
                              },
                            ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _saveEntry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ),
    );
  }
}