import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:url_launcher/url_launcher_string.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import '../models/branch.dart';

class BranchList extends StatelessWidget {
  final List<Branch> branches;
  final ValueChanged<Branch> onSelect;
  final geo.Position? userPosition;
  final String searchQuery;
  final RichText Function(String, String, {TextStyle? style}) highlightTextBuilder;

  const BranchList({
    super.key,
    required this.branches,
    required this.onSelect,
    this.userPosition,
    this.searchQuery = "",
    required this.highlightTextBuilder,
  });

  void _launchNavigation(Branch branch) async {
    final destination = '${branch.latitude},${branch.longitude}';
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=$destination&travelmode=driving';

    try {
      final launched =
          await launchUrlString(url, mode: LaunchMode.externalApplication);
      if (!launched) debugPrint('Could not launch navigation.');
    } catch (e) {
      debugPrint('Error launching navigation: $e');
    }
  }

  void _showBranchDialog(BuildContext context, Branch branch) {
    FocusScope.of(context).unfocus();

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

    mapbox.MapboxMap? previewMap;
    mapbox.PointAnnotationManager? pointManager;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: SizedBox(
            height: 450,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Close Button
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

                // Map Preview
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: mapbox.MapWidget(
                      styleUri: mapbox.MapboxStyles.MAPBOX_STREETS,
                      cameraOptions: mapbox.CameraOptions(
                        center: mapbox.Point(
                          coordinates: mapbox.Position(branch.longitude, branch.latitude),
                        ),
                        zoom: 14,
                      ),
                      onMapCreated: (map) async {
                        previewMap = map;
                        pointManager = await map.annotations.createPointAnnotationManager();
                        await pointManager!.create(
                          mapbox.PointAnnotationOptions(
                            geometry: mapbox.Point(
                              coordinates: mapbox.Position(branch.longitude, branch.latitude),
                            ),
                            iconImage: "marker",
                            iconSize: 5,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Branch Details
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      highlightTextBuilder(
                        branch.name,
                        searchQuery,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.red, size: 18),
                          const SizedBox(width: 4),
                          Expanded(
                            child: highlightTextBuilder(
                              branch.address,
                              searchQuery,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (distance != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${distance.toStringAsFixed(2)} km away',
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.phone, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              branch.contact,
                              style: const TextStyle(fontSize: 14, color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.email, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              branch.email,
                              style: const TextStyle(fontSize: 14, color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                onSelect(branch);
                              },
                              icon: const Icon(Icons.map),
                              label: const Text("View on Map"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _launchNavigation(branch),
                              icon: const Icon(Icons.directions),
                              label: const Text("Navigate"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 Header showing total branches
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              "Showing ${branches.length} branch${branches.length == 1 ? '' : 'es'}",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),

          // 🔹 Branch List
          Expanded(
            child: ListView.builder(
              itemCount: branches.length,
              itemBuilder: (context, i) {
                final branch = branches[i];
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        branch.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.red, size: 18),
                          const SizedBox(width: 4),
                          Expanded(
                            child: highlightTextBuilder(
                              branch.address,
                              searchQuery,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _showBranchDialog(context, branch),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text("View Details"),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

