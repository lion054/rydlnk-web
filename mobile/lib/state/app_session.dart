import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// App-wide session + auth facade over Supabase.
///
/// The static [name] / [initials] / [email] / [phone] fields are kept so the
/// existing screens (home, profile) keep reading them unchanged — they are now
/// populated from the signed-in user's `profiles` row instead of hardcoded.
class AppSession {
  AppSession._();

  static String name = '';
  static String initials = '';
  static String email = '';
  static String phone = '';
  static String role = 'rider'; // rider | driver | company_admin

  static bool get isDriver => role == 'driver';

  static SupabaseClient get client => Supabase.instance.client;

  /// Call once at startup before `runApp`.
  static Future<void> init() async {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
  }

  static bool get isSignedIn => client.auth.currentSession != null;

  static String get greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  // ─────────────────────────── Auth ───────────────────────────

  static Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await client.auth.signInWithPassword(email: email, password: password);
    await loadProfile();
  }

  static Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
    String? phone,
    String? homeAddress,
    String? workAddress,
    bool asDriver = false,
    String? vehicle,
    String? plate,
  }) async {
    final res = await client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName, 'phone': phone},
    );

    // A DB trigger creates the base profiles row from the metadata above.
    // Persist the extra details the sign-up wizard collected.
    final user = res.user;
    if (user != null) {
      await client.from('profiles').update({
        'full_name': fullName,
        'initials': _initialsOf(fullName),
        'phone': phone,
        'home_address': homeAddress,
        'work_address': workAddress,
      }).eq('id', user.id);
    }

    if (isSignedIn) {
      if (asDriver) {
        await becomeDriver(vehicle: vehicle, plate: plate);
      }
      await loadProfile();
    } else {
      // Email-confirmation is on; populate locally pending confirmation.
      AppSession.name = fullName.split(' ').first;
      AppSession.initials = _initialsOf(fullName);
      AppSession.email = email;
      AppSession.phone = phone ?? '';
      AppSession.role = asDriver ? 'driver' : 'rider';
    }
  }

  /// Promotes the signed-in user to a driver and saves their vehicle details.
  static Future<void> becomeDriver({String? vehicle, String? plate}) async {
    await client.rpc('become_driver', params: {
      'p_vehicle': vehicle,
      'p_plate': plate,
    });
    role = 'driver';
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
    name = '';
    initials = '';
    email = '';
    phone = '';
    role = 'rider';
  }

  static Future<void> sendPasswordReset(String email) async {
    await client.auth.resetPasswordForEmail(email);
  }

  /// Permanently deletes the signed-in user's account and all their data,
  /// then clears the session.
  static Future<void> deleteAccount() async {
    await client.rpc('delete_my_account');
    await signOut();
  }

  // ─────────────────────────── Profile ───────────────────────────

  /// Loads the signed-in user's profile into the static fields.
  static Future<void> loadProfile() async {
    final user = client.auth.currentUser;
    if (user == null) return;
    AppSession.email = user.email ?? '';

    final row = await client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (row != null) {
      final fullName = (row['full_name'] as String?)?.trim() ?? '';
      AppSession.name =
          fullName.isNotEmpty ? fullName.split(' ').first : 'there';
      AppSession.initials =
          (row['initials'] as String?) ?? _initialsOf(fullName);
      AppSession.phone = (row['phone'] as String?) ?? '';
      AppSession.role = (row['role'] as String?) ?? 'rider';
    }
  }

  static String _initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
