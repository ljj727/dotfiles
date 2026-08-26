#!/bin/bash
session=$1
if tmux has-session -t "$session" 2>/dev/null; then
    tmux switch-client -t "$session"
elif command -v tmuxinator >/dev/null && tmuxinator list -n 2>/dev/null | tail -n +2 | tr ' ' '\n' | grep -q "^$session\$"; then
    TMUX='' tmuxinator start "$session" --no-attach
    tmux switch-client -t "$session"
fi
