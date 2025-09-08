import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:pccmobile/config.dart';

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
  String _lastMapSearchQuery = "";
  bool _showMap = true;
  bool _showNearbyOnly = false;
  bool _isSearching = false;
  geo.Position? _userPosition;

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
    _markerBytes =
        (await rootBundle.load('assets/marker.png')).buffer.asUint8List();
  }

  List<Branch> get _filteredBranches {
    final query = _searchQuery.trim().toLowerCase();
    var filtered = _branches;

    if (query.isNotEmpty) {
      filtered = filtered.where((b) {
        final searchable = "${b.name} ${b.address}".toLowerCase();
        return searchable.contains(query);
      }).toList();
    }

    if (_showNearbyOnly && _userPosition != null) {
      filtered = filtered.where((b) {
        final distance = geo.Geolocator.distanceBetween(
          _userPosition!.latitude,
          _userPosition!.longitude,
          b.latitude,
          b.longitude,
        );
        return distance <= 10000;
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

  RichText highlightText(String text, String query, {TextStyle? style}) {
    final effectiveStyle = style ?? const TextStyle(color: Colors.black);
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return RichText(text: TextSpan(text: text, style: effectiveStyle));

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
        spans.add(TextSpan(text: text.substring(start, index), style: effectiveStyle));
      }
      spans.add(TextSpan(
        text: text.substring(index, index + lowerQuery.length),
        style: effectiveStyle.copyWith(
          backgroundColor: const Color.fromARGB(110, 4, 217, 228),
          fontWeight: FontWeight.bold,
        ),
      ));
      start = index + lowerQuery.length;
    }

    return RichText(text: TextSpan(children: spans, style: effectiveStyle));
  }

  Future<void> _flyToBranch(Branch branch) async {
    if (_mapboxMap == null) return;
    await _mapboxMap!.flyTo(
      mapbox.CameraOptions(
        center: mapbox.Point(coordinates: mapbox.Position(branch.longitude, branch.latitude)),
        zoom: 14,
      ),
      mapbox.MapAnimationOptions(duration: 1000),
    );
  }

  Future<void> _flyToLocation(mapbox.Position pos, {double zoom = 12}) async {
    if (_mapboxMap == null) return;
    await _mapboxMap!.flyTo(
      mapbox.CameraOptions(center: mapbox.Point(coordinates: pos), zoom: zoom),
      mapbox.MapAnimationOptions(duration: 1000),
    );
  }

  Future<void> _flyToUserLocation() async {
    try {
      setState(() => _isSearching = true);

      if (!await geo.Geolocator.isLocationServiceEnabled()) {
        setState(() => _isSearching = false);
        return;
      }

      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) {
          setState(() => _isSearching = false);
          return;
        }
      }
      if (permission == geo.LocationPermission.deniedForever) {
        setState(() => _isSearching = false);
        return;
      }

      final pos = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() {
        _userPosition = pos;
        _showNearbyOnly = true;
      });

      await _flyToLocation(mapbox.Position(pos.longitude, pos.latitude), zoom: 14);
      await _safeUpdateMarkers();
    } catch (e) {
      debugPrint("Error getting location: $e");
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<mapbox.Position?> _geocodeLocation(String query) async {
    final url = Uri.parse(
      "https://api.mapbox.com/geocoding/v5/mapbox.places/$query.json?access_token=$mapboxAccessToken&limit=1&country=PH",
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

  Future<void> _selectBranch(Branch branch) async {
    FocusScope.of(context).unfocus();
    setState(() => _showMap = true);
    await Future.delayed(const Duration(milliseconds: 300));
    await _flyToBranch(branch);
  }

  Future<void> _safeUpdateMarkers() async {
    if (_pointManager == null || _markerBytes == null) return;
    if (!mounted) return;

    try {
      await _pointManager!.deleteAll();
      for (final branch in _filteredBranches) {
        await _pointManager!.create(
          mapbox.PointAnnotationOptions(
            geometry: mapbox.Point(coordinates: mapbox.Position(branch.longitude, branch.latitude)),
            iconImage: "marker",
            iconSize: 5,
            textField: branch.name,
            textSize: 14,
            textColor: 0xFF0000FF,
            textOffset: [0, 2.5],
          ),
        );
      }

      if (_mapboxMap != null && _filteredBranches.isNotEmpty) {
        double minLat = _filteredBranches.first.latitude;
        double maxLat = _filteredBranches.first.latitude;
        double minLng = _filteredBranches.first.longitude;
        double maxLng = _filteredBranches.first.longitude;

        for (var b in _filteredBranches) {
          if (b.latitude < minLat) minLat = b.latitude;
          if (b.latitude > maxLat) maxLat = b.latitude;
          if (b.longitude < minLng) minLng = b.longitude;
          if (b.longitude > maxLng) maxLng = b.longitude;
        }

        final centerLat = (minLat + maxLat) / 2;
        final centerLng = (minLng + maxLng) / 2;

        final latDiff = maxLat - minLat;
        final lngDiff = maxLng - minLng;
        double zoom = 12 - (latDiff + lngDiff) * 10;
        if (zoom < 3) zoom = 3;
        if (zoom > 16) zoom = 16;

        await _mapboxMap!.flyTo(
          mapbox.CameraOptions(
            center: mapbox.Point(coordinates: mapbox.Position(centerLng, centerLat)),
            zoom: zoom,
          ),
          mapbox.MapAnimationOptions(duration: 1000),
        );
      }
    } catch (e) {
      debugPrint("Marker update failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Image.asset(
              'assets/PCCSUS.png',
              height: 40,
            ),
            const SizedBox(width: 8),
            const Text("PCC SUPP", style: TextStyle(color: Color(0xFF0255C2), fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text("Find Your Nearest", textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text("PCC SUPP", textAlign: TextAlign.center, style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFF0255C2))),
                  const SizedBox(height: 4),
                  const Text(
                    "Bringing quality healthcare closer to you...",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Color(0xFF242323), fontWeight: FontWeight.w600, fontStyle: FontStyle.italic, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  sf.SearchField(
                    onChanged: (val) {
                      setState(() => _searchQuery = val.trim());
                    },
                    onSubmitted: (val) async {
                      final query = val.trim();
                      if (query.isEmpty || query == _lastMapSearchQuery || _mapboxMap == null) return;
                      setState(() => _isSearching = true);
                      final pos = await _geocodeLocation(query);
                      if (pos != null) {
                        await _flyToLocation(pos);
                        _lastMapSearchQuery = query;
                      }
                      await _safeUpdateMarkers();
                      setState(() => _isSearching = false);
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
                            foregroundColor: Color(0xFF1E7DF2),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            elevation: 6,
                            shadowColor: Color(0xFF1E7DF2),
                          ),
                          child: const Text("View All", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E7DF2))),
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
              child: Stack(
                children: [
            
                  Offstage(
                    offstage: !_showMap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: mapbox.MapWidget(
                            key: const ValueKey("mapbox"),
                            textureView: true,
                            styleUri: mapbox.MapboxStyles.MAPBOX_STREETS,
                            cameraOptions: mapbox.CameraOptions(
                              center: _branches.isNotEmpty
                                  ? mapbox.Point(coordinates: mapbox.Position(_branches.first.longitude, _branches.first.latitude))
                                  : mapbox.Point(coordinates: mapbox.Position(120.9842, 14.5995)),
                              zoom: 12,
                            ),
                            onMapCreated: (map) async {
                              _mapboxMap = map;
                              _pointManager ??= await map.annotations.createPointAnnotationManager();
                              if (_markerBytes == null) await _loadMarker();
                              Future.delayed(const Duration(milliseconds: 500), _safeUpdateMarkers);
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  Offstage(
                    offstage: _showMap,
                    child: bl.BranchList(
                      branches: _filteredBranches,
                      onSelect: _selectBranch,
                      userPosition: _userPosition,
                      searchQuery: _searchQuery,
                      highlightTextBuilder: highlightText,
                    ),
                  ),
                  if (_isSearching)
                    Container(
                      color: Colors.black26,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
