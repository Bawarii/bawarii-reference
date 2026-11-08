import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BawariiReferenceApp());
}

class BawariiReferenceApp extends StatelessWidget {
  const BawariiReferenceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bawarii Reference',
      theme: BawariiTheme.light(),
      home: const HomeScreen(),
    );
  }
}
