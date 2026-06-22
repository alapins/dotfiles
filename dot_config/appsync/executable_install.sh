#!/usr/bin/env bash
# appsync installer: reads apps.yaml and installs every app via the right mechanism
# for the current OS. Idempotent; per-app failures are isolated and reported at the end.
#
#   install.sh            install/update everything
#   APPSYNC_OS=darwin install.sh --dry-run   preview the darwin plan on any machine
#
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$HERE/lib.sh"

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1
run() { if [ "$DRY_RUN" = 1 ]; then printf '   %s+%s %s\n' "$_c_dim" "$_c_reset" "$*"; else eval "$@"; fi; }

OS="$(appsync_os)"
FAILED=()

# Preconditions -------------------------------------------------------------
have yq || { err "yq is required (brew install yq)"; exit 1; }
[ -f "$APPS_YAML" ] || { err "no apps.yaml at $APPS_YAML"; exit 1; }
mkdir -p "$INSTALLERS_DIR" "$STATE_DIR"

log "appsync install — os=$OS  list=$APPS_YAML$([ "$DRY_RUN" = 1 ] && echo '  (dry-run)')"

# brew/cask/mas are batched into one Brewfile for a single `brew bundle`.
BREWFILE="$(mktemp)"
trap 'rm -f "$BREWFILE"' EXIT

add_brew() { printf 'brew "%s"\n' "$1" >>"$BREWFILE"; }
add_cask() { printf 'cask "%s"\n' "$1" >>"$BREWFILE"; }
add_mas()  { printf 'mas "%s", id: %s\n' "$1" "$2" >>"$BREWFILE"; }

# Homebrew token: optional `name:` override, else the app key.
pkgname() { local n; n=$(field "$1" "$OS" name); [ -n "$n" ] && printf '%s' "$n" || printf '%s' "$1"; }

install_flatpak() { # id
  local id=$1
  [ "$OS" = linux ] || { skip "flatpak $id (not linux)"; return 0; }
  if flatpak info "$id" >/dev/null 2>&1; then skip "flatpak $id (present)"; return 0; fi
  run "flatpak install -y --noninteractive flathub \"$id\"" && ok "flatpak $id"
}

install_appimage() { # app : uses `am` name or `url`
  local app=$1 am url
  [ "$OS" = linux ] || { skip "appimage $app (not linux)"; return 0; }
  have appman || { warn "appimage $app: appman not installed yet — skipping"; return 0; }
  am=$(field "$app" "$OS" am); url=$(field "$app" "$OS" url)
  if appman -l 2>/dev/null | grep -qiw "${am:-$app}"; then skip "appimage $app (present)"; return 0; fi
  if [ -n "$am" ]; then run "appman -i \"$am\"" && ok "appimage $am"
  elif [ -n "$url" ]; then run "appman -i \"$url\"" && ok "appimage $app (url)"
  else warn "appimage $app: needs `am:` or `url:`"; return 1; fi
}

install_mise() { # app : spec like aqua:tool / github:o/r / cargo:crate
  local app=$1 spec; spec=$(field "$app" "$OS" spec)
  [ -n "$spec" ] || { warn "mise $app: needs `spec:`"; return 1; }
  have mise || { warn "mise not installed — skipping $app"; return 0; }
  run "mise use -g -y \"$spec\"" && ok "mise $spec"
}

install_npm() { # app : global package via `npm install -g`
  local app=$1 pkg; pkg=$(pkgname "$app")
  have npm || { warn "npm not installed — skipping $app"; return 0; }
  # Presence check on the bare package name: drop a trailing @version but keep a leading scope @.
  local name=$pkg; case ${pkg#@} in *@*) name=${pkg%@*} ;; esac
  if npm ls -g --depth=0 "$name" >/dev/null 2>&1; then skip "npm $pkg (present)"; return 0; fi
  run "npm install -g \"$pkg\"" && ok "npm $pkg"
}

install_remote_script() { # app
  local app=$1 url repo tag dir marker cur args
  url=$(field "$app" "$OS" url); repo=$(field "$app" "$OS" repo)
  args=$(field "$app" "$OS" args)          # optional flags passed to the installer
  [ -n "$url" ] || { warn "remote-script $app: needs `url:`"; return 1; }
  dir="$INSTALLERS_DIR/$app"; marker="$STATE_DIR/$app.tag"; mkdir -p "$dir"
  # If a repo is given, only (re)run when the latest tag changes.
  if [ -n "$repo" ]; then
    tag=$(latest_tag "$repo")
    cur=$([ -f "$marker" ] && cat "$marker" || echo "")
    if [ -n "$tag" ] && [ "$tag" = "$cur" ]; then skip "remote-script $app ($tag present)"; return 0; fi
  fi
  run "curl -fsSL \"$url\" -o \"$dir/install.sh\"" || { err "remote-script $app: download failed"; return 1; }
  run "chmod +x \"$dir/install.sh\""
  run "\"$dir/install.sh\"${args:+ $args}" && ok "remote-script $app" || { err "remote-script $app failed"; return 1; }
  [ -n "${tag:-}" ] && [ "$DRY_RUN" = 0 ] && printf '%s' "$tag" >"$marker"
  return 0
}

install_local_script() { # app
  local app=$1 path; path=$(field "$app" "$OS" path)
  [ -n "$path" ] || { warn "local-script $app: needs `path:`"; return 1; }
  case "$path" in /*) : ;; *) path="$SCRIPTS_DIR/$path" ;; esac
  [ -x "$path" ] || { warn "local-script $app: $path not executable/found"; return 1; }
  run "\"$path\"" && ok "local-script $app"
}

# Main loop -----------------------------------------------------------------
while IFS= read -r app; do
  [ -n "$app" ] || continue
  if ! enabled "$app"; then skip "$app (disabled)"; continue; fi
  via=$(field "$app" "$OS" via)
  if [ -z "$via" ]; then skip "$app (no entry for $OS)"; continue; fi
  ( set -e
    case "$via" in
      brew)          add_brew "$(pkgname "$app")" ;;
      cask)          add_cask "$(pkgname "$app")" ;;
      mas)           add_mas  "$(pkgname "$app")" "$(field "$app" "$OS" id)" ;;
      flatpak)       install_flatpak "$(field "$app" "$OS" id)" ;;
      image)         skip "$app (provided by OS image)" ;;
      appimage)      install_appimage "$app" ;;
      mise)          install_mise "$app" ;;
      npm)           install_npm "$app" ;;
      remote-script) install_remote_script "$app" ;;
      local-script)  install_local_script "$app" ;;
      *)             warn "$app: unknown via '$via'" ; exit 1 ;;
    esac
  ) || FAILED+=("$app")
done < <(apps_list)

# Apply the batched Brewfile -------------------------------------------------
if [ -s "$BREWFILE" ]; then
  log "brew bundle ($(grep -c . "$BREWFILE") entries)"
  if [ "$DRY_RUN" = 1 ]; then
    sed 's/^/   + /' "$BREWFILE"
  elif have brew; then
    brew bundle --file="$BREWFILE" || FAILED+=("brew-bundle")
  else
    warn "brew not installed — skipped Brewfile"
  fi
fi

# Summary --------------------------------------------------------------------
if [ "${#FAILED[@]}" -gt 0 ]; then
  err "completed with failures: ${FAILED[*]}"
  exit 1
fi
ok "appsync install complete"
