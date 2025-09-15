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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search bar full width
        SizedBox(
          height: 44,
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            onSubmitted: (_) => onSubmitted?.call(),
            decoration: InputDecoration(
              hintText: "Search branches",
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
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

        const SizedBox(height: 12),

        // Toggle buttons below search
        Center(
          child: ToggleChips(
            showMap: showMap,
            onToggle: onToggle,
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
        _buildButton(
          icon: Icons.list,
          label: "List",
          selected: !showMap,
          onTap: () => onToggle(false),
        ),
        const SizedBox(width: 16),
        _buildButton(
          icon: Icons.map,
          label: "Map",
          selected: showMap,
          onTap: () => onToggle(true),
        ),
      ],
    );
  }

  Widget _buildButton({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? const Color(0xFF0255C2) : Colors.black87,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? const Color(0xFF0255C2) : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
