// ignore_for_file: prefer_final_fields

import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

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

  List<Branch> _branches = [];
  String _searchQuery = "";
  bool _showMap = false;
  bool _showNearbyOnly = false;
  bool _isSearching = false;
  geo.Position? _userPosition;
  geo.Position? _searchPosition;

  Branch? _nearestFromSearch;

  @override
  void initState() {
    super.initState();
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
    } catch (e) {
      debugPrint("Error getting location: $e");
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _flyToUserLocation() async {
    if (_userPosition == null) {
      await _initUserLocationAndNearbyBranches();
    }
    if (_userPosition == null) return;

    setState(() {
      _showNearbyOnly = true;
      _searchPosition = null;
    });

    if (_filteredBranches.isNotEmpty) {
      final nearest = _filteredBranches.first;
      await _flyToLocation(
        mapbox.Position(nearest.longitude, nearest.latitude),
        zoom: 14,
      );
    }
  }

  Future<void> _flyToLocation(mapbox.Position pos, {double zoom = 12}) async {
    if (_mapboxMap == null) return;
    await _mapboxMap!.flyTo(
      mapbox.CameraOptions(center: mapbox.Point(coordinates: pos), zoom: zoom),
      mapbox.MapAnimationOptions(duration: 1000),
    );
  }

  Future<void> _updateSearchPosition(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchPosition = null;
        _nearestFromSearch = null;
      });
      return;
    }

    try {
      final mapboxToken = dotenv.env['mapbox_access_token'] ?? "";
      final url = Uri.parse(
        "https://api.mapbox.com/geocoding/v5/mapbox.places/$query.json"
        "?access_token=$mapboxToken&limit=1&country=PH",
      );

      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data["features"] != null && data["features"].isNotEmpty) {
          final coords = data["features"][0]["geometry"]["coordinates"];
          final lng = coords[0];
          final lat = coords[1];

          setState(() {
            _searchPosition = geo.Position(
              latitude: lat,
              longitude: lng,
              timestamp: DateTime.now(),
              accuracy: 0,
              altitude: 0,
              altitudeAccuracy: 0,
              heading: 0,
              headingAccuracy: 0,
              speed: 0,
              speedAccuracy: 0,
            );
          });

          _findNearestBranch();
        }
      }
    } catch (e) {
      debugPrint("Mapbox geocoding error: $e");
    }
  }

  void _findNearestBranch() {
    if (_searchPosition == null || _branches.isEmpty) return;

    Branch? nearest;
    double nearestDist = double.infinity;

    for (final b in _branches) {
      final dist = geo.Geolocator.distanceBetween(
        _searchPosition!.latitude,
        _searchPosition!.longitude,
        b.latitude,
        b.longitude,
      );
      if (dist < nearestDist) {
        nearest = b;
        nearestDist = dist;
      }
    }

    if (nearest != null) {
      setState(() => _nearestFromSearch = nearest);
      _flyToLocation(mapbox.Position(nearest.longitude, nearest.latitude),
          zoom: 14);
    }
  }

  void _listenBranches() {
    FirebaseFirestore.instance.collection('branches').snapshots().listen(
      (snapshot) {
        final branches = snapshot.docs.map((doc) {
          return Branch.fromJson({'id': doc.id, ...doc.data()});
        }).toList();

        setState(() => _branches = branches);
      },
      onError: (e) => debugPrint("Error fetching branches: $e"),
    );
  }

  List<Branch> get _filteredBranches {
    final query = _searchQuery.trim().toLowerCase();

    if (_searchPosition != null) {
      var filtered = _branches.where((b) {
        final searchable = "${b.name} ${b.address}".toLowerCase();
        return searchable.contains(query);
      }).toList();

      if (filtered.isEmpty && _nearestFromSearch != null) {
        return [_nearestFromSearch!];
      }
      return filtered;
    }

    if (_showNearbyOnly && _userPosition != null) {
      var nearby = _branches.where((b) {
        final distance = geo.Geolocator.distanceBetween(
          _userPosition!.latitude,
          _userPosition!.longitude,
          b.latitude,
          b.longitude,
        );
        return distance <= 10000;
      }).toList();

      nearby.sort((a, b) {
        final distA = geo.Geolocator.distanceBetween(
          _userPosition!.latitude,
          _userPosition!.longitude,
          a.latitude,
          a.longitude,
        );
        final distB = geo.Geolocator.distanceBetween(
          _userPosition!.latitude,
          _userPosition!.longitude,
          b.latitude,
          b.longitude,
        );
        return distA.compareTo(distB);
      });
      return nearby;
    }

    var sorted = [..._branches];
    sorted.sort((a, b) {
      final nameA =
          a.name.replaceFirst(RegExp(r'^PCC\\s*', caseSensitive: false), '');
      final nameB =
          b.name.replaceFirst(RegExp(r'^PCC\\s*', caseSensitive: false), '');
      return nameA.compareTo(nameB);
    });
    return sorted;
  }

  RichText highlightText(String text, String query, {TextStyle? style}) {
    final effectiveStyle = style ?? const TextStyle(color: Colors.black);
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return RichText(text: TextSpan(text: text, style: effectiveStyle));
    }

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
        spans.add(TextSpan(
            text: text.substring(start, index), style: effectiveStyle));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      endDrawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            Image.asset('assets/PCCSUS.png', height: 40),
            const SizedBox(width: 8),
            const Text(
              "PCC SUPP",
              style: TextStyle(
                color: Color(0xFF0255C2),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF0255C2)),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text("Find Your Nearest",
                          style: TextStyle(
                              fontSize: 30, fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text(
                        "PCC SUPP",
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0255C2),
                        ),
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
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ActionButtons(
                    onToggle: () async {
                      if (_showNearbyOnly) {
                        setState(() {
                          _showNearbyOnly = false;
                          _searchPosition = null;
                          _nearestFromSearch = null;
                        });
                      } else {
                        await _flyToUserLocation();
                      }
                    },
                    onViewAll: () {
                      setState(() {
                        _showNearbyOnly = false;
                        _searchPosition = null;
                        _nearestFromSearch = null;
                      });
                    },
                    isNearbyMode: _showNearbyOnly,
                    isLoading: _isSearching,
                    nearbyCount: _filteredBranches.length,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: sf.SearchField(
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.trim()),
                    onSubmitted: (val) async {
                      FocusScope.of(context).unfocus();
                      setState(() {
                        _searchQuery = val.trim();
                        _showNearbyOnly = false;
                      });
                      await _updateSearchPosition(val.trim());
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: ToggleChips(
                                showMap: _showMap,
                                onToggle: (val) {
                                  FocusScope.of(context).unfocus();
                                  setState(() => _showMap = val);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: Stack(
                              children: [
                                Offstage(
                                  offstage: !_showMap,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: mapbox.MapWidget(
                                        key: const ValueKey("mapbox"),
                                        styleUri:
                                            "mapbox://styles/salam17/cmfkq2hqe006u01sd3ig62gz0",
                                        cameraOptions: mapbox.CameraOptions(
                                          center: _branches.isNotEmpty
                                              ? mapbox.Point(
                                                  coordinates: mapbox.Position(
                                                    _branches.first.longitude,
                                                    _branches.first.latitude,
                                                  ),
                                                )
                                              : mapbox.Point(
                                                  coordinates: mapbox.Position(
                                                    120.9842,
                                                    14.5995,
                                                  ),
                                                ),
                                          zoom: 12,
                                        ),
                                        onMapCreated: (map) async {
                                          _mapboxMap = map;
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                Offstage(
                                  offstage: _showMap,
                                  child: bl.BranchList(
                                    branches: _filteredBranches,
                                    allBranches: _branches,
                                    userPosition: _userPosition,
                                    searchPosition: _searchPosition,
                                    searchQuery: _searchQuery,
                                    highlightTextBuilder: highlightText,
                                    onSelect: (branch) async {
                                      if (_mapboxMap != null) {
                                        await _flyToLocation(
                                          mapbox.Position(
                                            branch.longitude,
                                            branch.latitude,
                                          ),
                                          zoom: 14,
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_isSearching)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.25),
                    child: const Center(
                      child: SizedBox(
                        height: 60,
                        width: 60,
                        child: Image(
                          image: AssetImage('assets/PCCSUS.png'),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
