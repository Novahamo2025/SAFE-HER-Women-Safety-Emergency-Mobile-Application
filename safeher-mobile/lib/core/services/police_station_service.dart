import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class PoliceStation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? address;
  final String? phone;
  final double distanceMeters;

  const PoliceStation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
    this.phone,
    required this.distanceMeters,
  });

  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.toStringAsFixed(0)} m';
    } else {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
  }
}

class PoliceStationService {
  /// Fetches real nearby police stations using OpenStreetMap Overpass API around the user's coordinates.
  /// Strictly queries live open geospatial data; never fabricates mock or invented stations.
  static Future<List<PoliceStation>> fetchNearbyStations({
    required double latitude,
    required double longitude,
    int radiusMeters = 8000,
  }) async {
    final overpassQuery = '''
[out:json][timeout:15];
(
  node["amenity"="police"](around:$radiusMeters,$latitude,$longitude);
  way["amenity"="police"](around:$radiusMeters,$latitude,$longitude);
);
out center 15;
''';

    final uri = Uri.parse('https://overpass-api.de/api/interpreter');
    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'User-Agent': 'SvaShield-Safety-App/1.0',
            },
            body: {'data': overpassQuery},
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        debugPrint('[PoliceStationService] Overpass server returned HTTP ${response.statusCode}');
        return [];
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      final List<dynamic> elements = data['elements'] as List<dynamic>? ?? [];

      final List<PoliceStation> stations = [];

      for (final item in elements) {
        if (item is! Map<String, dynamic>) continue;

        double? stationLat;
        double? stationLon;

        if (item.containsKey('lat') && item.containsKey('lon')) {
          stationLat = (item['lat'] as num?)?.toDouble();
          stationLon = (item['lon'] as num?)?.toDouble();
        } else if (item.containsKey('center') && item['center'] is Map<String, dynamic>) {
          final center = item['center'] as Map<String, dynamic>;
          stationLat = (center['lat'] as num?)?.toDouble();
          stationLon = (center['lon'] as num?)?.toDouble();
        }

        if (stationLat == null || stationLon == null) continue;

        final tags = item['tags'] as Map<String, dynamic>? ?? {};
        final name = (tags['name'] as String?)?.trim() ??
            (tags['name:en'] as String?)?.trim() ??
            'Police Station';

        // Extract available address details
        final List<String> addrParts = [];
        if (tags['addr:street'] != null) addrParts.add(tags['addr:street'].toString());
        if (tags['addr:suburb'] != null) addrParts.add(tags['addr:suburb'].toString());
        if (tags['addr:city'] != null) addrParts.add(tags['addr:city'].toString());

        final address = addrParts.isNotEmpty ? addrParts.join(', ') : null;

        // Extract available contact phone
        final phone = (tags['phone'] as String?)?.trim() ??
            (tags['contact:phone'] as String?)?.trim();

        final distance = Geolocator.distanceBetween(
          latitude,
          longitude,
          stationLat,
          stationLon,
        );

        stations.add(
          PoliceStation(
            id: item['id'].toString(),
            name: name,
            latitude: stationLat,
            longitude: stationLon,
            address: address,
            phone: phone,
            distanceMeters: distance,
          ),
        );
      }

      // Sort by closest distance first
      stations.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
      return stations;
    } catch (e) {
      debugPrint('[PoliceStationService] Error fetching nearby police stations: $e');
      rethrow;
    }
  }
}
