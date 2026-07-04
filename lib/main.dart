import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/state/sonos_controller.dart';
import 'src/ui/home_page.dart';

void main() {
  runApp(const PersonalSonosApp());
}

class PersonalSonosApp extends StatelessWidget {
  const PersonalSonosApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF1DB954); // a warm "media" green
    return ChangeNotifierProvider(
      create: (_) => SonosController()..initialize(),
      child: MaterialApp(
        title: 'Personal Sonos',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: seed),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: seed,
            brightness: Brightness.dark,
          ),
        ),
        themeMode: ThemeMode.system,
        home: const HomePage(),
      ),
    );
  }
}
