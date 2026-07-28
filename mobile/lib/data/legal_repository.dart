import 'package:supabase_flutter/supabase_flutter.dart';

import '../state/app_session.dart';
import '../utils/legal.dart';

/// Records a user's acceptance of a legal document version.
class LegalRepository {
  SupabaseClient get _c => AppSession.client;

  Future<void> accept(LegalDoc doc) async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return;
    await _c.from('legal_acceptances').upsert(
      {'user_id': uid, 'doc_type': doc.key, 'version': doc.version},
      onConflict: 'user_id,doc_type,version',
    );
  }

  Future<void> acceptAll(List<LegalDoc> docs) async {
    for (final d in docs) {
      await accept(d);
    }
  }
}
