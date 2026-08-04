// Claim-then-send wrapper over notification_log (migration 026).
//
// Both senders of lifecycle mail go through this: the Stripe webhook for
// receipts, and billing-notify for statements and low-float warnings. Neither
// may send twice, and neither may fail its real job because an email bounced.

import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { sendEmail } from './resend.ts';
import type { RenderedEmail } from './email.ts';

export type NotificationKind = 'topup_receipt' | 'statement_ready' | 'low_balance';

export type NotifyOutcome =
  | { status: 'sent'; recipients: string[] }
  | { status: 'skipped'; reason: 'already-sent' | 'no-recipients' }
  | { status: 'failed'; reason: string };

/**
 * Send one company notification, at most once.
 *
 * The claim is taken before the send and released only as an outcome, so a
 * crash between the two leaves the row 'claimed' and the notification is not
 * retried unless the caller passed a retryAfter.
 */
export async function notifyCompany(
  admin: SupabaseClient,
  input: {
    companyId: string;
    kind: NotificationKind;
    /** Identifies the subject — a top-up id, invoice id, or a period key. */
    ref: string;
    message: RenderedEmail & { subject: string };
    /** Reopens a claim older than this Postgres interval, e.g. '2 hours'. */
    retryAfter?: string;
  },
): Promise<NotifyOutcome> {
  const { data: claimed, error: claimError } = await admin.rpc('claim_notification', {
    p_company: input.companyId,
    p_kind: input.kind,
    p_ref: input.ref,
    p_retry_after: input.retryAfter ?? null,
  });

  if (claimError) return { status: 'failed', reason: claimError.message };
  if (!claimed) return { status: 'skipped', reason: 'already-sent' };

  const { data: recipients, error: recipientError } = await admin.rpc('billing_recipients', {
    p_company: input.companyId,
  });

  const to: string[] = recipients ?? [];
  if (recipientError || to.length === 0) {
    const reason = recipientError?.message ?? 'no billing recipients';
    await admin.rpc('finish_notification', {
      p_company: input.companyId,
      p_kind: input.kind,
      p_ref: input.ref,
      p_recipients: [],
      p_error: reason,
    });
    return recipientError
      ? { status: 'failed', reason }
      : { status: 'skipped', reason: 'no-recipients' };
  }

  const sent = await sendEmail({
    to,
    subject: input.message.subject,
    email: input.message,
    tags: { type: input.kind, company: input.companyId },
  });

  await admin.rpc('finish_notification', {
    p_company: input.companyId,
    p_kind: input.kind,
    p_ref: input.ref,
    p_recipients: to,
    p_error: sent.delivered ? null : (sent.error ?? 'delivery failed'),
  });

  return sent.delivered
    ? { status: 'sent', recipients: to }
    : { status: 'failed', reason: sent.error ?? 'delivery failed' };
}

/** Origin for links in mail. Falls back so a missing secret cannot break a send. */
export function siteOrigin(): string {
  return (Deno.env.get('SITE_ORIGIN') ?? 'https://rydlnk.us').replace(/\/$/, '');
}
