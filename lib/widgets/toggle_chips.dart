import 'package:flutter/material.dart';

class SearchWithToggle extends StatelessWidget {
  final TextEditingController controller;
  final bool showMap;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onChanged;
  final VoidCallback? onSubmitted;

  const SearchWithToggle({
    super.key,
    required this.controller,
    required this.showMap,
    required this.onToggle,
    required this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Toggle buttons on the left
        ToggleChips(
          showMap: showMap,
          onToggle: onToggle,
        ),
        const SizedBox(width: 12),

        // Search bar takes the remaining space
        Expanded(
          child: SizedBox(
            height: 40, // match toggle button height
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: (_) => onSubmitted?.call(),
              decoration: InputDecoration(
                hintText: "Search branches",
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                filled: true,
                fillColor: Colors.white,
                suffixIcon: const Icon(Icons.search),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ToggleChips extends StatelessWidget {
  final bool showMap;
  final ValueChanged<bool> onToggle;

  const ToggleChips({super.key, required this.showMap, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildIconButton(
          icon: Icons.list,
          selected: !showMap,
          onTap: () => onToggle(false),
        ),
        const SizedBox(width: 8),
        _buildIconButton(
          icon: Icons.map,
          selected: showMap,
          onTap: () => onToggle(true),
        ),
      ],
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 40, // same as search bar
        width: 40,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0255C2) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: selected ? Border.all(color: const Color(0xFF0255C2)) : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0255C2).withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Icon(icon, size: 20, color: selected ? Colors.white : Colors.black),
      ),
    );
  }
}
