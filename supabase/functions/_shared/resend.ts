// Resend delivery.
//
// Split from email.ts so that rendering stays free of runtime globals: this is
// the only file in the email path that touches Deno, which is what lets the
// preview generator and the auth-template build import the renderer under Node.

import type { RenderedEmail } from './email.ts';

export type SendResult = { delivered: boolean; id?: string; error?: string };

/**
 * Sends through Resend.
 *
 * Returns rather than throws. Every caller has something more useful to do than
 * fail — the invite hands back a copyable link, the receipt has already banked
 * the money — so a bounced send must never become a failed request.
 */
export async function sendEmail(input: {
  to: string | string[];
  subject: string;
  email: RenderedEmail;
  replyTo?: string;
  tags?: Record<string, string>;
}): Promise<SendResult> {
  const key = Deno.env.get('RESEND_API_KEY');
  const from = Deno.env.get('INVITE_FROM_EMAIL');
  if (!key || !from) return { delivered: false, error: 'email provider is not configured' };

  try {
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        from,
        to: Array.isArray(input.to) ? input.to : [input.to],
        subject: input.subject,
        html: input.email.html,
        // Sending text/plain alongside the HTML is a deliverability
        // requirement, not a courtesy — filters penalise HTML-only mail, and
        // the invite is the first thing a fresh sending domain ever sends.
        text: input.email.text,
        ...(input.replyTo ? { reply_to: input.replyTo } : {}),
        // Resend rejects tag values outside [A-Za-z0-9_-].
        ...(input.tags
          ? {
              tags: Object.entries(input.tags).map(([name, value]) => ({
                name,
                value: value.replace(/[^A-Za-z0-9_-]/g, '_').slice(0, 60),
              })),
            }
          : {}),
      }),
    });

    if (!response.ok) {
      const detail = await response.text();
      console.error('resend send failed', response.status, detail.slice(0, 500));
      return { delivered: false, error: `delivery failed (${response.status})` };
    }

    const body = await response.json().catch(() => ({}));
    return { delivered: true, id: body?.id };
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    console.error('resend send threw', message);
    return { delivered: false, error: message };
  }
}
