#!/usr/bin/env bash
# appsync updater — handles ONLY the layers Aurora's `uupd` does not cover:
# mise tools, AppMan AppImages, and remote/local install scripts.
#
# Linux: invoked by the extended `ujust update` recipe AFTER uupd has updated the
#        OS image / flatpaks / brew. We deliberately do NOT touch those here.
# macOS: no uupd — run a full `topgrade` (brew/cask/mas/mise + custom) instead.
#
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$HERE/lib.sh"

OS="$(appsync_os)"

if [ "$OS" = darwin ]; then
  log "appsync update (macOS) — full topgrade"
  if have topgrade; then topgrade; else
    warn "topgrade missing; falling back to brew + mise"
    have brew && brew upgrade
    have mise && mise upgrade
  fi
  exit $?
fi

# ---- Linux: gaps only (uupd owns OS/flatpak/brew) ----
log "appsync update (Linux) — mise, AppImages, scripts"

if have mise; then log "mise upgrade"; mise upgrade || warn "mise upgrade had errors"; fi
if have appman; then log "appman update"; appman -u -y || warn "appman update had errors"; fi
if have rustup; then log "rustup update"; rustup update || warn "rustup update had errors"; fi

# Re-run remote/local script installers. install.sh re-checks GitHub tags and only
# re-runs a remote-script when its repo has a newer release (idempotent otherwise).
log "re-checking script-based installers"
"$HERE/install.sh" || warn "script installers reported issues"

ok "appsync update complete"
