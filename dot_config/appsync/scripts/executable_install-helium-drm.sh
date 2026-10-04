#!/usr/bin/env bash
# appsync local-script: give the Helium AppImage working Widevine DRM via
# vikas5914/helium-drm-fixer, which copies Chrome's WidevineCdm into Helium's
# profile (<profile>/WidevineCdm/<version>/ + the component-updater hint file).
#
# The CDM lives in the profile, not the AppImage, so Helium upgrades don't undo
# it. Runs on every install.sh / update.sh pass (update.sh calls install.sh after
# `appman -u`) and is a no-op unless Chrome's Widevine version isn't in Helium yet.
#
# Pinned to a reviewed commit — bump FIXER_REF deliberately after reading the diff.
set -euo pipefail

FIXER_REPO="https://github.com/vikas5914/helium-drm-fixer"
FIXER_REF="${HELIUM_DRM_FIXER_REF:-9a31ccd}"
src="${XDG_DATA_HOME:-$HOME/.local/share}/appsync/installers/helium-drm-fixer"
profile="${XDG_CONFIG_HOME:-$HOME/.config}/net.imput.helium"
helium_dir="$HOME/Applications/helium"          # AppMan install dir
chrome_cdm="/opt/google/chrome/WidevineCdm"     # google-chrome from the image

say() { echo "install-helium-drm: $*"; }

[ -x "$helium_dir/helium" ] || { say "Helium not installed — skipping"; exit 0; }
# "Local State" (not just the dir) — chezmoi creates the dir for the KeePassXC manifest.
[ -f "$profile/Local State" ] || { say "launch Helium once to create its profile, then re-run"; exit 0; }
[ -f "$chrome_cdm/manifest.json" ] || { say "no Chrome WidevineCdm at $chrome_cdm — skipping"; exit 0; }

ver="$(yq -r .version "$chrome_cdm/manifest.json")"
if [ -f "$profile/WidevineCdm/$ver/manifest.json" ] \
   && [ -f "$profile/WidevineCdm/latest-component-updated-widevine-cdm" ]; then
  say "Widevine $ver already in Helium profile"
  exit 0
fi

command -v bun >/dev/null || { say "bun not found (appsync installs it via npm)"; exit 1; }

if [ -d "$src/.git" ]; then
  git -C "$src" fetch -q origin
else
  git clone -q "$FIXER_REPO" "$src"
fi
git -C "$src" checkout -q --detach "$FIXER_REF"
(cd "$src" && bun install --frozen-lockfile >/dev/null)

say "copying Chrome Widevine $ver into Helium"
# --helium-path only bypasses the fixer's system-package detection (it doesn't know
# AppImages); on Linux the copy target is always the profile dir found above.
(cd "$src" && bun run cli.ts --chrome-path "$chrome_cdm" --helium-path "$helium_dir")
say "done — restart Helium for DRM to take effect"
