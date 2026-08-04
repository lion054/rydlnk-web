// Scheduled billing mail: statement-ready notices and low-float warnings.
//
// Driven from outside the database rather than by pg_cron. The scheduled jobs
// in migration 015 run inside Postgres, which cannot reach an edge function
// without pg_net, and pg_net is not installed on this project. So this is a
// private HTTP endpoint on a shared secret — the same shape as `health` — and
// something external calls it. .github/workflows/billing-notify.yml does that;
// any scheduler that can send a header works equally well.
//
// Safe to call repeatedly. Every send is claimed through notification_log
// first, so running it hourly does not mail anyone twice.
//
// Deploy:  supabase functions deploy billing-notify --no-verify-jwt
// Secrets: supabase secrets set BILLING_NOTIFY_SECRET=… RESEND_API_KEY=… \
//            INVITE_FROM_EMAIL="Rydlnk <billing@your-domain.com>" SITE_ORIGIN=https://…

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { notifyCompany, siteOrigin } from '../_shared/notify.ts';
import { lowBalance, statementReady } from '../_shared/messages.ts';

const admin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

type Tally = { sent: number; skipped: number; failed: number };
const tally = (): Tally => ({ sent: 0, skipped: 0, failed: 0 });

Deno.serve(async (req) => {
  const expected = Deno.env.get('BILLING_NOTIFY_SECRET');
  const supplied = req.headers.get('x-billing-secret');
  // Compared only after the presence check so a missing secret cannot be
  // satisfied by a missing header.
  if (!expected || supplied !== expected) {
    return json({ error: 'unauthorized' }, 401);
  }

  const url = new URL(req.url);
  // `?dry=1` reports what would be sent without claiming or sending anything.
  const dryRun = url.searchParams.get('dry') === '1';
  const started = Date.now();

  const [statements, lowFloat] = await Promise.all([
    runStatements(dryRun),
    runLowFloat(dryRun),
  ]);

  const failed = statements.failed + lowFloat.failed;
  return json(
    {
      dry_run: dryRun,
      statements,
      low_float: lowFloat,
      duration_ms: Date.now() - started,
    },
    // 200 even with failures: this is polled by a scheduler, and a partial
    // failure is not a reason to alarm on the endpoint itself. The counts say
    // what happened; Sentry gets the detail from the console.
    failed > 0 ? 207 : 200,
  );
});

// ── Statement ready ─────────────────────────────────────────────────────────

async function runStatements(dryRun: boolean): Promise<Tally & { candidates: number }> {
  const out = { ...tally(), candidates: 0 };

  const { data, error } = await admin.rpc('statements_awaiting_notice', {
    p_since: '7 days',
  });
  if (error) {
    console.error('statements_awaiting_notice failed', error.message);
    return { ...out, failed: 1 };
  }

  const rows = data ?? [];
  out.candidates = rows.length;
  if (dryRun) return out;

  for (const row of rows) {
    const outcome = await notifyCompany(admin, {
      companyId: row.company_id,
      kind: 'statement_ready',
      ref: row.invoice_id,
      message: statementReady({
        companyName: row.company_name ?? 'Your company',
        periodStart: row.period_start,
        periodEnd: row.period_end,
        seats: row.seats ?? 0,
        credits: row.credits ?? 0,
        number: row.number ?? '—',
        invoiceUrl: `${siteOrigin()}/portal/billing/invoices/${row.invoice_id}`,
      }),
    });
    record(out, outcome, `statement ${row.invoice_id}`);
  }

  return out;
}

// ── Low float ───────────────────────────────────────────────────────────────

/**
 * The ref is the current UTC date, so a company that stays below its threshold
 * is warned once per day rather than once per run — the unique index on
 * (company_id, kind, ref) is what enforces that, not a timer here.
 */
function lowFloatRef(): string {
  return new Date().toISOString().slice(0, 10);
}

async function runLowFloat(dryRun: boolean): Promise<Tally & { candidates: number }> {
  const out = { ...tally(), candidates: 0 };

  const { data, error } = await admin.rpc('companies_low_float');
  if (error) {
    console.error('companies_low_float failed', error.message);
    return { ...out, failed: 1 };
  }

  const rows = data ?? [];
  out.candidates = rows.length;
  if (dryRun) return out;

  const ref = lowFloatRef();

  for (const row of rows) {
    const outcome = await notifyCompany(admin, {
      companyId: row.company_id,
      kind: 'low_balance',
      ref,
      message: lowBalance({
        companyName: row.company_name ?? 'Your company',
        credits: row.credits ?? 0,
        threshold: row.threshold ?? 0,
        autoTopupEnabled: Boolean(row.auto_enabled),
        topupUrl: `${siteOrigin()}/portal/billing`,
      }),
    });
    record(out, outcome, `low float ${row.company_id}`);
  }

  return out;
}

// ── Shared ──────────────────────────────────────────────────────────────────

function record(
  out: Tally,
  outcome: Awaited<ReturnType<typeof notifyCompany>>,
  label: string,
): void {
  if (outcome.status === 'sent') out.sent++;
  else if (outcome.status === 'skipped') out.skipped++;
  else {
    out.failed++;
    console.error(`billing-notify: ${label} failed — ${outcome.reason}`);
  }
}

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
  });
}
