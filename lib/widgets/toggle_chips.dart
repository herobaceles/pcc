import 'package:flutter/material.dart';

class ToggleChips extends StatelessWidget {
  final bool showMap;
  final ValueChanged<bool> onToggle;

  const ToggleChips({super.key, required this.showMap, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ChoiceChip(
          label: const Text("List"),
          selected: !showMap,
          selectedColor: Colors.blue,
          backgroundColor: Colors.grey[200],
          labelStyle: TextStyle(
            color: !showMap ? Colors.white : Colors.black,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          onSelected: (_) => onToggle(false),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text("Map"),
          selected: showMap,
          selectedColor: Colors.blue,
          backgroundColor: Colors.grey[200],
          labelStyle: TextStyle(
            color: showMap ? Colors.white : Colors.black,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          onSelected: (_) => onToggle(true),
        ),
      ],
    );
  }
}
