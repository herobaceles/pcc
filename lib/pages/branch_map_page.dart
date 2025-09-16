// // ignore_for_file: prefer_final_fields

// import 'dart:async';
// import 'dart:convert';
// import 'dart:ui';
// import 'package:flutter/material.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
// import 'package:geolocator/geolocator.dart' as geo;
// import 'package:http/http.dart' as http;
// import 'package:cloud_firestore/cloud_firestore.dart';

// import '../models/branch.dart';
// import '../widgets/action_buttons.dart';
// import '../widgets/toggle_chips.dart';
// import '../widgets/branch_list.dart' as bl;
// import 'app_drawer.dart';

// class BranchMapPage extends StatefulWidget {
//   const BranchMapPage({super.key});

//   @override
//   State<BranchMapPage> createState() => _BranchMapPageState();
// }

// class _BranchMapPageState extends State<BranchMapPage> {
//   mapbox.MapboxMap? _mapboxMap;

//   List<Branch> _branches = [];
//   String _searchQuery = "";
//   bool _showMap = false;
//   bool _showNearbyOnly = false;
//   bool _isSearching = false;
//   geo.Position? _userPosition;
//   geo.Position? _searchPosition;

//   Branch? _nearestFromSearch;

//   // Suggestions state
//   List<Map<String, dynamic>> _suggestions = [];
//   Timer? _debounce;

//   // Route coords
//   List<List<double>> _routeCoordinates = [];

//   @override
//   void initState() {
//     super.initState();
//     _listenBranches();
//     _initUserLocationAndNearbyBranches();
//   }

//   Future<void> _initUserLocationAndNearbyBranches() async {
//     setState(() => _isSearching = true);
//     try {
//       if (!await geo.Geolocator.isLocationServiceEnabled()) return;

//       var permission = await geo.Geolocator.checkPermission();
//       if (permission == geo.LocationPermission.denied) {
//         permission = await geo.Geolocator.requestPermission();
//         if (permission == geo.LocationPermission.denied) return;
//       }
//       if (permission == geo.LocationPermission.deniedForever) return;

//       final pos = await geo.Geolocator.getCurrentPosition(
//         desiredAccuracy: geo.LocationAccuracy.high,
//       );

//       if (!mounted) return;
//       setState(() {
//         _userPosition = pos;
//         _showNearbyOnly = true;
//       });
//     } catch (e) {
//       debugPrint("Error getting location: $e");
//     } finally {
//       if (mounted) setState(() => _isSearching = false);
//     }
//   }

//   Future<void> _flyToUserLocation() async {
//     if (_userPosition == null) {
//       await _initUserLocationAndNearbyBranches();
//     }
//     if (_userPosition == null) return;

//     setState(() {
//       _showNearbyOnly = true;
//       _searchPosition = null;
//     });

//     if (_filteredBranches.isNotEmpty) {
//       final nearest = _filteredBranches.first;
//       await _flyToLocation(
//         mapbox.Position(nearest.longitude, nearest.latitude),
//         zoom: 14,
//       );
//     }
//   }

//   Future<void> _flyToLocation(mapbox.Position pos, {double zoom = 12}) async {
//     if (_mapboxMap == null) return;
//     await _mapboxMap!.flyTo(
//       mapbox.CameraOptions(center: mapbox.Point(coordinates: pos), zoom: zoom),
//       mapbox.MapAnimationOptions(duration: 1000),
//     );
//   }

//   // Fetch live suggestions from Mapbox
//   Future<void> _fetchSuggestions(String query) async {
//     if (query.isEmpty) {
//       setState(() => _suggestions = []);
//       return;
//     }

//     final mapboxToken = dotenv.env['mapbox_access_token'] ?? "";
//     final url = Uri.parse(
//       "https://api.mapbox.com/geocoding/v5/mapbox.places/$query.json"
//       "?access_token=$mapboxToken&autocomplete=true&limit=5&country=PH",
//     );

//     try {
//       final res = await http.get(url);
//       if (res.statusCode == 200) {
//         final data = jsonDecode(res.body);
//         final features = data["features"] as List<dynamic>;
//         setState(() {
//           _suggestions = features.map((f) {
//             return {
//               "place": f["place_name"],
//               "lat": f["geometry"]["coordinates"][1],
//               "lng": f["geometry"]["coordinates"][0],
//             };
//           }).toList();
//         });
//       }
//     } catch (e) {
//       debugPrint("Error fetching suggestions: $e");
//     }
//   }

//   // Select suggestion → fly map + fetch route
//   Future<void> _selectSuggestion(Map<String, dynamic> suggestion) async {
//     final lat = suggestion["lat"];
//     final lng = suggestion["lng"];

//     setState(() {
//       _searchQuery = suggestion["place"];
//       _suggestions = [];
//       _searchPosition = geo.Position(
//         latitude: lat,
//         longitude: lng,
//         timestamp: DateTime.now(),
//         accuracy: 0,
//         altitude: 0,
//         altitudeAccuracy: 0,
//         heading: 0,
//         headingAccuracy: 0,
//         speed: 0,
//         speedAccuracy: 0,
//       );
//     });

//     await _flyToLocation(mapbox.Position(lng, lat), zoom: 13);
//     _findNearestBranch();

//     if (_nearestFromSearch != null) {
//       await _fetchRoute(
//         [lng, lat],
//         [_nearestFromSearch!.longitude, _nearestFromSearch!.latitude],
//       );
//     }
//   }

//   void _findNearestBranch() {
//     if (_searchPosition == null || _branches.isEmpty) return;

//     Branch? nearest;
//     double nearestDist = double.infinity;

//     for (final b in _branches) {
//       final dist = geo.Geolocator.distanceBetween(
//         _searchPosition!.latitude,
//         _searchPosition!.longitude,
//         b.latitude,
//         b.longitude,
//       );
//       if (dist < nearestDist) {
//         nearest = b;
//         nearestDist = dist;
//       }
//     }

//     if (nearest != null) {
//       setState(() => _nearestFromSearch = nearest);
//     }
//   }

//   // Fetch route from Mapbox Directions API
//   Future<void> _fetchRoute(List<double> origin, List<double> destination) async {
//     final mapboxToken = dotenv.env['mapbox_access_token'] ?? "";
//     final url =
//         "https://api.mapbox.com/directions/v5/mapbox/driving/${origin[0]},${origin[1]};${destination[0]},${destination[1]}"
//         "?geometries=geojson&access_token=$mapboxToken";

//     try {
//       final res = await http.get(Uri.parse(url));
//       if (res.statusCode == 200) {
//         final data = jsonDecode(res.body);
//         final route = data["routes"][0]["geometry"]["coordinates"] as List;
//         setState(() {
//           _routeCoordinates = route.map<List<double>>((c) => [c[0], c[1]]).toList();
//         });
//         await _drawRouteOnMap();
//       }
//     } catch (e) {
//       debugPrint("Error fetching route: $e");
//     }
//   }

//   // Draw route line on map
//   Future<void> _drawRouteOnMap() async {
//     if (_mapboxMap == null || _routeCoordinates.isEmpty) return;

//     final routeData = {
//       "type": "FeatureCollection",
//       "features": [
//         {
//           "type": "Feature",
//           "geometry": {
//             "type": "LineString",
//             "coordinates": _routeCoordinates,
//           },
//         }
//       ]
//     };

//     final style = _mapboxMap!.style;

//     if (await style.styleSourceExists("route-source")) {
//       await style.removeStyleLayer("route-layer");
//       await style.removeStyleSource("route-source");
//     }

//     final source = mapbox.GeoJsonSource(
//       id: "route-source",
//       data: jsonEncode(routeData), // ✅ FIX
//     );
//     await style.addSource(source);

//     final layer = mapbox.LineLayer(
//       id: "route-layer",
//       sourceId: "route-source",
//       lineColor: Colors.blue.value, // ✅ FIX
//       lineWidth: 5.0,
//     );
//     await style.addLayer(layer);
//   }

//   void _listenBranches() {
//     FirebaseFirestore.instance.collection('branches').snapshots().listen(
//       (snapshot) {
//         final branches = snapshot.docs.map((doc) {
//           return Branch.fromJson({'id': doc.id, ...doc.data()});
//         }).toList();

//         setState(() => _branches = branches);
//       },
//       onError: (e) => debugPrint("Error fetching branches: $e"),
//     );
//   }

//   List<Branch> get _filteredBranches {
//     final query = _searchQuery.trim().toLowerCase();

//     if (_searchPosition != null) {
//       var filtered = _branches.where((b) {
//         final searchable = "${b.name} ${b.address}".toLowerCase();
//         return searchable.contains(query);
//       }).toList();

//       if (filtered.isEmpty && _nearestFromSearch != null) {
//         return [_nearestFromSearch!];
//       }
//       return filtered;
//     }

//     if (_showNearbyOnly && _userPosition != null) {
//       var nearby = _branches.where((b) {
//         final distance = geo.Geolocator.distanceBetween(
//           _userPosition!.latitude,
//           _userPosition!.longitude,
//           b.latitude,
//           b.longitude,
//         );
//         return distance <= 10000;
//       }).toList();

//       nearby.sort((a, b) {
//         final distA = geo.Geolocator.distanceBetween(
//           _userPosition!.latitude,
//           _userPosition!.longitude,
//           a.latitude,
//           a.longitude,
//         );
//         final distB = geo.Geolocator.distanceBetween(
//           _userPosition!.latitude,
//           _userPosition!.longitude,
//           b.latitude,
//           b.longitude,
//         );
//         return distA.compareTo(distB);
//       });
//       return nearby;
//     }

//     var sorted = [..._branches];
//     sorted.sort((a, b) {
//       final nameA =
//           a.name.replaceFirst(RegExp(r'^PCC\\s*', caseSensitive: false), '');
//       final nameB =
//           b.name.replaceFirst(RegExp(r'^PCC\\s*', caseSensitive: false), '');
//       return nameA.compareTo(nameB);
//     });
//     return sorted;
//   }

//   RichText highlightText(String text, String query, {TextStyle? style}) {
//     final effectiveStyle = style ?? const TextStyle(color: Colors.black);
//     final trimmedQuery = query.trim();
//     if (trimmedQuery.isEmpty) {
//       return RichText(text: TextSpan(text: text, style: effectiveStyle));
//     }

//     final lowerText = text.toLowerCase();
//     final lowerQuery = trimmedQuery.toLowerCase();
//     final spans = <TextSpan>[];
//     int start = 0;

//     while (true) {
//       final index = lowerText.indexOf(lowerQuery, start);
//       if (index < 0) {
//         spans.add(TextSpan(text: text.substring(start), style: effectiveStyle));
//         break;
//       }
//       if (index > start) {
//         spans.add(TextSpan(
//             text: text.substring(start, index), style: effectiveStyle));
//       }
//       spans.add(TextSpan(
//         text: text.substring(index, index + lowerQuery.length),
//         style: effectiveStyle.copyWith(
//           backgroundColor: const Color.fromARGB(110, 4, 217, 228),
//           fontWeight: FontWeight.bold,
//         ),
//       ));
//       start = index + lowerQuery.length;
//     }
//     return RichText(text: TextSpan(children: spans, style: effectiveStyle));
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       endDrawer: const AppDrawer(),
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         surfaceTintColor: Colors.transparent,
//         title: Row(
//           children: [
//             Image.asset('assets/PCCSUS.png', height: 40),
//             const SizedBox(width: 8),
//             const Text(
//               "PCC SUPP",
//               style: TextStyle(
//                 color: Color(0xFF0255C2),
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ],
//         ),
//         actions: [
//           Builder(
//             builder: (context) => IconButton(
//               icon: const Icon(Icons.menu, color: Color(0xFF0255C2)),
//               onPressed: () => Scaffold.of(context).openEndDrawer(),
//             ),
//           ),
//         ],
//       ),
//       body: SafeArea(
//         child: Stack(
//           children: [
//             Column(
//               children: [
//                 const Padding(
//                   padding: EdgeInsets.all(16),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.center,
//                     children: [
//                       Text("Find Your Nearest",
//                           style: TextStyle(
//                               fontSize: 30, fontWeight: FontWeight.bold)),
//                       SizedBox(height: 8),
//                       Text(
//                         "PCC SUPP",
//                         style: TextStyle(
//                           fontSize: 36,
//                           fontWeight: FontWeight.w900,
//                           color: Color(0xFF0255C2),
//                         ),
//                       ),
//                       SizedBox(height: 4),
//                       Text(
//                         "Bringing quality healthcare closer to you...",
//                         textAlign: TextAlign.center,
//                         style: TextStyle(
//                           fontSize: 16,
//                           color: Color(0xFF242323),
//                           fontWeight: FontWeight.w600,
//                           fontStyle: FontStyle.italic,
//                           height: 1.4,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 const SizedBox(height: 12),
//                 Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 16),
//                   child: ActionButtons(
//                     onToggle: () async {
//                       if (_showNearbyOnly) {
//                         setState(() {
//                           _showNearbyOnly = false;
//                           _searchPosition = null;
//                           _nearestFromSearch = null;
//                         });
//                       } else {
//                         await _flyToUserLocation();
//                       }
//                     },
//                     onViewAll: () {
//                       setState(() {
//                         _showNearbyOnly = false;
//                         _searchPosition = null;
//                         _nearestFromSearch = null;
//                       });
//                     },
//                     isNearbyMode: _showNearbyOnly,
//                     isLoading: _isSearching,
//                     nearbyCount: _filteredBranches.length,
//                   ),
//                 ),
//                 const SizedBox(height: 12),

//                 // Search Field with Suggestions
//                 Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 16),
//                   child: Column(
//                     children: [
//                       TextField(
//                         decoration: InputDecoration(
//                           hintText: "Search branch or place...",
//                           prefixIcon: const Icon(Icons.search,
//                               color: Color(0xFF0255C2)),
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(12),
//                             borderSide:
//                                 BorderSide(color: Colors.grey.shade300),
//                           ),
//                           filled: true,
//                           fillColor: Colors.white,
//                         ),
//                         onChanged: (val) {
//                           if (_debounce?.isActive ?? false) _debounce!.cancel();
//                           _debounce = Timer(const Duration(milliseconds: 400),
//                               () => _fetchSuggestions(val));
//                           setState(() => _searchQuery = val);
//                         },
//                       ),
//                       if (_suggestions.isNotEmpty)
//                         Container(
//                           margin: const EdgeInsets.only(top: 4),
//                           decoration: BoxDecoration(
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(8),
//                             boxShadow: const [
//                               BoxShadow(
//                                   color: Colors.black26,
//                                   blurRadius: 4,
//                                   offset: Offset(0, 2))
//                             ],
//                           ),
//                           child: ListView.builder(
//                             shrinkWrap: true,
//                             itemCount: _suggestions.length,
//                             itemBuilder: (context, i) {
//                               final suggestion = _suggestions[i];
//                               return ListTile(
//                                 title: Text(suggestion["place"]),
//                                 onTap: () => _selectSuggestion(suggestion),
//                               );
//                             },
//                           ),
//                         ),
//                     ],
//                   ),
//                 ),

//                 const SizedBox(height: 12),
//                 Expanded(
//                   child: Stack(
//                     children: [
//                       Column(
//                         children: [
//                           Padding(
//                             padding: const EdgeInsets.symmetric(horizontal: 16),
//                             child: Align(
//                               alignment: Alignment.centerLeft,
//                               child: ToggleChips(
//                                 showMap: _showMap,
//                                 onToggle: (val) {
//                                   FocusScope.of(context).unfocus();
//                                   setState(() => _showMap = val);
//                                 },
//                               ),
//                             ),
//                           ),
//                           const SizedBox(height: 12),
//                           Expanded(
//                             child: Stack(
//                               children: [
//                                 Offstage(
//                                   offstage: !_showMap,
//                                   child: Padding(
//                                     padding: const EdgeInsets.symmetric(
//                                         horizontal: 16, vertical: 8),
//                                     child: ClipRRect(
//                                       borderRadius: BorderRadius.circular(16),
//                                       child: mapbox.MapWidget(
//                                         key: const ValueKey("mapbox"),
//                                         styleUri:
//                                             "mapbox://styles/salam17/cmfkq2hqe006u01sd3ig62gz0",
//                                         cameraOptions: mapbox.CameraOptions(
//                                           center: _branches.isNotEmpty
//                                               ? mapbox.Point(
//                                                   coordinates: mapbox.Position(
//                                                     _branches.first.longitude,
//                                                     _branches.first.latitude,
//                                                   ),
//                                                 )
//                                               : mapbox.Point(
//                                                   coordinates: mapbox.Position(
//                                                     120.9842,
//                                                     14.5995,
//                                                   ),
//                                                 ),
//                                           zoom: 12,
//                                         ),
//                                         onMapCreated: (map) async {
//                                           _mapboxMap = map;
//                                         },
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                                 Offstage(
//                                   offstage: _showMap,
//                                   child: bl.BranchList(
//                                     branches: _filteredBranches,
//                                     allBranches: _branches,
//                                     userPosition: _userPosition,
//                                     searchPosition: _searchPosition,
//                                     searchQuery: _searchQuery,
//                                     highlightTextBuilder: highlightText,
//                                     onSelect: (branch) async {
//                                       if (_mapboxMap != null) {
//                                         await _flyToLocation(
//                                           mapbox.Position(
//                                             branch.longitude,
//                                             branch.latitude,
//                                           ),
//                                           zoom: 14,
//                                         );
//                                       }
//                                     },
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//             if (_isSearching)
//               Positioned.fill(
//                 child: BackdropFilter(
//                   filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
//                   child: Container(
//                     color: Colors.black.withValues(alpha: 0.25),
//                     child: const Center(
//                       child: SizedBox(
//                         height: 60,
//                         width: 60,
//                         child: Image(
//                           image: AssetImage('assets/PCCSUS.png'),
//                           fit: BoxFit.contain,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }


// ignore_for_file: prefer_final_fields



// ignore_for_file: prefer_final_fields

import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/branch.dart';
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

  List<Map<String, dynamic>> _suggestions = [];
  Timer? _debounce;

  List<List<double>> _routeCoordinates = [];

  bool _isFetchingRoute = false;

  static const String _routeSourceId = "route-source";
  static const String _routeLayerId = "route-layer";

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

  Future<void> _fetchSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    final mapboxToken = dotenv.env['mapbox_access_token'] ?? "";
    if (mapboxToken.isEmpty) return;

    final url = Uri.parse(
      "https://api.mapbox.com/geocoding/v5/mapbox.places/$query.json"
      "?access_token=$mapboxToken&autocomplete=true&limit=5&country=PH",
    );

    try {
      final res = await http.get(url);
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final features = (data["features"] as List<dynamic>? ?? []);
        setState(() {
          _suggestions = features.map((f) {
            return {
              "place": f["place_name"],
              "lat": f["geometry"]["coordinates"][1],
              "lng": f["geometry"]["coordinates"][0],
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint("Error fetching suggestions: $e");
    }
  }

  Future<void> _selectSuggestion(Map<String, dynamic> suggestion) async {
    final double lat = suggestion["lat"];
    final double lng = suggestion["lng"];

    setState(() {
      _searchQuery = suggestion["place"];
      _suggestions = [];
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
    _findNearestBranch();

    if (_nearestFromSearch != null) {
      await _fetchRoute(
        [lng, lat],
        [_nearestFromSearch!.longitude, _nearestFromSearch!.latitude],
      );
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
    }
  }

  Future<void> _fetchRoute(List<double> origin, List<double> destination) async {
    if (_isFetchingRoute) return;
    _isFetchingRoute = true;

    final mapboxToken = dotenv.env['mapbox_access_token'] ?? "";
    if (mapboxToken.isEmpty) {
      _isFetchingRoute = false;
      return;
    }

    final url =
        "https://api.mapbox.com/directions/v5/mapbox/driving-traffic/${origin[0]},${origin[1]};${destination[0]},${destination[1]}"
        "?geometries=geojson&overview=full&steps=true&access_token=$mapboxToken";

    try {
      final res = await http.get(Uri.parse(url));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final routes = (data["routes"] as List<dynamic>? ?? []);
        if (routes.isEmpty) {
          debugPrint("No routes returned by Directions API");
          return;
        }
        final route = routes.first;
        final coords = (route["geometry"]["coordinates"] as List)
            .map<List<double>>((c) => [c[0] * 1.0, c[1] * 1.0])
            .toList();

        // 👇 Force append destination so line reaches branch
        coords.add([destination[0], destination[1]]);

        setState(() {
          _routeCoordinates = coords;
        });
        await _drawRouteOnMap();
        await _fitCameraToRoute();
      } else {
        debugPrint("Directions error: ${res.statusCode} ${res.body}");
      }
    } catch (e) {
      debugPrint("Error fetching route: $e");
    } finally {
      _isFetchingRoute = false;
    }
  }

  Future<void> _drawRouteOnMap() async {
    if (_mapboxMap == null || _routeCoordinates.isEmpty) return;

    final routeData = {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "geometry": {
            "type": "LineString",
            "coordinates": _routeCoordinates,
          },
        }
      ]
    };

    final style = _mapboxMap!.style;

    try {
      final exists = await style.styleSourceExists(_routeSourceId);
      if (!exists) {
        final source = mapbox.GeoJsonSource(
          id: _routeSourceId,
          data: jsonEncode(routeData),
        );
        await style.addSource(source);

        final layer = mapbox.LineLayer(
          id: _routeLayerId,
          sourceId: _routeSourceId,
          lineColor: Colors.blue.value,
          lineWidth: 5.0,
          lineCap: mapbox.LineCap.ROUND,
          lineJoin: mapbox.LineJoin.ROUND,
        );
        await style.addLayer(layer);
      } else {
        await style.removeStyleLayer(_routeLayerId);
        await style.removeStyleSource(_routeSourceId);

        final source = mapbox.GeoJsonSource(
          id: _routeSourceId,
          data: jsonEncode(routeData),
        );
        await style.addSource(source);

        final layer = mapbox.LineLayer(
          id: _routeLayerId,
          sourceId: _routeSourceId,
          lineColor: Colors.blue.value,
          lineWidth: 5.0,
          lineCap: mapbox.LineCap.ROUND,
          lineJoin: mapbox.LineJoin.ROUND,
        );
        await style.addLayer(layer);
      }
    } catch (e) {
      debugPrint("Error drawing route: $e");
    }
  }

  Future<void> _fitCameraToRoute() async {
    if (_mapboxMap == null || _routeCoordinates.isEmpty) return;

    double minLng = _routeCoordinates.first[0];
    double maxLng = _routeCoordinates.first[0];
    double minLat = _routeCoordinates.first[1];
    double maxLat = _routeCoordinates.first[1];

    for (final c in _routeCoordinates) {
      final lng = c[0];
      final lat = c[1];
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
    }

    final bounds = mapbox.CoordinateBounds(
      southwest: mapbox.Point(coordinates: mapbox.Position(minLng, minLat)),
      northeast: mapbox.Point(coordinates: mapbox.Position(maxLng, maxLat)),
      infiniteBounds: false,
    );

    final padding = mapbox.MbxEdgeInsets(
      top: 60,
      left: 40,
      bottom: 60,
      right: 40,
    );

    try {
      final cam = await _mapboxMap!.cameraForCoordinateBounds(
        bounds,
        padding,
        0.0,
        0.0,
        null,
        null,
      );
      await _mapboxMap!.flyTo(cam, mapbox.MapAnimationOptions(duration: 900));
    } catch (e) {
      final midLng = (minLng + maxLng) / 2.0;
      final midLat = (minLat + maxLat) / 2.0;
      await _flyToLocation(mapbox.Position(midLng, midLat), zoom: 12);
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
                // header texts...
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

                // buttons row
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

                // search field + suggestions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      TextField(
                        decoration: InputDecoration(
                          hintText: "Search branch or place...",
                          prefixIcon: const Icon(Icons.search,
                              color: Color(0xFF0255C2)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: Colors.grey.shade300),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (val) {
                          if (_debounce?.isActive ?? false) _debounce!.cancel();
                          _debounce = Timer(const Duration(milliseconds: 400),
                              () => _fetchSuggestions(val));
                          setState(() => _searchQuery = val);
                        },
                      ),
                      if (_suggestions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [
                              BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2))
                            ],
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _suggestions.length,
                            itemBuilder: (context, i) {
                              final suggestion = _suggestions[i];
                              return ListTile(
                                title: Text(suggestion["place"]),
                                onTap: () => _selectSuggestion(suggestion),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 👇 Expanded prevents overflow
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
