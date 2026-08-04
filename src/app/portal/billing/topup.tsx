"use client";

import { Elements, PaymentElement, useElements, useStripe } from "@stripe/react-stripe-js";
import { loadStripe } from "@stripe/stripe-js";
import { useState } from "react";
import { Panel } from "@/components/portal/chrome";
import { Button } from "@/components/ui";
import * as Icon from "@/components/icons";
import { CREDIT_VALUE } from "@/lib/data";
import { createClient } from "@/lib/supabase/client";

const publishableKey = process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY;
const stripePromise = publishableKey ? loadStripe(publishableKey) : null;

function ConfirmTopUp({ credits, onDone }: { credits: number; onDone: (message: string) => void }) {
  const stripe = useStripe();
  const elements = useElements();
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function confirm() {
    if (!stripe || !elements) return;
    setPending(true);
    setError(null);

    const result = await stripe.confirmPayment({
      elements,
      confirmParams: {
        return_url: `${window.location.origin}/portal/billing?topup=return`,
      },
      redirect: "if_required",
    });

    setPending(false);
    if (result.error) {
      setError(result.error.message ?? "The payment could not be confirmed.");
      return;
    }

    onDone(
      result.paymentIntent?.status === "succeeded"
        ? `Payment confirmed. ${credits.toLocaleString()} credits will appear after webhook verification.`
        : "Payment submitted. Bank payments can remain pending until Stripe confirms settlement.",
    );
  }

  return (
    <div className="space-y-4 border-t border-line p-5 lg:p-6">
      <PaymentElement options={{ layout: "tabs" }} />
      {error ? <p role="alert" className="text-sm text-flag">{error}</p> : null}
      <Button onClick={confirm} disabled={!stripe || !elements || pending}>
        {pending ? "Confirming…" : `Pay $${(credits * CREDIT_VALUE).toLocaleString()}.00`}
        {!pending ? <Icon.ArrowRight size={16} /> : null}
      </Button>
      <p className="text-xs text-muted">
        Payment details go directly to Stripe. Rydlnk never receives or stores card or bank account numbers.
      </p>
    </div>
  );
}

export function TopUpPanel({ companyId }: { companyId: string; connected: boolean }) {
  const [credits, setCredits] = useState(2000);
  const [pending, setPending] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const [clientSecret, setClientSecret] = useState<string | null>(null);

  async function submit() {
    if (!stripePromise) {
      setNotice("Stripe is not configured. Add NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY.");
      return;
    }

    setPending(true);
    setNotice(null);
    setClientSecret(null);
    const supabase = createClient();
    const { data, error } = await supabase.functions.invoke("company-topup", {
      body: { company_id: companyId, credits: Math.round(credits) },
    });
    setPending(false);

    if (error || !data?.client_secret) {
      setNotice(data?.error ?? error?.message ?? "Could not start the Stripe payment.");
      return;
    }
    setClientSecret(data.client_secret);
  }

  return (
    <Panel title="Add credits">
      <div className="grid gap-5 p-5 lg:grid-cols-[1fr_auto] lg:items-end lg:p-6">
        <div>
          <label htmlFor="credits" className="label mb-1.5 block">
            Credits to add
          </label>
          <div className="flex flex-wrap items-center gap-3">
            <input
              id="credits"
              type="number"
              min={100}
              step={100}
              value={credits}
              onChange={(e) => setCredits(Math.max(100, Number(e.target.value) || 100))}
              className="w-40 rounded-sm border border-linestrong px-3.5 py-2.5 text-base focus:border-signal focus:outline-none"
            />
            <span className="nums text-base text-muted">
              = ${(credits * CREDIT_VALUE).toLocaleString()}.00
            </span>
            <span className="flex gap-1.5">
              {[1000, 2500, 5000].map((v) => (
                <button
                  key={v}
                  onClick={() => setCredits(v)}
                  className="rounded-full border border-line px-3 py-1.5 text-xs font-semibold text-muted transition-colors hover:border-signal hover:text-ink"
                >
                  {v.toLocaleString()}
                </button>
              ))}
            </span>
          </div>
          <p className="mt-2.5 text-xs text-muted">
            Credits are posted only after Stripe confirms that the payment settled.
          </p>
        </div>

        <Button onClick={submit} disabled={pending}>
          {pending ? "Working…" : `Add ${credits.toLocaleString()} cr`}
          {!pending ? <Icon.ArrowRight size={16} /> : null}
        </Button>
      </div>

      {notice ? (
        <p role="status" className="flex items-center gap-2.5 border-t border-line px-5 py-3 text-base">
          <Icon.Check size={17} className="text-signal" />
          {notice}
        </p>
      ) : null}

      {clientSecret && stripePromise ? (
        <Elements
          stripe={stripePromise}
          options={{
            clientSecret,
            appearance: { theme: "stripe", variables: { colorPrimary: "#16794a" } },
          }}
        >
          <ConfirmTopUp
            credits={credits}
            onDone={(message) => {
              setNotice(message);
              setClientSecret(null);
            }}
          />
        </Elements>
      ) : null}
    </Panel>
  );
}
