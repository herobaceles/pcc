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
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      borderRadius: BorderRadius.circular(12),
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
                      highlightTextBuilder(
                        branch.address,
                        searchQuery,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
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
                                  borderRadius: BorderRadius.circular(10),
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
                                  borderRadius: BorderRadius.circular(10),
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
      child: ListView.builder(
        itemCount: branches.length,
        itemBuilder: (context, i) {
          final branch = branches[i];
        return InkWell(
  onTap: () => _showBranchDialog(context, branch),
  borderRadius: BorderRadius.circular(12),
  child: Container(
    margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4), // more space between tiles
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16), // more inner padding
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.blue.withOpacity(0.2),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 48, // slightly bigger icon container
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.location_on, color: Colors.blue),
        ),
        const SizedBox(width: 16), // more spacing between icon and text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              highlightTextBuilder(
                branch.name,
                searchQuery,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 4),
              highlightTextBuilder(
                branch.address,
                searchQuery,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
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