import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'search_field.dart';

class BranchServicesModal extends StatefulWidget {
  final DocumentReference branchRef;
  final String branchName;
  final Color themeColor;

  const BranchServicesModal({
    super.key,
    required this.branchRef,
    required this.branchName,
    this.themeColor = const Color(0xFF0255C2),
  });

  @override
  State<BranchServicesModal> createState() => _BranchServicesModalState();
}

class _BranchServicesModalState extends State<BranchServicesModal> {
  String _searchQuery = "";
  late final Stream<QuerySnapshot> _servicesStream; // ✅ Cached stream

  @override
  void initState() {
    super.initState();
    _servicesStream = FirebaseFirestore.instance
        .collection('services')
        .where(
          'availability',
          arrayContains: widget.branchRef,
        )
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20), // ✅ Rounded modal
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20), // ✅ Same radius
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: StreamBuilder<QuerySnapshot>(
                  stream: _servicesStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      // ✅ Branded loader with blur
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.25),
                              ),
                            ),
                          ),
                          const Center(
                            child: SizedBox(
                              height: 60,
                              width: 60,
                              child: Image(
                                image: AssetImage('assets/PCCSUS.png'),
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _buildFixedHeight(
                        child: const Center(
                          child: Text(
                            "No services available.",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      );
                    }

                    final allServices = snapshot.data!.docs;

                    // 🔎 Apply search filter locally
                    final filteredServices = allServices.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name =
                          (data['test_name'] ?? "").toString().toLowerCase();
                      final desc =
                          (data['test_description'] ?? "").toString().toLowerCase();
                      return name.contains(_searchQuery.toLowerCase()) ||
                          desc.contains(_searchQuery.toLowerCase());
                    }).toList();

                    return _buildFixedHeight(
                      child: Column(
                        children: [
                          // Header
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
                                  icon: const Icon(Icons.close,
                                      color: Colors.grey),
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
                                setState(() => _searchQuery = value);
                              },
                            ),
                          ),

                          const Divider(height: 1),

                          // Services list area
                          Expanded(
                            child: filteredServices.isEmpty
                                ? const Center(
                                    child: Text(
                                      "No results match your search.",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                        12, 16, 12, 20),
                                    itemCount: filteredServices.length,
                                    itemBuilder: (context, index) {
                                      return _buildServiceTile(
                                          filteredServices[index]);
                                    },
                                  ),
                          ),
                        ],
                      ),
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

  /// ✅ Keeps modal at fixed height even if empty
  Widget _buildFixedHeight({required Widget child}) {
    return SizedBox(
      height: 600,
      child: child,
    );
  }

  Widget _buildServiceTile(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12), // ✅ Rounded cards
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
          if (data['results_tats'] != null)
            Text(
              "TAT: ${data['results_tats']}",
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
