import 'package:flutter/material.dart';
import 'garden_home_screen.dart';
import 'journal_history_screen.dart';
import 'journal_entry_screen.dart';

class NavigationShell extends StatefulWidget {
  const NavigationShell({super.key});

  @override
  State<NavigationShell> createState() => NavigationShellState();
}

class NavigationShellState extends State<NavigationShell> {
  int _currentIndex = 0;

  final GlobalKey<GardenHomeScreenState> _gardenKey = GlobalKey<GardenHomeScreenState>();
  final GlobalKey<JournalHistoryScreenState> _historyKey = GlobalKey<JournalHistoryScreenState>();

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      GardenHomeScreen(key: _gardenKey),
      JournalHistoryScreen(key: _historyKey),
    ];
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });

    if (index == 0) {
      _gardenKey.currentState?.refreshState();
    } else if (index == 1) {
      _historyKey.currentState?.refreshData();
    }
  }

  void selectTab(int index) {
    _onTabTapped(index);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        clipBehavior: Clip.antiAlias,
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 10,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: Icon(
                  Icons.local_florist_rounded,
                  color: _currentIndex == 0 ? Colors.teal.shade400 : (isDark ? Colors.white38 : Colors.black38),
                ),
                tooltip: 'My Garden',
                onPressed: () => _onTabTapped(0),
              ),
              const SizedBox(width: 40),
              IconButton(
                icon: Icon(
                  Icons.history_edu_rounded,
                  color: _currentIndex == 1 ? Colors.teal.shade400 : (isDark ? Colors.white38 : Colors.black38),
                ),
                tooltip: 'Past Echoes',
                onPressed: () => _onTabTapped(1),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        elevation: 4,
        backgroundColor: Colors.teal.shade400,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        tooltip: 'Write a thought',
        onPressed: () async {
          final updated = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const JournalEntryScreen()),
          );
          if (updated == true) {
            _gardenKey.currentState?.refreshState();
            _historyKey.currentState?.refreshData();
            _onTabTapped(1);
          }
        },
        child: const Icon(Icons.add_rounded, size: 32),
      ),
    );
  }
}