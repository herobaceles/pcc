import 'package:flutter/material.dart';

class ActionButtons extends StatelessWidget {
  final VoidCallback onNearMe;
  final VoidCallback? onFilter;

  const ActionButtons({super.key, required this.onNearMe, this.onFilter});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Near Me Button
        Expanded(
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
        ),
        const SizedBox(width: 8),
        // Filter Button
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.filter_list),
            label: const Text("Filter"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,      // White background
              foregroundColor: Colors.blue,       // Blue text & icon
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 6,                       // Shadow elevation
              shadowColor: Colors.blue,           // Blue shadow
            ),
            onPressed: onFilter ?? () {},
          ),
        ),
      ],
    );
  }
}
