import 'package:flutter/material.dart';
import 'screens/dashboard.dart';

void main() {
  runApp(const GoldApp());
}

class GoldApp extends StatelessWidget {
  const GoldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Gold Tracker',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.amber,
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
      ),
      home: const DashboardScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
