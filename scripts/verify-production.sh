#!/usr/bin/env bash
#
# Probes a live Rydlnk deployment for the two launch blockers found on
# 2026-07-29 and reports whether each is still open.
#
#   ./scripts/verify-production.sh                    # uses .env.local
#   SUPABASE_URL=… SUPABASE_ANON_KEY=… ./scripts/verify-production.sh
#
# Uses the publishable key only, because the question is what an anonymous
# visitor can reach. PostgREST's OpenAPI document would be a tidier oracle, but
# Supabase rejects it for publishable keys ("Only secret API keys can be used
# for this endpoint"), and reading it with a secret key would answer a different
# question.
#
# So each privileged function is probed directly, and the check is fail-closed:
# a pass requires PostgREST to return exactly 42501 / "permission denied for
# function". Absence of a string is never read as safety — a network failure, an
# empty response or an unexpected status all fail. That distinction matters: an
# earlier revision inferred safety from an empty document and reported every
# security check green while having fetched nothing.
#
# Arguments are chosen so that a function which IS still exposed does nothing:
# ids that cannot match a row, and a statement period in the year 2000. Each was
# checked against the function body in migrations 014-017. There is no way to
# ask "may I call this?" without calling it, so the arguments carry the safety.
#
# Exits non-zero if any blocker is still open, so CI can gate a release on it.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/.env.local}"

if [[ -z "${SUPABASE_URL:-}" && -f "$ENV_FILE" ]]; then
  SUPABASE_URL=$(grep -E '^NEXT_PUBLIC_SUPABASE_URL=' "$ENV_FILE" | cut -d= -f2- | tr -d '"'"'"' \r')
  SUPABASE_ANON_KEY=$(grep -E '^NEXT_PUBLIC_SUPABASE_ANON_KEY=' "$ENV_FILE" | cut -d= -f2- | tr -d '"'"'"' \r')
fi

if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_ANON_KEY:-}" ]]; then
  echo "Set SUPABASE_URL and SUPABASE_ANON_KEY, or provide $ENV_FILE" >&2
  exit 2
fi

URL="${SUPABASE_URL%/}"
FAIL=0
PASS=0
Z=00000000-0000-0000-0000-000000000000

red()   { printf '\033[31m%s\033[0m' "$1"; }
green() { printf '\033[32m%s\033[0m' "$1"; }
dim()   { printf '\033[2m%s\033[0m'  "$1"; }

rpc() { # name, json → prints "<http_code>\t<body>"
  curl -s --max-time 20 -w '\n%{http_code}' -X POST "$URL/rest/v1/rpc/$1" \
    -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
    -H 'Content-Type: application/json' -d "$2"
}

# ── Preflight ───────────────────────────────────────────────────────────────
# Nothing below can be trusted if the API is not answering, so establish that
# first against a table that is known to be readable by anon.

echo
echo "Reachability"
echo "────────────"
pre=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 \
  "$URL/rest/v1/companies?select=id&limit=1" \
  -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $SUPABASE_ANON_KEY")
if [[ "$pre" != "200" ]]; then
  printf '  %s %s\n' "$(red '✗')" "$(red "PostgREST returned $pre for a known-readable table — aborting")"
  echo "    Every check below would be meaningless. Check the URL and key." >&2
  exit 2
fi
printf '  %s %-30s %s\n' "$(green '✓')" "PostgREST" "$(dim 'reachable with the publishable key')"

# ── Blocker 1: edge functions deployed AND gated ────────────────────────────
# An undeployed function answers 404 NOT_FOUND. A deployed one answers 401/400.
#
# A 200 from a function in PRIVATE below is a finding, not a pass. This probe
# used to treat any non-404 as success, and charge-weekly answered 200 to an
# unauthenticated POST — which means the probe itself executed a rider billing
# run. It charged nothing only because no cards were on file. A private endpoint
# that returns 200 to this call is unguarded by definition, so it now fails.

# Reachable without credentials by design (signature- or body-validated).
PUBLIC_FUNCTIONS=(stripe-webhook send-push)
# Must refuse an unauthenticated call. These move money or read private data.
PRIVATE_FUNCTIONS=(
  send-company-invite company-topup stripe-setup-intent charge-weekly
  health admin-set-user-status admin-refund-topup hris-offboard
  billing-notify auth-email
)
FUNCTIONS=("${PUBLIC_FUNCTIONS[@]}" "${PRIVATE_FUNCTIONS[@]}")

is_private() {
  local needle="$1" f
  for f in "${PRIVATE_FUNCTIONS[@]}"; do [ "$f" = "$needle" ] && return 0; done
  return 1
}

echo
echo "Edge function deployment"
echo "────────────────────────"
for fn in "${FUNCTIONS[@]}"; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 -X POST "$URL/functions/v1/$fn" \
    -H "apikey: $SUPABASE_ANON_KEY" -H 'Content-Type: application/json' -d '{}')
  case "$code" in
    404) printf '  %s %-24s %s\n' "$(red '✗')" "$fn" "$(dim 'not deployed')"; FAIL=$((FAIL + 1)) ;;
    000) printf '  %s %-24s %s\n' "$(red '✗')" "$fn" "$(red 'no response')";  FAIL=$((FAIL + 1)) ;;
    200|201|204)
      if is_private "$fn"; then
        printf '  %s %-24s %s\n' "$(red '✗')" "$fn" \
          "$(red "UNGATED — ran on an unauthenticated call (HTTP $code)")"
        FAIL=$((FAIL + 1))
      else
        printf '  %s %-24s %s\n' "$(green '✓')" "$fn" "$(dim "live (HTTP $code)")"
        PASS=$((PASS + 1))
      fi ;;
    *)   printf '  %s %-24s %s\n' "$(green '✓')" "$fn" "$(dim "live (HTTP $code)")"; PASS=$((PASS + 1)) ;;
  esac
done

# ── Blocker 2: privileged functions are not anon-callable ───────────────────

denied() { # name, no-op args, what exposure would mean
  local fn="$1" body="$2" desc="$3" out code payload
  out=$(rpc "$fn" "$body")
  code=$(tail -n1 <<<"$out")
  payload=$(sed '$d' <<<"$out")

  # Fail-closed: only this exact pair is a pass.
  if [[ "$code" == "401" || "$code" == "403" ]] && grep -q '"42501"' <<<"$payload"; then
    printf '  %s %-30s %s\n' "$(green '✓')" "$fn" "$(dim 'denied to anon (42501)')"
    PASS=$((PASS + 1))
    return
  fi

  if [[ "$code" == "404" ]] && grep -q 'PGRST202' <<<"$payload"; then
    # Signature drifted from this script. Not a finding, but nothing was proven,
    # so it must not be counted as a pass.
    printf '  %s %-30s %s\n' "$(red '✗')" "$fn" \
      "$(red 'signature not found — probe proved nothing, fix this script')"
    FAIL=$((FAIL + 1))
    return
  fi

  printf '  %s %-30s %s\n' "$(red '✗')" "$fn" "$(red "REACHABLE (HTTP $code) — $desc")"
  FAIL=$((FAIL + 1))
}

echo
echo "Privileged function grants"
echo "──────────────────────────"
denied settle_topup '{"p_stripe_pi":"pi_verify_nonexistent"}' \
  'credits a company float with no payment behind it'
denied generate_company_statements '{"p_period_start":"2000-01-01","p_period_end":"2000-01-02"}' \
  'rewrites statements for every company'
denied finish_stripe_event '{"p_event_id":"evt_verify_nonexistent","p_error":null}' \
  'marks a Stripe webhook event complete'
denied claim_stripe_event '{"p_event_id":"evt_verify_nonexistent","p_event_type":"probe"}' \
  'claims an event id and starves the real webhook'
denied recompute_trip_fares "{\"p_trip\":\"$Z\"}" \
  'rewrites trip fares'
denied benefit_headroom "{\"p_company\":\"$Z\",\"p_user\":\"$Z\"}" \
  'discloses benefit headroom for any company'
denied trip_occupancy "{\"p_trip\":\"$Z\"}" \
  'discloses trip occupancy'
# Migration 026. Reads auth.users, so exposure would enumerate staff addresses.
denied billing_recipients "{\"p_company\":\"$Z\"}" \
  'enumerates staff email addresses for any company'
denied companies_low_float '{}' \
  'lists every company float balance'

# ── The grant that must stay ────────────────────────────────────────────────
# Over-revoking is its own outage: /invite/[token] renders the company name
# before the recipient signs in, so this one has to answer.

echo
echo "Intentionally public"
echo "────────────────────"
out=$(rpc company_invite_preview '{"p_token":"verify-probe"}')
code=$(tail -n1 <<<"$out")
if [[ "$code" == "200" ]]; then
  printf '  %s %-30s %s\n' "$(green '✓')" "company_invite_preview" "$(dim 'anon can still preview an invite')"
  PASS=$((PASS + 1))
else
  printf '  %s %-30s %s\n' "$(red '✗')" "company_invite_preview" \
    "$(red "HTTP $code — over-revoked; invite acceptance is broken")"
  FAIL=$((FAIL + 1))
fi

echo
if (( FAIL > 0 )); then
  echo "$(red "✗ $FAIL check(s) failed"), $PASS passed — not ready to launch"
  exit 1
fi
echo "$(green "✓ all $PASS checks passed")"
