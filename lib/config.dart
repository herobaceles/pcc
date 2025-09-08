// config.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

late final String mapboxAccessToken;

Future<void> loadConfig() async {
  await dotenv.load(fileName: ".env");
  mapboxAccessToken = dotenv.env['mapbox_access_token'] ?? '';

  if (mapboxAccessToken.isEmpty) {
    throw Exception("Mapbox access token is missing in .env");
  }
}
