#!/usr/bin/env bash
#
# Deploys rydlnk.us to the shared server at 13.247.190.131.
#
#   ./scripts/deploy-to-server.sh              # build, ship, reload
#   ./scripts/deploy-to-server.sh --no-build   # ship the existing .next
#   ./scripts/deploy-to-server.sh --dry-run    # show what would transfer
#
# Builds LOCALLY and ships the artefact. The server has 1.9G of RAM and already
# runs nginx, MariaDB, Redis, PHP-FPM and two other Node apps; `next build` peaks
# well above what is free there, and an OOM mid-build would take the other sites
# down with it. Building here also keeps the toolchain off the box entirely.
#
# Ships `.next/standalone`, which is ~123M rather than the ~760M of node_modules
# the full build would need. That matters on a 15G volume at 76%.

set -euo pipefail

SERVER_IP="${SERVER_IP:-13.247.190.131}"
SERVER_USER="${SERVER_USER:-ubuntu}"
SSH="${SERVER_USER}@${SERVER_IP}"

APP="rydlnk.us"
REMOTE="/var/www/${APP}"
PORT="${PORT:-3002}"
PM2_NAME="rydlnk"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUILD=1
DRY=""
for arg in "$@"; do
  case "$arg" in
    --no-build) BUILD=0 ;;
    --dry-run)  DRY="--dry-run" ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

step() { printf '\n\033[1;32m▸\033[0m \033[1m%s\033[0m\n' "$1"; }
fail() { printf '\033[31m✗ %s\033[0m\n' "$1" >&2; exit 1; }

# ── Preflight ───────────────────────────────────────────────────────────────

step "Preflight"
[ -f .env.production.local ] || fail ".env.production.local is missing — the build would bake localhost:3000 into every canonical URL"
ssh -o ConnectTimeout=8 -o BatchMode=yes "$SSH" 'echo ok' >/dev/null 2>&1 || fail "cannot reach $SSH over SSH"
echo "  SSH to $SSH ok"

# ── Build ───────────────────────────────────────────────────────────────────

if [ "$BUILD" = "1" ]; then
  step "Building (NODE_ENV=production)"
  rm -rf .next
  NODE_ENV=production npm run build
fi

[ -f .next/standalone/server.js ] || fail "no .next/standalone/server.js — is output:'standalone' still set in next.config.ts?"

# The check that would have caught the bug this script was written after: every
# NEXT_PUBLIC_* value is inlined at build time, so a wrong origin is baked into
# the artefact and no amount of runtime config fixes it. Assert on the rendered
# sitemap, which is the cheapest place the mistake becomes visible.
step "Verifying the baked-in origin"
SITEMAP=".next/standalone/.next/server/app/sitemap.xml.body"
[ -f "$SITEMAP" ] || fail "sitemap not found at $SITEMAP"
grep -q "https://rydlnk.us" "$SITEMAP" || fail "sitemap does not contain https://rydlnk.us — check NEXT_PUBLIC_SITE_URL precedence"
if grep -q "localhost" "$SITEMAP"; then
  fail "sitemap still contains localhost — .env.local is probably beating .env.production.local"
fi
echo "  sitemap resolves to https://rydlnk.us"

# ── Transfer ────────────────────────────────────────────────────────────────
# Three separate trees because standalone deliberately excludes the last two:
# they are meant to come from a CDN, and nginx plays that role here.

step "Transferring"
ssh "$SSH" "sudo -n mkdir -p ${REMOTE} && sudo -n chown -R ${SERVER_USER}:${SERVER_USER} ${REMOTE}"

rsync -az --delete $DRY --info=stats1 \
  .next/standalone/ "${SSH}:${REMOTE}/"
rsync -az --delete $DRY --info=stats1 \
  .next/static/ "${SSH}:${REMOTE}/.next/static/"
rsync -az --delete $DRY --info=stats1 \
  public/ "${SSH}:${REMOTE}/public/"

if [ -n "$DRY" ]; then
  step "Dry run complete — nothing was changed"
  exit 0
fi

# Runtime env. Only values actually read at runtime; the NEXT_PUBLIC_* ones are
# already inlined in the bundle and are listed here purely so a server-side
# render that reads process.env at request time sees the same thing.
step "Writing runtime env"
scp -q .env.production.local "${SSH}:${REMOTE}/.env.production"
ssh "$SSH" "chmod 600 ${REMOTE}/.env.production"

# ── Start / reload ──────────────────────────────────────────────────────────

step "Starting under pm2"
ssh "$SSH" bash -s <<REMOTE_SCRIPT
set -euo pipefail
cd ${REMOTE}

if pm2 describe ${PM2_NAME} >/dev/null 2>&1; then
  # reload, not restart: pm2 brings the new process up before retiring the old
  # one, so a deploy does not drop in-flight requests.
  PORT=${PORT} HOSTNAME=127.0.0.1 NODE_ENV=production pm2 reload ${PM2_NAME} --update-env
  echo "  reloaded ${PM2_NAME}"
else
  PORT=${PORT} HOSTNAME=127.0.0.1 NODE_ENV=production \\
    pm2 start server.js --name ${PM2_NAME} --cwd ${REMOTE}
  echo "  started ${PM2_NAME}"
fi
pm2 save >/dev/null 2>&1 || true
REMOTE_SCRIPT

# ── Verify ──────────────────────────────────────────────────────────────────

step "Verifying"
sleep 3
for attempt in 1 2 3 4 5; do
  code=$(ssh "$SSH" "curl -s -o /dev/null -w '%{http_code}' --max-time 8 http://127.0.0.1:${PORT}/ || true")
  [ "$code" = "200" ] && break
  sleep 3
done

if [ "$code" != "200" ]; then
  printf '\033[31m✗ app on 127.0.0.1:%s returned %s\033[0m\n' "$PORT" "$code" >&2
  ssh "$SSH" "pm2 logs ${PM2_NAME} --lines 25 --nostream --no-color" >&2 || true
  exit 1
fi
echo "  node on 127.0.0.1:${PORT} → 200"

# Through nginx, by Host header, so this works before DNS points here.
nginx_code=$(ssh "$SSH" "curl -s -o /dev/null -w '%{http_code}' --max-time 8 -H 'Host: rydlnk.us' http://127.0.0.1/ || true")
echo "  nginx (Host: rydlnk.us) → ${nginx_code}"

printf '\n\033[1;32m✓ deployed\033[0m  %s → %s:%s\n' "$APP" "$SERVER_IP" "$PORT"
