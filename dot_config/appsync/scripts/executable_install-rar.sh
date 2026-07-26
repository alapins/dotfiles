#!/usr/bin/env bash
# appsync local-script: install RAR (the `rar` + `unrar` CLIs) from RARLAB's
# official Linux tarball into ~/.local/bin.
#
# Why not brew: Homebrew's `rar` is a macOS-only *cask* (and deprecated over a
# Gatekeeper failure), so it can't provide rar on Linux at all. RARLAB ships a
# self-contained x64 tarball with prebuilt `rar`/`unrar` binaries — that's the
# durable Linux route. Idempotent: skips the download when the target version is
# already installed. Override the version with RAR_VERSION (e.g. 712 for 7.12).
set -euo pipefail

version="${RAR_VERSION:-723}"            # RARLAB packs 7.23 as "723"
bindir="${HOME}/.local/bin"

case "$(uname -m)" in
  x86_64|amd64) arch=x64 ;;
  *) echo "install-rar: only x86_64 is wired up; see https://www.rarlab.com/download.htm for $(uname -m)" >&2; exit 1 ;;
esac
url="https://www.rarlab.com/rar/rarlinux-${arch}-${version}.tar.gz"
pretty="$(printf '%s' "$version" | sed -E 's/([0-9])([0-9]{2})$/\1.\2/')"   # 723 -> 7.23

# Presence check — capture output separately so rar's nonzero exit (it prints its
# banner then exits non-zero with no args) doesn't trip `set -e` / pipefail.
cur="$([ -x "$bindir/rar" ] && "$bindir/rar" 2>/dev/null || true)"
if printf '%s' "$cur" | grep -q "RAR $pretty"; then
  echo "install-rar: rar $pretty already installed at $bindir/rar"
  exit 0
fi

mkdir -p "$bindir"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
echo "install-rar: downloading $url"
curl -fsSL "$url" -o "$tmp/rar.tar.gz"
tar -xzf "$tmp/rar.tar.gz" -C "$tmp"
install -m 0755 "$tmp/rar/rar"   "$bindir/rar"
install -m 0755 "$tmp/rar/unrar" "$bindir/unrar"

printf 'install-rar: %s\n' "$("$bindir/rar" 2>/dev/null | head -1 || true)"
echo "install-rar: installed rar + unrar into $bindir"
