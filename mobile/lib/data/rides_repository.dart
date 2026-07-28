import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ride.dart';
import '../models/ride_detail.dart';
import '../models/schedule.dart';
import '../state/app_session.dart';
import '../utils/format.dart';

/// Data access for schedules and rides. All calls are scoped to the signed-in
/// user by Row Level Security on the database.
class RidesRepository {
  SupabaseClient get _c => AppSession.client;

  /// Creates a schedule and generates its rides server-side (via the
  /// `create_schedule` Postgres function). Returns the new schedule id.
  Future<String> createSchedule({
    String? title,
    required String pickup,
    required String dropoff,
    String? pickupAfter, // 'HH:mm:ss'
    String? arriveBy, // 'HH:mm:ss'
    required List<int> days, // 0=Sun … 6=Sat
    required DateTime start,
    DateTime? end,
    bool returnRide = false,
    bool recurring = true,
    bool autoReschedule = false,
    int priceCents = 817,
    double? pickupLat,
    double? pickupLng,
    double? dropoffLat,
    double? dropoffLng,
  }) async {
    final id = await _c.rpc('create_schedule', params: {
      'p_title': title,
      'p_pickup': pickup,
      'p_dropoff': dropoff,
      'p_pickup_after': pickupAfter,
      'p_arrive_by': arriveBy,
      'p_days': days,
      'p_start': dateToDb(start),
      'p_end': end != null ? dateToDb(end) : null,
      'p_return_ride': returnRide,
      'p_recurring': recurring,
      'p_auto_reschedule': autoReschedule,
      'p_price_cents': priceCents,
      'p_pickup_lat': pickupLat,
      'p_pickup_lng': pickupLng,
      'p_dropoff_lat': dropoffLat,
      'p_dropoff_lng': dropoffLng,
    });
    return id as String;
  }

  Future<List<Schedule>> mySchedules() async {
    final rows = await _c
        .from('schedules')
        .select()
        .neq('status', 'cancelled')
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => Schedule.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> setScheduleStatus(String id, String status) async {
    await _c.from('schedules').update({'status': status}).eq('id', id);
  }

  /// Cancels a schedule and its future rides, recomputing co-riders' fares.
  Future<void> cancelSchedule(String id) async {
    await _c.rpc('cancel_schedule', params: {'p_schedule_id': id});
  }

  /// Cancels a single upcoming ride, recomputing the trip's remaining fares.
  Future<void> cancelRide(String id) async {
    await _c.rpc('cancel_ride', params: {'p_ride_id': id});
  }

  /// Rates the driver of a completed ride (1–5). Idempotent per ride.
  Future<void> rateRide(String rideId, int stars, {String? comment}) async {
    await _c.rpc('rate_ride', params: {
      'p_ride_id': rideId,
      'p_stars': stars,
      'p_comment': comment,
    });
  }

  Future<List<Ride>> todayRides() async {
    final today = dateToDb(DateTime.now());
    final rows = await _c
        .from('rides')
        .select()
        .eq('ride_date', today)
        .neq('status', 'cancelled')
        .order('pickup_time', nullsFirst: true);
    return _rides(rows);
  }

  Future<List<Ride>> history() async {
    final today = dateToDb(DateTime.now());
    final rows = await _c
        .from('rides')
        .select()
        .lt('ride_date', today)
        .order('ride_date', ascending: false)
        .limit(50);
    return _rides(rows);
  }

  /// This week's rider stats: real ride count + transparent impact estimates
  /// (≈ pooling savings and CO₂ avoided per shared commute).
  Future<({int rides, int savingsCents, int co2Grams})> weeklyStats() async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final rows = await _c
        .from('rides')
        .select('id')
        .gte('ride_date', dateToDb(weekStart))
        .lte('ride_date', dateToDb(now))
        .neq('status', 'cancelled');
    final n = (rows as List).length;
    return (rides: n, savingsCents: n * 400, co2Grams: n * 900);
  }

  /// The next upcoming ride (today or later), or null.
  Future<Ride?> nextRide() async {
    final today = dateToDb(DateTime.now());
    final rows = await _c
        .from('rides')
        .select()
        .gte('ride_date', today)
        .neq('status', 'cancelled')
        .order('ride_date', ascending: true)
        .order('pickup_time', ascending: true, nullsFirst: true)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return Ride.fromJson(list.first as Map<String, dynamic>);
  }

  List<Ride> _rides(dynamic rows) => (rows as List)
      .map((e) => Ride.fromJson(e as Map<String, dynamic>))
      .toList();

  // ── Detailed rides (with driver identity + live pool size) ──

  Future<List<RideDetail>> _detailed(DateTime from, DateTime to) async {
    final rows = await _c.rpc('my_rides_detailed', params: {
      'p_from': dateToDb(from),
      'p_to': dateToDb(to),
    });
    return (rows as List)
        .map((e) => RideDetail.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<RideDetail>> todayDetailed() {
    final now = DateTime.now();
    return _detailed(now, now);
  }

  Future<List<RideDetail>> historyDetailed() async {
    final now = DateTime.now();
    final all = await _detailed(now.subtract(const Duration(days: 120)),
        now.subtract(const Duration(days: 1)));
    return all.reversed.toList(); // most recent first
  }

  Future<RideDetail?> nextDetailed() async {
    final now = DateTime.now();
    final upcoming = await _detailed(now, now.add(const Duration(days: 30)));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  Future<void> renameSchedule(String id, String title) async {
    await _c.from('schedules').update({'title': title}).eq('id', id);
  }

  Future<void> updateHomeWork({String? home, String? work}) async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return;
    final data = <String, dynamic>{};
    if (home != null) data['home_address'] = home;
    if (work != null) data['work_address'] = work;
    if (data.isEmpty) return;
    await _c.from('profiles').update(data).eq('id', uid);
  }

  Future<Map<String, dynamic>> notificationPrefs() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return {};
    final row = await _c
        .from('profiles')
        .select('notification_prefs')
        .eq('id', uid)
        .maybeSingle();
    return (row?['notification_prefs'] as Map?)?.cast<String, dynamic>() ?? {};
  }

  Future<void> setNotificationPrefs(Map<String, dynamic> prefs) async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return;
    await _c.from('profiles').update({'notification_prefs': prefs}).eq('id', uid);
  }

  /// The signed-in user's saved home/work addresses, with sensible fallbacks.
  Future<({String home, String work})> myAddresses() async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return (home: 'Home', work: 'Work');
    final row = await _c
        .from('profiles')
        .select('home_address, work_address')
        .eq('id', uid)
        .maybeSingle();
    final home = (row?['home_address'] as String?)?.trim();
    final work = (row?['work_address'] as String?)?.trim();
    return (
      home: (home == null || home.isEmpty) ? 'Home' : home,
      work: (work == null || work.isEmpty) ? 'Work' : work,
    );
  }
}
