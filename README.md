# dotfiles

Personal configuration managed with [chezmoi](https://chezmoi.io), plus **appsync** — a small,
single-list system for installing applications reproducibly across **Linux** and **macOS**
(Windows later), regardless of how each app is delivered (Homebrew, Flatpak, AppImage, or an
install script).

- **Source of truth for apps:** [`dot_config/appsync/apps.yaml`](dot_config/appsync/apps.yaml)
- **All install/update logic:** `dot_config/appsync/` → deployed to `~/.config/appsync/`
- **Dotfiles:** the usual chezmoi `dot_*` files (zsh, ghostty, yazi, tmux, starship, …)

---

## How the layers fit together

appsync does **not** try to own everything. Each layer stays authoritative for what it does
best:

| Layer | Linux (atomic / Aurora) | macOS |
| --- | --- | --- |
| OS, desktop, drivers, most GUI apps | **[bluebuild image](https://github.com/alapins/atomic-alex)** (dnf + system flatpaks) | n/a |
| Cross-OS CLI tools | Homebrew (`brew`) | Homebrew (`brew`) |
| GUI apps on macOS | — | Homebrew **casks** / Mac App Store |
| GUI AppImages | **AppMan** (rootless) | brew cask / DMG |
| Single-binary CLI tools | **mise** (`aqua`/`github`/`ubi`/`cargo`) | mise |
| Install scripts | remote / local script | remote / local script |
| Dotfiles & config | **chezmoi** | chezmoi |
| Updates | `ujust update-all` | `topgrade` |

On Linux, the bluebuild image already installs the desktop and most GUI apps, so the app list is
mostly the cross-OS CLI tools plus a few extras. On macOS — which starts empty — the same list
provides the GUI apps as casks (e.g. KeePassXC as a cask, preserving fingerprint unlock).

---

## The app list: `~/.config/appsync/apps.yaml`

This is the **only** file you edit to add or remove an application. It is keyed by app name. Use
a top-level `via:` when the app is the same on every OS; otherwise nest per-OS (`linux:` /
`darwin:`), each with its own `via:` and fields.

```yaml
apps:
  ripgrep:                      # same everywhere
    via: brew

  keepassxc:
    linux:  { via: image }      # provided by the bluebuild image
    darwin: { via: cask }       # Homebrew cask on macOS

  obsidian:
    linux:  { via: flatpak, id: md.obsidian.Obsidian }
    darwin: { via: cask }

  some-appimage:
    linux:  { via: appimage, am: some-appimage }   # managed by AppMan
```

### `via:` reference

| `via` | Extra fields | What it does | OS |
| --- | --- | --- | --- |
| `brew` | `name:` (optional) | Homebrew formula | any |
| `cask` | `name:` (optional) | Homebrew cask (GUI app) | macOS |
| `mas` | `id:` (App Store id) | Mac App Store app | macOS |
| `flatpak` | `id:` (app id) | Flatpak from Flathub (not already in the image) | Linux |
| `image` | — | Provided by the bluebuild image; skipped (documents provenance) | Linux |
| `appimage` | `am:` name **or** `url:` | GUI AppImage via **AppMan** (creates a launcher entry + icon) | Linux |
| `mise` | `spec:` e.g. `aqua:cli/cli` | Single-binary CLI via mise (on your shell `PATH`) | any |
| `npm` | `name:` (optional) | Global npm package (`npm install -g`); the app key is the package name unless `name:` overrides it (e.g. scoped pkgs) | any (where `npm` exists) |
| `remote-script` | `url:`, `repo:` (optional) | Download the script to `~/.local/share/appsync/installers/<app>/` and run it. With `repo:`, it only re-runs when that GitHub repo cuts a new release. | any |
| `local-script` | `path:` | Run a script under `~/.config/appsync/scripts/` | any |

Add `enabled: false` to any app to skip it temporarily. Add an optional `name:` to override the
Homebrew token when it differs from the app key.

> **AppMan vs mise:** use `appimage` (AppMan) for **GUI** apps — it generates a `.desktop`
> launcher entry and icon so the app appears in your menu. Use `mise` for **CLI** binaries —
> they go on your shell `PATH` only, with no launcher entry.

---

## Adding or removing an app

```sh
chezmoi edit ~/.config/appsync/apps.yaml   # edits the source in this repo
chezmoi apply                              # deploys it and re-runs the installer
```

`apps.yaml` is chezmoi-managed, so always edit it through chezmoi (or in the chezmoi source
dir), **not** the deployed copy. After `chezmoi apply`, commit and push so other machines and the
bluebuild image pick up the change:

```sh
chezmoi cd
git commit -am "apps: add <name>" && git push
```

You can also run the installer directly without changing the list:

```sh
~/.config/appsync/install.sh            # install everything for this OS (idempotent)
~/.config/appsync/install.sh --dry-run  # preview the plan; honors APPSYNC_OS=darwin too
```

---

## Bootstrap a new machine

### Linux (Aurora / atomic — the primary target)

The bluebuild [image](https://github.com/alapins/atomic-alex) runs chezmoi at build time and
bakes in the prerequisites (`yq`, `topgrade`). After installing the image, apply the post-image
delta:

```sh
chezmoi init --apply alapins
```

This deploys `~/.config/appsync/`, installs rootless **AppMan**, and runs the installer (brew CLI
tools + any AppImages/mise/scripts in the list).

### macOS (or any non-atomic Linux)

```sh
# 1. Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Prerequisites (yq parses apps.yaml; chezmoi applies this repo)
brew install chezmoi yq

# 3. Apply — installs the full app set (CLI formulae + GUI casks + mas)
chezmoi init --apply alapins
```

> **No chicken-and-egg:** `yq` is a *prerequisite*, not a managed app. It is baked into the
> image on Linux and `brew install`ed above (and again by the chezmoi hook as a safety net)
> *before* the installer ever parses `apps.yaml`.

---

## Updating

Reproducing the install set (above) is separate from upgrading versions.

### Linux

`ujust update` (Aurora's updater) keeps owning the OS image, Flatpaks and Homebrew. A custom
recipe adds the layers it doesn't cover:

```sh
ujust update-all       # = ujust update  +  appsync's extra layers
ujust update-extras    # only the appsync layers: mise, AppMan AppImages, scripts
```

### macOS

```sh
topgrade               # brew / cask / mas / mise + custom commands, in one pass
# or, equivalently:
~/.config/appsync/update.sh
```

---

## Layout

```
~/.config/appsync/
  apps.yaml        # the single app list (edit this)
  install.sh       # reads apps.yaml, installs per `via` for the current OS (idempotent)
  update.sh        # updates the layers uupd/brew don't cover (mise, AppMan, scripts)
  lib.sh           # shared helpers
  scripts/         # local install scripts referenced by `via: local-script`
~/.config/topgrade.toml                     # updater config (defers OS/flatpak/brew to uupd on Linux)
~/.local/share/appsync/installers/<app>/    # downloaded `remote-script` installers
```

The chezmoi hook `run_onchange_after_run-appsync-install.sh.tmpl` re-runs the installer whenever
`apps.yaml` (or the appsync scripts) change. It is guarded to no-op during the image build (when
chezmoi runs as root).
