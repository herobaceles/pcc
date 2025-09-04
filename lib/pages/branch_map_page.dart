import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:geolocator/geolocator.dart' as geo;

import '../models/branch.dart';
import '../services/branch_service.dart';
import '../widgets/search_field.dart';
import '../widgets/action_buttons.dart';
import '../widgets/toggle_chips.dart';
import '../widgets/branch_list.dart';

class BranchMapPage extends StatefulWidget {
  const BranchMapPage({super.key});

  @override
  State<BranchMapPage> createState() => _BranchMapPageState();
}

class _BranchMapPageState extends State<BranchMapPage> {
  mapbox.MapboxMap? _mapboxMap;
  mapbox.PointAnnotationManager? _pointManager;

  List<Branch> _branches = [];
  String _searchQuery = "";
  bool _showMap = true;
  Branch? _selectedBranch;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    final branches = await BranchService.loadBranches();
    setState(() {
      _branches = branches;
    });
  }

  List<Branch> get _filteredBranches => _branches
      .where((b) => b.name.toLowerCase().contains(_searchQuery.toLowerCase()))
      .toList();

  void _selectBranch(Branch branch) {
    setState(() {
      _selectedBranch = branch;
      _showMap = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 300));
      await _flyToBranch(branch);
      await _addMarkers();
    });
  }

  // MAP LOGIC
  Future<void> _addMarkers() async {
    if (_pointManager == null) return;
    await _pointManager!.deleteAll();

    for (var branch in _branches) {
      await _pointManager!.create(
        mapbox.PointAnnotationOptions(
          geometry: mapbox.Point(
            coordinates: mapbox.Position(branch.longitude, branch.latitude),
          ),
          iconImage: branch == _selectedBranch ? "marker-15" : "marker-15",
          iconSize: branch == _selectedBranch ? 2.0 : 1.5,
        ),
      );
    }
  }

  Future<void> _flyToBranch(Branch branch) async {
    if (_mapboxMap == null) return;
    await _mapboxMap!.flyTo(
      mapbox.CameraOptions(
        center: mapbox.Point(
          coordinates: mapbox.Position(branch.longitude, branch.latitude),
        ),
        zoom: 14,
      ),
      mapbox.MapAnimationOptions(duration: 1000),
    );
  }

  Future<void> _flyToUserLocation() async {
    try {
      if (!await geo.Geolocator.isLocationServiceEnabled()) return;
      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) return;
      }
      if (permission == geo.LocationPermission.deniedForever) return;

      final pos = await geo.Geolocator.getCurrentPosition();
      await _mapboxMap?.flyTo(
        mapbox.CameraOptions(
          center: mapbox.Point(
            coordinates: mapbox.Position(pos.longitude, pos.latitude),
          ),
          zoom: 14,
        ),
        mapbox.MapAnimationOptions(duration: 1000),
      );
    } catch (e) {
      debugPrint("Error getting location: $e");
    }
  }

  Widget _buildMap() {
    if (_branches.isEmpty) return const Center(child: CircularProgressIndicator());

    return mapbox.MapWidget(
      key: ValueKey(_branches.length),
      styleUri: mapbox.MapboxStyles.MAPBOX_STREETS,
      cameraOptions: mapbox.CameraOptions(
        center: mapbox.Point(
          coordinates: mapbox.Position(
            _branches[0].longitude,
            _branches[0].latitude,
          ),
        ),
        zoom: 5.5,
      ),
      onMapCreated: (map) async {
        _mapboxMap = map;
        _pointManager = await map.annotations.createPointAnnotationManager();
        await _addMarkers();
        if (_selectedBranch != null) await _flyToBranch(_selectedBranch!);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_branches.isEmpty) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("PCC SUS",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 8),
              const Text("Find your Nearest", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
              const Text("PCC SUPP",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 8),
              const Text(
                "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et.",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              SearchField(onChanged: (val) => setState(() => _searchQuery = val)),
              const SizedBox(height: 16),
              ActionButtons(onNearMe: _flyToUserLocation),
              const SizedBox(height: 16),
              ToggleChips(showMap: _showMap, onToggle: (val) => setState(() => _showMap = val)),
              const SizedBox(height: 16),
              Expanded(child: _showMap ? _buildMap() : BranchList(branches: _filteredBranches, onSelect: _selectBranch)),
            ],
          ),
        ),
      ),
    );
  }
}
