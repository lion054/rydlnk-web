import 'package:flutter/material.dart';

import '../data/payments_repository.dart';
import '../models/payment_method.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/errors.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  final _repo = PaymentsRepository();
  late Future<List<PaymentMethod>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.methods();
  }

  void _reload() => setState(() => _future = _repo.methods());

  Future<void> _remove(PaymentMethod pm) async {
    try {
      await _repo.removeMethod(pm.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
    _reload();
  }

  Future<void> _addCard() async {
    // The SetupIntent backend is ready; collecting the card needs the Stripe
    // SDK + your Stripe publishable key (the last go-live step for payments).
    try {
      await _repo.createSetupIntent();
      if (!mounted) return;
      _showInfo(
        'Card setup is ready on the backend. The final step — the Stripe '
        'card sheet — activates once the Stripe SDK and publishable key are '
        'added.',
      );
    } catch (_) {
      if (!mounted) return;
      _showInfo(
        'Payments backend not connected yet. Deploy the stripe-setup-intent '
        'function and set your Stripe keys to enable adding cards.',
      );
    }
  }

  void _showInfo(String message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
            24, 20, 24, 28 + MediaQuery.of(context).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded,
                color: AppColors.primary, size: 26),
            const SizedBox(height: 12),
            Text('Almost there', style: AppType.h3),
            const SizedBox(height: 8),
            Text(message, style: AppType.body),
          ],
        ),
      ),
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
        title: Text('Payment methods', style: AppType.h3),
      ),
      body: FutureBuilder<List<PaymentMethod>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          final cards = snap.data ?? const [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            physics: const BouncingScrollPhysics(),
            children: [
              if (cards.isEmpty)
                const _NoCards()
              else
                for (final pm in cards) ...[
                  _CardTile(
                    brand: pm.displayBrand,
                    last4: pm.last4,
                    expires: pm.expiresLabel,
                    isDefault: pm.isDefault,
                    onRemove: () => _remove(pm),
                  ),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(child: Divider(color: AppColors.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('add a card', style: AppType.caption),
                  ),
                  const Expanded(child: Divider(color: AppColors.border)),
                ],
              ),
              const SizedBox(height: 16),
              _AddCardTile(onTap: _addCard),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lock_outline_rounded,
                        size: 14, color: AppColors.muted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Cards are stored securely by Stripe. rydlnk never sees your full card number.',
                        style: AppType.caption.copyWith(fontSize: 12),
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

class _NoCards extends StatelessWidget {
  const _NoCards();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.credit_card_off_rounded,
              color: AppColors.muted, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text('No cards saved yet. Add one to pay for your rides.',
                style: AppType.body.copyWith(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({
    required this.brand,
    required this.last4,
    required this.expires,
    this.isDefault = false,
    this.onRemove,
  });

  final String brand;
  final String? last4;
  final String? expires;
  final bool isDefault;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDefault ? AppColors.primary : AppColors.border,
          width: isDefault ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.credit_card_rounded,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(brand, style: AppType.bodyStrong),
                    if (isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTint,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Default',
                          style: AppType.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                if (last4 != null)
                  Text(
                    '•••• •••• •••• $last4'
                    '${expires != null && expires!.isNotEmpty ? '   ·   Expires $expires' : ''}',
                    style: AppType.caption,
                  )
                else
                  Text('Saved card', style: AppType.caption),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.danger, size: 18),
            ),
        ],
      ),
    );
  }
}

class _AddCardTile extends StatelessWidget {
  const _AddCardTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35),
              width: 1.5,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Add new card',
                style: AppType.button.copyWith(color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
