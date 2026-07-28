import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../data/rides_repository.dart';
import '../data/routing_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Full-screen location picker: type to search (OSM), or drag the map under the
/// pin. Returns a [Place] via Navigator.pop.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key, required this.title, this.initial});

  final String title;
  final LatLng? initial;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _routing = RoutingService();
  final _searchCtrl = TextEditingController();
  final _map = MapController();

  Timer? _debounce;
  List<Place> _results = const [];
  bool _searching = false;

  LatLng _center = const LatLng(-17.8252, 31.0335); // Harare default
  String? _pinLabel;
  bool _reversing = false;
  bool _locating = false;
  String? _home;
  String? _work;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) _center = widget.initial!;
    RidesRepository().myAddresses().then((a) {
      if (!mounted) return;
      setState(() {
        _home = (a.home == 'Home') ? null : a.home;
        _work = (a.work == 'Work') ? null : a.work;
      });
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'Location services are off.';
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw 'Location permission denied.';
      }
      final pos = await Geolocator.getCurrentPosition();
      final here = LatLng(pos.latitude, pos.longitude);
      _map.move(here, 16);
      await _onMapMoved(here);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Couldn't get your location — search instead.")));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _useSaved(String address) async {
    setState(() => _reversing = true);
    final place = await _routing.geocode(address);
    if (!mounted) return;
    if (place == null) {
      setState(() => _reversing = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't locate “$address”.")));
      return;
    }
    setState(() {
      _center = place;
      _pinLabel = address;
      _reversing = false;
    });
    _map.move(place, 15);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      if (q.trim().length < 3) {
        setState(() => _results = const []);
        return;
      }
      setState(() => _searching = true);
      final r = await _routing.searchPlaces(q);
      if (!mounted) return;
      setState(() {
        _results = r;
        _searching = false;
      });
    });
  }

  void _selectResult(Place p) {
    FocusScope.of(context).unfocus();
    setState(() {
      _results = const [];
      _searchCtrl.text = p.label;
      _center = p.latLng;
      _pinLabel = p.label;
    });
    _map.move(p.latLng, 15);
  }

  Future<void> _onMapMoved(LatLng center) async {
    _center = center;
    setState(() => _reversing = true);
    final label = await _routing.reverseGeocode(center.latitude, center.longitude);
    if (!mounted) return;
    setState(() {
      _pinLabel = label;
      _reversing = false;
    });
  }

  void _confirm() {
    final label = _pinLabel?.trim();
    if (label == null || label.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Search or drop a pin to pick a place.')),
      );
      return;
    }
    Navigator.pop(
      context,
      Place(label: label, lat: _center.latitude, lng: _center.longitude),
    );
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
        title: Text(widget.title, style: AppType.h3),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(14, 0, 8, 0),
                    child: Icon(Icons.search_rounded,
                        size: 18, color: AppColors.muted),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: _onQueryChanged,
                      style: AppType.bodyStrong,
                      decoration: InputDecoration(
                        hintText: 'Search an address or place',
                        hintStyle:
                            AppType.body.copyWith(color: AppColors.subtle),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                  if (_searching)
                    const Padding(
                      padding: EdgeInsets.only(right: 14),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _Chip(
                  icon: _locating
                      ? Icons.hourglass_bottom_rounded
                      : Icons.my_location_rounded,
                  label: _locating ? 'Locating…' : 'Current location',
                  onTap: _locating ? null : _useCurrentLocation,
                ),
                if (_home != null) ...[
                  const SizedBox(width: 8),
                  _Chip(
                      icon: Icons.home_rounded,
                      label: 'Home',
                      onTap: () => _useSaved(_home!)),
                ],
                if (_work != null) ...[
                  const SizedBox(width: 8),
                  _Chip(
                      icon: Icons.work_rounded,
                      label: 'Work',
                      onTap: () => _useSaved(_work!)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 14,
                    onPositionChanged: (pos, hasGesture) {
                      if (hasGesture) _center = pos.center;
                    },
                    onMapEvent: (evt) {
                      if (evt is MapEventMoveEnd) _onMapMoved(evt.camera.center);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.rydlnk.app',
                    ),
                  ],
                ),
                // Center pin
                const IgnorePointer(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 36),
                      child: Icon(Icons.location_on_rounded,
                          size: 44, color: AppColors.primary),
                    ),
                  ),
                ),
                // Search results overlay
                if (_results.isNotEmpty)
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 0,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            for (final p in _results)
                              ListTile(
                                dense: true,
                                leading: const Icon(Icons.place_outlined,
                                    size: 18, color: AppColors.primary),
                                title: Text(p.label,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppType.caption
                                        .copyWith(color: AppColors.ink)),
                                onTap: () => _selectResult(p),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
                20, 14, 20, 16 + MediaQuery.of(context).padding.bottom),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.my_location_rounded,
                        size: 15, color: AppColors.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _reversing
                            ? 'Locating…'
                            : (_pinLabel ?? 'Move the map to place the pin'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.caption,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Material(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: _confirm,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      alignment: Alignment.center,
                      child: Text('Use this location',
                          style: AppType.button.copyWith(color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 16,
                  color: enabled ? AppColors.primary : AppColors.muted),
              const SizedBox(width: 6),
              Text(label,
                  style: AppType.captionStrong.copyWith(
                      color: enabled ? AppColors.ink : AppColors.muted,
                      fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
