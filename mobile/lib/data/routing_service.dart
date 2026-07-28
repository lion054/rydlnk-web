import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../utils/format.dart';

/// Distance-based fare quote for a trip — the WHOLE-trip base fare, before it's
/// split among pooled riders.
class FareQuote {
  FareQuote({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.fareCents,
  });

  final double distanceMeters;
  final double durationSeconds;
  final int fareCents;

  String get distanceLabel => '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  String get etaLabel => '~${(durationSeconds / 60).round()} min';
  String get fareLabel => money(fareCents);
}

/// A geocoded place: a human label plus coordinates.
class Place {
  Place({required this.label, required this.lat, required this.lng});
  final String label;
  final double lat;
  final double lng;
  LatLng get latLng => LatLng(lat, lng);
}

/// Open-source routing + geocoding, no Google, no API key:
///   • Geocoding via Nominatim (OpenStreetMap)
///   • Driving distance/duration via OSRM
///
/// For production scale, point [_nominatim] / [_osrm] at your own hosted
/// instances (or a keyed OSM provider like openrouteservice) — the public
/// demo servers are rate-limited and not for heavy traffic.
class RoutingService {
  RoutingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _nominatim = 'https://nominatim.openstreetmap.org/search';
  static const _osrm = 'https://router.project-osrm.org/route/v1/driving';
  static const _headers = {'User-Agent': 'rydlnk/1.0 (support@rydlnk.app)'};

  // Fare model (whole trip): flag + per-km + per-min, with a floor.
  static const _flagCents = 150;
  static const _perKmCents = 90;
  static const _perMinCents = 12;
  static const _minFareCents = 350;

  Future<LatLng?> geocode(String address) async {
    if (address.trim().isEmpty) return null;
    final uri = Uri.parse(
        '$_nominatim?q=${Uri.encodeQueryComponent(address)}&format=json&limit=1');
    try {
      final res = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as List;
      if (data.isEmpty) return null;
      final first = data.first as Map<String, dynamic>;
      return LatLng(
        double.parse(first['lat'] as String),
        double.parse(first['lon'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  /// Autocomplete-style search for the location picker.
  Future<List<Place>> searchPlaces(String query) async {
    if (query.trim().length < 3) return const [];
    final uri = Uri.parse('$_nominatim?q=${Uri.encodeQueryComponent(query)}'
        '&format=json&limit=6&addressdetails=1');
    try {
      final res = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return const [];
      final data = jsonDecode(res.body) as List;
      return data.map((e) {
        final m = e as Map<String, dynamic>;
        return Place(
          label: m['display_name'] as String? ?? '',
          lat: double.parse(m['lat'] as String),
          lng: double.parse(m['lon'] as String),
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Coordinates → a short human label (for a dropped pin).
  Future<String?> reverseGeocode(double lat, double lng) async {
    final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json');
    try {
      final res = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final m = jsonDecode(res.body) as Map<String, dynamic>;
      return m['display_name'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Returns (distanceMeters, durationSeconds) or null.
  Future<(double, double)?> routeBetween(LatLng a, LatLng b) async {
    final uri = Uri.parse(
        '$_osrm/${a.longitude},${a.latitude};${b.longitude},${b.latitude}?overview=false');
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;
      final r = routes.first as Map<String, dynamic>;
      return ((r['distance'] as num).toDouble(), (r['duration'] as num).toDouble());
    } catch (_) {
      return null;
    }
  }

  int fareFor(double meters, double seconds) {
    final km = meters / 1000;
    final min = seconds / 60;
    final fare = (_flagCents + _perKmCents * km + _perMinCents * min).round();
    return fare < _minFareCents ? _minFareCents : fare;
  }

  /// Quote directly from known coordinates (skips geocoding — most reliable).
  Future<FareQuote?> quoteBetween(LatLng from, LatLng to) async {
    final route = await routeBetween(from, to);
    if (route == null) return null;
    final (meters, seconds) = route;
    return FareQuote(
      distanceMeters: meters,
      durationSeconds: seconds,
      fareCents: fareFor(meters, seconds),
    );
  }

  /// Full quote from two address strings. Null if either can't be located.
  Future<FareQuote?> quote(String pickup, String dropoff) async {
    final coords =
        await Future.wait([geocode(pickup), geocode(dropoff)]);
    final from = coords[0];
    final to = coords[1];
    if (from == null || to == null) return null;
    final route = await routeBetween(from, to);
    if (route == null) return null;
    final (meters, seconds) = route;
    return FareQuote(
      distanceMeters: meters,
      durationSeconds: seconds,
      fareCents: fareFor(meters, seconds),
    );
  }
}
