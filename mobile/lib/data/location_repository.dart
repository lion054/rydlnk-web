import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../state/app_session.dart';

/// Live driver location: drivers publish their position; riders subscribe to
/// the driver on their active trip (RLS-scoped, via Supabase Realtime).
class LocationRepository {
  SupabaseClient get _c => AppSession.client;

  Future<void> updateMyLocation(double lat, double lng, {double? heading}) async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return;
    await _c.from('driver_locations').upsert({
      'driver_id': uid,
      'lat': lat,
      'lng': lng,
      'heading': heading,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Live position of [driverId], or null until the first fix arrives.
  Stream<LatLng?> streamDriver(String driverId) {
    return _c
        .from('driver_locations')
        .stream(primaryKey: ['driver_id'])
        .eq('driver_id', driverId)
        .map((rows) => rows.isEmpty
            ? null
            : LatLng(
                (rows.first['lat'] as num).toDouble(),
                (rows.first['lng'] as num).toDouble(),
              ));
  }
}
