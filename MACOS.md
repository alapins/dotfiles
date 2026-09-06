# macOS setup

Companion to [`README.md`](README.md). The README covers the cross-OS design and the generic
bootstrap; **this file covers only what is macOS-specific** — the automatic OS gating, the manual
steps that cannot be scripted, the keyboard model, and the pieces that are still open.

Work top to bottom on a new Mac.

---

## 1. Bootstrap

```sh
# 1. Homebrew — only needed to get `chezmoi` itself. After this, the
#    run_once_before_install-homebrew hook keeps brew installed on every apply.
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. chezmoi (yq is installed by the appsync hook before it parses apps.yaml)
brew install chezmoi

# 3. Apply everything
chezmoi init --apply alapins
```

`chezmoi init` generates `~/.config/chezmoi/chezmoi.toml` from
[`.chezmoi.toml.tmpl`](.chezmoi.toml.tmpl), which detects the architecture and sets:

| Data key | Apple Silicon | Intel | Linux |
| --- | --- | --- | --- |
| `.brewPrefix` | `/opt/homebrew` | `/usr/local` | `/home/linuxbrew/.linuxbrew` |
| `.dropbox` | `~/Dropbox` | `~/Dropbox` | `/var/home/alex/Dropbox` |
| `.isDarwin` / `.isLinux` | `true` / `false` | `true` / `false` | `false` / `true` |

Everything OS-dependent flows from those. If a path ever looks wrong, re-run `chezmoi init` and
check `chezmoi data`.

---

## 2. Manual steps — nothing works until these are done

These require a human at the GUI; they cannot be scripted, and macOS only prompts for some of
them once.

### 2.1 skhd permissions (required)

skhd is the hotkey daemon that replaces COSMIC's custom shortcuts. It is **silently inert**
without Accessibility access.

- [ ] **System Settings → Privacy & Security → Accessibility** → enable **skhd**
- [ ] Restart it afterwards — the grant does not take effect on the running process:
      ```sh
      skhd --restart-service
      ```
- [ ] **System Settings → Privacy & Security → Screen Recording** → enable **skhd**
      (needed for the screenshot bindings, since skhd spawns `screencapture`)

Verify it is running and loaded:

```sh
skhd --reload                     # no error = config parsed
tail -f /tmp/skhd_$USER.err.log   # parse errors and command failures land here
skhd --observe                    # prints key names; Ctrl+C to quit
```

The launchd agent is installed at `~/Library/LaunchAgents/com.koekeishiya.skhd.plist` with
`RunAtLoad`, so it starts at login. That registration is done by
[`run_onchange_after_configure-skhd.sh.tmpl`](run_onchange_after_configure-skhd.sh.tmpl), which
also reloads skhd whenever `skhdrc` changes.

### 2.2 Rectangle (required)

Rectangle replaces COSMIC's tiling. Its shortcuts live in **Rectangle's own preferences**, not in
this repo — skhd deliberately binds nothing on `Ctrl+Shift` so it never shadows them.

- [ ] Set the window-layout shortcuts to `Ctrl+Shift+<vim>`, mirroring COSMIC's `Super+<vim>`
- [ ] **Read [§4 Known conflicts](#4-known-conflicts) first** — three of the obvious vim keys are
      already taken by Ghostty
- [ ] Launch at login: Rectangle's own preferences → *Launch on login*

> Rectangle's out-of-box "Recommended" defaults occupy `Ctrl+Alt` +
> `C D E F G I J K R T U`, all four arrows, `Return`, `Delete`, `=`, `-`. That is the **same
> modifier the launchers in `skhdrc` use**. Moving Rectangle to `Ctrl+Shift` (per the mapping in
> §3) is what keeps the two out of each other's way — if you leave Rectangle on its defaults
> instead, `Ctrl+Alt+E` and `Ctrl+Alt+T` will fire two actions each.

### 2.3 Maccy (required for the clipboard binding)

Maccy stands in for ringboard, which is Linux-only.

- [ ] Clear Maccy's own global hotkey in its preferences, so `Ctrl+Alt+V` from skhd is the single
      binding
- [ ] Enable *Launch at login* in Maccy's preferences

### 2.4 SSH keys

macOS has its own launchd `ssh-agent` — the `ssh-agent.service` systemd unit is **not** ported.
Use the Keychain instead of a user agent unit:

```
# ~/.ssh/config
Host *
    UseKeychain yes
    AddKeysToAgent yes
```

---

## 3. Keyboard model

macOS Ctrl and Linux Super swap roles, because Cmd absorbs everything Linux Ctrl does — which
leaves macOS Ctrl as free for window management as Super is on Linux.

| Linux | macOS | Role |
| --- | --- | --- |
| `Ctrl` | `Cmd` | App commands (copy/paste/save/quit) |
| `Super` | `Ctrl` | Window management |
| `Alt` | `Alt` (Option) | unchanged |

Which divides the modifier space:

| Namespace | Owner | Configured in |
| --- | --- | --- |
| `Ctrl + Shift` | Rectangle | Rectangle's preferences (not this repo) |
| `Ctrl + Alt` | skhd | [`dot_config/skhd/skhdrc`](dot_config/skhd/skhdrc) |

### App launchers — identical chords to COSMIC

| Chord | Action | COSMIC original |
| --- | --- | --- |
| `Ctrl+Alt+E` | Finder | `Spawn("dolphin")` |
| `Ctrl+Alt+T` | Ghostty (new window) | `System(Terminal)` |
| `Ctrl+Alt+S` | SSH host picker | `Spawn("~/.local/bin/ssh-launcher.sh")` |
| `Ctrl+Alt+O` | Obsidian daily note | `Spawn("xdg-open obsidian://daily")` |
| `Ctrl+Alt+V` | Clipboard history (Maccy) | `ringboard-egui toggle` |

### Screenshots — two chords had to move

Mac keyboards have no `Print` key, and COSMIC's `Super+Shift+S` becomes `Ctrl+Shift+S` under the
mapping above, which belongs to Rectangle. So both moved into the skhd namespace:

| Chord | Action | COSMIC original |
| --- | --- | --- |
| `Ctrl+Alt+P` | Region select → file + clipboard + notification | `Print` |
| `Ctrl+Alt+Shift+P` | Fullscreen | — |
| `Ctrl+Alt+Shift+S` | Edit most recent screenshot | `Super+Alt+S` |

macOS's built-in `Cmd+Shift+3/4/5` still work; these are additive.

### Option is a dead key

macOS Option composes accented characters (`Option+1` → `¡`). Anything relying on `Alt` as a
plain modifier needs the terminal to pass it through — see §4.

---

## 4. Known conflicts

### Ghostty already owns 18 chords on `Ctrl+Shift`

Rectangle is global, so it wins and Ghostty silently loses whatever it shadows. Before choosing
Rectangle's map, check against Ghostty's existing bindings:

```
a  c  comma  down  equal  i  j  left  n  page_down  page_up  q  right  t  tab  up  v  w
```

For the vim keys specifically:

| Key | Status |
| --- | --- |
| `h` `k` `l` `m` `y` `o` `p` `u` | free |
| `j` | **taken** — Ghostty `write_scrollback_file:paste` |
| `i` | **taken** — Ghostty `inspector:toggle` |
| `n` | **taken** — Ghostty `new_window` |

Also note `up` / `down` / `left` / `right` are taken, if you were considering arrows for halves.

Resolve by either picking free keys in Rectangle, or rebinding those Ghostty actions in
[`dot_config/ghostty/config`](dot_config/ghostty/config).

Regenerate this list any time with:

```sh
grep -oE 'ctrl\+shift\+[a-z0-9_+]+' dot_config/ghostty/config | sed 's/ctrl+shift+//' | sort -u
```

### Ghostty is not yet macOS-adjusted

`dot_config/ghostty/config` is still the Linux config verbatim. Two things will misbehave:

- `alt+one` … `alt+nine` (tab switching) and `ctrl+alt+{h,j,k,l,m,n,comma,period}` (splits) emit
  accented characters instead of firing, unless `macos-option-as-alt = both` is set.
  **This also blocks tmux** — the entire `M-h/j/k/l`, `M-C-*`, `M-o/u/y/i`, `M-n/m/,/.` scheme
  rides on Option and will not reach tmux until this is on.
- `alt+f4=close_window` is meaningless on macOS.

Ghostty's config format has no OS conditionals, so fixing this means templating the file
(`config` → `config.tmpl`). Not yet done.

---

## 5. What the OS gating does automatically

[`.chezmoiignore`](.chezmoiignore) is always evaluated as a template. Ignored paths stay in the
repo but are never applied.

**Skipped on macOS** (Linux desktop plumbing): `.config/cosmic`, `.config/systemd`,
`.config/autostart`, `.config/pipewire`, `.config/input-remapper-2`, `.config/kdeglobals`,
`.config/dolphinrc`, `.local/share/applications`, `.local/share/icons`,
`.local/share/pop-launcher`, and the Linux-only scripts in `.local/bin` (`ssh-launcher.sh`,
`screenshot.sh`, `keepassxc-cli`, `mise`, `uxplay-session`, `winpodx-sleep-hook`,
`xwaylandvideobridge-minimized`).

**Skipped on Linux** (macOS-only): `.config/skhd`, `.local/bin/screenshot-macos.sh`,
`.local/bin/ssh-launcher-macos.sh`.

Templated per-OS: `.zshenv`, `.config/zsh/{.zshenv,.zprofile,.zshrc}`, `.config/topgrade.toml`,
`.npmrc`.

Scripts that render **empty** on Linux — chezmoi skips empty scripts entirely, so they are inert
there: `run_once_before_install-homebrew`, `run_onchange_after_configure-skhd`.

`run_once_after_install-appman` is the mirror case, but does *not* render empty on macOS — it
renders a script that prints `AppMan is Linux-only; nothing to do on darwin` and exits 0.

Preview any of it without a Mac:

```sh
chezmoi execute-template --init < .chezmoi.toml.tmpl   # config for this machine
chezmoi cat ~/.config/zsh/.zshrc                       # render one file
chezmoi ignored                                        # what is being skipped here
APPSYNC_OS=darwin ~/.config/appsync/install.sh --dry-run
```

---

## 6. Not ported

### systemd user units → launchd

None of `dot_config/systemd/user/` applies on macOS. Status:

| Unit | macOS |
| --- | --- |
| `rclone@.service` (gdrive/plexus/podus/servus) | **Still to do.** Needs macFUSE (a kernel extension — requires a security approval + reboot), or switch to an NFS mount or Mountain Duck. The unit also hardcodes `/var/home/alex/mnt/%i` and `/usr/bin/rclone`. |
| `ssh-agent.service` | **Drop** — use the Keychain (§2.4) |
| `syncthing` | `brew services start syncthing` |
| `syncthingy.service` | **Drop** — Flatpak wrapper |
| `refresh-cass.timer` | **Still to do.** launchd `StartCalendarInterval` |
| `uxplay.service` | **Drop** — a Mac is already an AirPlay target |
| `xwaylandvideobridge`, `ydotoold`, `appimagelauncherd` | **Drop** — X11/Wayland only |
| `winpodx-sleep-hook.service` | **Still to do** if wanted; needs `sleepwatcher` |

### Other open items

- **`~/.local/bin/mux`** (the tmux popup bound to `prefix + m`) is not in `apps.yaml` and not
  chezmoi-managed on either OS — the binding will point at nothing until it is added.
- **Browser wrapper scripts** (`chrome-*.sh`, `brave-*.sh`) call the `google-chrome` binary and
  read `~/.config/google-chrome/Default/Bookmarks`. On macOS that is
  `open -a "Google Chrome"` and `~/Library/Application Support/Google/Chrome/Default/Bookmarks`.
- **Input remapping** (G502 button → Super) has no port; use Logi Options+ or Karabiner-Elements.
- **Audio EQ** (`pipewire/my-eq.conf`) has no port; eqMac or Background Music.

---

## 7. Troubleshooting

| Symptom | Check |
| --- | --- |
| No hotkey does anything | Accessibility not granted, or skhd not restarted after granting (§2.1) |
| One hotkey does nothing | `tail /tmp/skhd_$USER.err.log`; confirm the key name with `skhd --observe` |
| A hotkey fires two actions | Rectangle still on its `Ctrl+Alt` defaults (§2.2), or Maccy's own hotkey is set (§2.3) |
| Screenshot chords do nothing | Screen Recording not granted to skhd (§2.1) |
| `brew` not found in a new shell | `~/.zprofile` runs `brew shellenv` only on darwin — confirm `chezmoi data` shows `isDarwin = true` |
| Option key types `¡™£¢` | `macos-option-as-alt` not set in Ghostty (§4) |
| tmux `M-` bindings dead | Same cause as above |
| An app did not install | `~/.config/appsync/install.sh --dry-run` and look for `skip <app> (no entry for darwin)` |
