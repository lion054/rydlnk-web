import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../state/app_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/routes.dart';
import 'root_router.dart';
import 'sign_up_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _obscure = true;
  bool _loading = false;

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      _showError('Enter your email and password to continue.');
      return;
    }

    setState(() => _loading = true);
    HapticFeedback.lightImpact();
    final nav = Navigator.of(context);
    try {
      await AppSession.signIn(email: email, password: password);
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
      _showError('Something went wrong. Check your connection and try again.');
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
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.directions_car_filled_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Welcome back',
                  style: AppType.hero.copyWith(fontSize: 32),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Sign in to continue your journey',
                  style: AppType.body,
                ),
              ),
              const SizedBox(height: 40),
              const _Label('Email address'),
              const SizedBox(height: 8),
              _Field(
                icon: Icons.mail_outline_rounded,
                hint: 'you@example.com',
                controller: _emailCtrl,
                keyboard: TextInputType.emailAddress,
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
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _ForgotPasswordSheet.show(context),
                  child: Text(
                    'Forgot password?',
                    style: AppType.captionStrong
                        .copyWith(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _GradientButton(
                loading: _loading,
                onTap: _handleSignIn,
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account? ",
                        style: AppType.caption.copyWith(fontSize: 14)),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        FadeSlideRoute(child: const SignUpScreen()),
                      ),
                      child: Text(
                        'Sign up',
                        style: AppType.captionStrong.copyWith(
                          color: AppColors.primary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
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
  const _GradientButton({required this.onTap, required this.loading});
  final VoidCallback onTap;
  final bool loading;

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
                        'Signing in…',
                        style: AppType.button
                            .copyWith(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  )
                : Text(
                    'Sign in',
                    style:
                        AppType.button.copyWith(color: Colors.white, fontSize: 16),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ForgotPasswordSheet extends StatefulWidget {
  const _ForgotPasswordSheet();

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ForgotPasswordSheet(),
    );
  }

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  bool _sent = false;
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    setState(() => _sent = true);
    HapticFeedback.lightImpact();
    try {
      await AppSession.sendPasswordReset(email);
    } catch (_) {
      // Intentionally quiet: never reveal whether an email is registered.
    }
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 1400));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Forgot password', style: AppType.hero.copyWith(fontSize: 22)),
          const SizedBox(height: 6),
          Text(
            "Enter your email and we'll send you a reset link.",
            style: AppType.body,
          ),
          const SizedBox(height: 24),
          _Field(
            icon: Icons.mail_outline_rounded,
            hint: 'you@example.com',
            controller: _emailCtrl,
            keyboard: TextInputType.emailAddress,
          ),
          const SizedBox(height: 20),
          _GradientButton(
            loading: false,
            onTap: _sendReset,
          ),
          if (_sent) ...[
            const SizedBox(height: 12),
            Text(
              "We'll send a reset link to your email.",
              textAlign: TextAlign.center,
              style: AppType.caption.copyWith(color: AppColors.primary),
            ),
          ],
        ],
      ),
    );
  }
}
