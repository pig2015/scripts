#!/bin/bash

show_help() {
    cat <<EOF
Usage:
  $(basename "$0")              Attach to a tmux session (interactive)
  $(basename "$0") <name>       Attach to <name>, or create it if missing
  $(basename "$0") -l          List all tmux sessions
  $(basename "$0") -h|--help    Show this help

Behavior (no args):
  - 0 sessions  : prompt for a new session name
  - 1 session   : auto-attach after a brief pause
  - N sessions  : list sessions and ask which one
EOF
}

if [[ "$1" == "-h" || "$1" == "-help" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

if [ "$#" -gt 1 ]; then
    echo "Error: too many arguments." >&2
    show_help
    exit 1
fi

if [[ "$1" == -* && "$1" != "-l" ]]; then
    echo "Error: unknown option '$1'." >&2
    show_help
    exit 1
fi

if [ "$1" = "-l" ]; then
    sessions=$(tmux list-sessions 2>/dev/null)
    if [ -z "$sessions" ]; then
        echo "No tmux sessions."
    else
        echo "$sessions"
    fi
    exit 0
fi

if [ -n "$1" ]; then
    target="$1"
    if tmux has-session -t "$target" 2>/dev/null; then
        echo "Attaching to existing session: $target"
        sleep 1
        tmux attach -t "$target"
    else
        echo "Creating new session: $target"
        sleep 1
        tmux new -s "$target"
    fi
    exit 0
fi

sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null)

if [ -z "$sessions" ]; then
    echo "No tmux sessions found."
    read -p "Enter new session name: " name
    if [ -z "$name" ]; then
        echo "No name given. Aborting." >&2
        exit 1
    fi
    tmux new -s "$name"
    exit 0
fi

count=$(echo "$sessions" | wc -l)

if [ "$count" -eq 1 ]; then
    echo "Attaching to only session: $sessions"
    sleep 1
    tmux attach -t "$sessions"
    exit 0
fi

echo "Available sessions:"
i=1
declare -a names
while IFS= read -r s; do
    echo "  $i) $s"
    names[$i]="$s"
    i=$((i + 1))
done <<< "$sessions"

read -p "Choose session number or name: " choice

if [[ "$choice" =~ ^[0-9]+$ ]] && [ -n "${names[$choice]}" ]; then
    target="${names[$choice]}"
else
    target="$choice"
fi

if tmux has-session -t "$target" 2>/dev/null; then
    tmux attach -t "$target"
else
    echo "Session '$target' does not exist." >&2
    exit 1
fi
