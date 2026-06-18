import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/firefly.dart';
import '../models/physical_log.dart';
import '../models/thought.dart';
import '../models/habit.dart';
import '../painters/firefly_painter.dart';
import '../painters/plant_painter.dart';
import '../services/database_service.dart';
import '../widgets/habit_tracker_card.dart';
import '../widgets/cozy_almanac_card.dart';
import '../widgets/causal_correlation_card.dart';
import 'journal_entry_screen.dart';
import 'journal_history_screen.dart';

class PlantType {
  final String id;
  final String name;
  final String emoji;
  final int requiredConsistencyDays;
  final String description;

  const PlantType({
    required this.id,
    required this.name,
    required this.emoji,
    required this.requiredConsistencyDays,
    required this.description,
  });
}

const List<PlantType> _availablePlantTypes = [
  PlantType(id: 'default', name: 'Fern of Solitude', emoji: '🌿', requiredConsistencyDays: 0, description: 'A quiet, resilient fern that thrives in peaceful solitude.'),
  PlantType(id: 'lavender', name: 'Lavender of Calm', emoji: '🪻', requiredConsistencyDays: 3, description: 'Soothing lavender blooms that reward persistent mindfulness.'),
  PlantType(id: 'bonsai', name: 'Bonsai of Focus', emoji: '🌳', requiredConsistencyDays: 5, description: 'An elegant bonsai reflecting deep wisdom and rooted stability.'),
  PlantType(id: 'sakura', name: 'Sakura of Joy', emoji: '🌸', requiredConsistencyDays: 7, description: 'Cherry blossoms that burst into radiant joy after a week of routine.'),
];

class GardenHomeScreen extends StatefulWidget {
  const GardenHomeScreen({super.key});

  @override
  State<GardenHomeScreen> createState() => GardenHomeScreenState();
}

class GardenHomeScreenState extends State<GardenHomeScreen> with TickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();

  double _moodValue = 6.0;
  bool _isTwilight = false;
  bool _isCloudy = false;

  Set<String> _completedHabits = {};
  List<HabitDefinition> _availableHabits = [];
  List<Thought> _historyThoughts = [];
  List<HabitLog> _allHabitLogs = [];

  bool _showCopingReminder = false;
  String _latestLinkedReason = '';

  DateTime _selectedAlmanacDate = DateTime.now();
  Thought? _selectedAlmanacThought;
  List<String> _selectedAlmanacHabits = [];

  Map<String, String> _localInsights = {'status': 'Cultivating sanctuary analytics...'};

  late AnimationController _animController;
  late AnimationController _wiggleController;
  double _swayOffset = 0.0;
  final List<Firefly> _fireflies = [];
  final math.Random _random = math.Random();

  String _selectedPlantId = 'default';
  int _consistencyDays = 0;

  @override
  void initState() {
    super.initState();
    _initializeLocalDatabase();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _animController.addListener(() {
      setState(() {
        _swayOffset = math.sin(_animController.value * math.pi * 2) * 0.05;
        _updateFireflies();
      });
    });

    _wiggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _wiggleController.addListener(() {
      setState(() {});
    });

    for (int i = 0; i < 15; i++) {
      _fireflies.add(Firefly(
        position: Offset(_random.nextDouble(), _random.nextDouble()),
        speed: _random.nextDouble() * 0.002 + 0.001,
        angle: _random.nextDouble() * math.pi * 2,
        size: _random.nextDouble() * 3 + 1.5,
      ));
    }
  }

  void _initializeLocalDatabase() async {
    await _db.init();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedPlantId = prefs.getString('selected_plant_id') ?? 'default';
    });
    _syncStateFromDatabase();
  }

  void refreshState() {
    _syncStateFromDatabase();
  }

  void _syncStateFromDatabase() {
    final list = _db.getThoughts();
    final insights = _db.calculateLocalCausalCorrelations();
    final habitDefs = _db.getHabitDefinitions();
    final allLogs = _db.getHabitLogs();

    final today = DateTime.now();
    final todayCompleted = allLogs.where((log) =>
    log.occurrenceDate.year == today.year &&
        log.occurrenceDate.month == today.month &&
        log.occurrenceDate.day == today.day
    ).map((log) => log.habitId).toSet();

    final loggedDates = list.map((t) => DateTime(t.timestamp.year, t.timestamp.month, t.timestamp.day)).toSet();
    final consistency = loggedDates.length;

    setState(() {
      _historyThoughts = list;
      _localInsights = insights;
      _availableHabits = habitDefs;
      _allHabitLogs = allLogs;
      _completedHabits = todayCompleted;
      _consistencyDays = consistency;

      if (list.isNotEmpty) {
        _moodValue = list.first.moodScore.toDouble();
        if (list.first.linkedThoughtId != null) {
          _latestLinkedReason = list.first.connectionReason ?? '';
        } else {
          _latestLinkedReason = '';
        }
      }
      _loadAlmanacDetailsForDate(_selectedAlmanacDate);
    });
  }

  void _selectPlant(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_plant_id', id);
    setState(() {
      _selectedPlantId = id;
    });
  }

  void _showPlantSelectorDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text("Unlock & Select Plants", style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _availablePlantTypes.length,
              itemBuilder: (context, index) {
                final plant = _availablePlantTypes[index];
                final isUnlocked = _consistencyDays >= plant.requiredConsistencyDays;
                final isSelected = _selectedPlantId == plant.id;

                return ListTile(
                  leading: Text(plant.emoji, style: const TextStyle(fontSize: 28)),
                  title: Text(plant.name, style: TextStyle(fontWeight: FontWeight.bold, color: isUnlocked ? null : Colors.grey)),
                  subtitle: Text(isUnlocked ? plant.description : "Unlocks at ${plant.requiredConsistencyDays} days logged (Current: $_consistencyDays)"),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Colors.teal)
                      : (!isUnlocked ? const Icon(Icons.lock, size: 16, color: Colors.grey) : null),
                  onTap: isUnlocked
                      ? () {
                          _selectPlant(plant.id);
                          Navigator.pop(context);
                        }
                      : null,
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _loadAlmanacDetailsForDate(DateTime date) {
    _selectedAlmanacDate = date;

    final dayThought = _historyThoughts.cast<Thought?>().firstWhere(
          (t) => t!.timestamp.year == date.year && t.timestamp.month == date.month && t.timestamp.day == date.day,
      orElse: () => null,
    );

    final dayHabits = _allHabitLogs
        .where((log) => log.occurrenceDate.year == date.year && log.occurrenceDate.month == date.month && log.occurrenceDate.day == date.day)
        .map((log) {
      final def = _availableHabits.cast<HabitDefinition?>().firstWhere(
            (h) => h!.id == log.habitId || h.name == log.habitId,
        orElse: () => null,
      );
      return def != null ? "${def.iconEmoji} ${def.name}" : "🌿 ${log.habitId}";
    })
        .toList();

    setState(() {
      _selectedAlmanacThought = dayThought;
      _selectedAlmanacHabits = dayHabits;
    });
  }

  void _showAddHabitDialog() {
    final nameController = TextEditingController();
    String selectedEmoji = '🌿';
    final emojis = ['🌿', '☀️', '💧', '🛌', '📖', '🏃‍♀️', '🧘‍♀️', '🍵', '🍎', '🎨', '🐶', '🎶'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text(
                "Add Custom Routine",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: "What's the routine?",
                      hintText: "e.g., Watered my herbs",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Choose an icon",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: emojis.map((emoji) {
                      final isSelected = selectedEmoji == emoji;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedEmoji = emoji;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.teal.withOpacity(0.15) : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.teal : Colors.grey.withOpacity(0.2),
                              width: 1.5,
                            ),
                          ),
                          child: Text(emoji, style: const TextStyle(fontSize: 20)),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) return;

                    final newDef = HabitDefinition(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameController.text.trim(),
                      iconEmoji: selectedEmoji,
                    );

                    await _db.saveHabitDefinition(newDef);
                    Navigator.pop(context);
                    _syncStateFromDatabase();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Create"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _wiggleController.dispose();
    super.dispose();
  }

  void _updateFireflies() {
    if (!_isTwilight) return;
    for (var f in _fireflies) {
      f.position = Offset(
        (f.position.dx + math.cos(f.angle) * f.speed) % 1.0,
        (f.position.dy + math.sin(f.angle) * f.speed) % 1.0,
      );
      if (_random.nextDouble() < 0.05) {
        f.angle += (_random.nextDouble() - 0.5) * 0.5;
      }
    }
  }

  List<Color> _getBackgroundGradient() {
    if (_isTwilight) {
      return [
        const Color(0xFF0F172A),
        const Color(0xFF1E1B4B),
        const Color(0xFF311042),
      ];
    }
    if (_isCloudy) {
      return [
        const Color(0xFFE2E8F0),
        const Color(0xFFCBD5E1),
        const Color(0xFF94A3B8),
      ];
    }
    return [
      const Color(0xFFF1F5F9),
      const Color(0xFFECFDF5),
      const Color(0xFFD1FAE5),
    ];
  }

  Color _getDashboardCardColor() {
    return _isTwilight ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.65);
  }

  double _getWiggleSway() {
    if (_wiggleController.isAnimating) {
      double t = _wiggleController.value;
      return math.sin(t * math.pi * 8) * (1.0 - t) * 0.25;
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    double growthProgress = (_moodValue / 10.0) * 0.6 + 0.4;
    if (_completedHabits.isNotEmpty) {
      growthProgress += (_completedHabits.length * 0.08);
    }
    growthProgress = growthProgress.clamp(0.2, 1.2);
    double bloomProgress = (_moodValue >= 6) ? ((_moodValue - 5) / 5.0) : 0.0;

    return Scaffold(
      body: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _getBackgroundGradient(),
              ),
            ),
          ),
          if (_isTwilight)
            CustomPaint(
              size: Size.infinite,
              painter: FireflyPainter(_fireflies),
            ),

          Positioned(
            top: 50,
            right: 20,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.local_florist, size: 28, color: Colors.teal),
                  onPressed: _showPlantSelectorDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.history_edu, size: 28, color: Colors.teal),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const JournalHistoryScreen()),
                    ).then((_) => _syncStateFromDatabase());
                  },
                ),
                IconButton(
                  icon: Icon(
                    _isTwilight ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
                    color: _isTwilight ? Colors.amber : Colors.indigo,
                    size: 28,
                  ),
                  onPressed: () {
                    setState(() {
                      _isTwilight = !_isTwilight;
                      if (_isTwilight) _isCloudy = false;
                    });
                  },
                ),
              ],
            ),
          ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).size.height * 0.45,
            child: SafeArea(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: 40,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 1200),
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _isTwilight
                                ? Colors.indigoAccent.withOpacity(0.15)
                                : (_isCloudy ? Colors.blueGrey.withOpacity(0.1) : Colors.amber.withOpacity(0.25)),
                            blurRadius: 70,
                            spreadRadius: 30,
                          )
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      _wiggleController.forward(from: 0.0);
                    },
                    child: CustomPaint(
                      size: const Size(300, 320),
                      painter: PlantPainter(
                        growthProgress: growthProgress,
                        bloomProgress: bloomProgress,
                        isTwilight: _isTwilight,
                        isCloudy: _isCloudy,
                        sway: _swayOffset + _getWiggleSway(),
                        completedHabits: _completedHabits,
                        plantId: _selectedPlantId,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.52,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              decoration: BoxDecoration(
                color: _getDashboardCardColor(),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  )
                ],
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: _isTwilight ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    ElevatedButton.icon(
                      onPressed: () async {
                        final updated = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const JournalEntryScreen()),
                        );
                        if (updated == true) {
                          _syncStateFromDatabase();
                        }
                      },

                      label: const Text("What's on your mind?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade400,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_moodValue <= 4 && _latestLinkedReason.isNotEmpty) _buildCopingReminderAnchor(),

                    const SizedBox(height: 16),

                    _buildLocalInsightContainer(),

                    const SizedBox(height: 20),

                    HabitTrackerCard(
                      availableHabits: _availableHabits,
                      completedHabits: _completedHabits,
                      isTwilight: _isTwilight,
                      onAddHabitRequested: _showAddHabitDialog,
                      onHabitToggled: (habit, isSelected) async {
                        setState(() {
                          if (isSelected) {
                            _completedHabits.remove(habit.id);
                            _completedHabits.remove(habit.name);
                          } else {
                            _completedHabits.add(habit.id);
                          }
                        });

                        await _db.saveHabitLog(HabitLog(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          habitId: habit.id,
                          occurrenceDate: DateTime.now(),
                          createdAt: DateTime.now(),
                        ));
                        _syncStateFromDatabase();
                      },
                    ),

                    const SizedBox(height: 24),

                    CozyAlmanacCard(
                      historyThoughts: _historyThoughts,
                      allHabitLogs: _allHabitLogs,
                      availableHabits: _availableHabits,
                      selectedDate: _selectedAlmanacDate,
                      selectedThought: _selectedAlmanacThought,
                      selectedHabits: _selectedAlmanacHabits,
                      onDateSelected: _loadAlmanacDetailsForDate,
                    ),

                    const SizedBox(height: 24),

                    CausalCorrelationCard(
                      historyThoughts: _historyThoughts,
                      availableHabits: _availableHabits,
                      allHabitLogs: _allHabitLogs,
                      physicalLogs: _db.getPhysicalLogs(),
                    ),

                    const SizedBox(height: 20),
                    _buildSimulatorControls(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalInsightContainer() {
    final hasInsight = _localInsights.containsKey('insight');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.teal.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _localInsights['status'] ?? 'Cultivating...',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal),
          ),
          if (hasInsight) ...[
            const SizedBox(height: 6),
            Text(
              _localInsights['insight']!,
              style: TextStyle(fontSize: 12, color: _isTwilight ? Colors.white70 : Colors.black87, height: 1.4),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildCopingReminderAnchor() {
    return AnimatedCrossFade(
      firstChild: InkWell(
        onTap: () {
          setState(() {
            _showCopingReminder = true;
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.withOpacity(0.3), width: 1.2),
          ),
          child: Row(
            children: [
              const Icon(Icons.blur_on, color: Colors.amber, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "A gentle echo waits here...",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.amber),
                    ),
                    Text(
                      "Tap to review a time you survived this headspace before.",
                      style: TextStyle(fontSize: 11, color: _isTwilight ? Colors.white60 : Colors.black87),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.amber),
            ],
          ),
        ),
      ),
      secondChild: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.teal.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.teal.withOpacity(0.3), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_florist_outlined, color: Colors.teal, size: 18),
                const SizedBox(width: 8),
                const Text("From your notes:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "\"$_latestLinkedReason\"",
              style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, height: 1.4, color: _isTwilight ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                setState(() {
                  _showCopingReminder = false;
                });
              },
              child: const Text(
                "Close gentle reminder",
                style: TextStyle(fontSize: 11, decoration: TextDecoration.underline, color: Colors.grey),
              ),
            )
          ],
        ),
      ),
      crossFadeState: _showCopingReminder ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 300),
    );
  }

  Widget _buildSimulatorControls() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isTwilight ? Colors.white.withOpacity(0.02) : Colors.teal.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _isTwilight ? Colors.white10 : Colors.teal.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Simulator Sandbox Dashboard (Testing Controls)",
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: _isTwilight ? Colors.white38 : Colors.teal.shade800),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isCloudy = !_isCloudy;
                      if (_isCloudy) _isTwilight = false;
                    });
                  },
                  icon: const Icon(Icons.cloud_queue, size: 16),
                  label: Text(_isCloudy ? "Clear Skies" : "Simulate Mist"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final now = DateTime.now();
                    for (int i = 1; i <= 14; i++) {
                      final day = now.subtract(Duration(days: i));
                      final completedSteppedOutside = i % 2 == 0;
                      final sleepHours = i % 3 == 0 ? 4.5 : 8.5;
                      final mood = i % 3 == 0 ? 3 : (completedSteppedOutside ? 9 : 6);

                      await _db.savePhysicalLog(PhysicalLog(
                        date: day,
                        sleepHours: sleepHours,
                        isPeriodDay: false,
                        skippedMeal: i % 4 == 0,
                        lateCaffeine: i % 3 == 0,
                      ));

                      await _db.saveThought(Thought(
                        id: 'mock_day_$i',
                        timestamp: day,
                        moodScore: mood,
                        textContent: i % 3 == 0
                            ? "Felt so tired and stagnant today. Stayed indoors."
                            : "Went on an incredibly serene walk. Sun was shining bright!",
                        categories: i % 3 == 0 ? ['Energy'] : ['Nature'],
                      ));

                      if (completedSteppedOutside) {
                        await _db.saveHabitLog(HabitLog(
                          id: 'mock_hl_outside_$i',
                          habitId: '1',
                          occurrenceDate: day,
                          createdAt: day,
                        ));
                      }
                      if (sleepHours > 7) {
                        await _db.saveHabitLog(HabitLog(
                          id: 'mock_hl_sleep_$i',
                          habitId: '2',
                          occurrenceDate: day,
                          createdAt: day,
                        ));
                      }
                    }

                    _syncStateFromDatabase();
                  },
                  icon: const Icon(Icons.insights, size: 16),
                  label: const Text("Seed Sandbox"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}