import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/driver_location_service.dart';
import '../../data/driver_repository.dart';
import '../../models/driver_profile.dart';
import '../../models/trip.dart';
import '../../models/trip_stop.dart';
import '../../state/app_session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/errors.dart';
import '../../utils/format.dart';
import '../../widgets/chat_sheet.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final _repo = DriverRepository();
  DriverProfile? _driver;
  List<Trip> _today = const [];
  bool _loading = true;
  bool _togglingOnline = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final driver = await _repo.myDriver();
    final today = await _repo.myTrips(todayOnly: true);
    if (!mounted) return;
    setState(() {
      _driver = driver;
      _today = today;
      _loading = false;
    });
  }

  Future<void> _toggleOnline(bool value) async {
    setState(() => _togglingOnline = true);
    HapticFeedback.lightImpact();
    try {
      await _repo.setAvailability(value);
      if (value) {
        final ok = await DriverLocationService.instance.start();
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Location permission is needed for riders to track you.')));
        }
      } else {
        await DriverLocationService.instance.stop();
      }
      if (!mounted) return;
      setState(() => _driver = _driver == null
          ? null
          : DriverProfile.fromJson({
              'id': _driver!.id,
              'vehicle': _driver!.vehicle,
              'license_plate': _driver!.plate,
              'rating': _driver!.rating,
              'is_available': value,
              'verified': _driver!.verified,
            }));
    } finally {
      if (mounted) setState(() => _togglingOnline = false);
    }
  }

  Future<void> _advance(Trip t) async {
    final next = t.nextStatus;
    if (next == null) return;
    HapticFeedback.lightImpact();
    try {
      await _repo.setTripStatus(t.id, next);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  int get _earnedTodayCents => _today
      .where((t) => t.status == 'completed')
      .fold(0, (sum, t) => sum + t.baseFareCents);

  @override
  Widget build(BuildContext context) {
    final online = _driver?.isAvailable ?? false;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Row(
                children: [
                  Text('Driver', style: AppType.h1.copyWith(fontSize: 26)),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.markAccent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text('BETA',
                        style: AppType.overline
                            .copyWith(color: AppColors.warning, fontSize: 10)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _OnlineHero(
                name: AppSession.name.isEmpty ? 'there' : AppSession.name,
                online: online,
                busy: _togglingOnline,
                tripsToday: _today.length,
                earnedToday: moneyRound(_earnedTodayCents),
                onToggle: _toggleOnline,
              ),
              if (_driver != null && !_driver!.verified) ...[
                const SizedBox(height: 16),
                const _VerificationBanner(),
              ],
              const SizedBox(height: 24),
              Text("Today's trips", style: AppType.h2.copyWith(fontSize: 18)),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary)),
                )
              else if (_today.isEmpty)
                const _EmptyTrips()
              else
                for (final t in _today) ...[
                  _TripCard(
                    trip: t,
                    onAdvance: () => _advance(t),
                    onMessage: () => ChatSheet.show(context,
                        tripId: t.id, title: 'Your riders'),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Online hero ───────────────────────────

class _OnlineHero extends StatelessWidget {
  const _OnlineHero({
    required this.name,
    required this.online,
    required this.busy,
    required this.tripsToday,
    required this.earnedToday,
    required this.onToggle,
  });

  final String name;
  final bool online;
  final bool busy;
  final int tripsToday;
  final String earnedToday;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      online ? "You're online" : "You're offline",
                      style: AppType.h2
                          .copyWith(color: Colors.white, fontSize: 19),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      online
                          ? 'Accepting trip requests, $name'
                          : 'Go online to get requests',
                      style: AppType.body.copyWith(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Opacity(
                opacity: busy ? 0.5 : 1,
                child: Switch(
                  value: online,
                  onChanged: busy ? null : onToggle,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.markAccent,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.25),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  icon: Icons.route_rounded,
                  value: '$tripsToday',
                  label: 'Trips today',
                ),
              ),
              Container(
                width: 1,
                height: 32,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: Colors.white.withValues(alpha: 0.18),
              ),
              Expanded(
                child: _HeroStat(
                  icon: Icons.payments_rounded,
                  value: earnedToday,
                  label: 'Earned today',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VerificationBanner extends StatelessWidget {
  const _VerificationBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_outlined,
              color: AppColors.warning, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Account under review',
                    style: AppType.bodyStrong.copyWith(fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  "You can go online, but accepting trips unlocks once you're verified.",
                  style: AppType.caption.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat(
      {required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 18),
        const SizedBox(height: 6),
        Text(value,
            style: AppType.h3.copyWith(color: Colors.white, fontSize: 17)),
        const SizedBox(height: 2),
        Text(label,
            style: AppType.caption.copyWith(
                color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
      ],
    );
  }
}

// ─────────────────────────── Trip card ───────────────────────────

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.trip,
    required this.onAdvance,
    required this.onMessage,
  });
  final Trip trip;
  final VoidCallback onAdvance;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final action = trip.driverActionLabel;
    final claimed = trip.status != 'scheduled';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(trip.timeLabel,
                    style: AppType.captionStrong
                        .copyWith(color: AppColors.primary, fontSize: 14)),
              ),
              if (claimed)
                Tooltip(
                  message: 'Message riders',
                  child: Semantics(
                    button: true,
                    label: 'Message riders',
                    child: GestureDetector(
                      onTap: onMessage,
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.fromLTRB(8, 8, 10, 8),
                        child: Icon(Icons.chat_bubble_outline_rounded,
                            size: 18, color: AppColors.primary),
                      ),
                    ),
                  ),
                ),
              _StatusChip(status: trip.status, label: trip.statusLabel),
            ],
          ),
          const SizedBox(height: 12),
          _TripStops(tripId: trip.id, dropoff: trip.dropoff),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.groups_rounded,
                  size: 15, color: AppColors.muted),
              const SizedBox(width: 6),
              Text(trip.seatsLabel, style: AppType.caption),
              const Spacer(),
              Text('You earn ${trip.driverPayLabel}',
                  style: AppType.captionStrong
                      .copyWith(color: AppColors.primary, fontSize: 13)),
            ],
          ),
          if (action != null) ...[
            const SizedBox(height: 14),
            Material(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: onAdvance,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  alignment: Alignment.center,
                  child: Text(action,
                      style: AppType.button.copyWith(color: Colors.white)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The multi-stop pickup sequence for a claimed trip, then the shared drop-off.
class _TripStops extends StatelessWidget {
  const _TripStops({required this.tripId, required this.dropoff});
  final String tripId;
  final String dropoff;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TripStop>>(
      future: DriverRepository().tripStops(tripId),
      builder: (context, snap) {
        final stops = snap.data ?? const [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (stops.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('${stops.length} pickups',
                    style: AppType.overline.copyWith(fontSize: 10)),
              ),
            if (stops.isEmpty)
              const _StopRow(icon: Icons.trip_origin_rounded, text: '…')
            else
              for (final s in stops)
                _StopRow(
                  icon: Icons.trip_origin_rounded,
                  text: s.pickup,
                  trailing: s.riderLabel,
                ),
            _StopRow(icon: Icons.location_on_rounded, text: dropoff),
          ],
        );
      },
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({required this.icon, required this.text, this.trailing});
  final IconData icon;
  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: AppType.bodyStrong.copyWith(fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(trailing!,
                  style: AppType.caption.copyWith(
                      color: AppColors.primary, fontSize: 11)),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.label});
  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final active = status != 'scheduled' && status != 'completed';
    final color = status == 'completed'
        ? AppColors.primary
        : active
            ? AppColors.accentOrange
            : AppColors.muted;
    final bg = status == 'completed'
        ? AppColors.primaryTint
        : active
            ? AppColors.accentOrangeTint
            : AppColors.elevatedSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(label,
          style: AppType.caption.copyWith(
              color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

class _EmptyTrips extends StatelessWidget {
  const _EmptyTrips();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.local_taxi_rounded,
              size: 32, color: AppColors.primary),
          const SizedBox(height: 12),
          Text('No trips yet today',
              style: AppType.bodyStrong.copyWith(fontSize: 15)),
          const SizedBox(height: 4),
          Text('Check Requests to pick up trips.',
              textAlign: TextAlign.center,
              style: AppType.caption.copyWith(color: AppColors.muted)),
        ],
      ),
    );
  }
}
