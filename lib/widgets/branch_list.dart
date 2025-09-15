import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:url_launcher/url_launcher_string.dart';
import '../models/branch.dart';
import 'branch_services_modal.dart'; // ✅ modal

class BranchList extends StatelessWidget {
  final List<Branch> branches;
  final List<Branch> allBranches;
  final geo.Position? userPosition;
  final geo.Position? searchPosition;
  final String searchQuery;
  final RichText Function(String, String, {TextStyle? style})
      highlightTextBuilder;
  final ValueChanged<Branch> onSelect;

  const BranchList({
    super.key,
    required this.branches,
    required this.allBranches,
    this.userPosition,
    this.searchPosition,
    this.searchQuery = "",
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

  Branch? _getNearestBranch() {
    if (allBranches.isEmpty) return null;
    final basePos = searchPosition ?? userPosition;
    if (basePos == null) return null;

    Branch nearest = allBranches.first;
    double nearestDistance = geo.Geolocator.distanceBetween(
      basePos.latitude,
      basePos.longitude,
      nearest.latitude,
      nearest.longitude,
    );

    for (final branch in allBranches.skip(1)) {
      final distance = geo.Geolocator.distanceBetween(
        basePos.latitude,
        basePos.longitude,
        branch.latitude,
        branch.longitude,
      );
      if (distance < nearestDistance) {
        nearest = branch;
        nearestDistance = distance;
      }
    }
    return nearest;
  }

  @override
  Widget build(BuildContext context) {
    if (branches.isEmpty && (searchPosition != null || userPosition != null)) {
      final nearest = _getNearestBranch();
      if (nearest != null) {
        final basePos = searchPosition ?? userPosition!;
        final distance = geo.Geolocator.distanceBetween(
              basePos.latitude,
              basePos.longitude,
              nearest.latitude,
              nearest.longitude,
            ) /
            1000;

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Text(
              searchPosition != null
                  ? "No exact match. Nearest branch (${distance.toStringAsFixed(2)} km away):"
                  : "No match. Nearest branch (${distance.toStringAsFixed(2)} km away):",
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            _buildBranchCard(context, nearest),
          ],
        );
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

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: branches.length,
      itemBuilder: (context, i) {
        return _buildBranchCard(context, branches[i]);
      },
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

    return GestureDetector(
      onTap: () => onSelect(branch),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Map preview (no extra markers, just Studio style)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 140,
                child: mapbox.MapWidget(
                  key: ValueKey("branch-map-${branch.id}"),
                  styleUri: mapbox.MapboxStyles.MAPBOX_STREETS,
                  cameraOptions: mapbox.CameraOptions(
                    center: mapbox.Point(
                      coordinates: mapbox.Position(
                        branch.longitude,
                        branch.latitude,
                      ),
                    ),
                    zoom: 14,
                  ),
                  onMapCreated: (map) async {
                    // No annotation manager → rely only on your Studio style
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Title + distance
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
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
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Contact & Email
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
                      showDialog(
                        context: context,
                        barrierColor: Colors.black54,
                        builder: (_) => BranchServicesModal(
                          branchId: branch.id,
                          branchName: branch.name,
                          themeColor: pccBlue,
                        ),
                      );
                    },
                    icon: const Icon(Icons.list, size: 18),
                    label: const Text("Services",
                        style: TextStyle(fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: pccBlue.withValues(alpha: 0.08),
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
