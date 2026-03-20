# permission-recommender

Mines your Claude Code session logs for denied `Bash` tool calls, then asks Claude to propose new deny rules for your `~/.claude/settings.json`.

## How it works

1. **Query** — DuckDB reads `~/.claude/projects/**/*.jsonl` and extracts every `Bash` call where you clicked "Deny"
2. **Analyse** — Claude receives the denial log + your current `settings.json` and proposes glob-pattern deny rules with risk annotations
3. **Review** — Output lands in `proposed_permissions_settings.json`; you diff and apply manually

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

> **Note:** `proposed_permissions_settings.json` and `tool_denials.txt` are regenerated on every run and are gitignored — they contain your local paths.

## Sample output

### tool_denials.txt (DuckDB query result)

```
┌──────────────────────────────────────────────┬──────────────────────────┬──────────────────────────────┐
│ command                                      │ timestamp                │ cwd                          │
├──────────────────────────────────────────────┼──────────────────────────┼──────────────────────────────┤
│ cat src/routes/api/garments/+server.ts       │ 2026-03-20T01:42:01.655Z │ /home/user/my-project        │
│ git -C /home/user/my-project log --oneline -3│ 2026-03-19T03:51:35.022Z │ /home/user/my-project        │
│ git -C /home/user/my-project log --oneline -3│ 2026-03-19T03:47:52.486Z │ /home/user/my-project        │
└──────────────────────────────────────────────┴──────────────────────────┴──────────────────────────────┘
  3 rows  3 columns
```

### proposed_permissions_settings.json (Claude's recommendations)

```jsonc
{
  "permissions": {
    "allow": [
      "Bash(ls:*)",
      "Bash(git add:*)",
      "Bash(git commit:*)",
      "Bash(* --version)",
      "Bash(* --help*)"
    ],
    "defaultMode": "acceptEdits",
    "deny": [
      "Bash(rm *)",
      // Risk: low | Denied: 18 | Reads git history from an arbitrary working directory via -C; prefer standard git log without -C path override.
      "Bash(git -C * log *)",
      // Risk: low | Denied: 4 | Reads file contents via shell cat rather than the Read tool; use Read tool instead.
      "Bash(cat *)"
    ]
  }
}
```

Claude collapses repeated exact commands into glob patterns and annotates each new rule with risk level, denial count, and a one-sentence rationale.

## Files

| File | Purpose |
|------|---------|
| `run.sh` | Orchestrates the pipeline |
| `usage_query.sql` | DuckDB query to extract denied commands |
| `prompt.txt` | System prompt template (placeholders replaced at runtime) |
| `proposed_permissions_settings.json` | Generated output — review before applying |
| `tool_denials.txt` | Intermediate query output |
