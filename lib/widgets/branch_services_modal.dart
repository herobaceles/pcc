import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'search_field.dart'; // ✅ reuse your SearchField

class BranchServicesModal extends StatefulWidget {
  final String branchId;
  final String branchName;
  final Color themeColor;

  const BranchServicesModal({
    super.key,
    required this.branchId,
    required this.branchName,
    this.themeColor = const Color(0xFF0255C2),
  });

  @override
  State<BranchServicesModal> createState() => _BranchServicesModalState();
}

class _BranchServicesModalState extends State<BranchServicesModal> {
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('services')
                      .where(
                        'availability',
                        isEqualTo: FirebaseFirestore.instance
                            .doc('branches/${widget.branchId}'),
                      )
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          "No services listed.",
                          style: TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                      );
                    }

                    final allServices = snapshot.data!.docs;

                    // Apply search filter
                    final filteredServices = allServices.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name =
                          (data['test_name'] ?? "").toString().toLowerCase();
                      final desc =
                          (data['test_description'] ?? "").toString().toLowerCase();
                      return name.contains(_searchQuery.toLowerCase()) ||
                          desc.contains(_searchQuery.toLowerCase());
                    }).toList();

                    // Decide scrollable or auto-size
                    final bool isScrollable = filteredServices.length > 4;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header with close button
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "${widget.branchName} Services",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: widget.themeColor,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.grey),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ),

                        // Search bar
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                          child: SearchField(
                            hintText: "Search services...",
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                            },
                            onSearchPressed: () {
                              setState(() {}); // refresh list
                            },
                          ),
                        ),

                        const Divider(height: 1),

                        // Services list
                        if (isScrollable)
                          Flexible(
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 16, 12, 20),
                              itemCount: filteredServices.length,
                              itemBuilder: (context, index) {
                                return _buildServiceTile(filteredServices[index]);
                              },
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 16, 12, 20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: filteredServices
                                  .map((doc) => _buildServiceTile(doc))
                                  .toList(),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceTile(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8), // ✅ only vertical margin
      padding: const EdgeInsets.all(14),
      width: double.infinity, // ✅ stretch to fill available width
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data['test_name'] ?? "Unnamed Service",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: widget.themeColor,
            ),
          ),
          const SizedBox(height: 6),
          if (data['test_description'] != null)
            Text(
              data['test_description'],
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          if (data['running_days'] != null)
            Text(
              "Running days: ${data['running_days']}",
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          if (data['results_tat'] != null)
            Text(
              "TAT: ${data['results_tat']}",
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          if (data['patient_preparation'] != null)
            Text(
              "Preparation: ${data['patient_preparation']}",
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
        ],
      ),
    );
  }
}
