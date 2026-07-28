import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'location_repository.dart';

/// Streams the driver's GPS to the backend while they're online. Foreground
/// only (MVP) — a production build would add a background location service.
class DriverLocationService {
  DriverLocationService._();
  static final DriverLocationService instance = DriverLocationService._();

  final _repo = LocationRepository();
  StreamSubscription<Position>? _sub;

  bool get isRunning => _sub != null;

  /// Begins publishing location. Returns false if permission was denied.
  Future<bool> start() async {
    if (_sub != null) return true;

    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return false;
    }

    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      ),
    ).listen((pos) {
      _repo.updateMyLocation(pos.latitude, pos.longitude, heading: pos.heading);
    });
    return true;
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }
}
