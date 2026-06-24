#!/bin/bash

set -euo pipefail

FWD="$(dirname -- "${BASH_SOURCE[0]}")"
P4BIN=$(command -v p4)

usage() {
    cat <<EOF
Usage: $(basename "$0") [-q] <from> <to>

Copy opened files from FROM workspace to TO workspace.
Each of FROM/TO can be a p4 client name or a local workspace path.

Files are copied locally and opened in TO with the same action (edit/add/delete).
Both workspaces must exist on the same Perforce server and map to the same depot.

Options:
  -q    quiet mode, skip interactive confirmation
EOF
    exit 1
}

die() {
    echo "Error: $*" >&2
    exit 1
}

QUIET=0
while getopts ":q" opt; do
    case "$opt" in
        q) QUIET=1 ;;
        *) usage ;;
    esac
done
shift $((OPTIND - 1))

FROM_ARG=${1:-}
TO_ARG=${2:-}

PORT_PLAN_LINES=()

FROM_MODE=""
FROM_VALUE=""
FROM_NAME=""
FROM_ROOT=""
TO_MODE=""
TO_VALUE=""
TO_NAME=""
TO_ROOT=""

[[ -n "$FROM_ARG" && -n "$TO_ARG" ]] || usage

expand_path() {
    local arg=$1
    if [[ "$arg" == ~/* ]]; then
        echo "${arg/#\~/$HOME}"
    else
        echo "$arg"
    fi
}

is_explicit_path() {
    local arg=$1
    [[ "$arg" == /* || "$arg" == ~/* || "$arg" == . || "$arg" == .. \
        || "$arg" == ./* || "$arg" == ../* ]]
}

p4_for() {
    local mode=$1
    local value=$2
    shift 2
    if [[ "$mode" == "path" ]]; then
        "$P4BIN" -d "$value" "$@"
    else
        "$P4BIN" -c "$value" "$@"
    fi
}

client_exists() {
    p4_for client "$1" clients -e "$1" 2>/dev/null | grep -q "^Client $1 "
}

resolve_workspace_path() {
    local arg=$1
    local label=$2
    local expanded realpath info

    expanded=$(expand_path "$arg")
    if is_explicit_path "$arg"; then
        realpath=$(readlink -f "$expanded")
    elif [[ -d "$expanded" ]]; then
        realpath=$(readlink -f "$expanded")
    else
        die "$label is not a client or workspace path: $arg"
    fi

    [[ -d "$realpath" ]] || die "$label workspace path not found: $arg"

    info=$(p4_for path "$realpath" info 2>/dev/null) || \
        die "$label is not a valid p4 workspace: $arg"

    MODE=path
    VALUE="$realpath"
    NAME=$(echo "$info" | awk '/^Client name:/ {print $3; exit}')
    ROOT=$(echo "$info" | awk '/^Client root:/ {print $3; exit}')
    [[ -n "$NAME" && -n "$ROOT" ]] || die "unable to resolve p4 client from $label path: $arg"
}

resolve_client_name() {
    local arg=$1
    local label=$2

    client_exists "$arg" || die "unknown $label client: $arg"

    MODE=client
    VALUE="$arg"
    NAME="$arg"
    ROOT=$(p4_for client "$arg" client -o "$arg" | awk '/^Root:/ {print $2; exit}')
    [[ -n "$ROOT" ]] || die "unable to read root for $label client: $arg"
}

resolve_target() {
    local arg=$1
    local label=$2
    local expanded

    expanded=$(expand_path "$arg")
    if is_explicit_path "$arg" || [[ -d "$expanded" ]]; then
        resolve_workspace_path "$arg" "$label"
    else
        resolve_client_name "$arg" "$label"
    fi
}

resolve_targets() {
    resolve_target "$FROM_ARG" "from"
    FROM_MODE=$MODE
    FROM_VALUE=$VALUE
    FROM_NAME=$NAME
    FROM_ROOT=$ROOT

    resolve_target "$TO_ARG" "to"
    TO_MODE=$MODE
    TO_VALUE=$VALUE
    TO_NAME=$NAME
    TO_ROOT=$ROOT

    [[ "$FROM_NAME" != "$TO_NAME" ]] || die "from and to resolve to the same client: $FROM_NAME"
}

get_server_address() {
    p4_for "$1" "$2" info 2>/dev/null | awk '/^Server address:/ {print $3; exit}'
}

get_stream() {
    p4_for "$1" "$2" client -o | awk '/^Stream:/ {print $2; exit}'
}

depot_root_from_path() {
    echo "$1" | awk -F/ 'NF >= 2 {print "//" $2; exit}'
}

get_view_depot_roots() {
    p4_for "$1" "$2" client -o | awk '
        /^View:/ { in_view=1; next }
        in_view && /^[^ \t]/ { in_view=0 }
        in_view {
            gsub(/\/\.\.\..*$/, "", $1)
            if ($1 ~ /^\/\//) print $1
        }
    ' | sort -u
}

validate_clients() {
    local from_server to_server
    from_server=$(get_server_address "$FROM_MODE" "$FROM_VALUE")
    to_server=$(get_server_address "$TO_MODE" "$TO_VALUE")
    [[ -n "$from_server" && -n "$to_server" ]] || die "unable to read server address from p4 info"
    [[ "$from_server" == "$to_server" ]] || die "clients on different servers: $from_server vs $to_server"

    local from_stream to_stream
    from_stream=$(get_stream "$FROM_MODE" "$FROM_VALUE")
    to_stream=$(get_stream "$TO_MODE" "$TO_VALUE")

    if [[ -n "$from_stream" && -n "$to_stream" ]]; then
        local from_depot to_depot
        from_depot=$(depot_root_from_path "$from_stream")
        to_depot=$(depot_root_from_path "$to_stream")
        [[ "$from_depot" == "$to_depot" ]] || die "stream clients map to different depots: $from_depot vs $to_depot"
        echo "Depot check: server=$from_server depot=$from_depot"
        return
    fi

    if [[ -n "$from_stream" || -n "$to_stream" ]]; then
        die "one client is stream-based and the other is not"
    fi

    local from_roots to_roots
    from_roots=$(get_view_depot_roots "$FROM_MODE" "$FROM_VALUE")
    to_roots=$(get_view_depot_roots "$TO_MODE" "$TO_VALUE")
    [[ -n "$from_roots" && -n "$to_roots" ]] || die "unable to read depot roots from client view"

    local root
    local matched=0
    while IFS= read -r root; do
        [[ -z "$root" ]] && continue
        if echo "$to_roots" | grep -qx "$root"; then
            matched=1
            break
        fi
    done <<< "$from_roots"
    [[ "$matched" -eq 1 ]] || die "client views do not share a depot root"
    echo "Depot check: server=$from_server shared depot root=$root"
}

local_path_for() {
    local mode=$1
    local value=$2
    local depot_path=$3
    local where_line
    where_line=$(p4_for "$mode" "$value" where "$depot_path" 2>/dev/null | head -1)
    [[ -n "$where_line" ]] || return 1
    echo "$where_line" | awk '{print $NF}'
}

parse_opened_line() {
    local line=$1
    DEPOT_PATH=$(echo "$line" | awk '{print $1}' | sed 's/#.*//')
    OPEN_ACTION=$(echo "$line" | sed -n 's/^[^ ]* - \([^ ]*\).*/\1/p')
    [[ -n "$OPEN_ACTION" ]] || die "unable to parse opened line: $line"
}

filter_opened_stream() {
    local mode=$1
    local value=$2
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        [[ "$line" == *" - integrate "* ]] && continue
        [[ "$line" == *" - import "* ]] && continue
        printf '%s\n' "$line"
    done < <(p4_for "$mode" "$value" opened)
}

ask_confirm() {
    local prompt=$1

    if [[ "$QUIET" -eq 1 ]]; then
        return 0
    fi

    local reply
    if ! read -r -p "$prompt " reply; then
        echo
        echo "Aborted."
        exit 0
    fi
    case "$reply" in
        y|Y|yes|Yes|YES) ;;
        *) echo "Aborted."; exit 0 ;;
    esac
}

print_action_stats() {
    local total=$1
    local edit=$2
    local add=$3
    local delete=$4
    local move_add=$5
    local move_delete=$6
    local branch=$7
    local other=$8

    echo "total: $total file(s)"
    if ((edit > 0)); then echo "  edit: $edit"; fi
    if ((add > 0)); then echo "  add: $add"; fi
    if ((delete > 0)); then echo "  delete: $delete"; fi
    if ((move_add > 0)); then echo "  move/add: $move_add"; fi
    if ((move_delete > 0)); then echo "  move/delete: $move_delete"; fi
    if ((branch > 0)); then echo "  branch: $branch"; fi
    if ((other > 0)); then echo "  other: $other"; fi
}

reset_action_counts() {
    COUNT_EDIT=0
    COUNT_ADD=0
    COUNT_DELETE=0
    COUNT_MOVE_ADD=0
    COUNT_MOVE_DELETE=0
    COUNT_BRANCH=0
    COUNT_OTHER=0
}

bump_action_count() {
    local action=$1
    case "$action" in
        edit) COUNT_EDIT=$((COUNT_EDIT + 1)) ;;
        add) COUNT_ADD=$((COUNT_ADD + 1)) ;;
        delete) COUNT_DELETE=$((COUNT_DELETE + 1)) ;;
        move/add) COUNT_MOVE_ADD=$((COUNT_MOVE_ADD + 1)) ;;
        move/delete) COUNT_MOVE_DELETE=$((COUNT_MOVE_DELETE + 1)) ;;
        branch) COUNT_BRANCH=$((COUNT_BRANCH + 1)) ;;
        *) COUNT_OTHER=$((COUNT_OTHER + 1)) ;;
    esac
}

count_lines_actions() {
    local line
    reset_action_counts
    for line in "$@"; do
        parse_opened_line "$line"
        bump_action_count "$OPEN_ACTION"
    done
}

preflight_opened_files() {
    local opened_lines=()
    mapfile -t opened_lines < <(filter_opened_stream "$FROM_MODE" "$FROM_VALUE")

    [[ ${#opened_lines[@]} -gt 0 ]] || die "no opened files in from workspace: $FROM_NAME"

    local line depot_path to_local
    for line in "${opened_lines[@]}"; do
        parse_opened_line "$line"
        depot_path=$DEPOT_PATH
        to_local=$(local_path_for "$TO_MODE" "$TO_VALUE" "$depot_path") || \
            die "to workspace cannot map depot path: $depot_path"
        local_path_for "$FROM_MODE" "$FROM_VALUE" "$depot_path" >/dev/null || \
            die "from workspace cannot map depot path: $depot_path"
    done

    printf '%s\n' "${opened_lines[@]}"
}

open_in_to() {
    local depot_path=$1
    local action=$2
    local to_local=$3

    case "$action" in
        edit|branch)
            p4_for "$TO_MODE" "$TO_VALUE" edit "$depot_path" >/dev/null
            ;;
        add)
            if p4_for "$TO_MODE" "$TO_VALUE" opened "$depot_path" 2>/dev/null | grep -q " - add "; then
                :
            elif p4_for "$TO_MODE" "$TO_VALUE" files "$depot_path" 2>/dev/null | grep -q .; then
                p4_for "$TO_MODE" "$TO_VALUE" edit "$depot_path" >/dev/null
            else
                p4_for "$TO_MODE" "$TO_VALUE" add "$to_local" >/dev/null
            fi
            ;;
        delete|move/delete)
            p4_for "$TO_MODE" "$TO_VALUE" delete "$depot_path" >/dev/null
            ;;
        move/add)
            if p4_for "$TO_MODE" "$TO_VALUE" files "$depot_path" 2>/dev/null | grep -q .; then
                p4_for "$TO_MODE" "$TO_VALUE" edit "$depot_path" >/dev/null
            else
                p4_for "$TO_MODE" "$TO_VALUE" add "$to_local" >/dev/null
            fi
            ;;
        *)
            die "unsupported open action '$action' for $depot_path"
            ;;
    esac
}

copy_opened_content() {
    local depot_path=$1
    local action=$2
    local from_local=$3
    local to_local=$4

    case "$action" in
        edit|add|branch|move/add)
            [[ -f "$from_local" ]] || die "source file missing: $from_local"
            mkdir -p "$(dirname "$to_local")"
            cp -f "$from_local" "$to_local"
            ;;
        delete|move/delete)
            ;;
        *)
            die "unsupported copy action '$action' for $depot_path"
            ;;
    esac
}

build_port_plan() {
    local opened_lines=()
    mapfile -t opened_lines < <(preflight_opened_files)

    local deletes=()
    local others=()
    local line action
    for line in "${opened_lines[@]}"; do
        parse_opened_line "$line"
        action=$OPEN_ACTION
        if [[ "$action" == "delete" || "$action" == "move/delete" ]]; then
            deletes+=("$line")
        else
            others+=("$line")
        fi
    done

    PORT_PLAN_LINES=()
    if ((${#deletes[@]} > 0)); then
        PORT_PLAN_LINES+=("${deletes[@]}")
    fi
    if ((${#others[@]} > 0)); then
        PORT_PLAN_LINES+=("${others[@]}")
    fi
    count_port_actions
}

count_port_actions() {
    count_lines_actions "${PORT_PLAN_LINES[@]}"
    PORT_COUNT_EDIT=$COUNT_EDIT
    PORT_COUNT_ADD=$COUNT_ADD
    PORT_COUNT_DELETE=$COUNT_DELETE
    PORT_COUNT_MOVE_ADD=$COUNT_MOVE_ADD
    PORT_COUNT_MOVE_DELETE=$COUNT_MOVE_DELETE
    PORT_COUNT_BRANCH=$COUNT_BRANCH
    PORT_COUNT_OTHER=$COUNT_OTHER
}

print_port_summary() {
    print_action_stats \
        "${#PORT_PLAN_LINES[@]}" \
        "$PORT_COUNT_EDIT" "$PORT_COUNT_ADD" "$PORT_COUNT_DELETE" \
        "$PORT_COUNT_MOVE_ADD" "$PORT_COUNT_MOVE_DELETE" \
        "$PORT_COUNT_BRANCH" "$PORT_COUNT_OTHER"
}

show_port_plan() {
    echo "== port plan: $FROM_NAME -> $TO_NAME =="
    echo "from root: $FROM_ROOT"
    echo "to root:   $TO_ROOT"
    echo
    print_port_summary
    echo
}

confirm_port_plan() {
    ask_confirm "Proceed? [y/N]"
}

confirm_to_already_opened() {
    local to_lines=()
    mapfile -t to_lines < <(filter_opened_stream "$TO_MODE" "$TO_VALUE")

    if ((${#to_lines[@]} == 0)); then
        return 0
    fi

    count_lines_actions "${to_lines[@]}"

    echo
    echo "== warning: to workspace already has opened files =="
    echo "to client: $TO_NAME"
    print_action_stats \
        "${#to_lines[@]}" \
        "$COUNT_EDIT" "$COUNT_ADD" "$COUNT_DELETE" \
        "$COUNT_MOVE_ADD" "$COUNT_MOVE_DELETE" \
        "$COUNT_BRANCH" "$COUNT_OTHER"
    echo
    ask_confirm "TO already has opened files. Continue anyway? [y/N]"
}

execute_port_plan() {
    local total=${#PORT_PLAN_LINES[@]}
    local i=0
    local line depot_path action from_local to_local

    echo "== porting: $FROM_NAME -> $TO_NAME ($total file(s)) =="

    for line in "${PORT_PLAN_LINES[@]}"; do
        i=$((i + 1))
        parse_opened_line "$line"
        depot_path=$DEPOT_PATH
        action=$OPEN_ACTION
        from_local=$(local_path_for "$FROM_MODE" "$FROM_VALUE" "$depot_path")
        to_local=$(local_path_for "$TO_MODE" "$TO_VALUE" "$depot_path")

        echo "[$i/$total] [$action] $depot_path"
        copy_opened_content "$depot_path" "$action" "$from_local" "$to_local"
        open_in_to "$depot_path" "$action" "$to_local"
    done
}

process_opened_files() {
    build_port_plan
    show_port_plan
    confirm_port_plan
    confirm_to_already_opened
    execute_port_plan
}

resolve_targets
validate_clients
process_opened_files
echo "== done =="
