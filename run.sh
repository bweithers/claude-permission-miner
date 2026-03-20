#!/bin/bash

DIR="$HOME/claude-daemons/permission-recommender"
SETTINGS="$HOME/.claude/settings.json"
SUMMARY="$DIR/tool_denials.txt"
OUTPUT="$DIR/proposed_permissions_settings.json"

duckdb -f "$DIR/usage_query.sql" > "$SUMMARY"

PROMPT=$(cat "$DIR/prompt.txt")
PROMPT="${PROMPT/CURRENT_SETTINGS_PLACEHOLDER/$(cat "$SETTINGS")}"
PROMPT="${PROMPT/USAGE_SUMMARY_PLACEHOLDER/$(cat "$SUMMARY")}"

claude -p "$PROMPT" > "$OUTPUT"

echo "Done. Diff: diff $SETTINGS $OUTPUT"
