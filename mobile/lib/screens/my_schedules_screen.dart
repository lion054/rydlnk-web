import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/rides_repository.dart';
import '../models/schedule.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/skeleton.dart';
import '../utils/errors.dart';
import '../widgets/ride_booking_card.dart';

class MySchedulesScreen extends StatefulWidget {
  const MySchedulesScreen({super.key});

  @override
  State<MySchedulesScreen> createState() => _MySchedulesScreenState();
}

class _MySchedulesScreenState extends State<MySchedulesScreen> {
  final _repo = RidesRepository();
  late Future<List<Schedule>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.mySchedules();
  }

  void _reload() {
    setState(() => _future = _repo.mySchedules());
  }

  Future<void> _toggle(Schedule s) async {
    HapticFeedback.lightImpact();
    try {
      await _repo.setScheduleStatus(s.id, s.isActive ? 'paused' : 'active');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
    _reload();
  }

  Future<void> _cancel(Schedule s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Cancel schedule?', style: AppType.h3),
        content: Text(
          'This cancels "${s.displayTitle}" and its upcoming rides. Co-riders on shared trips keep their seats.',
          style: AppType.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep it',
                style: AppType.button.copyWith(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Cancel schedule',
                style: AppType.button.copyWith(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.cancelSchedule(s.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
    _reload();
  }

  void _openWizard() {
    RideBookingCard.show(context).then((_) => _reload());
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
              child:
                  Text('My schedules', style: AppType.h1.copyWith(fontSize: 26)),
            ),
            Expanded(
              child: FutureBuilder<List<Schedule>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const SkeletonList(count: 3, height: 150);
                  }
                  if (snap.hasError) {
                    return _ErrorState(
                        message: '${snap.error}', onRetry: _reload);
                  }
                  final items = snap.data ?? const [];
                  if (items.isEmpty) {
                    return _EmptySchedules(onNew: _openWizard);
                  }
                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async {
                      _reload();
                      await _future;
                    },
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics()),
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final s = items[i];
                        return _ScheduleCard(
                          title: s.displayTitle,
                          days: s.daysLabel,
                          window: s.windowLabel,
                          route: s.routeLabel,
                          driver: 'Pending match',
                          weekly: s.weeklyLabel,
                          active: s.isActive,
                          onToggle: () => _toggle(s),
                          onEdit: () => _showEdit(context, s),
                          onCancel: () => _cancel(s),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openWizard,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: Text('New schedule',
            style: AppType.button.copyWith(color: Colors.white)),
        elevation: 4,
      ),
    );
  }

  Future<void> _showEdit(BuildContext context, Schedule s) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditScheduleSheet(schedule: s),
    );
    if (saved == true) _reload();
  }

}

// ─────────────────────────── Schedule card ───────────────────────────

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.title,
    required this.days,
    required this.window,
    required this.route,
    required this.driver,
    required this.weekly,
    required this.active,
    required this.onToggle,
    required this.onEdit,
    required this.onCancel,
  });

  final String title, days, window, route, driver, weekly;
  final bool active;
  final VoidCallback onToggle, onEdit, onCancel;

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
              Expanded(child: Text(title, style: AppType.h3)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: active ? AppColors.primaryTint : AppColors.background,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: active ? AppColors.primary : AppColors.muted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      active ? 'Active' : 'Paused',
                      style: AppType.caption.copyWith(
                        color: active ? AppColors.primary : AppColors.muted,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: 'Cancel schedule',
                child: Semantics(
                  button: true,
                  label: 'Cancel schedule',
                  child: GestureDetector(
                    onTap: onCancel,
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.fromLTRB(12, 8, 4, 8),
                      child: Icon(Icons.close_rounded,
                          size: 18, color: AppColors.muted),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MetaRow(icon: Icons.calendar_today_rounded, text: days),
          const SizedBox(height: 4),
          _MetaRow(icon: Icons.schedule_rounded, text: window),
          const SizedBox(height: 4),
          _MetaRow(icon: Icons.adjust_rounded, text: route),
          const SizedBox(height: 4),
          _MetaRow(icon: Icons.person_outline_rounded, text: driver),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(weekly,
                  style: AppType.h2
                      .copyWith(color: AppColors.primary, fontSize: 20)),
              Text(' / week',
                  style: AppType.caption.copyWith(fontSize: 13)),
              const Spacer(),
              _SmallAction(label: 'Edit', onTap: onEdit),
              const SizedBox(width: 8),
              _SmallAction(
                  label: active ? 'Pause' : 'Resume',
                  primary: true,
                  onTap: onToggle),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style:
                  AppType.body.copyWith(fontSize: 13, color: AppColors.body)),
        ),
      ],
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Material(
        color: primary ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: primary ? null : Border.all(color: AppColors.border),
            ),
            child: Text(
              label,
              style: AppType.captionStrong.copyWith(
                color: primary ? Colors.white : AppColors.body,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Edit sheet ───────────────────────────

class _EditScheduleSheet extends StatefulWidget {
  const _EditScheduleSheet({required this.schedule});
  final Schedule schedule;

  @override
  State<_EditScheduleSheet> createState() => _EditScheduleSheetState();
}

class _EditScheduleSheetState extends State<_EditScheduleSheet> {
  late final _ctrl = TextEditingController(text: widget.schedule.displayTitle);
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await RidesRepository()
          .renameSchedule(widget.schedule.id, _ctrl.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
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
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Rename schedule', style: AppType.h3),
            const SizedBox(height: 6),
            Text(
              'Days and times are set when you book. To change them, cancel and rebook.',
              style: AppType.caption,
            ),
            const SizedBox(height: 16),
            Text('Schedule name',
                style: AppType.captionStrong.copyWith(fontSize: 12)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _ctrl,
                style: AppType.bodyStrong,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Material(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: _saving ? null : _save,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  alignment: Alignment.center,
                  child: Text(_saving ? 'Saving…' : 'Save changes',
                      style: AppType.button.copyWith(color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 40, color: AppColors.muted),
            const SizedBox(height: 12),
            Text("Couldn't load your schedules",
                style: AppType.h3.copyWith(fontSize: 17)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: AppType.caption.copyWith(color: AppColors.muted)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: Text('Try again',
                  style: AppType.button.copyWith(color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Empty state ───────────────────────────

class _EmptySchedules extends StatelessWidget {
  const _EmptySchedules({required this.onNew});
  final VoidCallback onNew;

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
                color: AppColors.primaryTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.event_note_rounded,
                  size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text('No schedules yet',
                style: AppType.h3.copyWith(fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              'Set up your first recurring commute to get started.',
              textAlign: TextAlign.center,
              style: AppType.body.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 24),
            Material(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: onNew,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  child: Text('New schedule',
                      style: AppType.button
                          .copyWith(color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
