#!/usr/bin/env bash
# Install the Rust toolchain via the OFFICIAL rustup installer (rustup.rs).
#
# Why not brew? brew's `rust` and `rustup` formulae conflict (rustup is keg-only
# "because it conflicts with rust"), which breaks `brew upgrade` under `ujust
# update` — especially on atomic's symlinked /home. rustup is also the canonical
# toolchain multiplexer: per-project `rust-toolchain.toml` files pin exact
# versions, so projects needing different Rust versions coexist without conflict.
#
# Idempotent: no-ops if rustup is already installed. Toolchain *updates* are
# handled separately by update.sh (`rustup update`).
set -euo pipefail

if command -v rustup >/dev/null 2>&1 || [ -x "$HOME/.cargo/bin/rustup" ]; then
  echo "install-rustup: rustup already installed — nothing to do"
  exit 0
fi

echo "install-rustup: installing rustup via https://sh.rustup.rs"
curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs \
  | sh -s -- -y --default-toolchain stable --profile default
