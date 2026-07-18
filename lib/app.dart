import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

class AslRecognizerApp extends StatelessWidget {
  const AslRecognizerApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xff536dfe);
    return MaterialApp(
      title: 'ASL Letter Recognizer',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
