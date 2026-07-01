import 'package:flutter/material.dart';
import 'theme/wabway_theme.dart';
import 'shell/app_shell.dart';

void main() {
  runApp(const WabwayApp());
}

class WabwayApp extends StatelessWidget {
  const WabwayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wabway',
      debugShowCheckedModeBanner: false,
      theme: buildWabwayTheme(),
      home: const AppShell(),
    );
  }
}
