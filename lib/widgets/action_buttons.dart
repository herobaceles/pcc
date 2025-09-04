import 'package:flutter/material.dart';

class ActionButtons extends StatelessWidget {
  final VoidCallback onNearMe;

  const ActionButtons({super.key, required this.onNearMe});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity, // Make the button full width
      child: ElevatedButton.icon(
        icon: const Icon(Icons.near_me),
        label: const Text("Near Me"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onNearMe,
      ),
    );
  }
}
