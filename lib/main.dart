import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/services/sonos_api.dart';
import 'src/state/action_executor.dart';
import 'src/state/device_settings_store.dart';
import 'src/state/household_store.dart';
import 'src/ui/system_map_page.dart';

void main() {
  runApp(const SonosConfigApp());
}

class SonosConfigApp extends StatefulWidget {
  const SonosConfigApp({super.key});

  @override
  State<SonosConfigApp> createState() => _SonosConfigAppState();
}

class _SonosConfigAppState extends State<SonosConfigApp> {
  late final SonosApi _api;
  late final HouseholdStore _household;
  late final ActionExecutor _executor;
  late final DeviceSettingsStore _settings;

  @override
  void initState() {
    super.initState();
    _api = SonosApi();
    _household = HouseholdStore(api: _api);
    _executor =
        ActionExecutor(api: _api, refreshHousehold: _household.refresh);
    _settings = DeviceSettingsStore(_api);
    _household.initialize();
  }

  @override
  void dispose() {
    _executor.dispose();
    _settings.dispose();
    _household.dispose(); // closes the shared SonosApi
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF1DB954);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<HouseholdStore>.value(value: _household),
        ChangeNotifierProvider<ActionExecutor>.value(value: _executor),
        ChangeNotifierProvider<DeviceSettingsStore>.value(value: _settings),
      ],
      child: MaterialApp(
        title: 'Sonos Config',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: seed),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
              seedColor: seed, brightness: Brightness.dark),
        ),
        themeMode: ThemeMode.system,
        home: const SystemMapPage(),
      ),
    );
  }
}
