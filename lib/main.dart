import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:geolocator/geolocator.dart' as geo;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  mapbox.MapboxOptions.setAccessToken(mapboxAccessToken);
  runApp(const MyApp());
}

// 🔑 Mapbox Access Token
const String mapboxAccessToken =
    "pk.eyJ1Ijoic2FsYW0xNyIsImEiOiJjbHpxb3lub3IwZnJxMmtxODI5czJscHcyIn0.hPR3kEJ3J-kQ4OiZZL8WFA";

// 🌍 Branch Model
class Branch {
  final String id, name, address, contact, email;
  final double latitude, longitude;

  Branch({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.contact,
    required this.email,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      contact: json['contact'],
      email: json['email'],
    );
  }
}

// 📱 App Entry
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BranchMapPage(),
    );
  }
}

// 🗺️ Main Map & Branch Page
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

  // 🔹 Load branches from JSON
  Future<void> _loadBranches() async {
    try {
      final data = await rootBundle.loadString('assets/branches.json');
      final jsonList = json.decode(data) as List<dynamic>;
      setState(() {
        _branches = jsonList.map((e) => Branch.fromJson(e)).toList();
      });
    } catch (e) {
      debugPrint("Error loading branches: $e");
    }
  }

  // 🔹 Add markers for all branches, highlight selected
  Future<void> _addMarkers() async {
    if (_pointManager == null) return;
    await _pointManager!.deleteAll();

    for (var branch in _branches) {
      await _pointManager!.create(
        mapbox.PointAnnotationOptions(
          geometry: mapbox.Point(
            coordinates: mapbox.Position(branch.longitude, branch.latitude),
          ),
          iconImage: branch == _selectedBranch
              ? "marker-15" // 🟢 You could use a different icon for selected
              : "marker-15",
          iconSize: branch == _selectedBranch ? 2.0 : 1.5, // Highlight selected
        ),
      );
    }
  }

  // 🔹 Fly to a specific branch
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

  // 🔹 Fly to user's location
  Future<void> _flyToUserLocation() async {
    try {
      if (!await geo.Geolocator.isLocationServiceEnabled()) {
        debugPrint("Location services are disabled.");
        return;
      }

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

  // 🔹 Search filtered branches
  List<Branch> get _filteredBranches {
    return _branches
        .where((b) => b.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  // 🔹 Handle Branch Selection
  void _selectBranch(Branch branch) {
    setState(() {
      _selectedBranch = branch;
      _showMap = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 300));
      await _flyToBranch(branch);
      await _addMarkers(); // 🔥 Re-add markers with selected highlighted
    });
  }

  // 🔹 Build Search Field
  Widget _buildSearchField() {
    return TextField(
      decoration: InputDecoration(
        hintText: "Search...",
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onChanged: (val) => setState(() => _searchQuery = val),
    );
  }

  // 🔹 Build Action Buttons
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.near_me),
            label: const Text("Near Me"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _flyToUserLocation,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.filter_list),
            label: const Text("Filter"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[200],
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {},
          ),
        ),
      ],
    );
  }

  // 🔹 Build Toggle Chips
  Widget _buildToggleChips() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ChoiceChip(
          label: const Text("List"),
          selected: !_showMap,
          onSelected: (_) => setState(() => _showMap = false),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text("Map"),
          selected: _showMap,
          onSelected: (_) => setState(() => _showMap = true),
        ),
      ],
    );
  }

  // 🔹 Build Branch List
  Widget _buildBranchList() {
    return ListView.builder(
      itemCount: _filteredBranches.length,
      itemBuilder: (context, i) {
        final branch = _filteredBranches[i];
        return ListTile(
          leading: const Icon(Icons.location_on, color: Colors.red),
          title: Text(branch.name),
          subtitle: Text(branch.address),
          onTap: () => _selectBranch(branch),
        );
      },
    );
  }

  // 🔹 Build Map
  Widget _buildMap() {
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

        if (_selectedBranch != null) {
          await _flyToBranch(_selectedBranch!);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_branches.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("PCC SUS", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 8),
              const Text("Find your Nearest", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
              const Text("PCC SUPP", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 8),
              const Text(
                "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et.",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              _buildSearchField(),
              const SizedBox(height: 16),
              _buildActionButtons(),
              const SizedBox(height: 16),
              _buildToggleChips(),
              const SizedBox(height: 16),
              Expanded(
                child: _showMap ? _buildMap() : _buildBranchList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
