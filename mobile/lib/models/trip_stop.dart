/// One rider's pickup on a shared (multi-stop) trip — from `trip_stops`.
class TripStop {
  TripStop({
    required this.rideId,
    required this.pickup,
    required this.dropoff,
    this.pickupLat,
    this.pickupLng,
    this.riderName,
  });

  final String rideId;
  final String pickup;
  final String dropoff;
  final double? pickupLat;
  final double? pickupLng;
  final String? riderName;

  factory TripStop.fromJson(Map<String, dynamic> j) => TripStop(
        rideId: j['ride_id'] as String,
        pickup: j['pickup'] as String,
        dropoff: j['dropoff'] as String,
        pickupLat: (j['pickup_lat'] as num?)?.toDouble(),
        pickupLng: (j['pickup_lng'] as num?)?.toDouble(),
        riderName: j['rider_name'] as String?,
      );

  String get riderLabel {
    final n = riderName?.trim();
    if (n == null || n.isEmpty) return 'Rider';
    return n.split(' ').first;
  }
}
