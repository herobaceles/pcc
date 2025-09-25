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
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _onChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (value.isEmpty) {
        _removeOverlay();
        return;
      }
      final results = await widget.onFetchSuggestions(value);
      if (mounted) {
        setState(() => _suggestions = results);
        _showOverlay();
      }
    });
  }

  Future<void> _onSubmit(String value) async {
    if (value.trim().isEmpty) return;

    _removeOverlay(); // ✅ always close suggestions first

    final results = await widget.onFetchSuggestions(value);
    if (results.isNotEmpty) {
      widget.onSuggestionSelected(results.first);
    }
  }

  void _showOverlay() {
    _removeOverlay();
    if (_suggestions.isEmpty) return;

    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 32, // match parent width
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 50), // dropdown just below field
          child: Material(
            color: Colors.white,
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (context, i) {
                final suggestion = _suggestions[i];
                return ListTile(
                  title: Text(
                    suggestion["place"],
                    style: const TextStyle(color: Colors.black),
                  ),
                  onTap: () {
                    widget.onSuggestionSelected(suggestion);
                    _removeOverlay(); // ✅ close when suggestion tapped
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.controller,
                onChanged: _onChanged,
                onSubmitted: _onSubmit,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  border: const OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
                style: const TextStyle(fontSize: 16),
              ),
            ),
            SizedBox(
              height: 48,
              width: 48,
              child: IconButton(
                onPressed: () async {
                  final value = widget.controller?.text ?? "";
                  if (value.trim().isEmpty) return;

                  _removeOverlay(); // ✅ close dropdown right away

                  final results = await widget.onFetchSuggestions(value);
                  if (results.isNotEmpty) {
                    widget.onSuggestionSelected(results.first);
                  }
                },
                style: ButtonStyle(
                  backgroundColor:
                      MaterialStateProperty.all<Color>(const Color(0xFF0255C2)),
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
    );
  }
}
