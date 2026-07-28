import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/rides_repository.dart';
import '../models/ride_detail.dart';
import '../state/app_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/format.dart';
import '../widgets/chat_sheet.dart';
import '../widgets/impact_card.dart';
import '../widgets/live_track_sheet.dart';
import '../widgets/next_ride_card.dart';
import '../widgets/quick_action_tile.dart';
import '../widgets/ride_booking_card.dart';
import '../widgets/rydlnk_logo.dart';
import '../widgets/schedule_list_item.dart';
import '../widgets/stats_hero_card.dart';
import 'past_rides_screen.dart';
import 'payment_methods_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repo = RidesRepository();
  late Future<RideDetail?> _nextRide;
  late Future<List<RideDetail>> _todayRides;
  late Future<({int rides, int savingsCents, int co2Grams})> _stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _nextRide = _repo.nextDetailed();
    _todayRides = _repo.todayDetailed();
    _stats = _repo.weeklyStats();
  }

  void _reload() => setState(_load);

  String _countdown(RideDetail ride) {
    final now = DateTime.now();
    var h = 8, m = 0;
    if (ride.pickupTime != null) {
      final p = ride.pickupTime!.split(':');
      h = int.tryParse(p[0]) ?? 8;
      m = p.length > 1 ? (int.tryParse(p[1]) ?? 0) : 0;
    }
    final target = DateTime(
        ride.rideDate.year, ride.rideDate.month, ride.rideDate.day, h, m);
    final diff = target.difference(now);
    if (diff.isNegative) return 'soon';
    if (diff.inDays >= 1) return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'}';
    if (diff.inHours >= 1) return '${diff.inHours} hr';
    return '${diff.inMinutes} min';
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _TopBar()),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: FutureBuilder<
                      ({int rides, int savingsCents, int co2Grams})>(
                    future: _stats,
                    builder: (context, snap) {
                      final s = snap.data;
                      return StatsHeroCard(
                        greeting: AppSession.greeting,
                        name: AppSession.name,
                        subtitle: 'Ready for your commute?',
                        rides: s?.rides ?? 0,
                        savings: s == null ? '—' : money(s.savingsCents),
                        co2: s == null
                            ? '—'
                            : '${(s.co2Grams / 1000).toStringAsFixed(1)} kg',
                      );
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: FutureBuilder<RideDetail?>(
                  future: _nextRide,
                  builder: (context, snap) {
                    final ride = snap.data;
                    if (ride == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: NextRideCard(
                        title: ride.dropoff,
                        from: ride.pickup,
                        to: ride.dropoff,
                        window: ride.timeLabel,
                        driver: ride.hasDriver
                            ? ride.driverDisplay
                            : 'pending match',
                        countdown: _countdown(ride),
                        onTrack: (ride.hasDriver && ride.driverId != null)
                            ? () {
                                HapticFeedback.lightImpact();
                                LiveTrackSheet.show(context,
                                    driverId: ride.driverId!,
                                    title: 'Live tracking');
                              }
                            : () {},
                        onMessage: ride.tripId == null
                            ? () {}
                            : () => ChatSheet.show(context,
                                tripId: ride.tripId!, title: 'Your driver'),
                      ),
                    );
                  },
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _SectionTitle(label: 'Quick actions'),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _QuickActions(
                    onNewSchedule: () => _openBookingSheet(context),
                    onFindRides: () => _openBookingSheet(context),
                    onPayment: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PaymentMethodsScreen(),
                      ),
                    ),
                    onHistory: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PastRidesScreen(),
                      ),
                    ),
                  ),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _SectionTitle(label: "Today's schedule"),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: FutureBuilder<List<RideDetail>>(
                    future: _todayRides,
                    builder: (context, snap) {
                      final rides = snap.data ?? const [];
                      if (rides.isEmpty) {
                        return _EmptyToday(
                            onBook: () => _openBookingSheet(context));
                      }
                      return Column(
                        children: [
                          for (var i = 0; i < rides.length; i++) ...[
                            if (i > 0) const SizedBox(height: 10),
                            ScheduleListItem(
                              title: rides[i].dropoff,
                              window: rides[i].timeLabel,
                              route: rides[i].routeLabel,
                              driver: rides[i].hasDriver
                                  ? rides[i].driverDisplay
                                  : (rides[i].isShared
                                      ? rides[i].poolLabel
                                      : 'Finding a driver'),
                              highlighted: i == 0,
                              status: i == 0 ? 'Next' : null,
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                sliver: SliverToBoxAdapter(
                  child: FutureBuilder<
                      ({int rides, int savingsCents, int co2Grams})>(
                    future: _stats,
                    builder: (context, snap) {
                      final s = snap.data;
                      return ImpactCard(
                        rides: s?.rides ?? 0,
                        savedLabel: s == null ? '—' : money(s.savingsCents),
                        co2Label: s == null
                            ? '—'
                            : '${(s.co2Grams / 1000).toStringAsFixed(1)} kg',
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openBookingSheet(BuildContext context) =>
      RideBookingCard.show(context).then((_) => _reload());
}

// ─────────────────────────── Empty today ───────────────────────────

class _EmptyToday extends StatelessWidget {
  const _EmptyToday({required this.onBook});
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.event_available_rounded,
              size: 30, color: AppColors.primary),
          const SizedBox(height: 10),
          Text('Nothing scheduled today',
              style: AppType.bodyStrong.copyWith(fontSize: 15)),
          const SizedBox(height: 4),
          Text('Book a ride to fill your day.',
              style: AppType.caption.copyWith(color: AppColors.muted)),
          const SizedBox(height: 14),
          Material(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onBook,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                child: Text('Find a ride',
                    style: AppType.button.copyWith(color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Top bar ───────────────────────────

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
      child: Row(
        children: [
          const RydlnkLogo(size: 22),
          const Spacer(),
          _IconChip(
            icon: Icons.notifications_none_rounded,
            tooltip: 'Notifications',
            onTap: () {
              HapticFeedback.lightImpact();
              _NotificationsSheet.show(context);
            },
          ),
        ],
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon, required this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Semantics(
            button: true,
            label: tooltip,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(icon, size: 20, color: AppColors.body),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: AppType.h2.copyWith(fontSize: 18));
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onNewSchedule,
    required this.onFindRides,
    required this.onPayment,
    required this.onHistory,
  });

  final VoidCallback onNewSchedule;
  final VoidCallback onFindRides;
  final VoidCallback onPayment;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: QuickActionTile(
                icon: Icons.add_rounded,
                label: 'New schedule',
                tint: AppColors.accentBlueTint,
                iconColor: AppColors.accentBlue,
                onTap: onNewSchedule,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: QuickActionTile(
                icon: Icons.search_rounded,
                label: 'Find rides',
                tint: AppColors.accentPurpleTint,
                iconColor: AppColors.accentPurple,
                onTap: onFindRides,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: QuickActionTile(
                icon: Icons.credit_card_rounded,
                label: 'Payment',
                tint: AppColors.primaryTint,
                iconColor: AppColors.primary,
                onTap: onPayment,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: QuickActionTile(
                icon: Icons.history_rounded,
                label: 'History',
                tint: AppColors.accentOrangeTint,
                iconColor: AppColors.accentOrange,
                onTap: onHistory,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────── Notifications sheet ───────────────────────────

class _NotificationsSheet extends StatelessWidget {
  static void show(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const _NotificationsSheet(),
      );

  const _NotificationsSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 28 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text('Notifications', style: AppType.h3),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                const Icon(Icons.notifications_none_rounded,
                    size: 40, color: AppColors.muted),
                const SizedBox(height: 12),
                Text("You're all caught up",
                    style: AppType.bodyStrong.copyWith(fontSize: 15)),
                const SizedBox(height: 4),
                Text('Ride and schedule updates will appear here.',
                    textAlign: TextAlign.center,
                    style: AppType.caption.copyWith(color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
