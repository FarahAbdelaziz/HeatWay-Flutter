import 'package:flutter/material.dart';

import 'map_screen.dart';
import 'heatmap_screen.dart';
import 'insights_screen.dart';
import 'settings_screen.dart';
import 'splash_screen.dart';
import 'widgets/bottom_nav_bar.dart';

void main() {
  runApp(const HeatWayApp());
}

class HeatWayApp extends StatelessWidget {
  const HeatWayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HeatWay',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F6F1),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF677E61)),
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(destination: MainScreen()),
    );
  }
}

// ============================================================
// MAIN SCREEN
// ============================================================

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int currentIndex = 0;

  final List<Widget> screens = const [
    MapScreen(),
    HeatmapScreen(),
    InsightsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: currentIndex, children: screens),
      bottomNavigationBar: BottomNavBar(
        currentIndex: currentIndex,
        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },
      ),
    );
  }
}
