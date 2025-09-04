import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:url_launcher/url_launcher_string.dart';
import '../models/branch.dart';

class BranchList extends StatelessWidget {
  final List<Branch> branches;
  final ValueChanged<Branch> onSelect;
  final geo.Position? userPosition;

  const BranchList({
    super.key,
    required this.branches,
    required this.onSelect,
    this.userPosition,
  });

  // Launch navigation using Google Maps URL
  void _launchNavigation(Branch branch) async {
    final destination = '${branch.latitude},${branch.longitude}';
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=$destination&travelmode=driving';

    try {
      final launched =
          await launchUrlString(url, mode: LaunchMode.externalApplication);
      if (!launched) {
        debugPrint('Could not launch navigation.');
      }
    } catch (e) {
      debugPrint('Error launching navigation: $e');
    }
  }

  void _showBranchModal(BuildContext context, Branch branch) {
    double? distance;
    if (userPosition != null) {
      distance = geo.Geolocator.distanceBetween(
        userPosition!.latitude,
        userPosition!.longitude,
        branch.latitude,
        branch.longitude,
      ) / 1000; // in km
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(branch.name,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue)),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(child: Text(branch.address, style: const TextStyle(fontSize: 16))),
                ],
              ),
              if (distance != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${distance.toStringAsFixed(2)} km away',
                      style: const TextStyle(fontSize: 14, color: Colors.grey)),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.phone, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(child: Text(branch.contact, style: const TextStyle(fontSize: 14))),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.email, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(child: Text(branch.email, style: const TextStyle(fontSize: 14))),
                ],
              ),
              const SizedBox(height: 16),
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
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _launchNavigation(branch),
                      icon: const Icon(Icons.directions),
                      label: const Text("Navigate"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (branches.isEmpty) return const Center(child: Text("No branches found."));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ListView.builder(
        itemCount: branches.length,
        itemBuilder: (context, i) {
          final branch = branches[i];
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                colors: [Colors.white, Color(0xFFE3F2FD)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              leading: const Icon(Icons.location_on, color: Colors.blue),
              title: Text(branch.name),
              subtitle: Text(branch.address),
              onTap: () => _showBranchModal(context, branch),
            ),
          );
        },
      ),
    );
  }
}
