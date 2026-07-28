import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/driver_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/errors.dart';
import '../../widgets/primary_button.dart';

/// Shown when a driver has no vehicle record yet. Collects vehicle + plate,
/// creates the driver record, then hands back to the shell.
class DriverOnboardingScreen extends StatefulWidget {
  const DriverOnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<DriverOnboardingScreen> createState() => _DriverOnboardingScreenState();
}

class _DriverOnboardingScreenState extends State<DriverOnboardingScreen> {
  final _repo = DriverRepository();
  final _vehicleCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _vehicleCtrl.dispose();
    _plateCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final vehicle = _vehicleCtrl.text.trim();
    final plate = _plateCtrl.text.trim();
    if (vehicle.isEmpty || plate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add your vehicle and plate to continue.')),
      );
      return;
    }
    setState(() => _saving = true);
    HapticFeedback.lightImpact();
    try {
      await _repo.becomeDriver(vehicle: vehicle, plate: plate);
      widget.onDone();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.directions_car_filled_rounded,
                      color: Colors.white, size: 30),
                ),
              ),
              const SizedBox(height: 24),
              Text('Set up driving', style: AppType.hero.copyWith(fontSize: 30)),
              const SizedBox(height: 6),
              Text(
                'Tell us what you drive. Riders see this when you accept a trip.',
                style: AppType.body,
              ),
              const SizedBox(height: 32),
              const _Label('Vehicle'),
              const SizedBox(height: 8),
              _Field(
                controller: _vehicleCtrl,
                icon: Icons.directions_car_outlined,
                hint: 'e.g. Toyota Corolla, silver',
              ),
              const SizedBox(height: 16),
              const _Label('License plate'),
              const SizedBox(height: 8),
              _Field(
                controller: _plateCtrl,
                icon: Icons.badge_outlined,
                hint: 'e.g. ABC 1234',
                caps: true,
              ),
              const Spacer(),
              PrimaryButton(
                label: _saving ? 'Saving…' : 'Start driving',
                icon: Icons.arrow_forward_rounded,
                onPressed: _saving ? null : _save,
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'You can update these anytime in Account.',
                  style: AppType.caption,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(text, style: AppType.captionStrong.copyWith(fontSize: 13)),
      );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.icon,
    required this.hint,
    this.caps = false,
  });

  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final bool caps;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
            child: Icon(icon, size: 18, color: AppColors.muted),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              textCapitalization: caps
                  ? TextCapitalization.characters
                  : TextCapitalization.words,
              style: AppType.bodyStrong,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppType.body.copyWith(color: AppColors.subtle),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
