#!/bin/zsh
# macforge-notify — push a progress update or notification into MacForge's
# Notch Island from any CLI (Claude Code, Codex, builds, deploys, etc.).
#
# It appends one newline-delimited JSON event to the log MacForge watches:
#   ~/Library/Application Support/MacForge/agent-events.jsonl
#
# Usage:
#   macforge-notify --source "Claude Code" --title "Building" --message "3/8" --progress 0.4 --state running --id build
#   macforge-notify --source "Codex" --title "Review done" --message "3 findings" --state success --id review
#   macforge-notify --source "deploy" --title "Deploy finished" --notify   # one-off toast
#   macforge-notify --id build --clear                                     # remove a task
#
# Flags:
#   --id <string>        Stable id; repeat updates with the same id to advance a task.
#   --source <string>    Who is reporting (shown small on the row). Default: "CLI".
#   --title <string>     Headline.
#   --message <string>   Secondary line.
#   --progress <0..1>    Fractional progress for a running task.
#   --state <s>          running | success | failure | info. Default: running.
#   --notify             Shorthand for a one-off notification (state=info, kind=notification).
#   --clear              Remove the task with --id (or all tasks if no --id).
#
# You can also just echo JSON yourself:
#   echo '{"source":"Claude Code","title":"Building","progress":0.4,"state":"running"}' >> "$MACFORGE_AGENT_EVENTS"

set -euo pipefail

LOG="${MACFORGE_AGENT_EVENTS:-$HOME/Library/Application Support/MacForge/agent-events.jsonl}"

id=""
source="CLI"
title=""
message=""
progress=""
state="running"
kind=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --id) id="$2"; shift 2 ;;
    --source) source="$2"; shift 2 ;;
    --title) title="$2"; shift 2 ;;
    --message) message="$2"; shift 2 ;;
    --progress) progress="$2"; shift 2 ;;
    --state) state="$2"; shift 2 ;;
    --notify) kind="notification"; state="info"; shift ;;
    --clear) kind="clear"; shift ;;
    *) echo "macforge-notify: unknown flag $1" >&2; exit 2 ;;
  esac
done

mkdir -p "$(dirname "$LOG")"

# JSON-escape a string value.
esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\n'; }

json="{"
[[ -n "$id" ]] && json="$json\"id\":\"$(esc "$id")\","
json="$json\"source\":\"$(esc "$source")\","
[[ -n "$kind" ]] && json="$json\"kind\":\"$kind\","
[[ -n "$title" ]] && json="$json\"title\":\"$(esc "$title")\","
[[ -n "$message" ]] && json="$json\"message\":\"$(esc "$message")\","
[[ -n "$progress" ]] && json="$json\"progress\":$progress,"
json="$json\"state\":\"$(esc "$state")\"}"

printf '%s\n' "$json" >> "$LOG"
