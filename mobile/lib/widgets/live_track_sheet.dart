import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/location_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Rider-facing live tracking: follows the assigned driver's real position
/// over Supabase Realtime, on OpenStreetMap tiles.
class LiveTrackSheet extends StatefulWidget {
  const LiveTrackSheet({super.key, required this.driverId, required this.title});

  final String driverId;
  final String title;

  static void show(BuildContext context,
      {required String driverId, required String title}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LiveTrackSheet(driverId: driverId, title: title),
    );
  }

  @override
  State<LiveTrackSheet> createState() => _LiveTrackSheetState();
}

class _LiveTrackSheetState extends State<LiveTrackSheet> {
  final _repo = LocationRepository();
  final _map = MapController();

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
          Row(
            children: [
              Text('Live tracking', style: AppType.h3),
              const Spacer(),
              _LivePill(),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<LatLng?>(
            stream: _repo.streamDriver(widget.driverId),
            builder: (context, snap) {
              final pos = snap.data;
              return SizedBox(
                height: 260,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _map,
                        options: MapOptions(
                          initialCenter:
                              pos ?? const LatLng(40.2338, -111.6585),
                          initialZoom: 15,
                          interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.pinchZoom |
                                  InteractiveFlag.drag),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.rydlnk.app',
                          ),
                          if (pos != null)
                            MarkerLayer(markers: [
                              Marker(
                                point: pos,
                                width: 40,
                                height: 40,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.4),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                      Icons.directions_car_filled_rounded,
                                      color: Colors.white,
                                      size: 20),
                                ),
                              ),
                            ]),
                        ],
                      ),
                      if (pos == null)
                        Container(
                          color: AppColors.background.withValues(alpha: 0.6),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                  color: AppColors.primary),
                              const SizedBox(height: 12),
                              Text('Waiting for driver location…',
                                  style: AppType.caption),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text('Close',
                    style: AppType.button.copyWith(color: AppColors.body)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LivePill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: AppColors.dangerTint, borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
                color: AppColors.danger, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text('Live',
              style: AppType.caption.copyWith(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                  fontSize: 12)),
        ],
      ),
    );
  }
}
