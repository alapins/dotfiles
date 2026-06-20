#!/usr/bin/env bash
# appsync shared helpers. Sourced by install.sh and update.sh.
# No side effects on source beyond defining vars/functions.

# --- paths -------------------------------------------------------------------
APPSYNC_CONFIG_DIR="${APPSYNC_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/appsync}"
APPSYNC_DATA_DIR="${APPSYNC_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/appsync}"
APPS_YAML="${APPS_YAML:-$APPSYNC_CONFIG_DIR/apps.yaml}"
SCRIPTS_DIR="$APPSYNC_CONFIG_DIR/scripts"
INSTALLERS_DIR="$APPSYNC_DATA_DIR/installers"   # one download tree, per-app subdirs
STATE_DIR="$APPSYNC_DATA_DIR/state"             # records remote-script versions

# --- logging -----------------------------------------------------------------
if [ -t 1 ]; then
  _c_blue=$'\033[34m'; _c_green=$'\033[32m'; _c_yellow=$'\033[33m'
  _c_red=$'\033[31m'; _c_dim=$'\033[2m'; _c_reset=$'\033[0m'
else
  _c_blue=; _c_green=; _c_yellow=; _c_red=; _c_dim=; _c_reset=
fi
log()  { printf '%s==>%s %s\n'  "$_c_blue"  "$_c_reset" "$*"; }
ok()   { printf '%s  ok%s %s\n' "$_c_green" "$_c_reset" "$*"; }
skip() { printf '%s skip%s %s\n' "$_c_dim"  "$_c_reset" "$*"; }
warn() { printf '%s warn%s %s\n' "$_c_yellow" "$_c_reset" "$*" >&2; }
err()  { printf '%s err%s %s\n'  "$_c_red"   "$_c_reset" "$*" >&2; }

have() { command -v "$1" >/dev/null 2>&1; }

# --- os ----------------------------------------------------------------------
# APPSYNC_OS may be overridden (e.g. APPSYNC_OS=darwin) for dry-run testing.
appsync_os() {
  if [ -n "${APPSYNC_OS:-}" ]; then printf '%s' "$APPSYNC_OS"; return; fi
  case "$(uname -s)" in
    Linux)  printf 'linux'  ;;
    Darwin) printf 'darwin' ;;
    *)      printf 'unknown';;
  esac
}

# --- yaml access -------------------------------------------------------------
# List app names.
apps_list() { yq -r '.apps | keys | .[]' "$APPS_YAML"; }

# field <app> <os> <key>
# Returns top-level value if present, else the os-scoped value, else empty.
field() {
  local app=$1 os=$2 key=$3 v
  v=$(yq -r ".apps.\"$app\".\"$key\"" "$APPS_YAML" 2>/dev/null)
  if [ "$v" = "null" ] || [ -z "$v" ]; then
    v=$(yq -r ".apps.\"$app\".\"$os\".\"$key\"" "$APPS_YAML" 2>/dev/null)
  fi
  [ "$v" = "null" ] && v=""
  printf '%s' "$v"
}

# enabled <app> : honor optional `enabled: false`
enabled() {
  local app=$1 v
  v=$(yq -r ".apps.\"$app\".enabled" "$APPS_YAML" 2>/dev/null)
  [ "$v" = "false" ] && return 1
  return 0
}

# latest GitHub release tag for owner/repo (empty on failure)
latest_tag() {
  local repo=$1
  have gh && gh release view --repo "$repo" --json tagName -q .tagName 2>/dev/null && return
  # fallback to public API without auth
  if have curl; then
    curl -fsSL "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null \
      | yq -r '.tag_name' 2>/dev/null
  fi
}
