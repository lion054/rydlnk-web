// The catalogue of transactional emails.
//
// Content lives here rather than inside the function that happens to send it,
// so the whole set can be read — and previewed — in one place. Each entry
// returns a subject alongside the rendered bodies, because the subject is part
// of the message and drifts from the body when it lives at the call site.
//
// Preview every one of these without sending: npm run email:preview

import {
  escapeHtml,
  formatCredits,
  formatDate,
  formatMoney,
  renderEmail,
  strong,
  type RenderedEmail,
} from './email.ts';

type Message = RenderedEmail & { subject: string };

// ── Company invite ──────────────────────────────────────────────────────────

export function companyInvite(input: {
  companyName: string;
  recipientEmail: string;
  role: string;
  link: string;
  expiresInDays?: number;
}): Message {
  const roleLabel: Record<string, string> = {
    viewer: 'a rider on the programme',
    manager: 'a manager, able to approve trips for your team',
    finance: 'a finance user, able to fund and report on the programme',
    admin: 'an administrator, with full access to the programme',
  };
  const role = roleLabel[input.role] ?? 'a rider on the programme';

  return {
    subject: `${input.companyName} has added you to their Rydlnk commute`,
    ...renderEmail({
      preheader: `Accept your place on ${input.companyName}'s staff transport programme.`,
      heading: 'Your commute is covered.',
      subheading: `${input.companyName} is paying for your journey to and from work.`,
      blocks: [
        {
          kind: 'text',
          text: `You've been added to ${strong(input.companyName)}'s Rydlnk programme as ${role}. Accept below and your seat is booked from your first shift.`,
        },
        {
          kind: 'bullets',
          items: [
            'Nothing to pay — your employer funds the seat directly.',
            'Book a ride from the app, or ride a route your company already runs.',
            'Your travel is private. Your employer sees that a seat was used, not where you went.',
          ],
        },
      ],
      cta: { label: 'Accept your invitation', url: input.link },
      // footnote is rendered as HTML so interpolations are escaped here;
      // footerReason is escaped by renderEmail, so it takes the raw values.
      footnote: `This invitation was issued to ${escapeHtml(input.recipientEmail)} and only that address can accept it${
        input.expiresInDays ? `. It expires in ${input.expiresInDays} days` : ''
      }. If you weren't expecting it, ignore this message — nothing happens until you accept.`,
      footerReason: `${input.companyName} sent this invitation to ${input.recipientEmail}.`,
    }),
  };
}

// ── Top-up receipt ──────────────────────────────────────────────────────────

export function topupReceipt(input: {
  companyName: string;
  credits: number;
  amountCents: number;
  currency: string;
  reference: string;
  settledAt: string;
  floatAfter: number;
  automatic: boolean;
  portalUrl: string;
}): Message {
  return {
    subject: `Receipt — ${formatMoney(input.amountCents, input.currency)} added to your Rydlnk float`,
    ...renderEmail({
      preheader: `${formatCredits(input.credits)} are now available to allocate.`,
      heading: 'Your float has been topped up.',
      subheading: input.automatic
        ? 'This was an automatic top-up, triggered by your balance threshold.'
        : undefined,
      blocks: [
        {
          kind: 'text',
          text: `Payment has settled and ${strong(formatCredits(input.credits))} have been added to ${strong(input.companyName)}'s float. They're available to allocate now.`,
        },
        {
          kind: 'facts',
          rows: [
            ['Reference', input.reference],
            ['Date', formatDate(input.settledAt)],
            ['Credits added', formatCredits(input.credits)],
            ['Float after top-up', formatCredits(input.floatAfter)],
          ],
          total: ['Amount charged', formatMoney(input.amountCents, input.currency)],
        },
      ],
      cta: { label: 'Allocate credits', url: input.portalUrl },
      footnote:
        'Keep this receipt for your records. A full statement of funded seats is issued at the start of each month.',
      footerReason: 'You received this because you are a billing contact for this company on Rydlnk.',
    }),
  };
}

// ── Monthly statement ready ─────────────────────────────────────────────────

export function statementReady(input: {
  companyName: string;
  periodStart: string;
  periodEnd: string;
  seats: number;
  credits: number;
  number: string;
  invoiceUrl: string;
}): Message {
  return {
    subject: `Your Rydlnk statement for ${formatDate(input.periodStart)} – ${formatDate(input.periodEnd)}`,
    ...renderEmail({
      preheader: `${input.seats} funded seats across the period. Nothing to pay — this is a record of credits already spent.`,
      heading: 'Your monthly statement is ready.',
      subheading: `${formatDate(input.periodStart)} to ${formatDate(input.periodEnd)}`,
      blocks: [
        {
          kind: 'text',
          text: `Here's what ${strong(input.companyName)} funded last period. Every seat below was paid for from credits you had already bought, so there is nothing further to pay.`,
        },
        {
          kind: 'facts',
          rows: [
            ['Statement', input.number],
            ['Period', `${formatDate(input.periodStart)} – ${formatDate(input.periodEnd)}`],
            ['Seats funded', String(input.seats)],
          ],
          total: ['Credits drawn', formatCredits(input.credits)],
        },
        {
          kind: 'callout',
          tone: 'neutral',
          text: 'The full statement breaks every seat down by cost centre, ready to hand to finance.',
        },
      ],
      cta: { label: 'View the full statement', url: input.invoiceUrl },
      footerReason: 'You received this because you are a billing contact for this company on Rydlnk.',
    }),
  };
}

// ── Low float warning ───────────────────────────────────────────────────────

export function lowBalance(input: {
  companyName: string;
  credits: number;
  threshold: number;
  autoTopupEnabled: boolean;
  topupUrl: string;
}): Message {
  const critical = input.credits <= 0;

  return {
    subject: critical
      ? `Action needed — ${input.companyName}'s Rydlnk float is empty`
      : `${input.companyName}'s Rydlnk float is running low`,
    ...renderEmail({
      preheader: critical
        ? 'Staff seats cannot be funded until the float is topped up.'
        : `${formatCredits(input.credits)} left, below your ${formatCredits(input.threshold)} threshold.`,
      heading: critical ? 'Your float is empty.' : 'Your float is running low.',
      subheading: critical
        ? 'New seats cannot be funded until you top up.'
        : undefined,
      blocks: [
        {
          kind: 'text',
          text: critical
            ? `${strong(input.companyName)} has no credits left. Staff journeys will not be funded until the float is topped up — riders will be asked to pay for their own seat in the meantime.`
            : `${strong(input.companyName)} has ${strong(formatCredits(input.credits))} remaining, which is below the ${strong(formatCredits(input.threshold))} threshold you set.`,
        },
        input.autoTopupEnabled
          ? {
              kind: 'callout' as const,
              tone: 'warning' as const,
              title: 'Automatic top-up did not complete',
              text: 'Auto top-up is switched on, so this balance means the last attempt failed — usually an expired card. Check your payment method.',
            }
          : {
              kind: 'callout' as const,
              tone: 'neutral' as const,
              title: 'Automatic top-up is off',
              text: 'Turning it on refills the float before it runs out, so staff journeys are never interrupted.',
            },
      ],
      cta: { label: critical ? 'Top up now' : 'Top up the float', url: input.topupUrl },
      footerReason: 'You received this because you are a billing contact for this company on Rydlnk.',
    }),
  };
}

// ── Auth emails ─────────────────────────────────────────────────────────────
//
// These are sent by the `auth-email` edge function, wired to Supabase's Send
// Email Hook, so they go out through Resend from rydlnk.us like every other
// message here — not through Supabase's built-in mailer, which cannot be
// branded, stamps "powered by Supabase" on the footer, and is rate limited to a
// handful of messages an hour.
//
// Each takes the verification URL as a parameter. `npm run email:templates`
// still renders them to supabase/templates/*.html with a Go expression in place
// of the URL, because those files remain the fallback if the hook is ever turned
// off, and they are what `supabase start` uses locally.
//
// escapeUrl() rejects anything that is not http(s), so `{{ .ConfirmationURL }}`
// cannot be passed straight through. The generator passes a sentinel and swaps
// it afterwards, which leaves URL validation intact for every real caller.

export const AUTH_URL_SENTINEL = 'https://rydlnk.invalid/__CONFIRMATION_URL__';

/** Substitutions applied to the generated HTML, in order. */
export const AUTH_SUBSTITUTIONS: Array<[string, string]> = [
  [AUTH_URL_SENTINEL, '{{ .ConfirmationURL }}'],
];

const authFooter =
  'You received this because someone entered this address on Rydlnk. If that was not you, no action is needed — the link above is single-use and expires on its own.';

export function authMagicLink(url: string): Message {
  return {
    subject: 'Your Rydlnk sign-in link',
    ...renderEmail({
      preheader: 'One tap to sign in. The link expires in an hour.',
      heading: 'Sign in to Rydlnk.',
      subheading: 'No password needed — this link signs you straight in.',
      blocks: [
        {
          kind: 'text',
          text: 'Tap the button to open your company portal. For your security the link works once, and only from this message.',
        },
      ],
      cta: { label: 'Sign in to Rydlnk', url },
      footnote:
        'This link expires in one hour. If it has already lapsed, request a fresh one from the sign-in page.',
      footerReason: authFooter,
    }),
  };
}

export function authConfirmSignup(url: string): Message {
  return {
    subject: 'Confirm your email to finish setting up Rydlnk',
    ...renderEmail({
      preheader: 'One step left — confirm this address to activate your account.',
      heading: 'Confirm your email address.',
      subheading: 'This is the last step before your company account is live.',
      blocks: [
        {
          kind: 'text',
          text: 'Confirming proves the address is yours. It becomes the address your staff invitations are sent from, so it is worth getting right.',
        },
      ],
      cta: { label: 'Confirm my email', url },
      footerReason: authFooter,
    }),
  };
}

export function authRecovery(url: string): Message {
  return {
    subject: 'Reset your Rydlnk password',
    ...renderEmail({
      preheader: 'Choose a new password. This link expires in an hour.',
      heading: 'Reset your password.',
      blocks: [
        {
          kind: 'text',
          text: 'Use the button below to choose a new password. Your current password stays active until you do.',
        },
        {
          kind: 'callout',
          tone: 'warning',
          title: "Didn't ask for this?",
          text: 'Ignore this email and your password will not change. If you get these repeatedly, someone may know your address — tell your administrator.',
        },
      ],
      cta: { label: 'Choose a new password', url },
      footnote: 'This link expires in one hour and can only be used once.',
      footerReason: authFooter,
    }),
  };
}

export function authEmailChange(url: string): Message {
  return {
    subject: 'Confirm your new Rydlnk email address',
    ...renderEmail({
      preheader: 'Confirm the change to finish moving your account to this address.',
      heading: 'Confirm your new address.',
      subheading: 'Your Rydlnk account is being moved to this email address.',
      blocks: [
        {
          kind: 'text',
          text: 'Confirm below to complete the change. Until you do, your account stays on its current address and nothing is affected.',
        },
        {
          kind: 'callout',
          tone: 'warning',
          title: 'If this was not you',
          text: 'Do not confirm. Someone has entered this address on an account that may not be theirs — contact your administrator.',
        },
      ],
      cta: { label: 'Confirm the change', url },
      footerReason: authFooter,
    }),
  };
}

/**
 * Reauthentication — the one auth email that carries a code rather than a link.
 *
 * Supabase issues a six-digit token for this flow, so there is no URL to render
 * and no CTA. The code is set in a monospaced block because a proportional font
 * makes 0/O and 1/l ambiguous at the moment someone is copying digits by hand.
 */
export function authReauthentication(token: string): Message {
  return {
    subject: 'Your Rydlnk confirmation code',
    ...renderEmail({
      preheader: `Your confirmation code is ${token}.`,
      heading: 'Confirm it is you.',
      subheading: 'Enter this code to finish what you started.',
      blocks: [
        {
          kind: 'text',
          text: 'Someone — we assume you — asked to confirm a sensitive change on your Rydlnk account.',
        },
        { kind: 'code', label: 'Confirmation code', value: token },
        {
          kind: 'callout',
          tone: 'warning',
          title: 'Never share this code',
          text: 'Nobody from Rydlnk will ever ask you for it, by email, phone or chat.',
        },
      ],
      footnote: 'The code expires shortly. Request a new one if it has lapsed.',
      footerReason:
        'You received this because a sensitive change was requested on the Rydlnk account for this address.',
    }),
  };
}
