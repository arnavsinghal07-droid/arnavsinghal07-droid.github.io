#!/usr/bin/env bash
#
# deploy.sh — put the portfolio live at https://arnavsinghal07-droid.github.io
#
#   cd ~/Desktop/site && ./deploy.sh
#
# Run it again any time you rebuild the site; it re-copies the built files,
# commits and pushes. Nothing here force-pushes or rewrites history.

set -euo pipefail

USER_NAME="arnavsinghal07-droid"
REPO="$USER_NAME.github.io"
SRC="$HOME/Desktop/portfolio-site"
HERE="$(cd "$(dirname "$0")" && pwd)"

GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; DIM=$'\033[2m'; OFF=$'\033[0m'
ok()   { printf '%s✓%s %s\n' "$GREEN" "$OFF" "$*"; }
warn() { printf '%s!%s %s\n' "$YELLOW" "$OFF" "$*"; }
bad()  { printf '%s✗%s %s\n' "$RED" "$OFF" "$*"; }

cd "$HERE"

# ── refresh from the build ─────────────────────────────────────────────────
if [ -f "$SRC/arnav-singhal.html" ]; then
  cp "$SRC/arnav-singhal.html" index.html
  cp "$SRC/photo-culler.html"  photo-culler.html
  cp "$SRC/review-radar.html"  review-radar.html
  if [ -d "$SRC/clips" ]; then
    mkdir -p clips
    find "$SRC/clips" -maxdepth 1 -type f \( -name '*.mp4' -o -name '*.webm' \) -exec cp {} clips/ \; 2>/dev/null || true
    n="$(find clips -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')"
    [ "$n" != "0" ] && ok "copied $n clip(s)"
  fi
  ok "copied the latest build from portfolio-site"
else
  warn "no build found at $SRC — pushing whatever is already in this folder"
fi
touch .nojekyll

# ── guard rail: nothing oversized, nothing secret ──────────────────────────
big="$(find . -path ./.git -prune -o -type f -size +90M -print || true)"
if [ -n "$big" ]; then
  bad "files over 90MB — GitHub will reject these:"; printf '    %s\n' $big; exit 1
fi
if ls .env .env.* >/dev/null 2>&1; then
  bad "there is an .env in this folder — remove it before pushing"; exit 1
fi

total="$(du -sh . 2>/dev/null | cut -f1)"
printf '%s   site size: %s%s\n' "$DIM" "$total" "$OFF"

# ── commit ─────────────────────────────────────────────────────────────────
[ -d .git ] || git init -q -b main
git add -A
if git diff --cached --quiet; then
  ok "nothing changed since the last deploy"
else
  git commit -q -m "Update site — $(date '+%Y-%m-%d %H:%M')"
  ok "committed"
fi

# ── remote ─────────────────────────────────────────────────────────────────
if ! git remote get-url origin >/dev/null 2>&1; then
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    gh repo create "$USER_NAME/$REPO" --public --source=. --remote=origin \
      --description "Personal site — arnavsinghal07-droid.github.io"
    ok "created $USER_NAME/$REPO"
  else
    git remote add origin "https://github.com/$USER_NAME/$REPO.git"
    warn "no authenticated GitHub CLI."
    printf '%s  Create an EMPTY repo named exactly %s at https://github.com/new%s\n' "$DIM" "$REPO" "$OFF"
    printf '%s  (no README, no .gitignore, no license), then re-run this script.%s\n' "$DIM" "$OFF"
  fi
fi

# ── pick up anything changed on GitHub's side first ────────────────────────
# Setting a custom domain in the Pages UI commits a CNAME file directly to the
# repo, so the remote can be ahead of this folder.
if git remote get-url origin >/dev/null 2>&1; then
  if git fetch -q origin main 2>/dev/null && ! git merge-base --is-ancestor origin/main HEAD 2>/dev/null; then
    if git rebase -q origin/main 2>/dev/null; then
      ok "rebased onto changes made on GitHub"
    else
      git rebase --abort 2>/dev/null || true
      bad "the remote has changes that conflict with this folder."
      bad "run: git pull --rebase origin main   then re-run this script"
      exit 1
    fi
  fi
fi

# ── push ───────────────────────────────────────────────────────────────────
if git push -u origin main; then
  ok "pushed"
  echo
  ok "Live in a minute or two at:"
  echo "   https://$USER_NAME.github.io"
  echo "   https://$USER_NAME.github.io/photo-culler.html"
  echo "   https://$USER_NAME.github.io/review-radar.html"
  echo
  printf '%s   First deploy only: check Settings → Pages shows "main / (root)".%s\n' "$DIM" "$OFF"
else
  bad "push failed — create the repo at https://github.com/new first, then re-run"
  exit 1
fi
