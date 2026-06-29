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
import 'detailed_analytics_screen.dart';
import 'developer_view_screen.dart';
import 'journal_entry_screen.dart';
import 'journal_history_screen.dart';
import 'navigation_shell.dart';

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

  late AnimationController _animController;
  late AnimationController _wiggleController;
  double _swayOffset = 0.0;
  final List<Firefly> _fireflies = [];
  final math.Random _random = math.Random();

  String _selectedPlantId = 'default';
  int _consistencyDays = 0;
  bool _isTwilightInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isTwilightInitialized) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      _isTwilight = isDark;
      _isTwilightInitialized = true;
    }
  }

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
        .toSet()
        .toList();

    setState(() {
      _selectedAlmanacThought = dayThought;
      _selectedAlmanacHabits = dayHabits;
    });
  }

  void _showAddHabitDialog() {
    final nameController = TextEditingController();
    String selectedEmoji = '🌿';
    final emojis = [
      '🌿', '☀️', '💧', '🛌', '📖', '🏃‍♀️', '🧘‍♀️', '🍵', '🍎', '🎨', '🐶', '🎶',
      '⚡', '💥', '🤢', '💊'
    ];

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
                  icon: const Icon(Icons.terminal_rounded, size: 28, color: Colors.teal),
                  tooltip: "Dev Diagnostics",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DeveloperViewScreen(
                          historyThoughts: _historyThoughts,
                          availableHabits: _availableHabits,
                          allHabitLogs: _allHabitLogs,
                          physicalLogs: _db.getPhysicalLogs(),
                          isTwilight: _isTwilight,
                        ),
                      ),
                    ).then((_) => _syncStateFromDatabase());
                  },
                ),
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
            bottom: MediaQuery.of(context).size.height * 0.38,
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
                      size: const Size(240, 260),
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
              height: MediaQuery.of(context).size.height * 0.44,
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
                          if (context.mounted) {
                            context.findAncestorStateOfType<NavigationShellState>()?.selectTab(1);
                          }
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
                    const SizedBox(height: 20),

                    HabitTrackerCard(
                      availableHabits: _availableHabits.where((h) => h.id != 'seizure').toList(),
                      allHabitLogs: _allHabitLogs,
                      isTwilight: _isTwilight,
                      onAddHabitRequested: _showAddHabitDialog,
                      onHabitLogged: (habit) async {
                        await _db.saveHabitLog(HabitLog(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          habitId: habit.id,
                          occurrenceDate: DateTime.now(),
                          createdAt: DateTime.now(),
                        ));
                        _syncStateFromDatabase();
                      },
                      onHabitLogTimeUpdated: (logId, newTime) async {
                        await _db.updateHabitLogTime(logId, newTime);
                        _syncStateFromDatabase();
                      },
                      onHabitLogDeleted: (logId) async {
                        await _db.deleteHabitLog(logId);
                        _syncStateFromDatabase();
                      },
                      onHabitLoggedAtTime: (habit, time) async {
                        await _db.saveHabitLog(HabitLog(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          habitId: habit.id,
                          occurrenceDate: time,
                          createdAt: DateTime.now(),
                        ));
                        _syncStateFromDatabase();
                      },
                      onHabitDeletedPermanently: (habit) async {
                        await _db.deleteHabitDefinition(habit.id);
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
                      isTwilight: _isTwilight,
                    ),

                    const SizedBox(height: 24),

                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DetailedAnalyticsScreen(
                              historyThoughts: _historyThoughts,
                              availableHabits: _availableHabits,
                              allHabitLogs: _allHabitLogs,
                              physicalLogs: _db.getPhysicalLogs(),
                              isTwilight: _isTwilight,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _getDashboardCardColor(),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.teal.withOpacity(0.12)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.analytics_outlined, color: Colors.teal, size: 24),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Deep Analytics & Patterns",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: _isTwilight ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    "Analyze routine consistency & physical tracking trends.",
                                    style: TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.teal),
                          ],
                        ),
                      ),
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
          const SizedBox(height: 10),
          SizedBox(
            width: double.maxFinite,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DeveloperViewScreen(
                      historyThoughts: _historyThoughts,
                      availableHabits: _availableHabits,
                      allHabitLogs: _allHabitLogs,
                      physicalLogs: _db.getPhysicalLogs(),
                      isTwilight: _isTwilight,
                    ),
                  ),
                ).then((_) => _syncStateFromDatabase());
              },
              icon: const Icon(Icons.terminal_rounded, size: 14, color: Colors.white),
              label: const Text("Open Engine Diagnostics Console", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade500,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 10),
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
                    final List<Map<String, dynamic>> seedReflections = [
                      // High Mood / Calm / Active (Mood 8, 9, 10) - 15 unique items
                      {
                        'mood': 9,
                        'text': "A beautiful sunlit morning! Spent two hours tending to the lavender patches and potting new seedlings. The garden feels so calm, peaceful, and relaxed.",
                        'categories': ['Calm', 'Nature', 'Cozy']
                      },
                      {
                        'mood': 8,
                        'text': "Woke up early and walked through the nearby pine forest. Feeling so grateful and positive about this day. I am hopeful and highly motivated.",
                        'categories': ['Gratitude', 'Nature']
                      },
                      {
                        'mood': 9,
                        'text': "Cooked a wonderful dinner with fresh rosemary from the windowsill. Had a peaceful evening reading my book by the window. Happy, cozy, and full of joy.",
                        'categories': ['Joy', 'Cozy', 'Calm']
                      },
                      {
                        'mood': 8,
                        'text': "Finished a light jog in the park. My energy levels are surprisingly high today, and my body feels strong and flexible.",
                        'categories': ['Calm', 'Nature']
                      },
                      {
                        'mood': 10,
                        'text': "An absolutely perfect day. Everything felt flowing and peaceful. Extremely happy and joyful listening to the birds in the garden.",
                        'categories': ['Joy', 'Cozy', 'Gratitude']
                      },
                      {
                        'mood': 8,
                        'text': "Quiet evening. Made a hot cup of chamomile tea, put on ambient music, and spent time sketching. Restful, cozy, and peaceful.",
                        'categories': ['Calm', 'Cozy']
                      },
                      {
                        'mood': 9,
                        'text': "Accomplished all my study goals today without feeling rushed. I was completely focused and concentrated on my productive work tasks.",
                        'categories': ['Focus', 'Gratitude']
                      },
                      {
                        'mood': 8,
                        'text': "Woke up feeling refreshed after a deep sleep. Had a great morning coffee and resolved a complex coding problem. Feeling very motivated.",
                        'categories': ['Focus', 'Joy']
                      },
                      {
                        'mood': 9,
                        'text': "Lovely afternoon picnic in the botanical garden. The flowers are blooming beautifully. Felt a strong connection to nature and peace.",
                        'categories': ['Nature', 'Calm']
                      },
                      {
                        'mood': 10,
                        'text': "Had a hearty laugh with a close friend today. Grateful for supportive people in my life. The conversation lifted my mood significantly.",
                        'categories': ['Joy', 'Gratitude']
                      },
                      {
                        'mood': 8,
                        'text': "Organized my workspace and planned the upcoming week. The clarity of having a clean desk makes me feel focused and productive.",
                        'categories': ['Focus', 'Calm']
                      },
                      {
                        'mood': 9,
                        'text': "Spent the evening watching the sunset from the balcony. The sky was filled with vibrant colors. Feeling calm and appreciative.",
                        'categories': ['Nature', 'Calm', 'Gratitude']
                      },
                      {
                        'mood': 8,
                        'text': "Baked a fresh loaf of sourdough bread today. The house smells amazing. Enjoying the slow, cozy process of baking.",
                        'categories': ['Cozy', 'Joy']
                      },
                      {
                        'mood': 9,
                        'text': "Had a very productive brainstorming session. Ideas are flowing easily, and I feel excited to start working on these new projects.",
                        'categories': ['Focus', 'Joy']
                      },
                      {
                        'mood': 10,
                        'text': "A quiet, mindful day. Practiced meditation and yoga in the morning. Felt completely grounded, peaceful, and connected.",
                        'categories': ['Calm', 'Gratitude']
                      },
                      {
                        'mood': 9,
                        'text': "Visited the local farmer's market today. Bought fresh organic honey and wild berries. Loving the vibrant colors and friendly atmosphere.",
                        'categories': ['Calm', 'Nature', 'Joy']
                      },
                      {
                        'mood': 8,
                        'text': "Woke up at dawn and watched the morning fog clear over the hills. The silence was absolutely beautiful and meditative.",
                        'categories': ['Calm', 'Nature', 'Gratitude']
                      },
                      {
                        'mood': 9,
                        'text': "Had a very productive drawing session this evening. Finally completed the landscape sketch. Feeling accomplished and creative.",
                        'categories': ['Joy', 'Focus', 'Cozy']
                      },
                      {
                        'mood': 8,
                        'text': "Spent an hour doing light gardening. The soil felt warm, and planting the tomato seeds made me feel happy and grounded.",
                        'categories': ['Nature', 'Calm', 'Gratitude']
                      },
                      {
                        'mood': 9,
                        'text': "Had an amazing workout session today. Pushed my limits and felt strong. My energy levels are at an all-time high.",
                        'categories': ['Joy', 'Calm']
                      },
                      {
                        'mood': 8,
                        'text': "Read three chapters of my book in a cozy coffee shop. The warm ambient light and quiet chatter were very soothing.",
                        'categories': ['Cozy', 'Calm']
                      },
                      {
                        'mood': 9,
                        'text': "Sorted out my inbox and resolved all outstanding tasks. Felt a great sense of relief and focus going into the evening.",
                        'categories': ['Focus', 'Calm']
                      },
                      {
                        'mood': 8,
                        'text': "Walked along the lake as the sun went down. The water was perfectly still, reflecting the pink clouds. Truly peaceful.",
                        'categories': ['Nature', 'Calm']
                      },
                      {
                        'mood': 9,
                        'text': "Hosted a small dinner for family. Loved sharing good food and hearing stories. Deeply grateful for family connection.",
                        'categories': ['Joy', 'Gratitude']
                      },
                      {
                        'mood': 8,
                        'text': "Cleaned my workspace and set up a new planner. Feeling incredibly organized, focused, and ready for future tasks.",
                        'categories': ['Focus', 'Calm']
                      },
                      {
                        'mood': 9,
                        'text': "Had a wonderful conversation with a mentor today. Got clear guidance on my goals. Feeling inspired and motivated.",
                        'categories': ['Focus', 'Gratitude']
                      },
                      {
                        'mood': 8,
                        'text': "Spent a quiet afternoon playing the piano. Music always helps me center myself and feel at peace.",
                        'categories': ['Calm', 'Cozy']
                      },
                      {
                        'mood': 9,
                        'text': "Woke up feeling enthusiastic. Spent the morning coding a new UI design. The layout looks modern and clean.",
                        'categories': ['Focus', 'Joy']
                      },
                      {
                        'mood': 8,
                        'text': "A completely relaxing Sunday. Slept in, made pancakes, and spent the day listening to old vinyl records.",
                        'categories': ['Cozy', 'Joy']
                      },
                      {
                        'mood': 9,
                        'text': "Feeling incredibly content with where I am right now. Sitting with a warm cup of coffee and enjoying the present moment.",
                        'categories': ['Calm', 'Gratitude']
                      },

                      // Medium Mood / Balanced (Mood 5, 6, 7) - 15 unique items
                      {
                        'mood': 7,
                        'text': "Spent a quiet afternoon cleaning the apartment and rearranging the bookshelf. Focused on organization, feeling balanced and serene.",
                        'categories': ['Focus', 'Calm']
                      },
                      {
                        'mood': 6,
                        'text': "Feeling a bit distracted today. Work was busy, but I managed to step outside for some mindful, quiet breathing during my break.",
                        'categories': ['Calm', 'Reflection']
                      },
                      {
                        'mood': 5,
                        'text': "A bit of a mixed bag today. Feeling tired, sleepy, and exhausted in the afternoon with low energy, but a short nap helped.",
                        'categories': ['Energy', 'Reflection']
                      },
                      {
                        'mood': 6,
                        'text': "Decent day overall. Met up with a classmate for tea. Thankful for the company, though I feel tired and ready for a quiet night.",
                        'categories': ['Gratitude', 'Cozy']
                      },
                      {
                        'mood': 7,
                        'text': "The weather was overcast. Did some journaling, workspace organization, and quiet self-reflection. Feeling balanced.",
                        'categories': ['Reflection', 'Calm']
                      },
                      {
                        'mood': 6,
                        'text': "Tired but content. Got through a heavy task list. Planning to rest early tonight because my energy levels are low.",
                        'categories': ['Energy', 'Reflection']
                      },
                      {
                        'mood': 7,
                        'text': "Spent the morning running errands. The grocery store was crowded, which was slightly stressful, but now resting quietly at home.",
                        'categories': ['Stress', 'Calm']
                      },
                      {
                        'mood': 6,
                        'text': "A balanced day. Did some light reading and helped a neighbor. Nothing exciting happened, but it was peaceful and calm.",
                        'categories': ['Calm', 'Reflection']
                      },
                      {
                        'mood': 5,
                        'text': "Slow start to the day. Felt a bit foggy in the morning, but as the sun came out, I felt more grounded and organized.",
                        'categories': ['Reflection', 'Energy']
                      },
                      {
                        'mood': 6,
                        'text': "Had a busy workday. Lots of emails to answer, which made me feel slightly overwhelmed, but managed to keep my focus.",
                        'categories': ['Focus', 'Stress']
                      },
                      {
                        'mood': 7,
                        'text': "Rainy afternoon. Spent it listening to the rain and organizing my old photos. A reflective, slightly cozy mood.",
                        'categories': ['Reflection', 'Cozy']
                      },
                      {
                        'mood': 5,
                        'text': "Felt a bit low on energy today, so I skipped my workout. Instead, did some gentle stretching and went to bed early.",
                        'categories': ['Energy', 'Calm']
                      },
                      {
                        'mood': 6,
                        'text': "A standard day. Attended lectures, took notes, and prepared dinner. Feeling okay, just looking forward to the weekend.",
                        'categories': ['Reflection', 'Focus']
                      },
                      {
                        'mood': 7,
                        'text': "Cooked a new soup recipe. It turned out okay. Spent the rest of the evening relaxing and chatting with family in a cozy mood.",
                        'categories': ['Cozy', 'Reflection']
                      },
                      {
                        'mood': 6,
                        'text': "Woke up with a stiff neck, but a warm shower and some light stretching helped. Had a balanced, quiet day of reading.",
                        'categories': ['Calm', 'Reflection']
                      },

                      // Low Mood / Burdened / Crisis (Mood 2, 3, 4) - 15 unique items
                      {
                        'mood': 3,
                        'text': "Felt extremely low and drained today. My body feels heavy, and chronic pain is flaring up with deep fatigue and groggy brain fog.",
                        'categories': ['Discomfort', 'Energy']
                      },
                      {
                        'mood': 3,
                        'text': "A really challenging day. Had a seizure incident which left me feeling disoriented, frustrated, annoyed, and exhausted.",
                        'categories': ['Discomfort', 'Frustration']
                      },
                      {
                        'mood': 4,
                        'text': "Anxious and overwhelmed by work tasks. The stress and deadlines are piling up and my focus is completely shattered.",
                        'categories': ['Stress', 'Frustration']
                      },
                      {
                        'mood': 2,
                        'text': "Completely overwhelmed today. The headache pain levels are making it hard to concentrate. High anxiety and stress.",
                        'categories': ['Discomfort', 'Stress']
                      },
                      {
                        'mood': 3,
                        'text': "Very quiet, heavy headspace today. Felt sad, lonely, depressed, and isolated. Lacked the energy to interact.",
                        'categories': ['Sadness', 'Energy']
                      },
                      {
                        'mood': 4,
                        'text': "Woke up after a night of restless sleep loss. Deep fatigue and groggy brain fog make everything hard to manage.",
                        'categories': ['Energy', 'Discomfort']
                      },
                      {
                        'mood': 3,
                        'text': "Struggling with cycle symptoms. Severe cramps, nausea, and general physical discomfort made it a very unproductive day.",
                        'categories': ['Discomfort', 'Frustration']
                      },
                      {
                        'mood': 4,
                        'text': "Had a setback at work today. The feedback was harsh, and I feel annoyed, frustrated, and disappointed in myself.",
                        'categories': ['Frustration', 'Sadness']
                      },
                      {
                        'mood': 3,
                        'text': "Feeling very anxious and tense about the upcoming medical checkup. Hard to focus on anything else, mind is racing.",
                        'categories': ['Stress', 'Sadness']
                      },
                      {
                        'mood': 2,
                        'text': "A dark, gloomy day. Felt a deep sense of sadness and loneliness. Spent the whole day indoors under the covers.",
                        'categories': ['Sadness', 'Cozy']
                      },
                      {
                        'mood': 3,
                        'text': "Woke up with a migraine. The light sensitivity and pain are unbearable. Staying in a dark room all day.",
                        'categories': ['Discomfort', 'Energy']
                      },
                      {
                        'mood': 4,
                        'text': "Felt very irritable and frustrated today. Minor things kept annoying me. Need some space to calm down and reset.",
                        'categories': ['Frustration', 'Stress']
                      },
                      {
                        'mood': 3,
                        'text': "Exhausted from constant sleep struggles. My body is fatigued, and I feel emotionally sensitive and tearful today.",
                        'categories': ['Energy', 'Sadness']
                      },
                      {
                        'mood': 4,
                        'text': "Struggling to keep up with daily tasks. Everything feels like a chore when you are this exhausted and anxious.",
                        'categories': ['Stress', 'Energy']
                      },
                      {
                        'mood': 3,
                        'text': "A heavy, unproductive day. Had a minor seizure aura that left me feeling disoriented and anxious for hours.",
                        'categories': ['Discomfort', 'Stress']
                      }
                    ];

                    await _db.clearData();
                    final now = DateTime.now();
                    int highIdx = 0;
                    int medIdx = 0;
                    int lowIdx = 0;

                    for (int i = 45; i >= 1; i--) {
                      final day = now.subtract(Duration(days: i));
                      
                      // 1. Determine period cycle properties
                      final cycleDay = i % 28;
                      final isPeriod = cycleDay >= 1 && cycleDay <= 5;
                      String flow = 'None';
                      List<String> symptoms = [];
                      if (isPeriod) {
                        flow = (cycleDay == 1 || cycleDay == 5) ? 'Light' : ((cycleDay == 3) ? 'Heavy' : 'Medium');
                        symptoms = ['Cramps', 'Fatigue'];
                        if (cycleDay == 3) symptoms.add('Headache');
                      }
                      
                      // 2. Correlate mood, pain, and sleep with engineered patterns
                      double pain = 0.0;
                      double sleepHours = 7.5;
                      int mood = 7;
                      
                      if (i == 40 || i == 20) {
                        mood = 3;
                        pain = 7.0;
                        sleepHours = 5.5;
                      } else if (i == 39 || i == 19) {
                        mood = 8;
                        pain = 2.0;
                        sleepHours = 8.0;
                      } else if (isPeriod) {
                        pain = cycleDay == 3 ? 6.5 : 4.0;
                        sleepHours = 6.0;
                        mood = cycleDay == 3 ? 3 : 5;
                      } else {
                        if (i % 12 == 0) {
                          pain = 5.5;
                          sleepHours = 5.0;
                          mood = 4;
                        } else {
                          pain = (i % 7 == 0) ? 2.0 : 0.0;
                          sleepHours = (i % 5 == 0) ? 8.5 : 7.5;
                          mood = (i % 7 == 0) ? 6 : ((i % 10 == 0) ? 9 : 8);
                        }
                      }

                      // Habit Decay: Napping boosts mood in past but drags it recently
                      bool logNapping = false;
                      if (i >= 15) {
                        if (i % 3 == 0) {
                          logNapping = true;
                          mood = math.max(mood, 8);
                        }
                      } else {
                        if (i % 3 == 0) {
                          logNapping = true;
                          mood = math.min(mood, 4);
                        }
                      }
                      
                      // Seizures
                      List<String> seizures = [];
                      if ((sleepHours < 6.5 && pain > 5.0) || (i == 40 || i == 20)) {
                        seizures = ["10:30 AM"];
                      }
                      
                      // Save Physical Log
                      await _db.savePhysicalLog(PhysicalLog(
                        date: day,
                        sleepHours: sleepHours,
                        isPeriodDay: isPeriod,
                        skippedMeal: i % 4 == 0,
                        lateCaffeine: i % 3 == 0,
                        customPainLevel: pain > 0 ? pain : null,
                        customSeizuresCount: seizures.length,
                        seizureTimes: seizures,
                        flowLevel: flow,
                        cycleSymptoms: symptoms,
                      ));
                      
                      // Save Thoughts using dynamically matched seed reflections
                      final matchingReflections = seedReflections.where((ref) {
                        final int m = ref['mood'] as int;
                        if (mood <= 4) return m <= 4;
                        if (mood >= 8) return m >= 8;
                        return m >= 5 && m <= 7;
                      }).toList();

                      final Map<String, dynamic> selectedRef;
                      if (mood <= 4) {
                        selectedRef = matchingReflections[lowIdx % matchingReflections.length];
                        lowIdx++;
                      } else if (mood >= 8) {
                        selectedRef = matchingReflections[highIdx % matchingReflections.length];
                        highIdx++;
                      } else {
                        selectedRef = matchingReflections[medIdx % matchingReflections.length];
                        medIdx++;
                      }

                      final text = selectedRef['text'] as String;
                      final categories = List<String>.from(selectedRef['categories'] as List);
                      
                      await _db.saveThought(Thought(
                        id: 'mock_day_$i',
                        timestamp: day,
                        moodScore: mood,
                        textContent: text,
                        categories: categories,
                        userTags: [categories.first],
                      ));
                      
                      // Save Habit Logs
                      for (final timeStr in seizures) {
                        final dt = DateTime(day.year, day.month, day.day, 10, 30);
                        await _db.saveHabitLog(HabitLog(
                          id: 'mock_hl_seizure_${i}_${timeStr.replaceAll(':', '_')}',
                          habitId: 'seizure',
                          occurrenceDate: dt,
                          createdAt: dt,
                        ));
                      }
                      
                      // Eating
                      if (i % 4 != 0) {
                        await _db.saveHabitLog(HabitLog(
                          id: 'mock_hl_eating_$i',
                          habitId: 'eating',
                          occurrenceDate: day.add(const Duration(hours: 12)),
                          createdAt: day,
                        ));
                      }
                      
                      // Napping
                      if (logNapping) {
                        await _db.saveHabitLog(HabitLog(
                          id: 'mock_hl_napping_$i',
                          habitId: 'napping',
                          occurrenceDate: day.add(const Duration(hours: 15)),
                          createdAt: day,
                        ));
                      }
                      
                      // Gardening & Stepping Out (Synergy Combo)
                      // If both are completed, boost mood to 9/10
                      bool logGardening = (mood >= 8 && i % 2 == 0) || (i == 39 || i == 19);
                      bool logStepping = (mood >= 6 && i % 3 != 0) || (i == 39 || i == 19);
                      
                      if (logGardening && logStepping) {
                        // Synergy boost
                        mood = 9;
                      }

                      if (logGardening) {
                        await _db.saveHabitLog(HabitLog(
                          id: 'mock_hl_gardening_$i',
                          habitId: 'gardening',
                          occurrenceDate: day.add(const Duration(hours: 10)),
                          createdAt: day,
                        ));
                      }
                      
                      if (logStepping) {
                        await _db.saveHabitLog(HabitLog(
                          id: 'mock_hl_stepping_$i',
                          habitId: 'stepping_out',
                          occurrenceDate: day.add(const Duration(hours: 11)),
                          createdAt: day,
                        ));
                      }
                      
                      // Exercise
                      if (mood >= 8 && i % 3 == 0) {
                        await _db.saveHabitLog(HabitLog(
                          id: 'mock_hl_exercise_$i',
                          habitId: 'exercise',
                          occurrenceDate: day.add(const Duration(hours: 17)),
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