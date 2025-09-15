import 'package:flutter/material.dart';
import 'branch_map_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const BranchMapPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo (smaller size)
            Image(
              image: AssetImage('assets/PCCSUS.png'),
              height: 70,
              width: 70,
            ),
            SizedBox(height: 30),

            // Tagline text
            Text(
              "PCC NUMBAWAN",
              style: TextStyle(
                fontSize: 22, // larger text
                fontWeight: FontWeight.bold,
                color: Color(0xFF0255C2), // PCC Blue
                letterSpacing: 1.2,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: 50),

            // Subtle loading indicator
            CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0255C2)),
            ),
          ],
        ),
      ),
    );
  }
}
