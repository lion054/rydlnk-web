import { Suspense } from "react";
import Link from "next/link";
import { Logo } from "@/components/site-header";
import * as Icon from "@/components/icons";
import { SignInForm } from "./signin-form";

export const metadata = {
  title: "Sign in",
  robots: { index: false, follow: false },
};

export default function SignInPage() {
  return (
    <main id="main" className="grid min-h-screen lg:grid-cols-[1fr_1.1fr]">
      <div className="flex flex-col px-6 py-8 sm:px-10 lg:px-14">
        <Logo />

        <div className="mx-auto flex w-full max-w-[26rem] flex-1 flex-col justify-center py-12">
          <Suspense fallback={<p className="text-muted">Loading…</p>}>
            <SignInForm />
          </Suspense>
        </div>

        <Link href="/" className="inline-flex items-center gap-2 text-xs text-muted hover:text-ink">
          <Icon.ArrowLeft size={14} /> Back to rydlnk.us
        </Link>
      </div>

      <div className="relative hidden overflow-hidden bg-forest p-14 lg:flex lg:flex-col lg:justify-end">
        <div className="grid-lines pointer-events-none absolute inset-0" />
        <blockquote className="relative max-w-[36ch]">
          <p className="font-display text-[2rem] font-extrabold leading-[1.15] tracking-[-0.03em] text-white">
            &ldquo;Two operators, no reconciliation, and nobody could tell me what a trip cost. Now it&apos;s one
            invoice split by cost center.&rdquo;
          </p>
          <footer className="mt-6 text-base text-muteddark">Transport lead · manufacturing · Provo</footer>
        </blockquote>
      </div>
    </main>
  );
}
