import 'package:flutter/material.dart';

class ActionButtons extends StatelessWidget {
  final VoidCallback onNearMe;

  const ActionButtons({super.key, required this.onNearMe});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity, 
      child: ElevatedButton.icon(
        icon: const Icon(Icons.near_me),
        label: const Text("Near Me"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF1E7DF2),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onNearMe,
      ),
    );
  }
}
