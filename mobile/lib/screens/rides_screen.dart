import 'package:flutter/material.dart';

import '../data/rides_repository.dart';
import '../models/ride_detail.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/errors.dart';
import '../utils/format.dart';
import '../widgets/chat_sheet.dart';
import '../widgets/live_track_sheet.dart';
import '../widgets/rating_sheet.dart';
import '../widgets/safety_sheet.dart';
import '../widgets/skeleton.dart';

class RidesScreen extends StatefulWidget {
  const RidesScreen({super.key});

  @override
  State<RidesScreen> createState() => _RidesScreenState();
}

class _RidesScreenState extends State<RidesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Text('Rides', style: AppType.h1.copyWith(fontSize: 26)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: _SegmentedTabs(controller: _tab),
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: const [
                  _TodayTab(),
                  _HistoryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({required this.controller});
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.muted,
        labelStyle:
            AppType.button.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            AppType.button.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
        tabs: const [
          Tab(text: 'Today'),
          Tab(text: 'History'),
        ],
      ),
    );
  }
}

// ─────────────────────────── Today tab ───────────────────────────

class _TodayTab extends StatefulWidget {
  const _TodayTab();

  @override
  State<_TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends State<_TodayTab> {
  final _repo = RidesRepository();
  late Future<List<RideDetail>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.todayDetailed();
  }

  Future<void> _reload() async {
    setState(() => _future = _repo.todayDetailed());
    await _future;
  }

  void _showTrack(BuildContext context, String driverId) =>
      LiveTrackSheet.show(context, driverId: driverId, title: 'Live tracking');

  void _showChat(BuildContext context, String tripId) =>
      ChatSheet.show(context, tripId: tripId, title: 'Your driver');

  void _showSos(RideDetail r) => SafetySheet.show(
        context,
        shareText: "I'm on a Rydlnk ride from ${r.pickup} to ${r.dropoff}, "
            'due ${r.timeLabel}. Follow along and check in on me.',
      );

  Future<void> _cancel(RideDetail r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Cancel this ride?', style: AppType.h3),
        content: Text(
            'Your seat is released. If you share the trip, co-riders keep theirs.',
            style: AppType.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep it',
                style: AppType.button.copyWith(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Cancel ride',
                style: AppType.button.copyWith(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.cancelRide(r.rideId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RideDetail>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SkeletonList(count: 2, height: 150);
        }
        final rides = snap.data ?? const [];
        if (rides.isEmpty) {
          return const _EmptyRides(
            icon: Icons.wb_sunny_outlined,
            title: 'No rides today',
            subtitle: 'Book a ride and it will show up here.',
          );
        }
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _reload,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            itemCount: rides.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final r = rides[i];
              return _RideCard(
                title: r.dropoff,
                time: r.timeLabel,
                route: r.routeLabel,
                driver: r.driverDisplay,
                initials: r.driverInitialsOr,
                vehicle: r.vehicleLabel,
                rating: r.ratingLabel,
                pool: r.poolLabel,
                shared: r.isShared,
                status: r.isLive ? _RideStatus.live : _RideStatus.scheduled,
                onTrack: (r.hasDriver && r.driverId != null)
                    ? () => _showTrack(context, r.driverId!)
                    : null,
                onMessage: (r.hasDriver && r.tripId != null)
                    ? () => _showChat(context, r.tripId!)
                    : null,
                onSos: r.isLive ? () => _showSos(r) : null,
                onCancel: (r.status == 'scheduled' || r.status == 'matched')
                    ? () => _cancel(r)
                    : null,
              );
            },
          ),
        );
      },
    );
  }
}

// ─────────────────────────── History tab ───────────────────────────

class _HistoryTab extends StatefulWidget {
  const _HistoryTab();

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  final _repo = RidesRepository();
  late Future<List<RideDetail>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.historyDetailed();
  }

  Future<void> _reload() async {
    setState(() => _future = _repo.historyDetailed());
    await _future;
  }

  Future<void> _rate(RideDetail r) async {
    final result = await RatingSheet.show(context);
    if (result == null) return;
    try {
      await _repo.rateRide(r.rideId, result.stars, comment: result.comment);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks for the rating!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RideDetail>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SkeletonList(count: 3, height: 96);
        }
        final rides = snap.data ?? const [];
        if (rides.isEmpty) {
          return const _EmptyRides(
            icon: Icons.history_rounded,
            title: 'No past rides yet',
            subtitle: 'Completed rides will appear here.',
          );
        }
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _reload,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            itemCount: rides.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final r = rides[i];
              return _HistoryRow(
                date: relativeDate(r.rideDate),
                title: r.dropoff,
                route: r.routeLabel,
                driver: r.hasDriver ? r.driverDisplay : '—',
                price: r.priceLabel,
                completed: r.status == 'completed',
                onRate: (r.status == 'completed' && r.hasDriver)
                    ? () => _rate(r)
                    : null,
              );
            },
          ),
        );
      },
    );
  }
}

// ─────────────────────────── Empty state ───────────────────────────

class _EmptyRides extends StatelessWidget {
  const _EmptyRides({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics()),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.primaryTint,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 20),
        Center(child: Text(title, style: AppType.h3.copyWith(fontSize: 18))),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(subtitle,
              textAlign: TextAlign.center,
              style: AppType.body.copyWith(color: AppColors.muted)),
        ),
      ],
    );
  }
}

// ─────────────────────────── Ride card ───────────────────────────

enum _RideStatus { live, scheduled }

class _RideCard extends StatelessWidget {
  const _RideCard({
    required this.title,
    required this.time,
    required this.route,
    required this.driver,
    required this.initials,
    required this.vehicle,
    required this.status,
    this.rating,
    this.pool,
    this.shared = false,
    this.onTrack,
    this.onMessage,
    this.onCancel,
    this.onSos,
  });

  final String title;
  final String time;
  final String route;
  final String driver;
  final String initials;
  final String vehicle;
  final String? rating;
  final String? pool;
  final bool shared;
  final _RideStatus status;
  final VoidCallback? onTrack;
  final VoidCallback? onMessage;
  final VoidCallback? onCancel;
  final VoidCallback? onSos;

  @override
  Widget build(BuildContext context) {
    final isLive = status == _RideStatus.live;
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppType.h3),
                    const SizedBox(height: 4),
                    Text(time,
                        style: AppType.captionStrong.copyWith(
                            color: AppColors.primary, fontSize: 14)),
                  ],
                ),
              ),
              if (isLive)
                _LivePill()
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.accentBlueTint,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text('Scheduled',
                      style: AppType.caption.copyWith(
                        color: AppColors.accentBlue,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      )),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(route, style: AppType.body.copyWith(fontSize: 13)),
          if (pool != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.groups_rounded,
                    size: 14,
                    color: shared ? AppColors.accentPurple : AppColors.muted),
                const SizedBox(width: 6),
                Text(pool!,
                    style: AppType.caption.copyWith(
                        fontSize: 12,
                        color:
                            shared ? AppColors.accentPurple : AppColors.muted,
                        fontWeight:
                            shared ? FontWeight.w600 : FontWeight.w400)),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: AppType.captionStrong
                      .copyWith(color: Colors.white, fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(driver,
                              style:
                                  AppType.bodyStrong.copyWith(fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (rating != null) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.star_rounded,
                              size: 14, color: AppColors.markAccent),
                          const SizedBox(width: 2),
                          Text(rating!,
                              style: AppType.captionStrong
                                  .copyWith(fontSize: 12)),
                        ],
                      ],
                    ),
                    Text(vehicle,
                        style: AppType.caption.copyWith(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          if (isLive) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: onTrack,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.gps_fixed_rounded,
                                size: 16, color: Colors.white),
                            const SizedBox(width: 8),
                            Text('Track live',
                                style: AppType.button
                                    .copyWith(color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: onMessage,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.chat_bubble_outline_rounded,
                          size: 18, color: AppColors.body),
                    ),
                  ),
                ),
                if (onSos != null) ...[
                  const SizedBox(width: 10),
                  Material(
                    color: AppColors.dangerTint,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: onSos,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        alignment: Alignment.center,
                        child: Text('SOS',
                            style: AppType.button.copyWith(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (!isLive && onCancel != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4)),
                child: Text('Cancel ride',
                    style: AppType.captionStrong
                        .copyWith(color: AppColors.danger)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LivePill extends StatefulWidget {
  @override
  State<_LivePill> createState() => _LivePillState();
}

class _LivePillState extends State<_LivePill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.dangerTint,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween(begin: 0.4, end: 1.0).animate(_c),
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text('Live',
              style: AppType.caption.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              )),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.date,
    required this.title,
    required this.route,
    required this.driver,
    required this.price,
    this.completed = false,
    this.onRate,
  });

  final String date;
  final String title;
  final String route;
  final String driver;
  final String price;
  final bool completed;
  final VoidCallback? onRate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(date, style: AppType.caption.copyWith(fontSize: 12)),
              const Spacer(),
              Text(price,
                  style: AppType.h3
                      .copyWith(color: AppColors.primary, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 6),
          Text(title, style: AppType.bodyStrong.copyWith(fontSize: 15)),
          const SizedBox(height: 2),
          Text(route, style: AppType.caption.copyWith(fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Driver: $driver',
                  style: AppType.caption.copyWith(fontSize: 12)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: completed
                      ? AppColors.primaryTint
                      : AppColors.elevatedSurface,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  completed ? 'Completed' : 'Past',
                  style: AppType.caption.copyWith(
                    color: completed ? AppColors.primary : AppColors.muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
              if (onRate != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onRate,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.markAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 13, color: AppColors.markAccent),
                        const SizedBox(width: 4),
                        Text('Rate',
                            style: AppType.caption.copyWith(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w600,
                                fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
