import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/errors.dart';
import 'nav_shell.dart';

// ─────────────────────────── Entry point ───────────────────────────

class CompanyOnboardingScreen extends StatefulWidget {
  const CompanyOnboardingScreen({super.key});

  @override
  State<CompanyOnboardingScreen> createState() =>
      _CompanyOnboardingScreenState();
}

class _CompanyOnboardingScreenState extends State<CompanyOnboardingScreen> {
  int _step = 0;
  bool _forward = true;
  bool _loading = false;

  // Step 0 — Company
  final _companyCtrl = TextEditingController();
  String _industry = '';
  String _teamSize = '';

  // Step 1 — Admin
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();

  // Step 2 — Plan
  String _plan = 'growth';

  @override
  void dispose() {
    for (final c in [
      _companyCtrl,
      _nameCtrl,
      _emailCtrl,
      _phoneCtrl,
      _titleCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _canContinue {
    switch (_step) {
      case 0:
        return _companyCtrl.text.trim().isNotEmpty &&
            _industry.isNotEmpty &&
            _teamSize.isNotEmpty;
      case 1:
        return _nameCtrl.text.trim().isNotEmpty &&
            _emailCtrl.text.trim().isNotEmpty;
      default:
        return true;
    }
  }

  void _advance() {
    if (_step < 3) {
      setState(() {
        _forward = true;
        _step++;
      });
    } else {
      _create();
    }
  }

  void _retreat() {
    if (_step > 0) {
      setState(() {
        _forward = false;
        _step--;
      });
    } else {
      Navigator.maybePop(context);
    }
  }

  Future<void> _create() async {
    setState(() => _loading = true);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final uid = AppSession.client.auth.currentUser?.id;
      if (uid != null) {
        // Migration 013 made company_members authoritative and blocked direct
        // writes to profiles.company_id — the old insert-then-update pair now
        // throws. create_company() does both, makes the caller owner, and seeds
        // the default policy, benefit settings and top-up rule in one
        // transaction. It also persists the fields this screen used to discard.
        final companyId = await AppSession.client.rpc(
          'create_company',
          params: {
            'p_name': _companyCtrl.text.trim(),
            'p_legal_name': _companyCtrl.text.trim(),
            'p_industry': _industry,
            'p_size_band': _teamSize,
            'p_billing_email': _emailCtrl.text.trim().isEmpty
                ? null
                : _emailCtrl.text.trim(),
            'p_join_mode': 'invite_only',
          },
        );

        if (_titleCtrl.text.trim().isNotEmpty ||
            _phoneCtrl.text.trim().isNotEmpty) {
          await AppSession.client.from('company_members').update({
            if (_titleCtrl.text.trim().isNotEmpty)
              'job_title': _titleCtrl.text.trim(),
          }).match({'company_id': companyId, 'user_id': uid});
        }

        if (_phoneCtrl.text.trim().isNotEmpty ||
            _nameCtrl.text.trim().isNotEmpty) {
          await AppSession.client.from('profiles').update({
            if (_nameCtrl.text.trim().isNotEmpty)
              'full_name': _nameCtrl.text.trim(),
            if (_phoneCtrl.text.trim().isNotEmpty)
              'phone': _phoneCtrl.text.trim(),
          }).eq('id', uid);
        }
      }
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const NavShell()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  static const _titles = [
    'Company details',
    'Admin contact',
    'Choose a plan',
    'Review & confirm',
  ];

  static const _subtitles = [
    'Tell us about your organisation',
    'Who will manage the account?',
    'Pick the right fit for your team',
    'Everything look right?',
  ];

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _BizHeader(
                title: _titles[_step],
                subtitle: _subtitles[_step],
                onBack: _retreat,
              ),
              _StepRail(step: _step),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: CurvedAnimation(
                        parent: anim, curve: Curves.easeOut),
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: _forward
                            ? const Offset(0.06, 0)
                            : const Offset(-0.06, 0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                          parent: anim, curve: Curves.easeOutCubic)),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: _buildStep(),
                    ),
                  ),
                ),
              ),
              _NavFooter(
                step: _step,
                enabled: _canContinue,
                loading: _loading,
                onBack: _retreat,
                onNext: _advance,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _CompanyStep(
          ctrl: _companyCtrl,
          industry: _industry,
          teamSize: _teamSize,
          onIndustry: (v) => setState(() => _industry = v),
          onTeamSize: (v) => setState(() => _teamSize = v),
          onChanged: () => setState(() {}),
        );
      case 1:
        return _AdminStep(
          nameCtrl: _nameCtrl,
          emailCtrl: _emailCtrl,
          phoneCtrl: _phoneCtrl,
          titleCtrl: _titleCtrl,
          onChanged: () => setState(() {}),
        );
      case 2:
        return _PlanStep(
          selected: _plan,
          onSelect: (v) => setState(() => _plan = v),
        );
      case 3:
        return _ReviewStep(
          company: _companyCtrl.text.trim(),
          industry: _industry,
          teamSize: _teamSize,
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          title: _titleCtrl.text.trim(),
          plan: _plan,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─────────────────────────── Header ───────────────────────────

class _BizHeader extends StatelessWidget {
  const _BizHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            color: AppColors.body,
            onPressed: onBack,
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.business_rounded,
                            size: 11, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          'FOR BUSINESS',
                          style: AppType.overline.copyWith(
                            color: AppColors.primary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(title, style: AppType.h2),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppType.caption),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Step progress rail ───────────────────────────

class _StepRail extends StatelessWidget {
  const _StepRail({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: List.generate(4, (i) {
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
              height: 3,
              decoration: BoxDecoration(
                color: i <= step ? AppColors.primary : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────── Step 0: Company details ───────────────────────────

class _CompanyStep extends StatelessWidget {
  const _CompanyStep({
    required this.ctrl,
    required this.industry,
    required this.teamSize,
    required this.onIndustry,
    required this.onTeamSize,
    required this.onChanged,
  });

  final TextEditingController ctrl;
  final String industry;
  final String teamSize;
  final ValueChanged<String> onIndustry;
  final ValueChanged<String> onTeamSize;
  final VoidCallback onChanged;

  static const _industries = [
    'Technology',
    'Healthcare',
    'Finance',
    'Retail',
    'Logistics',
    'Education',
    'Other',
  ];
  static const _sizes = ['2–10', '11–50', '51–200', '200+'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Company name'),
        const SizedBox(height: 8),
        _BizField(
          ctrl: ctrl,
          icon: Icons.business_rounded,
          hint: 'Your company name',
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 24),
        const _FieldLabel('Industry'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _industries
              .map((ind) => _SelectChip(
                    label: ind,
                    selected: industry == ind,
                    onTap: () => onIndustry(ind),
                  ))
              .toList(),
        ),
        const SizedBox(height: 24),
        const _FieldLabel('Team size'),
        const SizedBox(height: 10),
        Row(
          children: List.generate(_sizes.length, (i) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < _sizes.length - 1 ? 8 : 0),
                child: _SelectChip(
                  label: _sizes[i],
                  selected: teamSize == _sizes[i],
                  onTap: () => onTeamSize(_sizes[i]),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ─────────────────────────── Step 1: Admin contact ───────────────────────────

class _AdminStep extends StatelessWidget {
  const _AdminStep({
    required this.nameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.titleCtrl,
    required this.onChanged,
  });

  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController titleCtrl;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Full name'),
        const SizedBox(height: 8),
        _BizField(
          ctrl: nameCtrl,
          icon: Icons.person_outline_rounded,
          hint: 'Jane Smith',
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 16),
        const _FieldLabel('Work email'),
        const SizedBox(height: 8),
        _BizField(
          ctrl: emailCtrl,
          icon: Icons.mail_outline_rounded,
          hint: 'jane@company.com',
          keyboard: TextInputType.emailAddress,
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 16),
        const _FieldLabel('Phone number'),
        const SizedBox(height: 8),
        _BizField(
          ctrl: phoneCtrl,
          icon: Icons.phone_outlined,
          hint: '+263 77 000 0000',
          keyboard: TextInputType.phone,
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 16),
        const _FieldLabel('Your role'),
        const SizedBox(height: 8),
        _BizField(
          ctrl: titleCtrl,
          icon: Icons.badge_outlined,
          hint: 'e.g. Head of Operations',
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ─────────────────────────── Step 2: Plan selection ───────────────────────────

class _PlanStep extends StatelessWidget {
  const _PlanStep({required this.selected, required this.onSelect});
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PlanCard(
          id: 'starter',
          name: 'Starter',
          price: 'Free to start',
          priceNote: 'then \$8 / seat / month',
          tagline: 'Perfect for small teams',
          features: const [
            'Up to 15 employees',
            'Weekly billing summaries',
            'Basic ride reports',
          ],
          locked: const [
            'Priority driver matching',
            'Analytics dashboard',
          ],
          popular: false,
          selected: selected == 'starter',
          onTap: () => onSelect('starter'),
        ),
        const SizedBox(height: 12),
        _PlanCard(
          id: 'growth',
          name: 'Growth',
          price: '\$12 / seat / month',
          priceNote: 'Billed monthly · cancel anytime',
          tagline: 'For growing organisations',
          features: const [
            'Up to 100 employees',
            'Priority driver matching',
            'Analytics dashboard',
            'Bulk schedule management',
          ],
          locked: const [],
          popular: true,
          selected: selected == 'growth',
          onTap: () => onSelect('growth'),
        ),
        const SizedBox(height: 12),
        _PlanCard(
          id: 'enterprise',
          name: 'Enterprise',
          price: 'Custom pricing',
          priceNote: 'Talk to our team',
          tagline: 'For large or complex deployments',
          features: const [
            'Unlimited employees',
            'Dedicated account manager',
            'Custom billing cycles',
            'API & SSO access',
          ],
          locked: const [],
          popular: false,
          selected: selected == 'enterprise',
          onTap: () => onSelect('enterprise'),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.id,
    required this.name,
    required this.price,
    required this.priceNote,
    required this.tagline,
    required this.features,
    required this.locked,
    required this.popular,
    required this.selected,
    required this.onTap,
  });

  final String id;
  final String name;
  final String price;
  final String priceNote;
  final String tagline;
  final List<String> features;
  final List<String> locked;
  final bool popular;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: selected ? AppColors.primarySurface : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(name, style: AppType.h3),
                              if (popular) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.markAccent
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(
                                    'Popular',
                                    style: AppType.overline.copyWith(
                                      color: AppColors.warning,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(tagline, style: AppType.caption),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.borderStrong,
                          width: 2,
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check_rounded,
                              size: 13, color: Colors.white)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  price,
                  style: AppType.bodyStrong.copyWith(
                    color:
                        selected ? AppColors.primary : AppColors.ink,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 1),
                Text(priceNote, style: AppType.caption),
                const SizedBox(height: 14),
                ...features.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Row(
                        children: [
                          const Icon(Icons.check_rounded,
                              size: 15, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(f,
                              style: AppType.caption
                                  .copyWith(color: AppColors.body)),
                        ],
                      ),
                    )),
                ...locked.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline_rounded,
                              size: 14, color: AppColors.subtle),
                          const SizedBox(width: 8),
                          Text(f,
                              style: AppType.caption
                                  .copyWith(color: AppColors.subtle)),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Step 3: Review ───────────────────────────

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    required this.company,
    required this.industry,
    required this.teamSize,
    required this.name,
    required this.email,
    required this.phone,
    required this.title,
    required this.plan,
  });

  final String company;
  final String industry;
  final String teamSize;
  final String name;
  final String email;
  final String phone;
  final String title;
  final String plan;

  static const _planLabels = {
    'starter': 'Starter — Free to start',
    'growth': 'Growth — \$12 / seat / month',
    'enterprise': 'Enterprise — Custom pricing',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ReviewSection(
          title: 'Company',
          icon: Icons.business_rounded,
          items: {
            'Name': company,
            'Industry': industry,
            'Team size': '$teamSize employees',
          },
        ),
        const SizedBox(height: 12),
        _ReviewSection(
          title: 'Admin',
          icon: Icons.person_outline_rounded,
          items: {
            'Name': name,
            'Email': email,
            if (phone.isNotEmpty) 'Phone': phone,
            if (title.isNotEmpty) 'Role': title,
          },
        ),
        const SizedBox(height: 12),
        _ReviewSection(
          title: 'Plan',
          icon: Icons.verified_outlined,
          items: {
            'Package': _planLabels[plan] ?? plan,
          },
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primaryTint,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.info_outline_rounded,
                    size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your team can start booking rides immediately. You fund a credit float and allocate from it — nothing is charged until you top up.',
                  style: AppType.caption
                      .copyWith(color: AppColors.primaryDark, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Map<String, String> items;

  @override
  Widget build(BuildContext context) {
    final entries = items.entries.toList();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(icon, size: 15, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: AppType.captionStrong.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          ...List.generate(entries.length, (i) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(entries[i].key,
                            style: AppType.caption),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          entries[i].value,
                          style: AppType.bodyStrong
                              .copyWith(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < entries.length - 1)
                  const Divider(
                      height: 1,
                      indent: 16,
                      color: AppColors.divider),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────── Nav footer ───────────────────────────

class _NavFooter extends StatelessWidget {
  const _NavFooter({
    required this.step,
    required this.enabled,
    required this.loading,
    required this.onBack,
    required this.onNext,
  });

  final int step;
  final bool enabled;
  final bool loading;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (step > 0) ...[
            _BackButton(onTap: onBack),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: _ContinueButton(
              label: step == 3 ? 'Create account' : 'Continue',
              loading: loading,
              enabled: enabled,
              onTap: onNext,
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: const Icon(Icons.arrow_back_rounded,
              color: AppColors.body, size: 20),
        ),
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({
    required this.label,
    required this.loading,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool loading;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: (enabled && !loading) ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: enabled
                ? const LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.primary],
                  )
                : null,
            color: enabled ? null : AppColors.border,
          ),
          child: loading
              ? const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: AppType.button.copyWith(
                        color: enabled ? Colors.white : AppColors.muted,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 17,
                      color: enabled ? Colors.white : AppColors.muted,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Shared sub-components ───────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        text,
        style: AppType.captionStrong.copyWith(fontSize: 13),
      ),
    );
  }
}

class _BizField extends StatelessWidget {
  const _BizField({
    required this.ctrl,
    required this.icon,
    required this.hint,
    this.keyboard,
    this.onChanged,
  });

  final TextEditingController ctrl;
  final IconData icon;
  final String hint;
  final TextInputType? keyboard;
  final ValueChanged<String>? onChanged;

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
              controller: ctrl,
              keyboardType: keyboard,
              style: AppType.bodyStrong,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppType.body.copyWith(color: AppColors.subtle),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectChip extends StatelessWidget {
  const _SelectChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppType.captionStrong.copyWith(
            color: selected ? Colors.white : AppColors.body,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
