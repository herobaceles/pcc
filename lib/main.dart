import 'package:flutter/material.dart';
import 'pages/branch_map_page.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;

const String mapboxAccessToken = "pk.eyJ1Ijoic2FsYW0xNyIsImEiOiJjbHpxb3lub3IwZnJxMmtxODI5czJscHcyIn0.hPR3kEJ3J-kQ4OiZZL8WFA";

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  mapbox.MapboxOptions.setAccessToken(mapboxAccessToken);
  runApp(const MyApp());
}

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
