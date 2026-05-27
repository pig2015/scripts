#!/bin/bash

show_help() {
    cat <<EOF
Usage:
  $(basename "$0")              Attach if exactly one session exists, else show help
  $(basename "$0") <name>       Attach to <name>, or create it if missing
  $(basename "$0") -l           List all tmux sessions
  $(basename "$0") -h|--help    Show this help
EOF
}

if [ "$#" -eq 0 ]; then
    sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null)
    count=$(echo -n "$sessions" | grep -c '^')
    if [ "$count" -eq 1 ]; then
        echo "Attaching to only session: $sessions"
        sleep 1
        tmux attach -t "$sessions"
        exit 0
    fi
    if [ "$count" -gt 1 ]; then
        echo "Existing sessions:"
        tmux list-sessions
        echo
    fi
    show_help
    exit 1
fi

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
