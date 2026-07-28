import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/driver_repository.dart';
import '../../models/driver_profile.dart';
import '../../state/app_session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/errors.dart';
import '../onboarding_screen.dart';
import 'driver_verification_screen.dart';

class DriverAccountScreen extends StatefulWidget {
  const DriverAccountScreen({super.key});

  @override
  State<DriverAccountScreen> createState() => _DriverAccountScreenState();
}

class _DriverAccountScreenState extends State<DriverAccountScreen> {
  final _repo = DriverRepository();
  late Future<DriverProfile?> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.myDriver();
  }

  void _reload() => setState(() => _future = _repo.myDriver());

  Future<void> _editVehicle(DriverProfile d) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditVehicleSheet(driver: d, repo: _repo),
    );
    if (saved == true) _reload();
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Sign out?', style: AppType.h3),
        content: Text("You'll need to sign in again to keep driving.",
            style: AppType.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: AppType.button.copyWith(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sign out',
                style: AppType.button.copyWith(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final nav = Navigator.of(context);
    await AppSession.signOut();
    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FutureBuilder<DriverProfile?>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary));
            }
            final d = snap.data;
            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text('Account', style: AppType.h1.copyWith(fontSize: 26)),
                const SizedBox(height: 16),
                _Header(driver: d),
                const SizedBox(height: 20),
                _Tile(
                  icon: Icons.directions_car_outlined,
                  iconBg: AppColors.primaryTint,
                  iconColor: AppColors.primary,
                  title: 'Vehicle',
                  subtitle: d?.vehicleLabel ?? 'No vehicle yet',
                  onTap: d == null ? null : () => _editVehicle(d),
                ),
                const SizedBox(height: 10),
                _Tile(
                  icon: d?.verified == true
                      ? Icons.verified_rounded
                      : Icons.upload_file_rounded,
                  iconBg: AppColors.accentBlueTint,
                  iconColor: AppColors.accentBlue,
                  title: 'Verification',
                  subtitle: switch (d?.verificationStatus) {
                    'approved' => 'Verified driver',
                    'pending' => 'Under review',
                    'rejected' => 'Action needed — re-upload',
                    _ => 'Upload documents to get verified',
                  },
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const DriverVerificationScreen()),
                  ).then((_) => _reload()),
                ),
                const SizedBox(height: 10),
                _Tile(
                  icon: Icons.star_rounded,
                  iconBg: AppColors.warningTint,
                  iconColor: AppColors.warning,
                  title: 'Rating',
                  subtitle: (d?.rating ?? 5.0).toStringAsFixed(1),
                  showChevron: false,
                ),
                const SizedBox(height: 24),
                Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: _signOut,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text('Sign out',
                          style:
                              AppType.button.copyWith(color: AppColors.danger)),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({this.driver});
  final DriverProfile? driver;

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
            child: Text(
              AppSession.initials.isEmpty ? 'D' : AppSession.initials,
              style: AppType.h2.copyWith(color: Colors.white, fontSize: 22),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppSession.name.isEmpty ? 'Driver' : AppSession.name,
                    style: AppType.h3,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(AppSession.email, style: AppType.caption),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text('Driver',
                      style: AppType.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.showChevron = true,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: iconBg, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppType.bodyStrong),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: AppType.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (showChevron && onTap != null)
                const Icon(Icons.chevron_right_rounded,
                    size: 20, color: AppColors.subtle),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditVehicleSheet extends StatefulWidget {
  const _EditVehicleSheet({required this.driver, required this.repo});
  final DriverProfile driver;
  final DriverRepository repo;

  @override
  State<_EditVehicleSheet> createState() => _EditVehicleSheetState();
}

class _EditVehicleSheetState extends State<_EditVehicleSheet> {
  late final _vehicleCtrl = TextEditingController(text: widget.driver.vehicle);
  late final _plateCtrl = TextEditingController(text: widget.driver.plate);
  bool _saving = false;

  @override
  void dispose() {
    _vehicleCtrl.dispose();
    _plateCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    HapticFeedback.lightImpact();
    try {
      await widget.repo.updateVehicle(
        vehicle: _vehicleCtrl.text.trim(),
        plate: _plateCtrl.text.trim(),
      );
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
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text('Edit vehicle', style: AppType.h3),
            const SizedBox(height: 16),
            _SheetField(controller: _vehicleCtrl, hint: 'Vehicle'),
            const SizedBox(height: 12),
            _SheetField(controller: _plateCtrl, hint: 'License plate'),
            const SizedBox(height: 20),
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

class _SheetField extends StatelessWidget {
  const _SheetField({required this.controller, required this.hint});
  final TextEditingController controller;
  final String hint;

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
