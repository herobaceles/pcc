import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';

import '../models/branch.dart';
import '../widgets/search_field.dart' as sf;
import '../widgets/action_buttons.dart';
import '../widgets/toggle_chips.dart';
import '../widgets/branch_list.dart' as bl;
import 'app_drawer.dart';

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
  bool _showMap = false;
  bool _showNearbyOnly = false;
  bool _isSearching = false;
  geo.Position? _userPosition;

  @override
  void initState() {
    super.initState();
    _loadMarker();
    _listenBranches();
    _initUserLocationAndNearbyBranches();
  }

  Future<void> _initUserLocationAndNearbyBranches() async {
    setState(() => _isSearching = true);
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

      await _safeUpdateMarkers();
    } catch (e) {
      debugPrint("Error getting location: $e");
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _listenBranches() {
    FirebaseFirestore.instance.collection('branches').snapshots().listen(
      (snapshot) {
        final branches = snapshot.docs.map((doc) {
          return Branch.fromJson({'id': doc.id, ...doc.data()});
        }).toList();

        setState(() => _branches = branches);
        _safeUpdateMarkers();
      },
      onError: (e) => debugPrint("Error fetching branches: $e"),
    );
  }

  Future<void> _loadMarker() async {
    _markerBytes =
        (await DefaultAssetBundle.of(context).load('assets/marker.png'))
            .buffer
            .asUint8List();
  }

  List<Branch> get _filteredBranches {
    var filtered = _branches;

    final query = _searchQuery.trim().toLowerCase();
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

    filtered.sort((a, b) {
      String nameA = a.name.replaceFirst(RegExp(r'^PCC\s*', caseSensitive: false), '');
      String nameB = b.name.replaceFirst(RegExp(r'^PCC\s*', caseSensitive: false), '');
      return nameA.compareTo(nameB);
    });

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

  Future<void> _flyToLocation(mapbox.Position pos, {double zoom = 12}) async {
    if (_mapboxMap == null) return;
    await _mapboxMap!.flyTo(
      mapbox.CameraOptions(center: mapbox.Point(coordinates: pos), zoom: zoom),
      mapbox.MapAnimationOptions(duration: 1000),
    );
  }

  Future<void> _flyToUserLocation() async {
    if (_userPosition == null) return;
    setState(() => _showNearbyOnly = true);
    await _safeUpdateMarkers();

    if (_filteredBranches.isNotEmpty) {
      final nearest = _filteredBranches.first;
      await _flyToLocation(mapbox.Position(nearest.longitude, nearest.latitude), zoom: 14);
    }
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
    } catch (e) {
      debugPrint("Marker update failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Image.asset('assets/PCCSUS.png', height: 40),
            const SizedBox(width: 8),
            const Text(
              "PCC SUPP",
              style: TextStyle(color: Color(0xFF0255C2), fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF0255C2)),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // --- HERO SECTION ---
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: const [
                  Text(
                    "Find Your Nearest",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "PCC SUPP",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFF0255C2)),
                  ),
                  SizedBox(height: 4),
                  Text(
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
                ],
              ),
            ),

            // --- TOP CONTROLS: NEAR ME + VIEW ALL ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ActionButtons(onNearMe: _flyToUserLocation),
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
                        foregroundColor: const Color(0xFF1E7DF2),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        elevation: 6,
                        shadowColor: const Color(0xFF1E7DF2),
                      ),
                      child: const Text(
                        "View All",
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E7DF2)),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // --- SEARCH FIELD + TOGGLE ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 50,
                child: Row(
                  children: [
                    // Search field on the left
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: sf.SearchField(
                          onChanged: (val) => setState(() => _searchQuery = val.trim()),
                          onSubmitted: (val) async {
                            FocusScope.of(context).unfocus();
                            await _safeUpdateMarkers();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Toggle button on the right
                    SizedBox(
                      height: 50,
                      child: ToggleChips(
                        showMap: _showMap,
                        onToggle: (val) {
                          FocusScope.of(context).unfocus();
                          setState(() => _showMap = val);
                          _safeUpdateMarkers();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // --- MAIN BRANCH LIST / MAP ---
            Expanded(
              child: Stack(
                children: [
                  Offstage(
                    offstage: !_showMap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  Offstage(
                    offstage: _showMap,
                    child: bl.BranchList(
                      branches: _filteredBranches,
                      userPosition: _userPosition,
                      searchQuery: _searchQuery,
                      highlightTextBuilder: highlightText,
                      onSelect: (branch) async {
                        if (_mapboxMap != null) {
                          await _flyToLocation(mapbox.Position(branch.longitude, branch.latitude), zoom: 14);
                        }
                      },
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
