SELECT
    bash.command,
    COUNT(*) as approval_count,
    MAX(bash_raw.timestamp) as last_approved
FROM (
    SELECT
        uuid,
        timestamp,
        cwd,
        UNNEST(message.content::JSON[]) as content
    FROM read_json_auto('~/.claude/projects/**/*.jsonl')
    WHERE type = 'assistant'
) bash_raw
CROSS JOIN LATERAL (SELECT content->>'input'->>'command' as command) bash
JOIN (
    SELECT
        sourceToolAssistantUUID
    FROM read_json_auto('~/.claude/projects/**/*.jsonl')
    WHERE type = 'user'
    AND toolUseResult IS NOT NULL
    AND toolUseResult::VARCHAR != 'null'
    AND toolUseResult::VARCHAR != '"User rejected tool use"'
) result
    ON result.sourceToolAssistantUUID = bash_raw.uuid
WHERE bash_raw.content->>'name' = 'Bash'
AND bash.command IS NOT NULL
GROUP BY bash.command
HAVING COUNT(*) >= 3
ORDER BY approval_count DESC
LIMIT 60;
