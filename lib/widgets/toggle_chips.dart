import 'package:flutter/material.dart';

class ToggleChips extends StatelessWidget {
  final bool showMap;
  final ValueChanged<bool> onToggle;

  const ToggleChips({super.key, required this.showMap, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildButton(
            label: "List",
            icon: Icons.list,
            selected: !showMap,
            onTap: () => onToggle(false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildButton(
            label: "Map",
            icon: Icons.map,
            selected: showMap,
            onTap: () => onToggle(true),
          ),
        ),
      ],
    );
  }

  Widget _buildButton({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: selected ? Border.all(color: Colors.blue) : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? Colors.white : Colors.black),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
