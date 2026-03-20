#!/bin/bash

DIR="$(cd "$(dirname "$0")" && pwd)"
SETTINGS="$HOME/.claude/settings.json"
APPROVALS="$DIR/tool_approvals.txt"
DENIALS="$DIR/tool_denials.txt"
OUTPUT="$DIR/proposed_permissions_settings.json"

duckdb -c "$(sed "s|~/.claude|$HOME/.claude|g" "$DIR/approvals_query.sql")" > "$APPROVALS"
duckdb -c "$(sed "s|~/.claude|$HOME/.claude|g" "$DIR/usage_query.sql")" > "$DENIALS"

PROMPT=$(cat "$DIR/prompt.txt")
PROMPT="${PROMPT/CURRENT_SETTINGS_PLACEHOLDER/$(cat "$SETTINGS")}"
PROMPT="${PROMPT/APPROVALS_PLACEHOLDER/$(cat "$APPROVALS")}"
PROMPT="${PROMPT/DENIALS_PLACEHOLDER/$(cat "$DENIALS")}"

claude -p "$PROMPT" > "$OUTPUT"

echo "Done. Diff: diff $SETTINGS $OUTPUT"
