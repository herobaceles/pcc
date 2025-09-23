import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:huawei_location/huawei_location.dart' as hms;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/branch.dart';
import '../widgets/action_buttons.dart';
import '../widgets/toggle_chips.dart';
import '../widgets/branch_list.dart' as bl;
import 'app_drawer.dart';
import '../widgets/search_field.dart';
import '../widgets/filter_button.dart';

class BranchMapPage extends StatefulWidget {
  const BranchMapPage({super.key});

  @override
  State<BranchMapPage> createState() => _BranchMapPageState();
}

class _BranchMapPageState extends State<BranchMapPage> {
  mapbox.MapboxMap? _mapboxMap;
  mapbox.PolylineAnnotationManager? _polylineManager;

  List<Branch> _branches = [];
  String _searchQuery = "";
  bool _showMap = false;
  bool _showNearbyOnly = false;
  bool _isSearching = false;
  bool _forceViewAll = false;
  geo.Position? _userPosition;
  geo.Position? _searchPosition;

  bool _isOnline = true;

  final TextEditingController _searchController = TextEditingController();
  List<String> _selectedServiceIds = [];

  @override
  void initState() {
    super.initState();
    _listenBranches();
    _initUserLocationAndNearbyBranches();

    Connectivity().onConnectivityChanged.listen((status) {
      setState(() {
        if (status is ConnectivityResult) {
          _isOnline = status != ConnectivityResult.none;
        } else if (status is List<ConnectivityResult>) {
          _isOnline = !status.contains(ConnectivityResult.none);
        }
      });
    });
  }

  /// ✅ Listen for Firestore branch updates
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

  /// ✅ Init location
  Future<void> _initUserLocationAndNearbyBranches() async {
    setState(() => _isSearching = true);
    try {
      geo.Position? pos;

      if (Platform.isAndroid) {
        final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
        var permission = await geo.Geolocator.checkPermission();

        if (serviceEnabled &&
            permission != geo.LocationPermission.deniedForever) {
          if (permission == geo.LocationPermission.denied) {
            permission = await geo.Geolocator.requestPermission();
          }
          if (permission == geo.LocationPermission.always ||
              permission == geo.LocationPermission.whileInUse) {
            pos = await geo.Geolocator.getCurrentPosition(
              desiredAccuracy: geo.LocationAccuracy.high,
            );
          }
        }

        // fallback Huawei
        if (pos == null) {
          try {
            final locationService = hms.FusedLocationProviderClient();
            final request = hms.LocationRequest()
              ..priority = hms.LocationRequest.PRIORITY_HIGH_ACCURACY
              ..interval = 10000
              ..numUpdates = 1;

            final completer = Completer<hms.Location?>();
            final sub =
                locationService.onLocationData?.listen((hms.Location location) {
              if (!completer.isCompleted) completer.complete(location);
            });

            final reqCode =
                await locationService.requestLocationUpdates(request);
            final hmsLoc =
                await completer.future.timeout(const Duration(seconds: 10));

            if (reqCode != null) {
              await locationService.removeLocationUpdates(reqCode);
            }
            await sub?.cancel();

            if (hmsLoc != null) {
              pos = geo.Position(
                latitude: hmsLoc.latitude!,
                longitude: hmsLoc.longitude!,
                timestamp: DateTime.fromMillisecondsSinceEpoch(
                    hmsLoc.time ?? DateTime.now().millisecondsSinceEpoch),
                accuracy: 0.0,
                altitude: hmsLoc.altitude?.toDouble() ?? 0.0,
                altitudeAccuracy: 0.0,
                heading: hmsLoc.bearing?.toDouble() ?? 0.0,
                headingAccuracy: 0.0,
                speed: hmsLoc.speed?.toDouble() ?? 0.0,
                speedAccuracy: 0.0,
              );
            }
          } catch (e) {
            debugPrint("❌ Huawei Location error: $e");
          }
        }
      } else {
        final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) return;

        var permission = await geo.Geolocator.checkPermission();
        if (permission == geo.LocationPermission.denied) {
          permission = await geo.Geolocator.requestPermission();
        }
        if (permission == geo.LocationPermission.always ||
            permission == geo.LocationPermission.whileInUse) {
          pos = await geo.Geolocator.getCurrentPosition(
            desiredAccuracy: geo.LocationAccuracy.high,
          );
        }
      }

      if (!mounted || pos == null) return;

      setState(() {
        _userPosition = pos;
        _showNearbyOnly = true;
        _forceViewAll = false;
      });

      if (_filteredBranches.isNotEmpty) {
        await _fitToBounds(_filteredBranches);
      }
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
      _forceViewAll = false;
      _clearPolyline();
    });

    if (_filteredBranches.isNotEmpty) {
      await _fitToBounds(_filteredBranches);

      // ✅ also draw route to nearest branch from user location
      Branch nearest = _filteredBranches.first;
      double nearestDist = double.infinity;

      for (final b in _filteredBranches) {
        final dist = geo.Geolocator.distanceBetween(
          _userPosition!.latitude,
          _userPosition!.longitude,
          b.latitude,
          b.longitude,
        );
        if (dist < nearestDist) {
          nearest = b;
          nearestDist = dist;
        }
      }

      await _drawPolyline(
        start: mapbox.Point(
          coordinates: mapbox.Position(
            _userPosition!.longitude,
            _userPosition!.latitude,
          ),
        ),
        end: mapbox.Point(
          coordinates: mapbox.Position(nearest.longitude, nearest.latitude),
        ),
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

  Future<void> _fitToBounds(List<Branch> branches) async {
    if (_mapboxMap == null || branches.isEmpty) return;

    final lats = branches.map((b) => b.latitude).toList();
    final lngs = branches.map((b) => b.longitude).toList();

    final minLat = lats.reduce((a, b) => a < b ? a : b);
    final maxLat = lats.reduce((a, b) => a > b ? a : b);
    final minLng = lngs.reduce((a, b) => a < b ? a : b);
    final maxLng = lngs.reduce((a, b) => a > b ? a : b);

    final center = mapbox.Point(
      coordinates: mapbox.Position(
        (minLng + maxLng) / 2,
        (minLat + maxLat) / 2,
      ),
    );

    final latDelta = (maxLat - minLat).abs();
    final lngDelta = (maxLng - minLng).abs();
    final maxDelta = latDelta > lngDelta ? latDelta : lngDelta;

    double zoom;
    if (maxDelta < 0.005) {
      zoom = 15;
    } else if (maxDelta < 0.05) {
      zoom = 13;
    } else if (maxDelta < 0.2) {
      zoom = 11;
    } else {
      zoom = 9;
    }

    await _mapboxMap!.flyTo(
      mapbox.CameraOptions(center: center, zoom: zoom),
      mapbox.MapAnimationOptions(duration: 1200),
    );
  }

  /// ✅ Fetch autocomplete suggestions from Mapbox
  /// ✅ Fetch autocomplete & full address suggestions from Mapbox
Future<List<Map<String, dynamic>>> _fetchSuggestions(String query) async {
  if (query.isEmpty) return [];

  final mapboxToken = dotenv.env['mapbox_access_token'] ?? "";
  if (mapboxToken.isEmpty) return [];

  // 🔹 Encode query to handle spaces, commas, special chars
  final encodedQuery = Uri.encodeComponent(query);

  final url = Uri.parse(
    "https://api.mapbox.com/geocoding/v5/mapbox.places/$encodedQuery.json"
    "?access_token=$mapboxToken"
    "&autocomplete=true"
    "&limit=7" // increase results
    "&country=PH"
    "&types=address,place,region,locality,neighborhood,poi"
  );

  try {
    final res = await http.get(url);
    if (!mounted) return [];
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final features = (data["features"] as List<dynamic>? ?? []);
      return features.map((f) {
        return {
          "place": f["place_name"], // full address text
          "lat": f["geometry"]["coordinates"][1],
          "lng": f["geometry"]["coordinates"][0],
        };
      }).toList();
    }
  } catch (e) {
    debugPrint("❌ Error fetching suggestions: $e");
  }
  return [];
}


  /// ✅ Handle suggestion select
  Future<void> _selectSuggestion(Map<String, dynamic> suggestion) async {
    final double lat = suggestion["lat"];
    final double lng = suggestion["lng"];

    setState(() {
      _searchQuery = suggestion["place"];
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

    await _flyToLocation(mapbox.Position(lng, lat), zoom: 13);

    // ✅ also draw route to true nearest branch
    if (_filteredBranches.isNotEmpty) {
      Branch nearest = _filteredBranches.first;
      double nearestDist = double.infinity;

      for (final b in _filteredBranches) {
        final dist = geo.Geolocator.distanceBetween(
          lat, lng,
          b.latitude, b.longitude,
        );
        if (dist < nearestDist) {
          nearest = b;
          nearestDist = dist;
        }
      }

      await _drawPolyline(
        start: mapbox.Point(coordinates: mapbox.Position(lng, lat)),
        end: mapbox.Point(
          coordinates: mapbox.Position(nearest.longitude, nearest.latitude),
        ),
      );
    }
  }

mapbox.PointAnnotationManager? _pointAnnotationManager;
/// ✅ Draw polyline using Mapbox Directions API
/// ✅ Draw polyline using Mapbox Directions API
Future<void> _drawPolyline({
  required mapbox.Point start,
  required mapbox.Point end,
}) async {
  if (_mapboxMap == null) return;

  final mapboxToken = dotenv.env['mapbox_access_token'] ?? "";
  if (mapboxToken.isEmpty) {
    debugPrint("❌ Mapbox token missing!");
    return;
  }

  final url = Uri.parse(
    "https://api.mapbox.com/directions/v5/mapbox/driving/"
    "${start.coordinates.lng},${start.coordinates.lat};"
    "${end.coordinates.lng},${end.coordinates.lat}"
    "?geometries=geojson&overview=full&access_token=$mapboxToken",
  );

  try {
    final res = await http.get(url);
    if (res.statusCode != 200) {
      debugPrint("❌ Directions API error: ${res.body}");
      return;
    }

    final data = jsonDecode(res.body);
    final coords =
        (data["routes"][0]["geometry"]["coordinates"] as List).cast<List>();

    final routePoints = coords
        .map((c) => mapbox.Position(c[0].toDouble(), c[1].toDouble()))
        .toList();

    if (routePoints.isEmpty) {
      debugPrint("❌ No route points found");
      return;
    }

    // ✅ Get route distance (in km)
    final distanceMeters = (data["routes"][0]["distance"] ?? 0).toDouble();
    final distanceKm = (distanceMeters / 1000).toStringAsFixed(1);

    // ✅ Find middle point of route
    final midIndex = (routePoints.length / 2).floor();
    final midPoint = mapbox.Point(coordinates: routePoints[midIndex]);

    // ✅ Clear old annotations
    _polylineManager ??=
        await _mapboxMap!.annotations.createPolylineAnnotationManager();
    await _polylineManager!.deleteAll();

    _pointAnnotationManager ??=
        await _mapboxMap!.annotations.createPointAnnotationManager();
    await _pointAnnotationManager!.deleteAll();

    // ✅ Draw polyline
    await _polylineManager!.create(
      mapbox.PolylineAnnotationOptions(
        geometry: mapbox.LineString(coordinates: routePoints),
        lineColor: 0xFF0255C2,
        lineWidth: 4.0,
        lineOpacity: 0.9,
      ),
    );

    // ✅ Add "You are here" marker
    await _pointAnnotationManager!.create(
      mapbox.PointAnnotationOptions(
        geometry: start,
        iconImage: "marker-15",
        iconSize: 1.5,
        textField: "You are here",
        textColor: Colors.blue.value,
        textHaloColor: Colors.white.value,
        textHaloWidth: 2,
        textSize: 14,
        textOffset: [0, -2],
      ),
    );

    // ✅ Add distance label in the middle of the route
    await _pointAnnotationManager!.create(
      mapbox.PointAnnotationOptions(
        geometry: midPoint,
        iconSize: 1.2,
        textField: "$distanceKm km",
        textColor: Colors.black.value,
        textHaloColor: Colors.white.value,
        textHaloWidth: 3,
        textSize: 16, // bigger text for readability
        textOffset: [0, -1.5],
      ),
    );

    // ✅ Add branch marker (end point)
    await _pointAnnotationManager!.create(
      mapbox.PointAnnotationOptions(
        geometry: end,
        iconImage: "marker-15",
        iconSize: 1.5,
      ),
    );

    debugPrint("✅ Route polyline + markers + distance label drawn!");
  } catch (e) {
    debugPrint("❌ Error fetching route: $e");
  }
}




  Future<void> _clearPolyline() async {
    if (_polylineManager != null) {
      await _polylineManager!.deleteAll();
    }
  }


  /// ✅ Filtering only
  List<Branch> get _filteredBranches {
    var filteredBranches = [..._branches];

    if (_selectedServiceIds.isNotEmpty) {
      filteredBranches = filteredBranches
          .where((b) => b.services.any((s) => _selectedServiceIds.contains(s)))
          .toList();
    }

    if (_forceViewAll) return filteredBranches;

    if (_searchPosition != null) {
      const double searchRadius = 20000; // 20 km
      final nearby = filteredBranches.where((b) {
        final dist = geo.Geolocator.distanceBetween(
          _searchPosition!.latitude,
          _searchPosition!.longitude,
          b.latitude,
          b.longitude,
        );
        return dist <= searchRadius;
      }).toList();

      if (nearby.isEmpty && filteredBranches.isNotEmpty) {
        Branch? nearest;
        double nearestDist = double.infinity;
        for (final b in filteredBranches) {
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
        return nearest != null ? [nearest] : [];
      }

      return nearby;
    }

    if (_showNearbyOnly && _userPosition != null) {
      final nearby = filteredBranches.where((b) {
        final distance = geo.Geolocator.distanceBetween(
          _userPosition!.latitude,
          _userPosition!.longitude,
          b.latitude,
          b.longitude,
        );
        return distance <= 10000; // 10 km
      }).toList();

      if (nearby.isEmpty && filteredBranches.isNotEmpty) {
        Branch? nearest;
        double nearestDist = double.infinity;
        for (final b in filteredBranches) {
          final dist = geo.Geolocator.distanceBetween(
            _userPosition!.latitude,
            _userPosition!.longitude,
            b.latitude,
            b.longitude,
          );
          if (dist < nearestDist) {
            nearest = b;
            nearestDist = dist;
          }
        }
        return nearest != null ? [nearest] : [];
      }

      return nearby;
    }

    return filteredBranches;
  }

  bool get _shouldShowNoBranchBanner {
    if (_searchPosition == null) return false;

    const double searchRadius = 20000;
    final hasNearby = _branches.any((b) {
      final dist = geo.Geolocator.distanceBetween(
        _searchPosition!.latitude,
        _searchPosition!.longitude,
        b.latitude,
        b.longitude,
      );
      return dist <= searchRadius;
    });

    return !hasNearby;
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
            Image.asset('assets/PCCSUS.png', height: 32),
            const SizedBox(width: 6),
            const Text(
              "PCC SUPP",
              style: TextStyle(
                color: Color(0xFF0255C2),
                fontWeight: FontWeight.bold,
                fontSize: 16,
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
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Find Your Nearest",
                                style: TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.bold)),
                            SizedBox(height: 4),
                            Text(
                              "PCC SUPP",
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0255C2),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              "Bringing quality healthcare closer to you...",
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF242323),
                                fontWeight: FontWeight.w500,
                                fontStyle: FontStyle.italic,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: ActionButtons(
                          onToggleNearby: () async {
                            await _flyToUserLocation();
                          },
                          onToggleAll: () {
                            setState(() {
                              _showNearbyOnly = false;
                              _searchPosition = null;
                              _userPosition = null;
                              _forceViewAll = true;
                              _clearPolyline();
                            });
                          },
                          isNearbyMode: _showNearbyOnly,
                          isLoading: _isSearching,
                          nearbyCount: _filteredBranches.length,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ServiceFilterButton(
                        selectedServices: _selectedServiceIds,
                        onApply: (newSelected) {
                          setState(() {
                            _selectedServiceIds = newSelected;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: SearchField(
                    controller: _searchController,
                    hintText: "Enter Your Location",
                    onFetchSuggestions: _fetchSuggestions,
                    onSuggestionSelected: _selectSuggestion,
                  ),
                ),
                const SizedBox(height: 4),
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
                          allBranches: _filteredBranches,
                          userPosition: _userPosition,
                          searchPosition: _searchPosition,
                          searchQuery: _searchQuery,
                          selectedServiceIds: _selectedServiceIds,
                          highlightTextBuilder: highlightText,
                          onSelect: (branch) async {
                            if (_mapboxMap != null) {
                              final startPos = _searchPosition != null
                                  ? mapbox.Point(
                                      coordinates: mapbox.Position(
                                        _searchPosition!.longitude,
                                        _searchPosition!.latitude,
                                      ),
                                    )
                                  : _userPosition != null
                                      ? mapbox.Point(
                                          coordinates: mapbox.Position(
                                            _userPosition!.longitude,
                                            _userPosition!.latitude,
                                          ),
                                        )
                                      : null;

                              final endPos = mapbox.Point(
                                coordinates: mapbox.Position(
                                    branch.longitude, branch.latitude),
                              );

                              await _flyToLocation(
                                mapbox.Position(
                                    branch.longitude, branch.latitude),
                                zoom: 14,
                              );

                              if (startPos != null) {
                                await _drawPolyline(
                                    start: startPos, end: endPos);
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ToggleChips(
                    showMap: _showMap,
                    onToggle: (val) {
                      FocusScope.of(context).unfocus();
                      setState(() => _showMap = val);
                    },
                  ),
                ),
              ),
            ),
            if (!_isOnline)
              Positioned(
                top: 10,
                left: 20,
                right: 20,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      )
                    ],
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.wifi_off, color: Colors.white, size: 22),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "No internet connection. Some features may not work.",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_shouldShowNoBranchBanner)
              IgnorePointer(
                ignoring: true,
                child: Positioned(
                  top: 60,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0255C2),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        )
                      ],
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.sentiment_dissatisfied,
                            color: Colors.white, size: 22),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Sorry, no branches were found in this area 💙",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_isSearching)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                  child: Container(
                    color: Colors.black26,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF0255C2),
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
