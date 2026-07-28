// Sends an FCM push to one or more users' devices.
// Body: { user_ids: string[], title: string, body: string, data?: object }
//
// Deploy:  supabase functions deploy send-push
// Secrets: supabase secrets set FCM_PROJECT_ID=... FCM_ACCESS_TOKEN=...
//
// NOTE: FCM v1 needs an OAuth access token minted from your Firebase service
// account. For production, mint it inside the function from the service-account
// JSON (google-auth) and cache it; here it's read from FCM_ACCESS_TOKEN so the
// wiring is clear. Requires the device_tokens table (migration 007) populated
// by the app via NotificationsRepository.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const admin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

Deno.serve(async (req) => {
  try {
    const { user_ids, title, body, data } = await req.json();
    if (!Array.isArray(user_ids) || user_ids.length === 0) {
      return new Response('user_ids required', { status: 400 });
    }

    const { data: rows } = await admin
      .from('device_tokens')
      .select('token')
      .in('user_id', user_ids);

    const tokens = (rows ?? []).map((r: { token: string }) => r.token);
    if (tokens.length === 0) {
      return new Response(JSON.stringify({ sent: 0 }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const projectId = Deno.env.get('FCM_PROJECT_ID')!;
    const accessToken = Deno.env.get('FCM_ACCESS_TOKEN')!;
    const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

    let sent = 0;
    for (const token of tokens) {
      const res = await fetch(url, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title, body },
            data: data ?? {},
          },
        }),
      });
      if (res.ok) sent += 1;
    }

    return new Response(JSON.stringify({ sent, of: tokens.length }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (e) {
    return new Response(`error: ${e}`, { status: 500 });
  }
});
