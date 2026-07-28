import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/rides_repository.dart';
import '../data/routing_service.dart';
import '../state/app_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/errors.dart';
import '../utils/format.dart';
import '../utils/legal.dart';
import '../widgets/rydlnk_logo.dart';
import 'company_onboarding_screen.dart';
import 'legal_viewer_screen.dart';
import 'location_picker_screen.dart';
import 'onboarding_screen.dart';
import 'past_rides_screen.dart';
import 'payment_methods_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    const RydlnkLogo(size: 22),
                    const Spacer(),
                    Material(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => _AppSettingsSheet.show(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(Icons.settings_outlined,
                              size: 20, color: AppColors.body),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              sliver: SliverToBoxAdapter(
                child: _ProfileHeader(
                  onEdit: () => _EditProfileSheet.show(context),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              sliver: SliverToBoxAdapter(
                child: _Section(
                  title: 'Activity',
                  items: [
                    _Item(
                      icon: Icons.history_rounded,
                      label: 'Past Rides',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PastRidesScreen()),
                      ),
                    ),
                    _Item(
                      icon: Icons.bookmark_border_rounded,
                      label: 'My Places',
                      onTap: () => _MyPlacesSheet.show(context),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              sliver: SliverToBoxAdapter(child: _ReferralCard()),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              sliver: SliverToBoxAdapter(
                child: _Section(
                  title: 'Account',
                  items: [
                    _Item(
                      icon: Icons.person_outline_rounded,
                      label: 'Edit Profile',
                      onTap: () => _EditProfileSheet.show(context),
                    ),
                    _Item(
                      icon: Icons.credit_card_rounded,
                      label: 'Payment Methods',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PaymentMethodsScreen()),
                      ),
                    ),
                    _Item(
                      icon: Icons.receipt_long_rounded,
                      label: 'Payment History',
                      onTap: () => _PaymentHistorySheet.show(context),
                    ),
                    _Item(
                      icon: Icons.notifications_none_rounded,
                      label: 'Notifications',
                      onTap: () => _NotificationPrefsSheet.show(context),
                    ),
                    _Item(
                      icon: Icons.eco_rounded,
                      label: 'Savings Stats',
                      onTap: () => _SavingsSheet.show(context),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              sliver: SliverToBoxAdapter(
                child: _Section(
                  title: 'Corporate account',
                  items: [
                    _Item(
                      icon: Icons.business_rounded,
                      label: 'Join a Company',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CompanyOnboardingScreen()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              sliver: SliverToBoxAdapter(
                child: _Section(
                  title: 'Support',
                  items: [
                    _Item(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Contact Support',
                      onTap: () => _SupportSheet.show(context),
                    ),
                    _Item(
                      icon: Icons.logout_rounded,
                      label: 'Sign out',
                      destructive: true,
                      onTap: () => _confirmSignOut(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Sign out?', style: AppType.h3),
        content: Text(
          "You'll need to sign in again to continue using Rydlnk.",
          style: AppType.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: AppType.button.copyWith(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () async {
              final rootNav = Navigator.of(context);
              Navigator.pop(ctx);
              await AppSession.signOut();
              rootNav.pushAndRemoveUntil(
                MaterialPageRoute(
                    builder: (_) => const OnboardingScreen()),
                (_) => false,
              );
            },
            child: Text('Sign out',
                style: AppType.button.copyWith(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Profile header ───────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({this.onEdit});
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: Text(AppSession.initials,
                style: AppType.h2.copyWith(color: Colors.white, fontSize: 22)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppSession.name,
                  style: AppType.h3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  AppSession.phone.isNotEmpty
                      ? AppSession.phone
                      : AppSession.email,
                  style: AppType.caption,
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_rounded,
                          size: 12, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Rider',
                        style: AppType.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (onEdit != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onEdit,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.edit_outlined,
                    size: 16, color: AppColors.body),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────── Referral card ───────────────────────────

class _ReferralCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.card_giftcard_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text('Invite friends',
                  style: AppType.h3.copyWith(color: Colors.white)),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            r'Give friends $5 off their first ride. You earn $5 too when they ride.',
            style: AppType.body.copyWith(
                color: Colors.white.withValues(alpha: 0.85), fontSize: 14),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Text(
                  'TAFAD6D9',
                  style: AppType.mono
                      .copyWith(color: Colors.white, letterSpacing: 2),
                ),
                const Spacer(),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () {
                      Clipboard.setData(
                          const ClipboardData(text: 'TAFAD6D9'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Referral code copied!'),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.ios_share_rounded,
                              size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text('Share',
                              style: AppType.captionStrong.copyWith(
                                  color: AppColors.primary, fontSize: 13)),
                        ],
                      ),
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

// ─────────────────────────── Section + item ───────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.items});
  final String title;
  final List<_Item> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(title.toUpperCase(), style: AppType.overline),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: List.generate(items.length, (i) {
              return Column(
                children: [
                  items[i],
                  if (i < items.length - 1)
                    const Padding(
                      padding: EdgeInsets.only(left: 56),
                      child: Divider(height: 1),
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.label,
    this.destructive = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool destructive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.danger : AppColors.ink;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: destructive
                      ? AppColors.dangerTint
                      : AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: AppType.bodyStrong.copyWith(color: color)),
              ),
              if (!destructive)
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.subtle),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Shared sheet scaffold ───────────────────────────

class _Sheet extends StatelessWidget {
  const _Sheet({required this.title, required this.child});
  final String title;
  final Widget child;

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
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(title, style: AppType.h3),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────── Edit profile sheet ───────────────────────────

class _EditProfileSheet extends StatefulWidget {
  static void show(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom),
          child: const _EditProfileSheet(),
        ),
      );

  const _EditProfileSheet();

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final _name = TextEditingController(text: AppSession.name);
  late final _phone = TextEditingController(text: AppSession.phone);
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final uid = AppSession.client.auth.currentUser?.id;
      if (uid != null) {
        await AppSession.client.from('profiles').update({
          'full_name': _name.text.trim(),
          'phone': _phone.text.trim(),
        }).eq('id', uid);
        await AppSession.loadProfile();
      }
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
    return _Sheet(
      title: 'Edit profile',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel('Full name'),
          const SizedBox(height: 8),
          _SheetField(controller: _name, hint: 'Your name'),
          const SizedBox(height: 16),
          const _FieldLabel('Phone number'),
          const SizedBox(height: 8),
          _SheetField(
              controller: _phone,
              hint: '+263 77 000 0000',
              keyboard: TextInputType.phone),
          const SizedBox(height: 24),
          _PrimarySheetButton(
            label: _saving ? 'Saving…' : 'Save changes',
            onTap: _saving ? () {} : _save,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── My places sheet ───────────────────────────

class _MyPlacesSheet extends StatefulWidget {
  static void show(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const _MyPlacesSheet(),
      );

  const _MyPlacesSheet();

  @override
  State<_MyPlacesSheet> createState() => _MyPlacesSheetState();
}

class _MyPlacesSheetState extends State<_MyPlacesSheet> {
  final _repo = RidesRepository();
  late Future<({String home, String work})> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.myAddresses();
  }

  Future<void> _edit(bool isHome) async {
    final place = await Navigator.push<Place>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            LocationPickerScreen(title: isHome ? 'Set home' : 'Set work'),
      ),
    );
    if (place == null) return;
    await _repo.updateHomeWork(
        home: isHome ? place.label : null, work: isHome ? null : place.label);
    if (!mounted) return;
    setState(() => _future = _repo.myAddresses());
  }

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      title: 'My places',
      child: FutureBuilder<({String home, String work})>(
        future: _future,
        builder: (context, snap) {
          final a = snap.data;
          return Column(
            children: [
              _PlaceTile(
                icon: Icons.home_rounded,
                label: 'Home',
                address: (a == null || a.home == 'Home')
                    ? 'Tap to set'
                    : a.home,
                onTap: () => _edit(true),
              ),
              const SizedBox(height: 10),
              _PlaceTile(
                icon: Icons.work_rounded,
                label: 'Work',
                address: (a == null || a.work == 'Work')
                    ? 'Tap to set'
                    : a.work,
                onTap: () => _edit(false),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile(
      {required this.icon,
      required this.label,
      required this.address,
      this.onTap});
  final IconData icon;
  final String label;
  final String address;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
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
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppType.bodyStrong),
                    const SizedBox(height: 2),
                    Text(address,
                        style: AppType.caption,
                        maxLines: 1,
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
    );
  }
}

// ─────────────────────────── Payment history sheet ───────────────────────────

class _PaymentHistorySheet extends StatelessWidget {
  static void show(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const _PaymentHistorySheet(),
      );

  const _PaymentHistorySheet();

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      title: 'Payment history',
      child: Column(
        children: [
          const SizedBox(height: 8),
          const Icon(Icons.receipt_long_outlined,
              size: 36, color: AppColors.muted),
          const SizedBox(height: 12),
          Text('No payments yet',
              style: AppType.bodyStrong.copyWith(fontSize: 15)),
          const SizedBox(height: 4),
          Text('Your ride charges will appear here.',
              textAlign: TextAlign.center,
              style: AppType.caption.copyWith(color: AppColors.muted)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}


class _NotificationPrefsSheet extends StatefulWidget {
  static void show(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const _NotificationPrefsSheet(),
      );

  const _NotificationPrefsSheet();

  @override
  State<_NotificationPrefsSheet> createState() =>
      _NotificationPrefsSheetState();
}

class _NotificationPrefsSheetState extends State<_NotificationPrefsSheet> {
  final _repo = RidesRepository();

  // key → (label, default)
  static const _defs = {
    'ride_reminders': ('Ride reminders', true),
    'driver_alerts': ('Driver alerts', true),
    'promotions': ('Promotions', false),
    'news': ('News & updates', false),
  };

  Map<String, dynamic> _prefs = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await _repo.notificationPrefs();
    if (!mounted) return;
    setState(() {
      _prefs = {
        for (final e in _defs.entries)
          e.key: saved[e.key] as bool? ?? e.value.$2,
      };
      _loading = false;
    });
  }

  Future<void> _set(String key, bool value) async {
    setState(() => _prefs[key] = value);
    try {
      await _repo.setNotificationPrefs(_prefs);
    } catch (_) {/* keep local state; will retry on next toggle */}
  }

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      title: 'Notifications',
      child: _loading
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary)),
            )
          : Column(
              children: [
                for (final e in _defs.entries) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(e.value.$1, style: AppType.bodyStrong),
                      ),
                      Switch(
                        value: _prefs[e.key] as bool? ?? e.value.$2,
                        onChanged: (v) => _set(e.key, v),
                        activeThumbColor: Colors.white,
                        activeTrackColor: AppColors.primary,
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                ],
                const SizedBox(height: 8),
              ],
            ),
    );
  }
}

// ─────────────────────────── Savings sheet ───────────────────────────

class _SavingsSheet extends StatelessWidget {
  static void show(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const _SavingsSheet(),
      );

  const _SavingsSheet();

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      title: 'Savings stats',
      child: FutureBuilder<({int rides, int savingsCents, int co2Grams})>(
        future: RidesRepository().weeklyStats(),
        builder: (context, snap) {
          final s = snap.data;
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                      child: _StatTile(
                          label: 'Rides this week',
                          value: s == null ? '—' : '${s.rides}')),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _StatTile(
                          label: 'Weekly savings',
                          value: s == null ? '—' : money(s.savingsCents))),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _StatTile(
                          label: 'CO₂ saved',
                          value: s == null
                              ? '—'
                              : '${(s.co2Grams / 1000).toStringAsFixed(1)} kg')),
                  const SizedBox(width: 12),
                  const Expanded(child: SizedBox()),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.eco_rounded,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Shared rides cut cost and CO₂ — the more you pool, the more you save.',
                        style: AppType.caption
                            .copyWith(color: AppColors.primary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style:
                  AppType.h2.copyWith(color: AppColors.primary, fontSize: 22)),
          const SizedBox(height: 2),
          Text(label, style: AppType.caption.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}

// ─────────────────────────── Support sheet ───────────────────────────

class _SupportSheet extends StatelessWidget {
  static void show(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const _SupportSheet(),
      );

  const _SupportSheet();

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      title: 'Contact support',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'We typically respond within 2 hours.',
            style: AppType.body.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          _SupportOption(
            icon: Icons.email_outlined,
            iconBg: AppColors.accentBlueTint,
            iconColor: AppColors.accentBlue,
            title: 'Email us',
            subtitle: 'support@rydlnk.com',
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 10),
          _SupportOption(
            icon: Icons.chat_bubble_outline_rounded,
            iconBg: AppColors.primaryTint,
            iconColor: AppColors.primary,
            title: 'Live chat',
            subtitle: 'Available Mon–Fri, 8am–6pm',
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _SupportOption extends StatelessWidget {
  const _SupportOption({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg, iconColor;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppType.bodyStrong),
                    Text(subtitle, style: AppType.caption),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.subtle),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── App settings sheet ───────────────────────────

class _AppSettingsSheet extends StatelessWidget {
  static void show(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const _AppSettingsSheet(),
      );

  const _AppSettingsSheet();

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      title: 'Settings',
      child: Column(
        children: [
          _SettingsRow(
              icon: Icons.shield_outlined,
              label: 'Privacy Policy',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const LegalViewerScreen(doc: kPrivacy)));
              }),
          const Divider(height: 1),
          _SettingsRow(
              icon: Icons.description_outlined,
              label: 'Terms of Service',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const LegalViewerScreen(doc: kTerms)));
              }),
          const Divider(height: 1),
          const _SettingsRow(
              icon: Icons.info_outline_rounded,
              label: 'App version',
              trailing: '1.0.0',
              onTap: null),
          const SizedBox(height: 20),
          Material(
            color: AppColors.dangerTint,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () async {
                final root = Navigator.of(context, rootNavigator: true);
                final messenger = ScaffoldMessenger.of(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    title: Text('Delete account?', style: AppType.h3),
                    content: Text(
                      'This permanently deletes your account and all your data. '
                      'This cannot be undone.',
                      style: AppType.body,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('Cancel',
                            style: AppType.button
                                .copyWith(color: AppColors.muted)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text('Delete',
                            style: AppType.button
                                .copyWith(color: AppColors.danger)),
                      ),
                    ],
                  ),
                );
                if (confirm != true) return;
                try {
                  await AppSession.deleteAccount();
                  root.pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (_) => const OnboardingScreen()),
                    (_) => false,
                  );
                } catch (e) {
                  messenger.showSnackBar(
                      SnackBar(content: Text(friendlyError(e))));
                }
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.center,
                child: Text('Delete account',
                    style:
                        AppType.button.copyWith(color: AppColors.danger)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow(
      {required this.icon,
      required this.label,
      this.trailing,
      required this.onTap});
  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.body),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: AppType.bodyStrong)),
              if (trailing != null) Text(trailing!, style: AppType.caption),
              if (onTap != null)
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.subtle),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Shared sheet helpers ───────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppType.captionStrong.copyWith(fontSize: 12));
}

class _SheetField extends StatelessWidget {
  const _SheetField(
      {required this.controller, required this.hint, this.keyboard});
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboard;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        style: AppType.bodyStrong,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppType.body.copyWith(color: AppColors.subtle),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}

class _PrimarySheetButton extends StatelessWidget {
  const _PrimarySheetButton(
      {required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          child: Text(label,
              style: AppType.button.copyWith(color: Colors.white)),
        ),
      ),
    );
  }
}
