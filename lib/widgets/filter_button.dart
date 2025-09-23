import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceFilterButton extends StatefulWidget {
  final List<String> selectedServices; // service IDs
  final void Function(List<String> selectedServices) onApply;

  const ServiceFilterButton({
    super.key,
    required this.selectedServices,
    required this.onApply,
  });

  @override
  State<ServiceFilterButton> createState() => _ServiceFilterButtonState();
}

class _ServiceFilterButtonState extends State<ServiceFilterButton> {
  List<Map<String, String>> _services = []; // {id, name}
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  Future<void> _fetchServices() async {
    final snap = await FirebaseFirestore.instance.collection('services').get();

    final services = snap.docs
        .where((doc) => (doc['availability'] ?? []).isNotEmpty)
        .map((doc) {
      final name = (doc['test_name'] ?? doc.id).toString();
      return {"id": doc.id, "name": name};
    }).toList();

    setState(() {
      _services = services..sort((a, b) => a['name']!.compareTo(b['name']!));
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ElevatedButton.icon(
      icon: const Icon(Icons.filter_alt, size: 18, color: Color(0xFF0255C2)),
      label: const Text(
        "Filter",
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: Color(0xFF0255C2),
        ),
      ),
      onPressed: () async {
        final result = await showModalBottomSheet<List<String>>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _ServiceFilterSheet(
            services: _services,
            selected: widget.selectedServices,
          ),
        );

        if (result != null) widget.onApply(result);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0255C2),
        side: const BorderSide(color: Color(0xFF0255C2), width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8), // ⬅ square edges
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 0,
      ),
    );
  }
}

class _ServiceFilterSheet extends StatefulWidget {
  final List<Map<String, String>> services;
  final List<String> selected;

  const _ServiceFilterSheet({
    required this.services,
    required this.selected,
  });

  @override
  State<_ServiceFilterSheet> createState() => _ServiceFilterSheetState();
}

class _ServiceFilterSheetState extends State<_ServiceFilterSheet> {
  late List<String> _selected;
  final TextEditingController _searchController = TextEditingController();
  late List<Map<String, String>> _filtered;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selected);
    _filtered = List.from(widget.services);
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = widget.services
          .where((s) => s['name']!.toLowerCase().contains(q))
          .toList();
    });
  }

  void _toggle(String id) {
    setState(() {
      _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "Select Services (${_selected.length})",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Color(0xFF0255C2),
                      ),
                    ),
                  ),
                  TextButton(
                      onPressed: () =>
                          setState(() => _selected = widget.services
                              .map((s) => s['id']!)
                              .toList()),
                      child: const Text("All")),
                  TextButton(
                      onPressed: () => setState(() => _selected.clear()),
                      child: const Text("Clear")),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, _selected),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0255C2),
                    ),
                    child: const Text("Apply"),
                  ),
                ],
              ),
            ),
            // search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Search services...",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // list
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final s = _filtered[i];
                  return CheckboxListTile(
                    value: _selected.contains(s['id']),
                    onChanged: (_) => _toggle(s['id']!),
                    title: Text(s['name']!),
                    activeColor: const Color(0xFF0255C2),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
