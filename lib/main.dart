import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'pages/branch_map_page.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'config.dart'; // ✅ Use centralized config

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Load app configuration
  await loadConfig(); // ✅ Loads .env and assigns global mapboxAccessToken

  // Set Mapbox access token
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
