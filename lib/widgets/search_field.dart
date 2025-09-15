import 'package:flutter/material.dart';

class SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onSearchPressed; // callback for search button
  final String hintText;
  final TextEditingController? controller;

  const SearchField({
    super.key,
    required this.onChanged,
    this.onSubmitted,
    this.onSearchPressed,
    this.hintText = "Enter your location",
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Text input field
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            decoration: InputDecoration(
              hintText: hintText,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              border: InputBorder.none,
              filled: true,
              fillColor: Colors.white,
            ),
            style: const TextStyle(fontSize: 16),
          ),
        ),
        const SizedBox(width: 8),

        // External search button
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF0255C2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            onPressed: onSearchPressed,
            icon: const Icon(Icons.search, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
