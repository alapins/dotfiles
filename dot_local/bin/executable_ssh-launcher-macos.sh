#!/bin/bash
# macOS equivalent of ssh-launcher.sh (Ctrl+Alt+S, via skhd).
#
# The Linux version opens cosmic-launcher and types "ssh " into it with
# ydotool, letting the pop-launcher ssh-hosts plugin filter. macOS has neither
# cosmic-launcher nor ydotool, so this uses AppleScript's native `choose from
# list` chooser instead — no extra dependencies, no Accessibility grant beyond
# the one skhd already needs.
#
# Host list is parsed exactly like the pop-launcher plugin:
#   dot_local/share/pop-launcher/plugins/ssh-hosts/ssh-hosts.sh
set -uo pipefail

SSH_CONFIG="${SSH_CONFIG:-$HOME/.ssh/config}"

notify() {
  /usr/bin/osascript -e "display notification \"$1\" with title \"SSH\"" >/dev/null 2>&1
}

[ -r "$SSH_CONFIG" ] || { notify "No ~/.ssh/config found"; exit 1; }

# Same parse as the Linux plugin: `Host` lines, first token, wildcards dropped.
hosts=$(grep -i "^Host " "$SSH_CONFIG" | awk '{print $2}' | grep -v '\*')
[ -n "$hosts" ] || { notify "No hosts in ~/.ssh/config"; exit 1; }

# Build an AppleScript list literal, quoting each host safely.
list=$(printf '%s\n' "$hosts" | sed 's/\\/\\\\/g; s/"/\\"/g; s/^/"/; s/$/",/' | tr -d '\n')
list="${list%,}"

host=$(/usr/bin/osascript <<EOF 2>/dev/null
set theHosts to {$list}
set chosen to choose from list theHosts with title "SSH" with prompt "Connect to:" without multiple selections allowed
if chosen is false then
	return ""
else
	return item 1 of chosen
end if
EOF
)

[ -n "$host" ] || exit 0   # user cancelled

# Open a new Ghostty window running the ssh session. The Linux version prefers
# xdg-terminal-exec then `ghostty -e`; on macOS `open -na` is the equivalent and
# guarantees a new instance rather than focusing an existing window.
open -na Ghostty --args -e ssh "$host" \
  || notify "Could not launch Ghostty for $host"
