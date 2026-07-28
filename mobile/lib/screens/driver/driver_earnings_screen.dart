import 'package:flutter/material.dart';

import '../../data/driver_repository.dart';
import '../../models/trip.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/format.dart';

class DriverEarningsScreen extends StatefulWidget {
  const DriverEarningsScreen({super.key});

  @override
  State<DriverEarningsScreen> createState() => _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends State<DriverEarningsScreen> {
  final _repo = DriverRepository();
  late Future<List<Trip>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.completedTrips();
  }

  Future<void> _reload() async {
    setState(() => _future = _repo.completedTrips());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FutureBuilder<List<Trip>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary));
            }
            final trips = snap.data ?? const [];
            final total = trips.fold<int>(0, (s, t) => s + t.baseFareCents);
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  Text('Earnings', style: AppType.h1.copyWith(fontSize: 26)),
                  const SizedBox(height: 16),
                  _EarningsHero(total: money(total), trips: trips.length),
                  const SizedBox(height: 24),
                  Text('Completed trips',
                      style: AppType.h2.copyWith(fontSize: 18)),
                  const SizedBox(height: 12),
                  if (trips.isEmpty)
                    _EmptyEarnings()
                  else
                    for (final t in trips) ...[
                      _EarningRow(trip: t),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EarningsHero extends StatelessWidget {
  const _EarningsHero({required this.total, required this.trips});
  final String total;
  final int trips;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
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
          Text('Total earned',
              style: AppType.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.75), fontSize: 13)),
          const SizedBox(height: 6),
          Text(total,
              style: AppType.h1.copyWith(color: Colors.white, fontSize: 40)),
          const SizedBox(height: 6),
          Text('$trips completed trip${trips == 1 ? '' : 's'}',
              style: AppType.body.copyWith(
                  color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
        ],
      ),
    );
  }
}

class _EarningRow extends StatelessWidget {
  const _EarningRow({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.check_rounded,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(trip.routeLabel,
                    style: AppType.bodyStrong.copyWith(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(prettyDate(trip.rideDate),
                    style: AppType.caption.copyWith(fontSize: 12)),
              ],
            ),
          ),
          Text(trip.driverPayLabel,
              style:
                  AppType.h3.copyWith(color: AppColors.primary, fontSize: 15)),
        ],
      ),
    );
  }
}

class _EmptyEarnings extends StatelessWidget {
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
          const Icon(Icons.savings_outlined,
              size: 32, color: AppColors.primary),
          const SizedBox(height: 12),
          Text('No earnings yet',
              style: AppType.bodyStrong.copyWith(fontSize: 15)),
          const SizedBox(height: 4),
          Text('Complete trips to start earning.',
              textAlign: TextAlign.center,
              style: AppType.caption.copyWith(color: AppColors.muted)),
        ],
      ),
    );
  }
}
