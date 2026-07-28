import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/message.dart';
import '../state/app_session.dart';

/// Per-trip group chat backed by Supabase Realtime.
class ChatRepository {
  SupabaseClient get _c => AppSession.client;
  String? get myId => _c.auth.currentUser?.id;

  /// Live-ordered stream of messages on a trip. Emits the full list on every
  /// change (Realtime, RLS-scoped to trip participants).
  Stream<List<Message>> messages(String tripId) {
    return _c
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('trip_id', tripId)
        .order('created_at')
        .map((rows) => rows.map(Message.fromJson).toList());
  }

  Future<void> send(String tripId, String body) async {
    final uid = myId;
    final text = body.trim();
    if (uid == null || text.isEmpty) return;
    await _c.from('messages').insert({
      'trip_id': tripId,
      'sender_id': uid,
      'body': text,
    });
  }
}
