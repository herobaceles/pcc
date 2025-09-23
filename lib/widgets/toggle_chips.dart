import 'package:flutter/material.dart';

class ToggleChips extends StatelessWidget {
  final bool showMap;
  final ValueChanged<bool> onToggle;

  const ToggleChips({super.key, required this.showMap, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildButton(
              icon: Icons.list,
              label: "List",
              selected: !showMap,
              onTap: () => onToggle(false),
              isLeft: true,
            ),
          ),
          Expanded(
            child: _buildButton(
              icon: Icons.map,
              label: "Map",
              selected: showMap,
              onTap: () => onToggle(true),
              isLeft: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required bool isLeft,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0255C2) : Colors.white,
          borderRadius: BorderRadius.horizontal(
            left: isLeft ? const Radius.circular(30) : Radius.zero,
            right: !isLeft ? const Radius.circular(30) : Radius.zero,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? Colors.white : const Color(0xFF0255C2),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : const Color(0xFF0255C2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
