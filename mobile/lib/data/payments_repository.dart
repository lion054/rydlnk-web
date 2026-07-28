import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/payment_method.dart';
import '../state/app_session.dart';

/// Data access for saved cards and billing.
///
/// Reads come straight from Supabase (RLS-scoped). Card creation goes through
/// the `stripe-setup-intent` Edge Function, which returns a client_secret the
/// Stripe SDK uses to collect the card — see [createSetupIntent].
class PaymentsRepository {
  SupabaseClient get _c => AppSession.client;

  Future<List<PaymentMethod>> methods() async {
    final rows = await _c
        .from('payment_methods')
        .select()
        .order('is_default', ascending: false)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => PaymentMethod.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> removeMethod(String id) async {
    await _c.from('payment_methods').delete().eq('id', id);
  }

  /// Asks the Edge Function for a SetupIntent client_secret. The caller then
  /// hands this to the Stripe SDK to actually collect and save the card.
  /// Throws if the function isn't deployed / Stripe keys aren't set yet.
  Future<String> createSetupIntent() async {
    final res = await _c.functions.invoke('stripe-setup-intent');
    final data = res.data as Map?;
    final secret = data?['client_secret'] as String?;
    if (secret == null) {
      throw Exception(data?['error'] ?? 'Could not start card setup');
    }
    return secret;
  }
}
