import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../data/rides_repository.dart';
import '../data/routing_service.dart';
import '../screens/booking_confirmed_screen.dart';
import '../screens/location_picker_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/errors.dart';
import '../utils/format.dart';
import 'day_selector.dart';
import 'primary_button.dart';

enum _BookingPhase { form, searching }

class RideBookingCard extends StatefulWidget {
  const RideBookingCard({
    super.key,
    required this.onDriverSelected,
    this.onClose,
  });

  final VoidCallback onDriverSelected;
  final VoidCallback? onClose;

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => RideBookingCard(
        onDriverSelected: () {
          Navigator.pop(ctx);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const BookingConfirmedScreen(),
            ),
          );
        },
        onClose: () => Navigator.pop(ctx),
      ),
    );
  }

  @override
  State<RideBookingCard> createState() => _RideBookingCardState();
}

class _RideBookingCardState extends State<RideBookingCard> {
  _BookingPhase _phase = _BookingPhase.form;

  String pickup = '';
  String dropoff = '';
  TimeOfDay pickupAfter = const TimeOfDay(hour: 8, minute: 30);
  TimeOfDay arriveBy = const TimeOfDay(hour: 9, minute: 0);

  bool returnRide = false;
  bool recurring = true;
  bool autoReschedule = true;

  Set<int> days = {1, 2, 3, 4, 5};
  late DateTime start;
  late DateTime end;

  FareQuote? _quote;
  bool _quoting = true;
  LatLng? _fromCoord;
  LatLng? _toCoord;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    start = DateTime(now.year, now.month, now.day);
    end = start.add(const Duration(days: 21));
    _prefillFromSavedPlaces();
  }

  /// Prefill from THIS user's saved Home/Work (not a forced default). New users
  /// with nothing saved start blank and must pick their own locations.
  Future<void> _prefillFromSavedPlaces() async {
    final a = await RidesRepository().myAddresses();
    if (!mounted) return;
    setState(() {
      if (a.home != 'Home') pickup = a.home;
      if (a.work != 'Work') dropoff = a.work;
    });
    if (pickup.isNotEmpty && dropoff.isNotEmpty) {
      _fetchQuote();
    } else {
      setState(() => _quoting = false);
    }
  }

  bool get _canBook => pickup.isNotEmpty && dropoff.isNotEmpty;

  Future<void> _fetchQuote() async {
    if (pickup.isEmpty || dropoff.isEmpty) return;
    setState(() => _quoting = true);
    final routing = RoutingService();
    // Ensure we have coordinates (from the picker, or by geocoding the labels)
    // so bookings can pool by corridor, not just exact address.
    _fromCoord ??= await routing.geocode(pickup);
    _toCoord ??= await routing.geocode(dropoff);
    final q = (_fromCoord != null && _toCoord != null)
        ? await routing.quoteBetween(_fromCoord!, _toCoord!)
        : null;
    if (!mounted) return;
    setState(() {
      _quote = q;
      _quoting = false;
    });
  }

  Future<void> _pickLocation({required bool isPickup}) async {
    final result = await Navigator.push<Place>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          title: isPickup ? 'Set pickup' : 'Set drop-off',
          initial: isPickup ? _fromCoord : _toCoord,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (isPickup) {
        pickup = result.label;
        _fromCoord = result.latLng;
      } else {
        dropoff = result.label;
        _toCoord = result.latLng;
      }
    });
    _fetchQuote();
  }

  int get rideCount {
    if (!recurring) return returnRide ? 2 : 1;
    final dayCount = end.difference(start).inDays + 1;
    var count = 0;
    for (var i = 0; i < dayCount; i++) {
      final d = start.add(Duration(days: i));
      final mappedDay = d.weekday == 7 ? 0 : d.weekday;
      if (days.contains(mappedDay)) count++;
    }
    return returnRide ? count * 2 : count;
  }

  Future<void> _startSearch() async {
    setState(() => _phase = _BookingPhase.searching);
    HapticFeedback.lightImpact();

    // Persist the booking as a real schedule (+ its rides) before matching.
    try {
      await RidesRepository().createSchedule(
        title: 'Commute',
        pickup: pickup,
        dropoff: dropoff,
        pickupAfter: timeToDb(pickupAfter),
        arriveBy: timeToDb(arriveBy),
        days: recurring ? (days.toList()..sort()) : const [],
        start: start,
        end: recurring ? end : null,
        returnRide: returnRide,
        recurring: recurring,
        autoReschedule: recurring && autoReschedule,
        priceCents: _quote?.fareCents ?? 817,
        pickupLat: _fromCoord?.latitude,
        pickupLng: _fromCoord?.longitude,
        dropoffLat: _toCoord?.latitude,
        dropoffLng: _toCoord?.longitude,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _phase = _BookingPhase.form);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
      return;
    }

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    // Booking is saved; a driver claims the trip later. Go straight to
    // confirmation — riders don't pick drivers in this model.
    widget.onDriverSelected();
  }

  @override
  Widget build(BuildContext context) {
    final headerTitle = switch (_phase) {
      _BookingPhase.form => 'Find a ride',
      _BookingPhase.searching => 'Booking your ride…',
    };

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DragHandle(),
          _SheetHeader(
            title: headerTitle,
            onClose: widget.onClose ?? () => Navigator.pop(context),
          ),
          Flexible(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: anim,
                    curve: Curves.easeOutCubic,
                  )),
                  child: child,
                ),
              ),
              child: _buildPhaseBody(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseBody(BuildContext context) {
    if (_phase == _BookingPhase.searching) {
      return const _SearchingOverlay(key: ValueKey('searching'));
    }
    return SingleChildScrollView(
      key: const ValueKey('form'),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LocationBlock(
            pickup: pickup,
            dropoff: dropoff,
            onPickupTap: () => _pickLocation(isPickup: true),
            onDropoffTap: () => _pickLocation(isPickup: false),
          ),
          const SizedBox(height: 22),
          Text('PICKUP WINDOW', style: AppType.overline),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _TimeChip(
                  label: 'After',
                  icon: Icons.schedule_rounded,
                  iconColor: AppColors.primary,
                  time: pickupAfter,
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: pickupAfter,
                    );
                    if (t != null) setState(() => pickupAfter = t);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TimeChip(
                  label: 'Arrive by',
                  icon: Icons.flag_rounded,
                  iconColor: AppColors.markAccent,
                  time: arriveBy,
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: arriveBy,
                    );
                    if (t != null) setState(() => arriveBy = t);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _StatsStrip(
            duration: _quoting ? '…' : (_quote?.etaLabel ?? '—'),
            distance: _quoting ? '…' : (_quote?.distanceLabel ?? '—'),
            price: _quoting
                ? '…'
                : (_quote != null ? '~${_quote!.fareLabel}' : r'~$8.00'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.groups_rounded,
                  size: 14, color: AppColors.accentPurple),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Shared ride — you split the fare with co-riders, so it drops as others join.',
                  style: AppType.caption.copyWith(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _ToggleRow(
                  icon: Icons.compare_arrows_rounded,
                  iconColor: AppColors.accentBlue,
                  iconBg: AppColors.accentBlueTint,
                  label: 'Return ride',
                  value: returnRide,
                  onChanged: (v) => setState(() => returnRide = v),
                ),
                const Divider(height: 1, color: AppColors.border),
                _ToggleRow(
                  icon: Icons.refresh_rounded,
                  iconColor: AppColors.primary,
                  iconBg: AppColors.primaryTint,
                  label: 'Recurring',
                  value: recurring,
                  onChanged: (v) => setState(() => recurring = v),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: recurring
                      ? Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                              child: Column(
                                children: [
                                  DaySelector(
                                    selected: days,
                                    onChanged: (s) => setState(() => days = s),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _DateChip(
                                          label: 'Start',
                                          date: start,
                                          onTap: () async {
                                            final d = await showDatePicker(
                                              context: context,
                                              initialDate: start,
                                              firstDate: DateTime(2024),
                                              lastDate: DateTime(2030),
                                            );
                                            if (d != null) setState(() => start = d);
                                          },
                                        ),
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 8),
                                        child: Icon(Icons.arrow_forward_rounded,
                                            size: 16, color: AppColors.muted),
                                      ),
                                      Expanded(
                                        child: _DateChip(
                                          label: 'End',
                                          date: end,
                                          onTap: () async {
                                            final d = await showDatePicker(
                                              context: context,
                                              initialDate: end,
                                              firstDate: start,
                                              lastDate: DateTime(2030),
                                            );
                                            if (d != null) setState(() => end = d);
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: AppColors.border),
                            _ToggleRow(
                              icon: Icons.autorenew_rounded,
                              iconColor: AppColors.accentPurple,
                              iconBg: AppColors.accentPurpleTint,
                              label: 'Auto-reschedule',
                              description: 'Keeps rides rolling 3 weeks ahead.',
                              value: autoReschedule,
                              onChanged: (v) => setState(() => autoReschedule = v),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: !_canBook
                ? 'Set pickup & drop-off'
                : (rideCount == 1 ? 'Book ride' : 'Book $rideCount rides'),
            icon: Icons.arrow_forward_rounded,
            onPressed: _canBook ? _startSearch : null,
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ─────────────────────────── Sheet chrome ───────────────────────────

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.onClose, this.title = 'Find a ride'});
  final VoidCallback onClose;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 16, 16),
      child: Row(
        children: [
          Text(title, style: AppType.h2),
          const Spacer(),
          GestureDetector(
            onTap: onClose,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.close_rounded, size: 18, color: AppColors.body),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Location block ───────────────────────────

class _LocationBlock extends StatelessWidget {
  const _LocationBlock({
    required this.pickup,
    required this.dropoff,
    required this.onPickupTap,
    required this.onDropoffTap,
  });

  final String pickup;
  final String dropoff;
  final VoidCallback onPickupTap;
  final VoidCallback onDropoffTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 21,
            top: 0,
            bottom: 0,
            child: Column(
              children: [
                const SizedBox(height: 30),
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: CustomPaint(
                    painter: _DashedLinePainter(),
                    size: const Size(1, double.infinity),
                  ),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
          Column(
            children: [
              InkWell(
                onTap: onPickupTap,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(46, 14, 14, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FROM',
                              style: AppType.overline.copyWith(
                                  fontSize: 10, letterSpacing: 0.8),
                            ),
                            const SizedBox(height: 3),
                            Text(pickup.isEmpty ? 'Set pickup' : pickup,
                                style: pickup.isEmpty
                                    ? AppType.bodyStrong
                                        .copyWith(color: AppColors.subtle)
                                    : AppType.bodyStrong,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          size: 18, color: AppColors.subtle),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, indent: 46, color: AppColors.border),
              InkWell(
                onTap: onDropoffTap,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(46, 14, 14, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TO',
                              style: AppType.overline.copyWith(
                                  fontSize: 10, letterSpacing: 0.8),
                            ),
                            const SizedBox(height: 3),
                            Text(dropoff.isEmpty ? 'Set drop-off' : dropoff,
                                style: dropoff.isEmpty
                                    ? AppType.bodyStrong
                                        .copyWith(color: AppColors.subtle)
                                    : AppType.bodyStrong,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          size: 18, color: AppColors.subtle),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const dash = 4.0;
    const gap = 4.0;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, (y + dash).clamp(0, size.height)),
        paint,
      );
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter _) => false;
}

// ─────────────────────────── Time & date chips ───────────────────────────

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.time,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final TimeOfDay time;
  final VoidCallback onTap;

  String _fmt(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.elevatedSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: AppType.caption.copyWith(fontSize: 11)),
                const SizedBox(height: 2),
                Text(_fmt(time),
                    style: AppType.bodyStrong.copyWith(fontSize: 15)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_rounded,
                size: 13, color: AppColors.primary),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppType.caption.copyWith(fontSize: 10)),
                Text(
                  '${_months[date.month - 1]} ${date.day}',
                  style: AppType.bodyStrong.copyWith(fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Stats strip ───────────────────────────

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({
    required this.duration,
    required this.distance,
    required this.price,
  });

  final String duration;
  final String distance;
  final String price;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(icon: Icons.schedule_rounded, label: duration),
          Container(width: 1, height: 18,
              color: AppColors.primary.withValues(alpha: 0.2)),
          _Stat(icon: Icons.straighten_rounded, label: distance),
          Container(width: 1, height: 18,
              color: AppColors.primary.withValues(alpha: 0.2)),
          _Stat(icon: Icons.payments_rounded, label: price),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppType.captionStrong.copyWith(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── Option rows ───────────────────────────

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    required this.onChanged,
    this.description,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: value ? iconBg : AppColors.elevatedSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18,
                color: value ? iconColor : AppColors.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppType.bodyStrong),
                if (description != null) ...[
                  const SizedBox(height: 1),
                  Text(description!, style: AppType.caption),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primaryTint,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Searching overlay ───────────────────────────

class _SearchingOverlay extends StatefulWidget {
  const _SearchingOverlay({super.key});

  @override
  State<_SearchingOverlay> createState() => _SearchingOverlayState();
}

class _SearchingOverlayState extends State<_SearchingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dots;

  @override
  void initState() {
    super.initState();
    _dots = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.primaryTint,
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text('Saving your rides',
                style: AppType.h3.copyWith(fontSize: 18)),
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: _dots,
              builder: (_, __) {
                final count = (_dots.value * 4).floor() % 4;
                return Text(
                  'Setting up your schedule${'.' * count}',
                  style: AppType.body.copyWith(color: AppColors.muted),
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
