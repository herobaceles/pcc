import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;

import '../models/branch.dart';
import '../services/branch_service.dart';
import '../widgets/search_field.dart' as sf;
import '../widgets/action_buttons.dart';
import '../widgets/toggle_chips.dart';
import '../widgets/branch_list.dart' as bl;

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

  Future<void> _loadBranches() async {
    try {
      final branches = await BranchService.loadBranches();
      if (!mounted) return;
      setState(() => _branches = branches);
    } catch (e) {
      debugPrint("Error loading branches: $e");
    }
  }

  Future<void> _loadMarker() async {
    _markerBytes = (await rootBundle.load(
      'assets/marker.png',
    )).buffer.asUint8List();
  }

  // Branch list filtering
  List<Branch> get _filteredBranches {
    final query = _searchQuery.toLowerCase().trim();
    if (query.isEmpty) return _branches;

    return _branches.where((b) {
      final searchable = "${b.name} ${b.address}".toLowerCase();
      return searchable.contains(query);
    }).toList();
  }

  // Mapbox geocoding for live map search
  Future<mapbox.Position?> _geocodeLocation(String query) async {
    const accessToken =
        "pk.eyJ1Ijoic2FsYW0xNyIsImEiOiJjbHpxb3lub3IwZnJxMmtxODI5czJscHcyIn0.hPR3kEJ3J-kQ4OiZZL8WFA";
    final url = Uri.parse(
      "https://api.mapbox.com/geocoding/v5/mapbox.places/$query.json?access_token=$accessToken&limit=1&country=PH",
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['features'] != null && data['features'].isNotEmpty) {
          final coords = data['features'][0]['center'];
          return mapbox.Position(coords[0], coords[1]);
        }
      }
    } catch (e) {
      debugPrint("Geocoding failed: $e");
    }
    return null;
  }

  Future<void> _flyToLocation(mapbox.Position pos, {double zoom = 12}) async {
    if (_mapboxMap == null) return;
    await _mapboxMap!.flyTo(
      mapbox.CameraOptions(
        center: mapbox.Point(coordinates: pos),
        zoom: zoom,
      ),
      mapbox.MapAnimationOptions(duration: 1000),
    );
  }

  // User location
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
      );

      if (!mounted) return;
      setState(() {
        _userPosition = pos;
        _showNearbyOnly = true;
      });

      await _flyToLocation(
        mapbox.Position(pos.longitude, pos.latitude),
        zoom: 14,
      );
      await _safeUpdateMarkers();
    } catch (e) {
      debugPrint("Error getting location: $e");
    }
  }

  // Map initialization
  Widget _buildMap() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.4,
      child: mapbox.MapWidget(
        textureView: true,
        styleUri: mapbox.MapboxStyles.MAPBOX_STREETS,
        cameraOptions: mapbox.CameraOptions(
          center: _branches.isNotEmpty
              ? mapbox.Point(
                  coordinates: mapbox.Position(
                    _branches.first.longitude,
                    _branches.first.latitude,
                  ),
                )
              : mapbox.Point(coordinates: mapbox.Position(120.9842, 14.5995)),
          zoom: 12,
        ),
        onMapCreated: (map) async {
          _mapboxMap = map;
          try {
            _pointManager = await map.annotations
                .createPointAnnotationManager();
            if (_markerBytes == null) await _loadMarker();
            Future.delayed(
              const Duration(milliseconds: 500),
              _safeUpdateMarkers,
            );
          } catch (e) {
            debugPrint("Error setting up Mapbox: $e");
          }
        },
      ),
    );
  }

  Future<void> _safeUpdateMarkers() async {
    if (_pointManager == null || _markerBytes == null) return;
    if (!mounted) return;

    try {
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
    } catch (e) {
      debugPrint("Marker update failed: $e");
    }
  }

  Future<void> _selectBranch(Branch branch) async {
    FocusScope.of(context).unfocus();
    setState(() => _showMap = true);
    await Future.delayed(const Duration(milliseconds: 300));
    await _flyToLocation(
      mapbox.Position(branch.longitude, branch.latitude),
      zoom: 14,
    );
  }

  RichText highlightText(String text, String query, {TextStyle? style}) {
    final effectiveStyle = style ?? const TextStyle(color: Colors.black);
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty)
      return RichText(
        text: TextSpan(text: text, style: effectiveStyle),
      );

    final lowerText = text.toLowerCase();
    final lowerQuery = trimmedQuery.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index < 0) {
        spans.add(TextSpan(text: text.substring(start), style: effectiveStyle));
        break;
      }
      if (index > start) {
        spans.add(
          TextSpan(text: text.substring(start, index), style: effectiveStyle),
        );
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + lowerQuery.length),
          style: effectiveStyle.copyWith(
            backgroundColor: const Color.fromARGB(110, 4, 217, 228),
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      start = index + lowerQuery.length;
    }
    return RichText(
      text: TextSpan(children: spans, style: effectiveStyle),
    );
  }

  //dito lang ako nag dadagdag ng code
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/PCCSUS.png', // ✅ fixed: include assets/ prefix
          height: 45, // adjust if needed
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.white, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      "Find Your Nearest",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "PCC SUPP",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Bringing quality healthcare closer to you...",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF242323),
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ✅ Single search field
                    sf.SearchField(
                      onChanged: (val) async {
                        final query = val.trim();
                        setState(() => _searchQuery = query);

                        // Map moves independently
                        if (query.isNotEmpty && _mapboxMap != null) {
                          final pos = await _geocodeLocation(query);
                          if (pos != null) {
                            await _flyToLocation(pos, zoom: 10);
                          }
                        }

                        // Update map markers according to filtered list
                        await _safeUpdateMarkers();
                      },
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: ActionButtons(
                            onNearMe: () async {
                              await _flyToUserLocation();
                              await _safeUpdateMarkers();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_showNearbyOnly)
                          ElevatedButton(
                            onPressed: () {
                              setState(() => _showNearbyOnly = false);
                              _safeUpdateMarkers();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 20,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              elevation: 6,
                              shadowColor: Colors.blue,
                            ),
                            child: const Text(
                              "View All",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    ToggleChips(
                      showMap: _showMap,
                      onToggle: (val) {
                        FocusScope.of(context).unfocus();
                        setState(() => _showMap = val);
                        _safeUpdateMarkers();
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              Expanded(
                child: _showMap
                    ? _buildMap()
                    : bl.BranchList(
                        branches: _filteredBranches,
                        onSelect: _selectBranch,
                        userPosition: _userPosition,
                        searchQuery: _searchQuery,
                        highlightTextBuilder: highlightText,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
