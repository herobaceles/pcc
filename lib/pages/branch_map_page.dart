import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  Uint8List? _markerBytes;

  List<Branch> _branches = [];
  String _searchQuery = "";
  bool _showMap = true;
  geo.Position? _userPosition;
  bool _showNearbyOnly = false;

  @override
  void initState() {
    super.initState();
    _loadBranches();
    _loadMarker();
  }

  /// Load branch data from JSON via service
  Future<void> _loadBranches() async {
    try {
      final branches = await BranchService.loadBranches();
      setState(() => _branches = branches);
    } catch (e) {
      debugPrint("Error loading branches: $e");
    }
  }

  /// Load marker image
  Future<void> _loadMarker() async {
    _markerBytes =
        (await rootBundle.load('assets/marker.png')).buffer.asUint8List();
  }

  /// Filter branches by search query & nearby toggle
  List<Branch> get _filteredBranches {
    var filtered = _branches
        .where((b) => b.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    if (_showNearbyOnly && _userPosition != null) {
      filtered = filtered.where((b) {
        final distance = geo.Geolocator.distanceBetween(
          _userPosition!.latitude,
          _userPosition!.longitude,
          b.latitude,
          b.longitude,
        );
        return distance / 1000 <= 10; // only within 10 km
      }).toList();

      filtered.sort((a, b) {
        final distA = geo.Geolocator.distanceBetween(
            _userPosition!.latitude, _userPosition!.longitude, a.latitude, a.longitude);
        final distB = geo.Geolocator.distanceBetween(
            _userPosition!.latitude, _userPosition!.longitude, b.latitude, b.longitude);
        return distA.compareTo(distB);
      });
    }

    return filtered;
  }

  /// Fly map to a specific branch
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

  /// Fly map to user's current location
  Future<void> _flyToUserLocation() async {
    try {
      if (!await geo.Geolocator.isLocationServiceEnabled()) return;

      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) return;
      }
      if (permission == geo.LocationPermission.deniedForever) return;

      final pos = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
        forceAndroidLocationManager: true,
      );

      setState(() {
        _userPosition = pos;
        _showNearbyOnly = true;
      });

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

  /// Update map markers
  Future<void> _updateMarkers() async {
    if (_pointManager == null || _markerBytes == null) return;

    await _pointManager!.deleteAll();

    for (final branch in _filteredBranches) {
      await _pointManager!.create(
        mapbox.PointAnnotationOptions(
          geometry: mapbox.Point(
            coordinates: mapbox.Position(branch.longitude, branch.latitude),
          ),
          iconImage: "marker",
          iconSize: 5,
          textField: branch.name,
          textSize: 14,
          textColor: 0xFF0000FF,
          textOffset: [0, 2.5],
        ),
      );
    }
  }

  /// Build Mapbox Map widget
  Widget _buildMap() {
    return mapbox.MapWidget(
      styleUri: mapbox.MapboxStyles.MAPBOX_STREETS,
      cameraOptions: mapbox.CameraOptions(
        center: _branches.isNotEmpty
            ? mapbox.Point(
                coordinates: mapbox.Position(
                    _branches.first.longitude, _branches.first.latitude))
            : mapbox.Point(coordinates: mapbox.Position(0, 0)),
        zoom: 14,
      ),
      onMapCreated: (map) async {
        _mapboxMap = map;
        _pointManager = await map.annotations.createPointAnnotationManager();

        if (_markerBytes == null) await _loadMarker();
        await _updateMarkers();
      },
    );
  }

  /// Handle branch selection
  Future<void> _selectBranch(Branch branch) async {
    setState(() => _showMap = true);
    await Future.delayed(const Duration(milliseconds: 300));
    await _flyToBranch(branch);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("PCC SUS"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    "Find your Nearest",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22),
                  ),
                  const Text(
                    "PCC SUPP",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                  const SizedBox(height: 16),
                  SearchField(
                    onChanged: (val) {
                      setState(() => _searchQuery = val);
                      _updateMarkers();
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ActionButtons(onNearMe: () async {
                          await _flyToUserLocation();
                          _updateMarkers();
                        }),
                      ),
                      const SizedBox(width: 8),
                      if (_showNearbyOnly)
                        ElevatedButton(
                          onPressed: () {
                            setState(() => _showNearbyOnly = false);
                            _updateMarkers();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 20),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4)),
                            elevation: 6,
                            shadowColor: Colors.blue,
                          ),
                          child: const Text(
                            "View All",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ToggleChips(
                      showMap: _showMap,
                      onToggle: (val) {
                        setState(() => _showMap = val);
                        _updateMarkers();
                      }),
                ],
              ),
            ),
            Expanded(
              child: _showMap
                  ? _buildMap()
                  : BranchList(
                      branches: _filteredBranches,
                      onSelect: _selectBranch,
                      userPosition: _userPosition,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
