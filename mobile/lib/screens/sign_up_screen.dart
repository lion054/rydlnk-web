import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/legal_repository.dart';
import '../state/app_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/legal.dart';
import '../widgets/wizard_stepper.dart';
import 'legal_viewer_screen.dart';
import 'root_router.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  int _step = 0;
  bool _loading = false;
  bool _obscure = true;

  bool _asDriver = false;
  bool _agreed = false;

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _homeCtrl = TextEditingController();
  final _workCtrl = TextEditingController();
  final _vehicleCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _homeCtrl.dispose();
    _workCtrl.dispose();
    _vehicleCtrl.dispose();
    _plateCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_step < 2) {
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showError('Please fill in your name, email and password.');
      setState(() => _step = 0);
      return;
    }
    if (password.length < 6) {
      _showError('Password must be at least 6 characters.');
      setState(() => _step = 1);
      return;
    }

    if (_asDriver &&
        (_vehicleCtrl.text.trim().isEmpty || _plateCtrl.text.trim().isEmpty)) {
      _showError('Add your vehicle and plate to finish.');
      setState(() => _step = 2);
      return;
    }

    if (!_agreed) {
      _showError('Please accept the Terms and Privacy Policy to continue.');
      setState(() => _step = 2);
      return;
    }

    setState(() => _loading = true);
    HapticFeedback.mediumImpact();
    final nav = Navigator.of(context);
    try {
      await AppSession.signUp(
        fullName: name,
        email: email,
        password: password,
        phone: _phoneCtrl.text.trim(),
        homeAddress: _asDriver ? null : _homeCtrl.text.trim(),
        workAddress: _asDriver ? null : _workCtrl.text.trim(),
        asDriver: _asDriver,
        vehicle: _asDriver ? _vehicleCtrl.text.trim() : null,
        plate: _asDriver ? _plateCtrl.text.trim() : null,
      );
      // Record consent (fire-and-forget; failure shouldn't block sign-up).
      LegalRepository().acceptAll([
        kTerms,
        kPrivacy,
        _asDriver ? kDriverAgreement : kRiderAgreement,
      ]);
      if (!mounted) return;
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => rootForRole()),
        (_) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Could not create your account. Please try again.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (_step > 0) {
              setState(() => _step--);
            } else {
              Navigator.maybePop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              WizardStepper(total: 3, current: _step),
              const SizedBox(height: 24),
              if (_step == 0) ...[
                _RoleToggle(
                  asDriver: _asDriver,
                  onChanged: (v) => setState(() => _asDriver = v),
                ),
                const SizedBox(height: 20),
              ],
              Text(
                _stepTitle(_step),
                style: AppType.hero.copyWith(fontSize: 28),
              ),
              const SizedBox(height: 6),
              Text(_stepSubtitle(_step), style: AppType.body),
              const SizedBox(height: 32),
              ..._stepFields(_step),
              const Spacer(),
              if (_step == 2) ...[
                _ConsentRow(
                  agreed: _agreed,
                  onChanged: (v) => setState(() => _agreed = v),
                  onView: (doc) => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => LegalViewerScreen(doc: doc)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _GradientButton(
                label: _step < 2 ? 'Continue' : 'Create account',
                loadingLabel: 'Creating account…',
                loading: _loading,
                onTap: _next,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _stepTitle(int step) {
    return switch (step) {
      0 => 'Your details',
      1 => 'Secure your account',
      _ => _asDriver ? 'Your vehicle' : 'Your commute',
    };
  }

  String _stepSubtitle(int step) {
    return switch (step) {
      0 => 'Tell us a little about yourself',
      1 => 'Keep your account safe',
      _ => _asDriver
          ? 'Riders see this when you accept a trip'
          : 'We\'ll use these to pre-fill your routes',
    };
  }

  List<Widget> _stepFields(int step) {
    return switch (step) {
      0 => [
          const _Label('Full name'),
          const SizedBox(height: 8),
          _Field(
            icon: Icons.person_outline_rounded,
            hint: 'Jane Doe',
            controller: _nameCtrl,
            keyboard: TextInputType.name,
          ),
          const SizedBox(height: 16),
          const _Label('Email address'),
          const SizedBox(height: 8),
          _Field(
            icon: Icons.mail_outline_rounded,
            hint: 'you@example.com',
            controller: _emailCtrl,
            keyboard: TextInputType.emailAddress,
          ),
        ],
      1 => [
          const _Label('Phone number'),
          const SizedBox(height: 8),
          _Field(
            icon: Icons.phone_outlined,
            hint: '+263 77 123 4567',
            controller: _phoneCtrl,
            keyboard: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          const _Label('Password'),
          const SizedBox(height: 8),
          _Field(
            icon: Icons.lock_outline_rounded,
            hint: '••••••••',
            controller: _passCtrl,
            obscure: _obscure,
            trailing: IconButton(
              icon: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
                color: AppColors.muted,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ],
      _ => _asDriver
          ? [
              const _Label('Vehicle'),
              const SizedBox(height: 8),
              _Field(
                icon: Icons.directions_car_outlined,
                hint: 'e.g. Toyota Corolla, silver',
                controller: _vehicleCtrl,
              ),
              const SizedBox(height: 16),
              const _Label('License plate'),
              const SizedBox(height: 8),
              _Field(
                icon: Icons.badge_outlined,
                hint: 'e.g. ABC 1234',
                controller: _plateCtrl,
              ),
            ]
          : [
              const _Label('Home address'),
              const SizedBox(height: 8),
              _Field(
                icon: Icons.home_outlined,
                hint: 'Avondale, Harare',
                controller: _homeCtrl,
              ),
              const SizedBox(height: 16),
              const _Label('Work address'),
              const SizedBox(height: 8),
              _Field(
                icon: Icons.work_outline_rounded,
                hint: 'Harare CBD',
                controller: _workCtrl,
              ),
            ],
    };
  }
}

// ─────────────────────────── Role toggle ───────────────────────────

class _RoleToggle extends StatelessWidget {
  const _RoleToggle({required this.asDriver, required this.onChanged});
  final bool asDriver;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _RoleTab(
            icon: Icons.person_rounded,
            label: 'Ride',
            selected: !asDriver,
            onTap: () => onChanged(false),
          ),
          _RoleTab(
            icon: Icons.directions_car_rounded,
            label: 'Drive',
            selected: asDriver,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _RoleTab extends StatelessWidget {
  const _RoleTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? AppColors.primary : AppColors.muted),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppType.button.copyWith(
                  fontSize: 14,
                  color: selected ? AppColors.primary : AppColors.muted,
                ),
              ),
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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(text, style: AppType.captionStrong.copyWith(fontSize: 13)),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.icon,
    required this.hint,
    this.controller,
    this.obscure = false,
    this.trailing,
    this.keyboard,
  });

  final IconData icon;
  final String hint;
  final TextEditingController? controller;
  final bool obscure;
  final Widget? trailing;
  final TextInputType? keyboard;

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
              obscureText: obscure,
              keyboardType: keyboard,
              style: AppType.bodyStrong,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppType.body.copyWith(color: AppColors.subtle),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.loadingLabel,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final String loadingLabel;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [AppColors.primaryDark, AppColors.primary],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            alignment: Alignment.center,
            child: loading
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        loadingLabel,
                        style: AppType.button
                            .copyWith(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  )
                : Text(
                    label,
                    style: AppType.button
                        .copyWith(color: Colors.white, fontSize: 16),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.agreed,
    required this.onChanged,
    required this.onView,
  });

  final bool agreed;
  final ValueChanged<bool> onChanged;
  final ValueChanged<LegalDoc> onView;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: Checkbox(
            value: agreed,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: AppColors.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('I agree to the ', style: AppType.caption),
              GestureDetector(
                onTap: () => onView(kTerms),
                child: Text('Terms',
                    style: AppType.captionStrong
                        .copyWith(color: AppColors.primary)),
              ),
              Text(' and ', style: AppType.caption),
              GestureDetector(
                onTap: () => onView(kPrivacy),
                child: Text('Privacy Policy',
                    style: AppType.captionStrong
                        .copyWith(color: AppColors.primary)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
