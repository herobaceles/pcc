import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:url_launcher/url_launcher_string.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/branch.dart';
import 'branch_services_modal.dart';

class BranchList extends StatelessWidget {
  final List<Branch> allBranches;
  final geo.Position? userPosition;
  final geo.Position? searchPosition;
  final String searchQuery;
  final List<String> selectedServiceIds;
  final Map<String, String> serviceNames;
  final RichText Function(String, String, {TextStyle? style})
      highlightTextBuilder;
  final ValueChanged<Branch> onSelect;

  const BranchList({
    super.key,
    required this.allBranches,
    this.userPosition,
    this.searchPosition,
    this.searchQuery = "",
    this.selectedServiceIds = const [],
    this.serviceNames = const {},
    required this.highlightTextBuilder,
    required this.onSelect,
  });

  final Color pccBlue = const Color(0xFF0255C2);

  Future<void> _launchNavigation(Branch branch) async {
    final lat = branch.latitude.toStringAsFixed(6);
    final lng = branch.longitude.toStringAsFixed(6);
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';

    if (await canLaunchUrlString(url)) {
      await launchUrlString(url);
    }
  }

  /// ✅ Sort only. Filtering is handled in BranchMapPage.
  List<Branch> _sortBranches(List<Branch> branches) {
    final sorted = [...branches];

    if (searchPosition != null) {
      sorted.sort((a, b) {
        final da = geo.Geolocator.distanceBetween(
          searchPosition!.latitude,
          searchPosition!.longitude,
          a.latitude,
          a.longitude,
        );
        final db = geo.Geolocator.distanceBetween(
          searchPosition!.latitude,
          searchPosition!.longitude,
          b.latitude,
          b.longitude,
        );
        return da.compareTo(db);
      });
    } else if (userPosition != null) {
      sorted.sort((a, b) {
        final da = geo.Geolocator.distanceBetween(
          userPosition!.latitude,
          userPosition!.longitude,
          a.latitude,
          a.longitude,
        );
        final db = geo.Geolocator.distanceBetween(
          userPosition!.latitude,
          userPosition!.longitude,
          b.latitude,
          b.longitude,
        );
        return da.compareTo(db);
      });
    } else {
      sorted.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    }

    return sorted;
  }

  /// ✅ Find the nearest branch overall
  Branch? _getNearestBranch() {
    if (searchPosition == null || allBranches.isEmpty) return null;

    Branch? nearest;
    double nearestDist = double.infinity;

    for (final b in allBranches) {
      final dist = geo.Geolocator.distanceBetween(
        searchPosition!.latitude,
        searchPosition!.longitude,
        b.latitude,
        b.longitude,
      );
      if (dist < nearestDist) {
        nearest = b;
        nearestDist = dist;
      }
    }
    return nearest;
  }

  @override
  Widget build(BuildContext context) {
    var branches = _sortBranches(allBranches);
    bool showingFallback = false;

    // ✅ If no branches found after search, show nearest branch instead
    if (branches.isEmpty && searchPosition != null) {
      final nearest = _getNearestBranch();
      if (nearest != null) {
        branches = [nearest];
        showingFallback = true;
      }
    }

    if (branches.isEmpty) {
      return const Center(
        child: Text(
          "No branches found",
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
      );
    }

    return Column(
      children: [
        if (showingFallback)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: pccBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "No branches were found in this area. Showing the nearest branch instead.",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: pccBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
            itemCount: branches.length,
            itemBuilder: (context, i) => _buildBranchCard(context, branches[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildBranchCard(BuildContext context, Branch branch) {
    double? distance;
    final basePos = searchPosition ?? userPosition;

    if (basePos != null) {
      distance = geo.Geolocator.distanceBetween(
            basePos.latitude,
            basePos.longitude,
            branch.latitude,
            branch.longitude,
          ) /
          1000;
    }

    final staticMapUrl =
        "https://api.mapbox.com/styles/v1/mapbox/streets-v12/static/"
        "pin-l+0255C2(${branch.longitude},${branch.latitude})/"
        "${branch.longitude},${branch.latitude},14,0/600x300"
        "?access_token=${dotenv.env['mapbox_access_token']}";

    return GestureDetector(
      onTap: () => onSelect(branch),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Static map
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: Image.network(
                  staticMapUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.map, color: Colors.grey, size: 40),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Name + Distance
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: highlightTextBuilder(
                    branch.name,
                    searchQuery,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: pccBlue,
                    ),
                  ),
                ),
                if (distance != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.directions_walk,
                            size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          '${distance.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),

            // Address
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, color: Colors.red, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: highlightTextBuilder(
                    branch.address,
                    searchQuery,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Contact
            if (branch.contact.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.phone, color: Color(0xFF0255C2), size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(branch.contact,
                        style: TextStyle(fontSize: 13, color: pccBlue)),
                  ),
                ],
              ),
            const SizedBox(height: 4),

            // Email
            if (branch.email.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.email, color: Color(0xFF0255C2), size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(branch.email,
                        style: TextStyle(fontSize: 13, color: pccBlue)),
                  ),
                ],
              ),
            const SizedBox(height: 8),

            // Services
            if (branch.services.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: -8,
                children: branch.services.map((sid) {
                  final name = serviceNames[sid] ?? sid;
                  return Chip(
                    label: Text(
                      name,
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: pccBlue.withOpacity(0.1),
                    labelStyle: TextStyle(color: pccBlue),
                  );
                }).toList(),
              ),
            if (branch.services.isNotEmpty) const SizedBox(height: 8),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _launchNavigation(branch),
                    icon: const Icon(Icons.directions, size: 18),
                    label: const Text("Navigate",
                        style: TextStyle(fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: pccBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final branchRef = FirebaseFirestore.instance
                          .collection("branches")
                          .doc(branch.id);

                      showDialog(
                        context: context,
                        barrierColor: Colors.black54,
                        builder: (_) => BranchServicesModal(
                          branchRef: branchRef,
                          branchName: branch.name,
                          themeColor: pccBlue,
                        ),
                      );
                    },
                    icon: const Icon(Icons.list, size: 18),
                    label: const Text("Services",
                        style: TextStyle(fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: pccBlue.withOpacity(0.08),
                      foregroundColor: pccBlue,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
