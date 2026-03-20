SELECT
    bash.command,
    bash_raw.timestamp,
    bash_raw.cwd
FROM (
    SELECT
        uuid,
        timestamp,
        cwd,
        UNNEST(message.content::JSON[]) as content
    FROM read_json_auto('/home/bweithers/.claude/projects/**/*.jsonl')
    WHERE type = 'assistant'
) bash_raw
CROSS JOIN LATERAL (SELECT content->>'input'->>'command' as command) bash
JOIN (
    SELECT
        sourceToolAssistantUUID,
        toolUseResult::VARCHAR as toolUseResult
    FROM read_json_auto('/home/bweithers/.claude/projects/**/*.jsonl')
    WHERE type = 'user'
    AND toolUseResult IS NOT NULL
    AND toolUseResult::VARCHAR != 'null'
) result
    ON result.sourceToolAssistantUUID = bash_raw.uuid
WHERE bash_raw.content->>'name' = 'Bash'
AND bash.command IS NOT NULL
AND result.toolUseResult = '"User rejected tool use"'
ORDER BY bash_raw.timestamp DESC;
