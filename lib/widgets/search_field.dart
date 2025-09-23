import 'dart:async';
import 'package:flutter/material.dart';

class SearchField extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> Function(String) onFetchSuggestions;
  final ValueChanged<Map<String, dynamic>> onSuggestionSelected;
  final String hintText;
  final TextEditingController? controller;

  const SearchField({
    super.key,
    required this.onFetchSuggestions,
    required this.onSuggestionSelected,
    this.hintText = "Enter your location",
    this.controller,
  });

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  List<Map<String, dynamic>> _suggestions = [];
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (value.isEmpty) {
        setState(() => _suggestions = []);
        return;
      }
      final results = await widget.onFetchSuggestions(value);
      if (mounted) {
        setState(() => _suggestions = results);
      }
    });
  }

  /// 🔹 Handle full address search when user presses Enter
  Future<void> _onSubmit(String value) async {
    if (value.trim().isEmpty) return;

    final results = await widget.onFetchSuggestions(value);
    if (results.isNotEmpty) {
      widget.onSuggestionSelected(results.first); // pick best match
      setState(() => _suggestions = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              // Text input
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  onChanged: _onChanged,
                  onSubmitted: _onSubmit, // ✅ Enter key support
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    border: const OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                  ),
                  style: const TextStyle(fontSize: 16),
                ),
              ),

              // Inline search button
              SizedBox(
                height: 48,
                width: 48,
                child: IconButton(
                  onPressed: () async {
                    final value = widget.controller?.text ?? "";
                    if (value.trim().isEmpty) return;

                    final results = await widget.onFetchSuggestions(value);
                    if (results.isNotEmpty) {
                      widget.onSuggestionSelected(results.first);
                      setState(() => _suggestions = []);
                    }
                  },
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all<Color>(
                      const Color(0xFF0255C2),
                    ),
                    shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                      const RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.search, color: Colors.white),
                ),
              ),
            ],
          ),
        ),

        // Suggestions dropdown
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                )
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (context, i) {
                final suggestion = _suggestions[i];
                return ListTile(
                  title: Text(suggestion["place"]),
                  onTap: () {
                    widget.onSuggestionSelected(suggestion);
                    setState(() => _suggestions = []);
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
