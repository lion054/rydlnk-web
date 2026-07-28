import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns a raw exception into a short, human, actionable message — never a
/// stack trace or a `PostgrestException(...)` string.
String friendlyError(Object e) {
  if (e is AuthException) {
    final m = e.message;
    if (m.toLowerCase().contains('invalid login')) {
      return 'That email or password looks wrong.';
    }
    if (m.toLowerCase().contains('already registered')) {
      return 'That email already has an account — try signing in.';
    }
    return m; // GoTrue messages are generally human-readable.
  }

  if (e is PostgrestException) {
    final m = e.message.toLowerCase();
    if (m.contains('pending verification')) {
      return 'Your driver account is still under review.';
    }
    if (m.contains('no longer available')) {
      return 'That trip was just taken. Pull to refresh for new ones.';
    }
    if (m.contains('not a driver')) {
      return "You're not set up as a driver yet.";
    }
    if (m.contains('not authenticated')) {
      return 'Please sign in again.';
    }
    if (e.code == '42501' || m.contains('row-level security')) {
      return "You don't have permission to do that.";
    }
    return 'Something went wrong on our end. Please try again.';
  }

  final s = e.toString().toLowerCase();
  if (s.contains('socketexception') ||
      s.contains('failed host lookup') ||
      s.contains('timeout') ||
      s.contains('clientexception')) {
    return 'Network problem — check your connection and try again.';
  }
  return 'Something went wrong. Please try again.';
}
