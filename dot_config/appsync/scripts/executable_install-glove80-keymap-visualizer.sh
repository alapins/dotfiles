#!/usr/bin/env bash
set -euo pipefail

package="glove80-keymap-visualizer"
python_version="${GLOVE80_VIZ_PYTHON_VERSION:-3.13}"
bin_path="${HOME}/.local/bin/glove80-viz"

if ! command -v uv >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    brew install uv
  else
    echo "install-glove80-keymap-visualizer: uv is required; install uv or Homebrew first" >&2
    exit 1
  fi
fi

uv tool install --upgrade --python "$python_version" "$package"

if [ ! -x "$bin_path" ]; then
  uv tool update-shell >/dev/null 2>&1 || true
fi

if [ ! -x "$bin_path" ]; then
  echo "install-glove80-keymap-visualizer: expected executable missing: $bin_path" >&2
  exit 1
fi
