#!/bin/bash
SESSION_PREFIX="ghostty"
i=0

while true; do
  SESSION_NAME="${SESSION_PREFIX}$i"
  if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null || ! tmux list-sessions | grep "^$SESSION_NAME:" | grep -q "(attached)"; then
    break
  fi
  i=$((i + 1))
done

tmux new-session -A -s "$SESSION_NAME"
