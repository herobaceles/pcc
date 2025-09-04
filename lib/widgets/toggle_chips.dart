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
          onSelected: (_) => onToggle(false),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text("Map"),
          selected: showMap,
          onSelected: (_) => onToggle(true),
        ),
      ],
    );
  }
}
