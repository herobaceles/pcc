import 'package:flutter/material.dart';

class SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final VoidCallback? onSearch;

  const SearchField({super.key, required this.onChanged, this.onSearch});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: "Search Branches",
        filled: true,
        fillColor: const Color(0xFFFFFFFF), // light gray background for modern look
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        prefixIcon: const Icon(Icons.search, color: Colors.grey),
        suffixIcon: GestureDetector(
          onTap: onSearch,
          child: Container(
            margin: const EdgeInsets.all(6), // spacing inside circle
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search, color: Colors.white),
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30), // rounded for modern style
          borderSide: BorderSide.none, // remove border
        ),
      ),
    );
  }
}
