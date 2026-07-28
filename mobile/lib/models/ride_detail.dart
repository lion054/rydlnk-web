import '../utils/format.dart';

/// A rider's ride enriched with the assigned driver's public identity and the
/// live pool size — from the `my_rides_detailed` RPC.
class RideDetail {
  RideDetail({
    required this.rideId,
    required this.pickup,
    required this.dropoff,
    required this.rideDate,
    this.tripId,
    this.pickupTime,
    this.status = 'scheduled',
    this.priceCents,
    this.driverId,
    this.driverName,
    this.driverInitials,
    this.driverRating,
    this.vehicle,
    this.plate,
    this.seatsTaken = 1,
  });

  final String rideId;
  final String? tripId;
  final String pickup;
  final String dropoff;
  final DateTime rideDate;
  final String? pickupTime;
  final String status;
  final int? priceCents;
  final String? driverId;
  final String? driverName;
  final String? driverInitials;
  final double? driverRating;
  final String? vehicle;
  final String? plate;
  final int seatsTaken;

  factory RideDetail.fromJson(Map<String, dynamic> j) => RideDetail(
        rideId: j['ride_id'] as String,
        tripId: j['trip_id'] as String?,
        pickup: j['pickup'] as String,
        dropoff: j['dropoff'] as String,
        rideDate: DateTime.parse(j['ride_date'] as String),
        pickupTime: j['pickup_time'] as String?,
        status: j['status'] as String? ?? 'scheduled',
        priceCents: (j['price_cents'] as num?)?.toInt(),
        driverId: j['driver_id'] as String?,
        driverName: j['driver_name'] as String?,
        driverInitials: j['driver_initials'] as String?,
        driverRating: (j['driver_rating'] as num?)?.toDouble(),
        vehicle: j['vehicle'] as String?,
        plate: j['license_plate'] as String?,
        seatsTaken: (j['seats_taken'] as num?)?.toInt() ?? 1,
      );

  bool get hasDriver => driverId != null;

  bool get isLive =>
      status == 'enroute' || status == 'arrived' || status == 'started';

  String get routeLabel => '$pickup  →  $dropoff';
  String get timeLabel => formatDbTime(pickupTime) ?? 'Time TBD';
  String get priceLabel => money(priceCents);

  /// Driver display name, falling back gracefully.
  String get driverDisplay {
    final n = driverName?.trim();
    if (n != null && n.isNotEmpty) return n;
    return hasDriver ? 'Your driver' : 'Finding a driver';
  }

  String get driverInitialsOr {
    final i = driverInitials?.trim();
    if (i != null && i.isNotEmpty) return i;
    return hasDriver ? '★' : '…';
  }

  String get vehicleLabel {
    final v = vehicle?.trim();
    final p = plate?.trim();
    if ((v == null || v.isEmpty) && (p == null || p.isEmpty)) {
      return hasDriver ? 'Vehicle details coming' : 'Awaiting driver';
    }
    if (p == null || p.isEmpty) return v!;
    if (v == null || v.isEmpty) return p;
    return '$v · $p';
  }

  String? get ratingLabel => driverRating?.toStringAsFixed(1);

  // ── Pool visibility ──
  int get coRiders => seatsTaken > 1 ? seatsTaken - 1 : 0;
  bool get isShared => coRiders > 0;

  /// e.g. "Sharing with 2 others" / "Just you so far".
  String get poolLabel {
    if (coRiders == 0) return 'Just you so far';
    return 'Sharing with $coRiders ${coRiders == 1 ? 'other' : 'others'}';
  }
}
