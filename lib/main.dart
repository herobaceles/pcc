import 'package:flutter/material.dart';
import 'pages/branch_map_page.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'config.dart'; // ✅ Use centralized config

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await loadConfig(); // ✅ Loads .env and assigns global mapboxAccessToken

  mapbox.MapboxOptions.setAccessToken(mapboxAccessToken);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BranchMapPage(),
    );
  }
}
