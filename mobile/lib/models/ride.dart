import '../utils/format.dart';

/// A single trip, generated from a [Schedule]. Rows in the `rides` table.
class Ride {
  Ride({
    required this.id,
    required this.pickup,
    required this.dropoff,
    required this.rideDate,
    this.scheduleId,
    this.driverId,
    this.tripId,
    this.pickupTime,
    this.status = 'scheduled',
    this.priceCents,
  });

  final String id;
  final String? scheduleId;
  final String? driverId;
  final String? tripId;
  final String pickup;
  final String dropoff;
  final DateTime rideDate;
  final String? pickupTime; // 'HH:mm:ss'
  final String status; // scheduled | matched | enroute | arrived | started | completed | cancelled
  final int? priceCents;

  factory Ride.fromJson(Map<String, dynamic> j) => Ride(
        id: j['id'] as String,
        scheduleId: j['schedule_id'] as String?,
        driverId: j['driver_id'] as String?,
        tripId: j['trip_id'] as String?,
        pickup: j['pickup'] as String,
        dropoff: j['dropoff'] as String,
        rideDate: DateTime.parse(j['ride_date'] as String),
        pickupTime: j['pickup_time'] as String?,
        status: j['status'] as String? ?? 'scheduled',
        priceCents: (j['price_cents'] as num?)?.toInt(),
      );

  bool get hasDriver => driverId != null;

  bool get isLive =>
      status == 'enroute' || status == 'arrived' || status == 'started';

  String get routeLabel => '$pickup  →  $dropoff';

  /// e.g. `8:30 AM` or `Time TBD`.
  String get timeLabel => formatDbTime(pickupTime) ?? 'Time TBD';

  String get priceLabel => money(priceCents);

  String get driverLabel => hasDriver ? 'Your driver' : 'Finding driver';

  String get statusLabel {
    switch (status) {
      case 'scheduled':
        return 'Scheduled';
      case 'matched':
        return 'Assigned';
      case 'enroute':
        return 'En route';
      case 'arrived':
        return 'Arrived';
      case 'started':
        return 'In progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  /// Driver-side trip progression. Returns null when there's no next step.
  String? get nextStatus => const {
        'matched': 'enroute',
        'enroute': 'arrived',
        'arrived': 'started',
        'started': 'completed',
      }[status];

  /// Label for the driver's action button that advances [status].
  String? get driverActionLabel => const {
        'matched': 'Start driving',
        'enroute': "I've arrived",
        'arrived': 'Start ride',
        'started': 'Complete ride',
      }[status];

  bool get isActiveForDriver =>
      status == 'matched' ||
      status == 'enroute' ||
      status == 'arrived' ||
      status == 'started';
}
