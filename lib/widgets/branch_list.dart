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
    final lat = branch.latitude.toStringAsFixed(6);
    final lng = branch.longitude.toStringAsFixed(6);

    final geoUrl = 'geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(branch.name)})';
    final iosUrl = 'comgooglemaps://?daddr=$lat,$lng&directionsmode=driving';
    final webUrl = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';

    try {
      if (await canLaunchUrlString(geoUrl)) {
        await launchUrlString(geoUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrlString(iosUrl)) {
        await launchUrlString(iosUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrlString(webUrl)) {
        await launchUrlString(webUrl, mode: LaunchMode.externalApplication);
      } else {
        debugPrint("Could not launch Google Maps.");
      }
    } catch (e) {
      debugPrint("Error launching navigation: $e");
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

    mapbox.PointAnnotationManager? pointManager;
    final TextEditingController searchController = TextEditingController();

    void _showServiceResults(List<String> results) {
      showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              height: 400,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Search Results',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: results.isEmpty
                        ? const Center(child: Text("No results found"))
                        : ListView.builder(
                            itemCount: results.length,
                            itemBuilder: (context, index) {
                              return ListTile(
                                leading: const Icon(Icons.check_circle, color: Colors.green),
                                title: Text(results[index]),
                              );
                            },
                          ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Close"),
                  )
                ],
              ),
            ),
          );
        },
      );
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha((0.5 * 255).toInt()),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.95,
                height: 550,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: Close button + search bar + search button
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.grey),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: searchController,
                                onSubmitted: (query) {
                                  final results = branch.services
                                      .where((s) => s.toLowerCase().contains(query.toLowerCase()))
                                      .toList();
                                  _showServiceResults(results);
                                },
                                decoration: InputDecoration(
                                  hintText: "Search services...",
                                  filled: true,
                                  fillColor: Colors.grey[200],
                                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () {
                                final results = branch.services
                                    .where((s) => s.toLowerCase().contains(searchController.text.toLowerCase()))
                                    .toList();
                                _showServiceResults(results);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0255C2),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Icon(Icons.search, color: Colors.white),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Map
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue.withAlpha(70),
                              width: 1,
                            ),
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
                              pointManager =
                                  await map.annotations.createPointAnnotationManager();
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

                      const SizedBox(height: 12),

                      // Branch info
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            highlightTextBuilder(
                              branch.name,
                              searchQuery,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.location_on, color: Colors.red, size: 18),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: highlightTextBuilder(
                                    branch.address,
                                    searchQuery,
                                    style: const TextStyle(fontSize: 16, color: Colors.black54),
                                  ),
                                ),
                              ],
                            ),
                            if (distance != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  '${distance.toStringAsFixed(2)} km away',
                                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                                ),
                              ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.phone, color: Color(0xFF0255C2)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    branch.contact,
                                    style: const TextStyle(fontSize: 14, color: Color(0xFF0255C2)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.email, color: Color(0xFF0255C2)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    branch.email,
                                    style: const TextStyle(fontSize: 14, color: Color(0xFF0255C2)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
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
                                  backgroundColor: Color(0xFF0255C2),
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
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
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
                              style: const TextStyle(fontSize: 14, color: Colors.black54),
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
                            backgroundColor: Color(0xFF0255C2),
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
