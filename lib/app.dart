import 'package:flutter/material.dart';

import 'engine/transfer_engine.dart';
import 'ui/screens/phase1_screen.dart';
import 'ui/theme/app_theme.dart';

class IsekaiDropApp extends StatelessWidget {
  const IsekaiDropApp({super.key, required this.engine});

  final TransferEngine engine;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Isekai Drop',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // Dark by default; a theme setting (dark/light/system) comes later.
      themeMode: ThemeMode.dark,
      home: Phase1Screen(engine: engine),
    );
  }
}
