import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/driver_document.dart';
import '../models/driver_profile.dart';
import '../models/trip.dart';
import '../models/trip_stop.dart';
import '../state/app_session.dart';
import '../utils/format.dart';

/// Data access for the driver experience. Drivers work at the **trip** level:
/// they claim a whole shared trip (all its pooled passengers) and advance its
/// status. Earnings are the trip base fares.
class DriverRepository {
  SupabaseClient get _c => AppSession.client;
  String? get _uid => _c.auth.currentUser?.id;

  Future<DriverProfile?> myDriver() async {
    final uid = _uid;
    if (uid == null) return null;
    final row = await _c.from('drivers').select().eq('id', uid).maybeSingle();
    return row == null ? null : DriverProfile.fromJson(row);
  }

  Future<void> becomeDriver({String? vehicle, String? plate}) =>
      AppSession.becomeDriver(vehicle: vehicle, plate: plate);

  Future<void> setAvailability(bool available) async {
    final uid = _uid;
    if (uid == null) return;
    await _c.from('drivers').update({'is_available': available}).eq('id', uid);
  }

  Future<void> updateVehicle({String? vehicle, String? plate}) async {
    final uid = _uid;
    if (uid == null) return;
    await _c
        .from('drivers')
        .update({'vehicle': vehicle, 'license_plate': plate})
        .eq('id', uid);
  }

  /// Unclaimed, upcoming trips available to accept (with live seat counts).
  Future<List<Trip>> availableTrips() async {
    final rows = await _c.rpc('available_trips');
    return _trips(rows);
  }

  Future<Trip> claimTrip(String tripId) async {
    final row = await _c.rpc('claim_trip', params: {'p_trip_id': tripId});
    final map = row is List ? row.first : row;
    return Trip.fromJson(map as Map<String, dynamic>);
  }

  /// This driver's assigned trips. [todayOnly] limits to today's manifest.
  Future<List<Trip>> myTrips({bool todayOnly = false}) async {
    final uid = _uid;
    if (uid == null) return const [];
    var q = _c.from('trips').select().eq('driver_id', uid);
    if (todayOnly) q = q.eq('ride_date', dateToDb(DateTime.now()));
    final rows = await q
        .order('ride_date', ascending: true)
        .order('pickup_time', ascending: true, nullsFirst: true);
    return _trips(rows);
  }

  Future<void> setTripStatus(String tripId, String status) async {
    await _c.rpc('set_trip_status',
        params: {'p_trip_id': tripId, 'p_status': status});
  }

  // ── Verification / vetting ──

  Future<List<DriverDocument>> myDocuments() async {
    final uid = _uid;
    if (uid == null) return const [];
    final rows =
        await _c.from('driver_documents').select().eq('driver_id', uid);
    return (rows as List)
        .map((e) => DriverDocument.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Uploads a document image to the private bucket and records it (pending
  /// review). Replaces any existing document of the same type.
  Future<void> uploadDocument({
    required String docType,
    required Uint8List bytes,
    DateTime? expiry,
    String contentType = 'image/jpeg',
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final path = '$uid/$docType.jpg';
    await _c.storage.from('driver-docs').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        );
    await _c.from('driver_documents').upsert({
      'driver_id': uid,
      'doc_type': docType,
      'storage_path': path,
      'status': 'pending',
      'expiry_date': expiry != null ? dateToDb(expiry) : null,
    }, onConflict: 'driver_id,doc_type');
  }

  Future<void> requestVerification() => _c.rpc('request_verification');

  /// The ordered pickup stops (one per pooled rider) for a claimed trip.
  Future<List<TripStop>> tripStops(String tripId) async {
    final rows = await _c.rpc('trip_stops', params: {'p_trip_id': tripId});
    return (rows as List)
        .map((e) => TripStop.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Trip>> completedTrips() async {
    final uid = _uid;
    if (uid == null) return const [];
    final rows = await _c
        .from('trips')
        .select()
        .eq('driver_id', uid)
        .eq('status', 'completed')
        .order('ride_date', ascending: false)
        .limit(100);
    return _trips(rows);
  }

  List<Trip> _trips(dynamic rows) => (rows as List)
      .map((e) => Trip.fromJson(e as Map<String, dynamic>))
      .toList();
}
