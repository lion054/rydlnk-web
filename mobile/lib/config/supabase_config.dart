/// Supabase connection settings.
///
/// The publishable key is safe to ship inside the client — it is protected by
/// Row Level Security on the database. NEVER put the secret key here.
///
/// Both values can be overridden at build time without editing this file:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_KEY=...
class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://zpduvchwzoxkzfjuqlww.supabase.co',
  );

  /// Publishable (anon) key — public by design, RLS-protected.
  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: 'sb_publishable_s0I_6ZO__NNxfedjj00vPw_oaYmn2C8',
  );
}
