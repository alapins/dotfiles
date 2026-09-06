#!/usr/bin/env bash
# appsync local-script: install grim + slurp (Wayland screenshot capture +
# region picker) into ~/.local/bin by extracting the Fedora RPMs.
#
# Why not the other mechanisms: neither tool is in brew (Linux), flatpak, or
# the AppMan catalog, and upstream ships no prebuilt binaries — the only
# alternative on an immutable image is rpm-ostree layering, which we avoid.
# The RPM binaries need only libs already in the base image (pixman, png,
# jpeg, cairo, xkbcommon, wayland). Linux/Wayland-only.
#
# Note: grim >= 1.5.0 is required for COSMIC — it added support for
# ext-image-copy-capture-v1, the only capture protocol cosmic-comp exposes.
# Fedora 44 ships 1.5.0. Idempotent: skips when both binaries exist;
# FORCE_REINSTALL=1 to refresh.
set -euo pipefail

bindir="${HOME}/.local/bin"

if [[ -x "$bindir/grim" && -x "$bindir/slurp" && "${FORCE_REINSTALL:-0}" != 1 ]]; then
  echo "install-grim-slurp: grim + slurp already installed in $bindir (FORCE_REINSTALL=1 to refresh)"
  exit 0
fi

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$bindir"

echo "install-grim-slurp: downloading Fedora RPMs"
dnf -q download --destdir "$tmp" grim slurp

for rpm in "$tmp"/*.rpm; do
  (cd "$tmp" && rpm2cpio "$rpm" | cpio -idm --quiet './usr/bin/*')
done

install -m 0755 "$tmp/usr/bin/grim" "$tmp/usr/bin/slurp" "$bindir/"
echo "install-grim-slurp: installed grim + slurp into $bindir"
