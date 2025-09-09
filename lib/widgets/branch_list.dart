import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:url_launcher/url_launcher_string.dart';
import '../models/branch.dart';

class BranchList extends StatelessWidget {
  final List<Branch> branches;
  final geo.Position? userPosition;
  final String searchQuery;
  final RichText Function(String, String, {TextStyle? style}) highlightTextBuilder;
  final ValueChanged<Branch> onSelect; // Callback when a branch is tapped

  const BranchList({
    super.key,
    required this.branches,
    this.userPosition,
    this.searchQuery = "",
    required this.highlightTextBuilder,
    required this.onSelect,
  });

  final Color pccBlue = const Color(0xFF0255C2);

  void _launchNavigation(Branch branch) async {
    final lat = branch.latitude.toStringAsFixed(6);
    final lng = branch.longitude.toStringAsFixed(6);
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url);
    } else {
      debugPrint("Could not launch $url");
    }
  }

  void _launchMapLocation(Branch branch) async {
    final lat = branch.latitude.toStringAsFixed(6);
    final lng = branch.longitude.toStringAsFixed(6);
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url);
    } else {
      debugPrint("Could not launch $url");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (branches.isEmpty) {
      return const Center(
        child: Text(
          "No branches found.",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ListView.builder(
        itemCount: branches.length,
        itemBuilder: (context, i) {
          final branch = branches[i];

          // Calculate distance if userPosition is available
          double? distance;
          if (userPosition != null) {
            distance = geo.Geolocator.distanceBetween(
                  userPosition!.latitude,
                  userPosition!.longitude,
                  branch.latitude,
                  branch.longitude,
                ) /
                1000; // km
          }

          return GestureDetector(
            onTap: () => onSelect(branch),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
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
                  // Branch Name
                  highlightTextBuilder(
                    branch.name,
                    searchQuery,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: pccBlue,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Address
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.red, size: 18),
                      const SizedBox(width: 4),
                      Expanded(
                        child: highlightTextBuilder(
                          branch.address,
                          searchQuery,
                          style: const TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                      ),
                    ],
                  ),

                  // Distance
                  if (distance != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${distance.toStringAsFixed(2)} km away',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),

                  const SizedBox(height: 8),

                  // Contact info
                  Row(
                    children: [
                      const Icon(Icons.phone, color: Color(0xFF0255C2)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          branch.contact,
                          style: TextStyle(fontSize: 14, color: pccBlue),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.email, color: Color(0xFF0255C2)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          branch.email,
                          style: TextStyle(fontSize: 14, color: pccBlue),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Services (show up to 3)
                  if (branch.services.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: branch.services
                          .take(3)
                          .map((s) => Chip(
                                label: Text(s),
                                backgroundColor: pccBlue.withOpacity(0.15),
                                labelStyle: TextStyle(color: pccBlue),
                              ))
                          .toList(),
                    ),

                  const SizedBox(height: 12),

                  // Buttons: Directions & Map
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _launchNavigation(branch),
                          icon: const Icon(Icons.directions),
                          label: const Text("Directions"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: pccBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: pccBlue.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.map, size: 20),
                          color: pccBlue,
                          onPressed: () => _launchMapLocation(branch),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
