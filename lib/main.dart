import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'pages/splash_screen.dart';
import 'pages/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize Firebase
  await Firebase.initializeApp();

  // ✅ Load .env config (Mapbox token, etc.)
  await loadConfig();
  mapbox.MapboxOptions.setAccessToken(mapboxAccessToken);

  // ✅ Check if onboarding was completed
  final prefs = await SharedPreferences.getInstance();
  final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

  runApp(MyApp(onboardingComplete: onboardingComplete));
}

class MyApp extends StatelessWidget {
  final bool onboardingComplete;
  const MyApp({super.key, required this.onboardingComplete});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "PCC Locator",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true, // ✅ Enable Material 3 styling
      ),
      // ✅ If onboarding is complete → go SplashScreen, otherwise show onboarding
      home: onboardingComplete
          ? const SplashScreen()
          : const OnboardingScreen(),
    );
  }
}
