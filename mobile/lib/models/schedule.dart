import '../utils/format.dart';

/// A recurring (or one-time) booking. Rows in the `schedules` table;
/// each schedule fans out into many `rides`.
class Schedule {
  Schedule({
    required this.id,
    required this.pickup,
    required this.dropoff,
    required this.days,
    required this.startDate,
    this.title,
    this.pickupAfter,
    this.arriveBy,
    this.endDate,
    this.returnRide = false,
    this.recurring = true,
    this.autoReschedule = false,
    this.status = 'active',
    this.estimatedPriceCents = 0,
  });

  final String id;
  final String? title;
  final String pickup;
  final String dropoff;
  final String? pickupAfter; // 'HH:mm:ss'
  final String? arriveBy; // 'HH:mm:ss'
  final List<int> days; // 0=Sun … 6=Sat
  final DateTime startDate;
  final DateTime? endDate;
  final bool returnRide;
  final bool recurring;
  final bool autoReschedule;
  final String status; // active | paused | cancelled
  final int estimatedPriceCents;

  factory Schedule.fromJson(Map<String, dynamic> j) => Schedule(
        id: j['id'] as String,
        title: j['title'] as String?,
        pickup: j['pickup'] as String,
        dropoff: j['dropoff'] as String,
        pickupAfter: j['pickup_after'] as String?,
        arriveBy: j['arrive_by'] as String?,
        days: ((j['days'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .toList(),
        startDate: DateTime.parse(j['start_date'] as String),
        endDate: j['end_date'] != null
            ? DateTime.parse(j['end_date'] as String)
            : null,
        returnRide: j['return_ride'] as bool? ?? false,
        recurring: j['recurring'] as bool? ?? true,
        autoReschedule: j['auto_reschedule'] as bool? ?? false,
        status: j['status'] as String? ?? 'active',
        estimatedPriceCents: (j['estimated_price_cents'] as num?)?.toInt() ?? 0,
      );

  bool get isActive => status == 'active';

  String get displayTitle =>
      (title != null && title!.trim().isNotEmpty) ? title!.trim() : 'Commute';

  String get daysLabel {
    if (days.isEmpty) return recurring ? 'No days set' : 'One-time';
    final sorted = [...days]..sort();
    return sorted.map(weekdayShort).join(' · ');
  }

  String get routeLabel => '$pickup  →  $dropoff';

  String get windowLabel {
    final a = formatDbTime(pickupAfter);
    final b = formatDbTime(arriveBy);
    if (a == null && b == null) return 'Flexible timing';
    if (b == null) return 'From $a';
    if (a == null) return 'By $b';
    return '$a – $b';
  }

  int get _ridesPerWeek {
    var c = days.isEmpty ? 1 : days.length;
    if (returnRide) c *= 2;
    return c;
  }

  String get weeklyLabel => moneyRound(_ridesPerWeek * estimatedPriceCents);
}
