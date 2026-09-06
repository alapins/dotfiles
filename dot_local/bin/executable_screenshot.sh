#!/usr/bin/env bash
# Omarchy-style screenshot for COSMIC — adapted from omarchy-capture-screenshot
# (https://github.com/omacom/omarchy). slurp picks a region, grim captures it,
# the file lands in Pictures and on the clipboard, and a notification offers
# click-to-edit in satty.
#
# Differences from the Hyprland original: no hyprpicker screen-freeze and no
# window-snapping "smart" mode (both need Hyprland IPC); "output" mode uses
# slurp's own monitor picker instead of hyprctl geometry.
#
#   screenshot.sh [region|output|fullscreen|edit] [slurp|copy|save]
#
#     edit        open the most recent screenshot in satty (no capture);
#                 COSMIC notifications don't support action buttons, so this
#                 replaces Omarchy's click-to-edit (bound to Super+Alt+S)
#
#     region      freeform selection (default)
#     output      click a monitor to capture it whole
#     fullscreen  every monitor, no interaction
#
#     slurp       save + clipboard + notification with edit action (default)
#     copy        clipboard only
#     save        file only, prints the path
#
# Env overrides: SCREENSHOT_DIR, SCREENSHOT_EDITOR.
set -uo pipefail

# When spawned from a COSMIC keyboard shortcut, stdin is a never-closing pipe
# from cosmic-comp — and slurp reads predefined boxes from stdin whenever it
# isn't a TTY, blocking forever before it even maps its overlay. /dev/null
# gives it instant EOF instead.
exec </dev/null

export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"

[[ -f ~/.config/user-dirs.dirs ]] && source ~/.config/user-dirs.dirs
OUTPUT_DIR="${SCREENSHOT_DIR:-${XDG_PICTURES_DIR:-$HOME/Pictures}}"
mkdir -p "$OUTPUT_DIR"

# Pressing the shortcut again while the picker is up cancels it (as in omarchy).
pkill -x slurp && exit 0

MODE="${1:-region}"
PROCESSING="${2:-slurp}"
# The mise shim for satty is unusable here: ~/.local/bin/mise is a wrapper
# script, so the shim loses its argv[0] and runs mise itself. Resolve the
# real binary through `mise which` instead.
EDITOR_BIN="${SCREENSHOT_EDITOR:-$(mise which satty 2>/dev/null || command -v satty || true)}"

if [[ $MODE == edit ]]; then
  [[ -z $EDITOR_BIN ]] && { notify-send --app-name=Screenshot "Screenshot editor not found" 2>/dev/null; exit 1; }
  LATEST=$(ls -t "$OUTPUT_DIR"/screenshot-*.png 2>/dev/null | head -1)
  [[ -z $LATEST ]] && { notify-send --app-name=Screenshot "No screenshots to edit" 2>/dev/null; exit 1; }
  exec "$EDITOR_BIN" --filename "$LATEST" \
    --output-filename "${LATEST%.png}-annotated.png" \
    --early-exit --copy-command wl-copy
fi

case "$MODE" in
  region)     SELECTION=$(slurp 2>/dev/null) || exit 0 ;;
  output)     SELECTION=$(slurp -o -r 2>/dev/null) || exit 0 ;;
  fullscreen) SELECTION="" ;;
  *) echo "usage: screenshot.sh [region|output|fullscreen] [slurp|copy|save]" >&2; exit 1 ;;
esac

capture() { # capture <target> — target "-" for stdout or a file path
  if [[ -n $SELECTION ]]; then
    grim -g "$SELECTION" "$1"
  else
    grim "$1"
  fi
}

FILENAME="screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png"
FILEPATH="$OUTPUT_DIR/$FILENAME"

case "$PROCESSING" in
  slurp)
    capture "$FILEPATH" || exit 1
    wl-copy --type image/png <"$FILEPATH"
    echo "$FILEPATH"

    # Best-effort: the shot is already saved and on the clipboard. COSMIC's
    # notification daemon doesn't render action buttons, so point at the
    # edit shortcut instead of offering a click target.
    notify-send --app-name=Screenshot \
      --icon "$FILEPATH" \
      "Screenshot saved and copied" "Edit with Super + Alt + S" 2>/dev/null || true
    ;;
  copy)
    capture - | wl-copy --type image/png
    ;;
  save)
    capture "$FILEPATH" || exit 1
    echo "$FILEPATH"
    ;;
esac
