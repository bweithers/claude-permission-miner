# permission-recommender

Mines your Claude Code session logs for `Bash` tool calls, then asks Claude to propose allow and deny rules for your `~/.claude/settings.json`. The primary goal is finding things to **auto-approve** so you stop being prompted for low-risk operations you always accept.

## How it works

1. **Query approvals** — DuckDB reads `~/.claude/projects/**/*.jsonl` and extracts every `Bash` call that ran successfully (not denied), grouped by command with frequency count
2. **Query denials** — same source, filtered for commands you explicitly rejected, also grouped with count
3. **Analyse** — Claude receives both logs + your current `settings.json` and proposes allow rules (primary) and deny rules (secondary), with glob patterns and risk annotations
4. **Review** — Output lands in `proposed_permissions_settings.json`; you diff and apply manually

## Requirements

- **Unix-like OS** (paths are hard-coded to `~/.claude/…` — tested on Linux/WSL)
- [`duckdb`](https://duckdb.org/docs/installation/) CLI in `PATH`
- [`claude`](https://claude.ai/code) CLI in `PATH` and authenticated

### Install DuckDB

```bash
# macOS
brew install duckdb

# Linux / WSL — grab the binary
curl -Lo duckdb.zip https://github.com/duckdb/duckdb/releases/latest/download/duckdb_cli-linux-amd64.zip
unzip duckdb.zip && chmod +x duckdb && sudo mv duckdb /usr/local/bin/
```

## Usage

```bash
git clone <this-repo>
cd permission-recommender
bash run.sh
```

Then review the proposed changes:

```bash
diff ~/.claude/settings.json proposed_permissions_settings.json
```

If happy, copy the output over your settings:

```bash
cp proposed_permissions_settings.json ~/.claude/settings.json
```

> **Note:** `proposed_permissions_settings.json`, `tool_approvals.txt`, and `tool_denials.txt` are regenerated on every run and are gitignored — they contain your local paths.

## Sample output

### tool_approvals.txt (approved commands with frequency)

```
┌──────────────────────────────┬───────────────┬──────────────────────────┐
│ command                      │ approval_count│ last_approved            │
├──────────────────────────────┼───────────────┼──────────────────────────┤
│ git status                   │ 47            │ 2026-03-20T01:42:01.655Z │
│ git log --oneline -10        │ 31            │ 2026-03-19T18:22:10.123Z │
│ npm run lint                 │ 18            │ 2026-03-19T03:51:35.022Z │
│ cat package.json             │ 12            │ 2026-03-18T14:20:00.000Z │
└──────────────────────────────┴───────────────┴──────────────────────────┘
```

### tool_denials.txt (denied commands with frequency)

```
┌──────────────────────────────────────────────┬─────────────┬──────────────────────────┐
│ command                                      │ denial_count│ last_denied              │
├──────────────────────────────────────────────┼─────────────┼──────────────────────────┤
│ git -C /home/user/my-project log --oneline -3│ 18          │ 2026-03-19T03:51:35.022Z │
│ cat src/routes/api/garments/+server.ts       │ 4           │ 2026-03-20T01:42:01.655Z │
└──────────────────────────────────────────────┴─────────────┴──────────────────────────┘
```

### proposed_permissions_settings.json (Claude's recommendations)

```jsonc
{
  "permissions": {
    "allow": [
      "Bash(ls:*)",
      // Risk: low | Approved: 47 | Read-only status check with no side effects.
      "Bash(git status*)",
      // Risk: low | Approved: 31 | Read-only history query.
      "Bash(git log *)",
      // Risk: low | Approved: 18 | Runs linter with no write side effects.
      "Bash(npm run lint*)"
    ],
    "defaultMode": "acceptEdits",
    "deny": [
      "Bash(rm *)",
      // Risk: low | Denied: 18 | Reads git history via -C path override; prefer standard git log.
      "Bash(git -C * log *)",
      // Risk: low | Denied: 4 | Reads file contents via shell cat rather than the Read tool.
      "Bash(cat *)"
    ]
  }
}
```

Claude collapses repeated exact commands into glob patterns and annotates each new rule with risk level, frequency, and a one-sentence rationale.

## Files

| File | Purpose |
|------|---------|
| `run.sh` | Orchestrates the pipeline |
| `approvals_query.sql` | DuckDB query to extract approved commands with frequency |
| `usage_query.sql` | DuckDB query to extract denied commands with frequency |
| `prompt.txt` | System prompt template (placeholders replaced at runtime) |
| `proposed_permissions_settings.json` | Generated output — review before applying |
| `tool_approvals.txt` | Intermediate: approved command frequencies |
| `tool_denials.txt` | Intermediate: denied command frequencies |
