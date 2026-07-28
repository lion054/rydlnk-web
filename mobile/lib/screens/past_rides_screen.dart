import 'package:flutter/material.dart';

import '../data/rides_repository.dart';
import '../models/ride_detail.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/format.dart';
import '../widgets/ride_list_item.dart';

class PastRidesScreen extends StatefulWidget {
  const PastRidesScreen({super.key});

  @override
  State<PastRidesScreen> createState() => _PastRidesScreenState();
}

class _PastRidesScreenState extends State<PastRidesScreen> {
  final _repo = RidesRepository();
  late Future<List<RideDetail>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.historyDetailed();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text('Past rides', style: AppType.h3),
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<List<RideDetail>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary));
            }
            final rides = snap.data ?? const [];
            if (rides.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.history_rounded,
                          size: 40, color: AppColors.muted),
                      const SizedBox(height: 12),
                      Text('No past rides yet',
                          style: AppType.h3.copyWith(fontSize: 17)),
                      const SizedBox(height: 6),
                      Text('Completed rides will show up here.',
                          textAlign: TextAlign.center,
                          style: AppType.body.copyWith(color: AppColors.muted)),
                    ],
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              physics: const BouncingScrollPhysics(),
              itemCount: rides.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final r = rides[i];
                final done = r.status == 'completed';
                return RideListItem(
                  date: prettyDate(r.rideDate),
                  time: r.timeLabel,
                  from: r.pickup,
                  to: r.dropoff,
                  riders: r.seatsTaken,
                  price: r.priceLabel,
                  status: done ? 'Completed' : 'Past',
                  statusColor: done ? AppColors.primary : AppColors.muted,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
