#!/bin/bash
# macOS counterpart of screenshot.sh — same CLI, same output naming, same
# save+clipboard+notify behaviour, built on `screencapture` instead of
# grim/slurp/wl-copy (all Wayland-only).
#
#   screenshot-macos.sh [region|window|fullscreen|edit] [notify|copy|save]
#
#     edit        open the most recent screenshot in the editor (no capture)
#     region      drag a selection (default)
#     window      click a window to capture it
#     fullscreen  every display, no interaction
#
#     notify      save + clipboard + notification (default; `slurp` accepted
#                 as an alias for parity with the Linux script's arg names)
#     copy        clipboard only
#     save        file only, prints the path
#
# Env overrides: SCREENSHOT_DIR, SCREENSHOT_EDITOR.
#
# NOTE: screencapture requires Screen Recording permission. macOS prompts on
# first use — grant it to skhd (System Settings > Privacy & Security > Screen
# Recording), since skhd is the process that spawns this.
set -uo pipefail

OUTPUT_DIR="${SCREENSHOT_DIR:-$HOME/Pictures}"
mkdir -p "$OUTPUT_DIR"

MODE="${1:-region}"
PROCESSING="${2:-notify}"
[[ $PROCESSING == slurp ]] && PROCESSING=notify   # Linux script's default name

# Preview is the built-in stand-in for satty (which is Linux-only).
EDITOR_APP="${SCREENSHOT_EDITOR:-Preview}"

notify() { # notify <title> <message> — best effort
  /usr/bin/osascript -e "display notification \"${2:-}\" with title \"${1}\"" >/dev/null 2>&1 || true
}

# Put a PNG on the clipboard as an image (not as a file path).
copy_png() {
  /usr/bin/osascript -e "set the clipboard to (read (POSIX file \"$1\") as «class PNGf»)" >/dev/null 2>&1
}

if [[ $MODE == edit ]]; then
  LATEST=$(ls -t "$OUTPUT_DIR"/screenshot-*.png 2>/dev/null | head -1)
  [[ -z $LATEST ]] && { notify "Screenshot" "No screenshots to edit"; exit 1; }
  exec open -a "$EDITOR_APP" "$LATEST"
fi

# screencapture flags per mode. -x suppresses the camera sound for the
# non-interactive case; interactive modes keep their normal UI feedback.
case "$MODE" in
  region)     CAP_ARGS=(-i)    ;;   # drag-select a region
  window)     CAP_ARGS=(-i -w) ;;   # click-select a window
  fullscreen) CAP_ARGS=(-x)    ;;
  *) echo "usage: screenshot-macos.sh [region|window|fullscreen|edit] [notify|copy|save]" >&2; exit 1 ;;
esac

FILENAME="screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png"
FILEPATH="$OUTPUT_DIR/$FILENAME"

case "$PROCESSING" in
  notify)
    # screencapture exits 0 even when the user cancels an interactive capture,
    # so test for the file rather than the exit status.
    screencapture "${CAP_ARGS[@]}" "$FILEPATH" || exit 1
    [[ -f $FILEPATH ]] || exit 0        # cancelled
    copy_png "$FILEPATH"
    echo "$FILEPATH"
    notify "Screenshot saved and copied" "Edit with Ctrl + Alt + Shift + S"
    ;;
  copy)
    # -c sends the capture straight to the clipboard, no file involved.
    screencapture "${CAP_ARGS[@]}" -c || exit 1
    ;;
  save)
    screencapture "${CAP_ARGS[@]}" "$FILEPATH" || exit 1
    [[ -f $FILEPATH ]] || exit 0        # cancelled
    echo "$FILEPATH"
    ;;
  *)
    echo "usage: screenshot-macos.sh [region|window|fullscreen|edit] [notify|copy|save]" >&2
    exit 1
    ;;
esac
