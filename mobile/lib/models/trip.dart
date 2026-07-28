import '../utils/format.dart';

/// A shared vehicle journey. Riders are pooled onto one trip and split the
/// fare; the driver claims the whole trip and earns [baseFareCents].
///
/// Constructs from either a `trips` table row or an `available_trips()` row
/// (which includes [seatsTaken]).
class Trip {
  Trip({
    required this.id,
    required this.pickup,
    required this.dropoff,
    required this.rideDate,
    this.driverId,
    this.pickupTime,
    this.capacity = 4,
    this.baseFareCents = 0,
    this.seatsTaken = 1,
    this.status = 'scheduled',
  });

  final String id;
  final String? driverId;
  final String pickup;
  final String dropoff;
  final DateTime rideDate;
  final String? pickupTime; // 'HH:mm:ss'
  final int capacity;
  final int baseFareCents;
  final int seatsTaken;
  final String status;

  factory Trip.fromJson(Map<String, dynamic> j) => Trip(
        id: j['id'] as String,
        driverId: j['driver_id'] as String?,
        pickup: j['pickup'] as String,
        dropoff: j['dropoff'] as String,
        rideDate: DateTime.parse(j['ride_date'] as String),
        pickupTime: j['pickup_time'] as String?,
        capacity: (j['capacity'] as num?)?.toInt() ?? 4,
        baseFareCents: (j['base_fare_cents'] as num?)?.toInt() ?? 0,
        seatsTaken: (j['seats_taken'] as num?)?.toInt() ?? 1,
        status: j['status'] as String? ?? 'scheduled',
      );

  String get routeLabel => '$pickup  →  $dropoff';
  String get timeLabel => formatDbTime(pickupTime) ?? 'Time TBD';

  /// What the driver earns for the whole trip.
  String get driverPayLabel => money(baseFareCents);

  /// Each rider's split of the fare at the current passenger count.
  int get farePerRiderCents =>
      seatsTaken <= 0 ? baseFareCents : (baseFareCents / seatsTaken).round();
  String get farePerRiderLabel => money(farePerRiderCents);

  String get seatsLabel {
    final open = capacity - seatsTaken;
    if (open <= 0) return 'Full · $seatsTaken riders';
    return '$seatsTaken of $capacity seats';
  }

  String get statusLabel {
    switch (status) {
      case 'scheduled':
        return 'Open';
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

  String? get nextStatus => const {
        'matched': 'enroute',
        'enroute': 'arrived',
        'arrived': 'started',
        'started': 'completed',
      }[status];

  String? get driverActionLabel => const {
        'matched': 'Start driving',
        'enroute': "I've arrived",
        'arrived': 'Start ride',
        'started': 'Complete trip',
      }[status];
}
