import 'package:flutter/material.dart';

class AppInfoDialog extends StatelessWidget {
  const AppInfoDialog({super.key});

  @override
  Widget build(BuildContext context) {
    const Color pccBlue = Color(0xFF0255C2);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 🔹 Logo before title
            Image.asset(
              'assets/PCCSUS.png',
              height: 60,
            ),
            const SizedBox(height: 12),

            const Text(
              "PCC LOCATOR",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: pccBlue,
              ),
            ),

            const SizedBox(height: 8),
            const Divider(color: pccBlue, thickness: 1),
            const SizedBox(height: 8),

            const Text(
              "Helping patients find PCC Branches and services with ease",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: pccBlue,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 20),
            Text(
              "Developed by Equiserve.",
              style: TextStyle(
                fontSize: 13,
                color: pccBlue,
                fontStyle: FontStyle.italic,
              ),
            ),

            const SizedBox(height: 16),

            // Close button
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "CLOSE",
                style: TextStyle(
                  color: pccBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
