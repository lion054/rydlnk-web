import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/driver_repository.dart';
import '../../models/trip.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/skeleton.dart';
import '../../utils/errors.dart';
import '../../utils/format.dart';

class DriverRequestsScreen extends StatefulWidget {
  const DriverRequestsScreen({super.key});

  @override
  State<DriverRequestsScreen> createState() => _DriverRequestsScreenState();
}

class _DriverRequestsScreenState extends State<DriverRequestsScreen> {
  final _repo = DriverRepository();
  late Future<List<Trip>> _future;
  final _claiming = <String>{};
  bool _verified = true;

  @override
  void initState() {
    super.initState();
    _future = _repo.availableTrips();
    _repo.myDriver().then((d) {
      if (mounted && d != null) setState(() => _verified = d.verified);
    });
  }

  Future<void> _reload() async {
    setState(() => _future = _repo.availableTrips());
    await _future;
  }

  Future<void> _claim(Trip t) async {
    setState(() => _claiming.add(t.id));
    HapticFeedback.mediumImpact();
    try {
      await _repo.claimTrip(t.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip added to Today.')),
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      setState(() => _claiming.remove(t.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Text('Trip requests',
                  style: AppType.h1.copyWith(fontSize: 26)),
            ),
            if (!_verified)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.warningTint,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded,
                          size: 18, color: AppColors.warning),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Accepting trips is locked until your account is verified.',
                          style: AppType.caption.copyWith(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: FutureBuilder<List<Trip>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const SkeletonList(count: 3, height: 150);
                  }
                  if (snap.hasError) {
                    return _Message(
                      icon: Icons.cloud_off_rounded,
                      title: "Couldn't load requests",
                      subtitle: '${snap.error}',
                    );
                  }
                  final trips = snap.data ?? const [];
                  if (trips.isEmpty) {
                    return RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _reload,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics()),
                        children: const [
                          SizedBox(height: 80),
                          _Message(
                            icon: Icons.inbox_rounded,
                            title: 'No open trips',
                            subtitle:
                                'Trips appear here as riders book them. Pull to refresh.',
                          ),
                        ],
                      ),
                    );
                  }
                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _reload,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics()),
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                      itemCount: trips.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final t = trips[i];
                        return _RequestCard(
                          trip: t,
                          busy: _claiming.contains(t.id),
                          onAccept: () => _claim(t),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.trip,
    required this.busy,
    required this.onAccept,
  });

  final Trip trip;
  final bool busy;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
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
                child: Text(prettyDate(trip.rideDate),
                    style: AppType.bodyStrong.copyWith(fontSize: 15)),
              ),
              Text(trip.driverPayLabel,
                  style: AppType.h3
                      .copyWith(color: AppColors.primary, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(trip.timeLabel,
                  style: AppType.captionStrong
                      .copyWith(color: AppColors.primary, fontSize: 13)),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accentPurpleTint,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.groups_rounded,
                        size: 12, color: AppColors.accentPurple),
                    const SizedBox(width: 4),
                    Text(trip.seatsLabel,
                        style: AppType.caption.copyWith(
                            fontSize: 11, color: AppColors.accentPurple)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Leg(
              icon: Icons.trip_origin_rounded,
              label: 'Pickup',
              value: trip.pickup),
          const SizedBox(height: 8),
          _Leg(
              icon: Icons.location_on_rounded,
              label: 'Drop-off',
              value: trip.dropoff),
          const SizedBox(height: 16),
          Material(
            color: busy ? AppColors.borderStrong : AppColors.primary,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: busy ? null : onAccept,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                alignment: Alignment.center,
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.2, color: Colors.white),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_rounded,
                              size: 18, color: Colors.white),
                          const SizedBox(width: 8),
                          Text('Accept trip',
                              style:
                                  AppType.button.copyWith(color: Colors.white)),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Leg extends StatelessWidget {
  const _Leg({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppType.caption.copyWith(fontSize: 11)),
              Text(value,
                  style: AppType.bodyStrong.copyWith(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                  color: AppColors.primaryTint, shape: BoxShape.circle),
              child: Icon(icon, size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(title, style: AppType.h3.copyWith(fontSize: 18)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: AppType.body.copyWith(color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}
