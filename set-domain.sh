#!/usr/bin/env bash
#
# set-domain.sh — point the site at a custom domain you own.
#
#   cd ~/Desktop/site && ./set-domain.sh arnavsinghal.com
#
# Run this only AFTER you have bought the domain and set its DNS records
# (see the DNS section below). Running it before DNS resolves will take the
# site offline until DNS catches up, because GitHub starts redirecting
# arnavsinghal07-droid.github.io to the custom domain immediately.
#
# What it does:
#   1. writes the CNAME file GitHub Pages reads
#   2. repoints the two demo buttons inside the site at the new domain
#   3. rebuilds and deploys
#
# DNS records to create at your registrar first:
#   A     @     185.199.108.153
#   A     @     185.199.109.153
#   A     @     185.199.110.153
#   A     @     185.199.111.153
#   CNAME www   arnavsinghal07-droid.github.io.
#
# Then, once this script has run: GitHub repo → Settings → Pages → tick
# "Enforce HTTPS". The certificate takes a few minutes to issue.

set -euo pipefail

DOMAIN="${1:-}"
SRC="$HOME/Desktop/portfolio-site"
HERE="$(cd "$(dirname "$0")" && pwd)"

GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; DIM=$'\033[2m'; OFF=$'\033[0m'
ok()   { printf '%s✓%s %s\n' "$GREEN" "$OFF" "$*"; }
warn() { printf '%s!%s %s\n' "$YELLOW" "$OFF" "$*"; }
bad()  { printf '%s✗%s %s\n' "$RED" "$OFF" "$*"; }

if [ -z "$DOMAIN" ]; then
  bad "usage: ./set-domain.sh yourdomain.com"; exit 1
fi
if ! printf '%s' "$DOMAIN" | grep -Eq '^[a-z0-9.-]+\.[a-z]{2,}$'; then
  bad "that does not look like a bare domain (no https://, no trailing slash)"; exit 1
fi

# ── is the DNS actually pointing here yet? ─────────────────────────────────
ips="$(dig +short A "$DOMAIN" 2>/dev/null || true)"
if printf '%s' "$ips" | grep -q '185.199.10[89].153\|185.199.11[01].153'; then
  ok "$DOMAIN already resolves to GitHub Pages"
else
  warn "$DOMAIN does not resolve to GitHub Pages yet."
  printf '%s   Found: %s%s\n' "$DIM" "${ips:-nothing}" "$OFF"
  printf '%s   Set the four A records listed at the top of this script, wait for%s\n' "$DIM" "$OFF"
  printf '%s   them to propagate, then re-run. Continuing now will make the site%s\n' "$DIM" "$OFF"
  printf '%s   unreachable until they do.%s\n' "$DIM" "$OFF"
  printf 'Continue anyway? [y/N] '
  read -r reply
  case "$reply" in [yY]*) ;; *) echo "stopped."; exit 0 ;; esac
fi

# ── 1. the CNAME file ──────────────────────────────────────────────────────
printf '%s\n' "$DOMAIN" > "$HERE/CNAME"
ok "wrote CNAME → $DOMAIN"

# ── 2. repoint the demo buttons ────────────────────────────────────────────
if [ -f "$SRC/template.html" ]; then
  python3 - "$SRC/template.html" "$DOMAIN" <<'PY'
import re, sys
path, domain = sys.argv[1], sys.argv[2]
s = open(path, encoding='utf-8').read()
before = s
for page in ("photo-culler.html", "review-radar.html"):
    s = re.sub(r'url:"https://[^"]*/' + re.escape(page) + '"',
               'url:"https://%s/%s"' % (domain, page), s)
if s != before:
    open(path, 'w', encoding='utf-8').write(s)
    print("   demo links now point at %s" % domain)
else:
    print("   demo links already correct")
PY
  ( cd "$SRC" && python3 build.py )
  ok "rebuilt"
else
  warn "no template.html at $SRC — skipping the rebuild"
fi

# ── 3. deploy ──────────────────────────────────────────────────────────────
"$HERE/deploy.sh"

echo
ok "Now open the repo's Settings → Pages and tick \"Enforce HTTPS\"."
echo "   https://github.com/arnavsinghal07-droid/arnavsinghal07-droid.github.io/settings/pages"
