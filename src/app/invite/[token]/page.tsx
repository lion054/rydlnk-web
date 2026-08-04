import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Logo } from "@/components/site-header";
import * as Icon from "@/components/icons";
import { contact, stores, smsHref } from "@/lib/site";
import { createClient } from "@/lib/supabase/server";
import { AcceptInvite } from "./accept";

export const metadata: Metadata = {
  title: "You've been invited",
  robots: { index: false, follow: false },
};

/**
 * Invite landing — the missing link in employer onboarding.
 *
 * An admin adds staff in the portal; each person gets a text message or SMS link.
 * That link had nowhere to land, so employer-side onboarding had no delivery
 * path at all. This page resolves the token, shows who invited them and what
 * they've been given, and routes to the right store.
 *
 * The raw token is resolved only by a SECURITY DEFINER function that returns a
 * minimal preview. Expired, revoked and unknown tokens receive a 404.
 */
export default async function InvitePage({ params }: { params: Promise<{ token: string }> }) {
  const { token } = await params;

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { data: previews, error } = await supabase.rpc("company_invite_preview", { p_token: token });
  const invite = previews?.[0];
  if (error || !invite) notFound();

  return (
    <main id="main" className="min-h-screen bg-shell">
      <div className="wrap flex h-[68px] items-center">
        <Logo />
      </div>

      <div className="wrap grid gap-12 pb-20 pt-8 lg:grid-cols-[1.1fr_1fr] lg:items-start lg:pt-16">
        <div>
          <p className="eyebrow text-signal">You&apos;ve been invited</p>
          <h1 className="mt-3 max-w-[18ch] font-display text-[clamp(2rem,4vw,3rem)] font-extrabold leading-[1.05] tracking-[-0.03em]">
            {invite.company_name} invited you to Rydlnk.
          </h1>
          <p className="mt-5 max-w-[52ch] text-md text-muted">
            Accept with <span className="font-semibold text-ink">{invite.invited_email}</span> to join your
            employer&apos;s transport programme. Any credits and schedule policy assigned by the company will
            attach to that account.
          </p>

          <dl className="mt-8 grid gap-3 sm:grid-cols-3">
            {[
              [invite.invited_role, "portal role", Icon.Users],
              [invite.department ?? "Unassigned", "department", Icon.Wallet],
              [new Date(invite.expires_at).toLocaleDateString(), "invite expires", Icon.Clock],
            ].map(([v, l, G]) => {
              const Glyph = G as typeof Icon.Wallet;
              return (
                <div key={l as string} className="rounded-card border border-line bg-white p-4">
                  <Glyph size={18} className="text-signal" />
                  <dt className="mt-2.5 font-display text-lg font-extrabold tracking-[-0.02em]">{v as string}</dt>
                  <dd className="mt-1 text-xs text-muted">{l as string}</dd>
                </div>
              );
            })}
          </dl>

          <div className="mt-9 max-w-[30rem]">
            <AcceptInvite token={token} signedIn={Boolean(user)} />
          </div>

          <p className="mt-8 label text-muted">Then get the app</p>
          <div className="mt-3 flex flex-wrap gap-3">
            <a
              href={stores.ios}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex min-h-[48px] items-center gap-2.5 rounded-full bg-ink px-6 font-semibold text-white transition-colors hover:bg-forest"
            >
              <Icon.Phone size={18} /> App Store
            </a>
            <a
              href={stores.android}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex min-h-[48px] items-center gap-2.5 rounded-full bg-ink px-6 font-semibold text-white transition-colors hover:bg-forest"
            >
              <Icon.Phone size={18} /> Google Play
            </a>
            <a
              href={smsHref}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex min-h-[48px] items-center gap-2.5 rounded-full border border-linestrong px-6 font-semibold text-ink transition-colors hover:border-signal hover:bg-signal/5"
            >
              <Icon.Chat size={18} /> Use text message instead
            </a>
          </div>

          <p className="mt-5 text-xs text-muted">
            Invite reference <span className="nums font-mono">{token.slice(0, 12)}</span>. Sign up with the number
            your employer has on file so the credits attach to you.
          </p>
        </div>

        <aside className="space-y-3 lg:sticky lg:top-8">
          <div className="rounded-lg border border-line bg-white p-6">
            <h2 className="text-lg font-extrabold tracking-[-0.015em]">What your employer can see</h2>
            <ul className="mt-4 space-y-3 text-base text-muted">
              {[
                "The seats they funded — which run, and what it cost them.",
                "Nothing about trips you pay for yourself, ever.",
                "Your corridor and cluster, never your exact home pin.",
                "Never your ID document.",
              ].map((t) => (
                <li key={t} className="flex gap-3">
                  <Icon.Check size={17} className="mt-0.5 shrink-0 text-signal" />
                  {t}
                </li>
              ))}
            </ul>
            <Link
              href="/legal/privacy"
              className="mt-5 inline-flex items-center gap-1.5 text-xs font-semibold text-signal underline underline-offset-4"
            >
              Read the privacy policy <Icon.ArrowRight size={14} />
            </Link>
          </div>

          <div className="rounded-lg border border-line bg-white p-6">
            <h2 className="text-lg font-extrabold tracking-[-0.015em]">If you&apos;d rather not</h2>
            <p className="mt-2 text-base text-muted">
              Taking a seat is optional. Ignore this and nothing happens — your employer sees an unclaimed
              entitlement, not a refusal, and the credits go back to their float.
            </p>
            <p className="mt-4 text-xs text-muted">
              Questions: <span className="font-mono">{contact.phoneDisplay}</span>
            </p>
          </div>
        </aside>
      </div>
    </main>
  );
}
