import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart'; // ✅ added for distance filter
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox; // ✅ added for map

import 'branch_services_modal.dart'; // make sure you have this

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
  bool _loadingServices = true;

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  Future<void> _fetchServices() async {
    final query = await FirebaseFirestore.instance.collection('services').get();

    final services = query.docs.where((doc) {
      final availability = List.from(doc['availability'] ?? []);
      return availability.isNotEmpty;
    }).map((doc) {
      final name = (doc.data()['test_name'] ?? doc.id).toString();
      return {"id": doc.id, "name": name};
    }).toList();

    setState(() {
      _services = services..sort((a, b) => a['name']!.compareTo(b['name']!));
      _loadingServices = false;
    });

    debugPrint("✅ Loaded ${_services.length} services with availability");
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingServices) {
      return const Center(child: CircularProgressIndicator());
    }

    return OutlinedButton.icon(
      icon: const Icon(Icons.filter_alt, size: 20, color: Color(0xFF0255C2)),
      label: const Text(
        "Filter",
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0255C2),
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFF0255C2), width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onPressed: () async {
        final result = await showModalBottomSheet<List<String>>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _ServiceFilterSheet(
            services: _services,
            currentSelected: widget.selectedServices,
          ),
        );

        if (result != null) {
          widget.onApply(result);
        }
      },
    );
  }
}

class _ServiceFilterSheet extends StatefulWidget {
  final List<Map<String, String>> services; // {id, name}
  final List<String> currentSelected;

  const _ServiceFilterSheet({
    super.key,
    required this.services,
    required this.currentSelected,
  });

  @override
  State<_ServiceFilterSheet> createState() => _ServiceFilterSheetState();
}

class _ServiceFilterSheetState extends State<_ServiceFilterSheet> {
  late List<String> _selectedServices;
  late List<Map<String, String>> _filteredServices;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _matchingBranches = [];
  bool _loadingBranches = false;

  bool _nearbyOnly = false; // ✅ toggle for nearby filtering
  Position? _userPosition; // ✅ user position

  bool _showMapView = false; // ✅ toggle for map view
  mapbox.MapboxMap? _mapboxMap;

  final Color pccBlue = const Color(0xFF0255C2);

  @override
  void initState() {
    super.initState();
    _selectedServices = List.from(widget.currentSelected);
    _filteredServices = List.from(widget.services);
    _searchController.addListener(_onSearchChanged);

    _fetchMatchingBranches();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredServices = widget.services
          .where((s) => s['name']!.toLowerCase().contains(query))
          .toList()
        ..sort((a, b) => a['name']!.compareTo(b['name']!));
    });
  }

  Future<void> _fetchMatchingBranches() async {
    if (_selectedServices.isEmpty) {
      setState(() => _matchingBranches = []);
      return;
    }

    setState(() => _loadingBranches = true);

    final branchSnap =
        await FirebaseFirestore.instance.collection('branches').get();
    final serviceSnap =
        await FirebaseFirestore.instance.collection('services').get();

    final Map<String, List<String>> branchServices = {};
    for (var service in serviceSnap.docs) {
      final serviceId = service.id;
      final availability = List.from(service['availability'] ?? []);
      for (var ref in availability) {
        String branchId;
        if (ref is DocumentReference) {
          branchId = ref.id;
        } else if (ref is String) {
          branchId = ref.split('/').last;
        } else {
          continue;
        }
        branchServices.putIfAbsent(branchId, () => []).add(serviceId);
      }
    }

    var branches = branchSnap.docs.where((doc) {
      final services = branchServices[doc.id] ?? [];
      return _selectedServices.every((s) => services.contains(s));
    }).map((doc) {
      final data = doc.data();
      return {
        "id": doc.id,
        "name": data["name"] ?? "",
        "address": data["address"] ?? "",
        "contact": data["contact"] ?? "",
        "email": data["email"] ?? "",
        "latitude": (data["latitude"] ?? 0).toDouble(),
        "longitude": (data["longitude"] ?? 0).toDouble(),
      };
    }).toList();

    // ✅ Nearby filter with distance
    if (_nearbyOnly) {
      try {
        _userPosition ??= await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        branches = branches.map((b) {
          final distance = Geolocator.distanceBetween(
            _userPosition!.latitude,
            _userPosition!.longitude,
            b['latitude'],
            b['longitude'],
          );
          return {...b, "distanceKm": distance / 1000};
        }).where((b) => (b["distanceKm"] as double) <= 10).toList();

        // Sort by distance
        branches.sort((a, b) =>
            (a["distanceKm"] as double).compareTo(b["distanceKm"] as double));
      } catch (e) {
        debugPrint("❌ Could not get location for nearby filter: $e");
      }
    }

    setState(() {
      _matchingBranches = branches;
      _loadingBranches = false;
    });
  }

  void _selectAllServices() {
    setState(() {
      _selectedServices = widget.services.map((s) => s['id']!).toList();
    });
    _fetchMatchingBranches();
  }

  void _clearAllServices() {
    setState(() {
      _selectedServices.clear();
    });
    _fetchMatchingBranches();
  }

  Future<void> _launchNavigation(double lat, double lng) async {
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final branchCount = _matchingBranches.length;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.6,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
            ),

            // Header with actions + nearby toggle + map toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "Select Services • $branchCount branches",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0255C2),
                      ),
                    ),
                  ),
                  Switch(
                    value: _nearbyOnly,
                    activeColor: Colors.green,
                    onChanged: (val) {
                      setState(() => _nearbyOnly = val);
                      _fetchMatchingBranches();
                    },
                  ),
                  Text(
                    _nearbyOnly ? "Nearby" : "All",
                    style: const TextStyle(fontSize: 12),
                  ),
                  IconButton(
                    icon: Icon(
                      _showMapView ? Icons.list : Icons.map,
                      color: pccBlue,
                    ),
                    onPressed: () => setState(() => _showMapView = !_showMapView),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _selectAllServices,
                    child: const Text(
                      "Select All",
                      style: TextStyle(color: Colors.green),
                    ),
                  ),
                  TextButton(
                    onPressed: _clearAllServices,
                    child: const Text(
                      "Clear All",
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, _selectedServices),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0255C2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Apply"),
                  ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Search services...",
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF0255C2)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // List or Map view
            Expanded(
              child: _loadingBranches
                  ? const Center(child: CircularProgressIndicator())
                  : _matchingBranches.isEmpty
                      ? const Center(
                          child: Text("No matching branches found",
                              style: TextStyle(color: Colors.grey)),
                        )
                      : _showMapView
                          ? _buildMapView()
                          : _buildListView(controller),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(ScrollController controller) {
    return ListView.builder(
      controller: controller,
      itemCount: _matchingBranches.length,
      itemBuilder: (_, i) {
        final branch = _matchingBranches[i];
        final staticMapUrl =
            "https://api.mapbox.com/styles/v1/mapbox/streets-v12/static/"
            "pin-l+0255C2(${branch['longitude']},${branch['latitude']})/"
            "${branch['longitude']},${branch['latitude']},14,0/600x300"
            "?access_token=${dotenv.env['mapbox_access_token']}";

        final distanceKm = branch["distanceKm"] != null
            ? (branch["distanceKm"] as double).toStringAsFixed(1)
            : null;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  child: Image.network(staticMapUrl, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 10),

              // Name + Distance
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    branch["name"] ?? "",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0255C2),
                    ),
                  ),
                  if (distanceKm != null)
                    Text("$distanceKm km",
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green)),
                ],
              ),
              const SizedBox(height: 6),

              Text(branch["address"] ?? "",
                  style: const TextStyle(fontSize: 13)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMapView() {
    if (_matchingBranches.isEmpty) {
      return const Center(child: Text("No branches to display on map"));
    }

    final first = _matchingBranches.first;
    return mapbox.MapWidget(
      key: const ValueKey("mapbox_filter"),
      styleUri: "mapbox://styles/mapbox/streets-v12",
      cameraOptions: mapbox.CameraOptions(
        center: mapbox.Point(
          coordinates: mapbox.Position(first["longitude"], first["latitude"]),
        ),
        zoom: 11,
      ),
      onMapCreated: (map) {
        _mapboxMap = map;
        _addBranchMarkers();
      },
    );
  }

  Future<void> _addBranchMarkers() async {
    if (_mapboxMap == null) return;

    final manager =
        await _mapboxMap!.annotations.createPointAnnotationManager();
    await manager.deleteAll();

    for (final branch in _matchingBranches) {
      await manager.create(
        mapbox.PointAnnotationOptions(
          geometry: mapbox.Point(
            coordinates: mapbox.Position(
              branch["longitude"],
              branch["latitude"],
            ),
          ),
          iconSize: 1.5,
        ),
      );
    }
  }
}
