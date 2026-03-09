// Posts welcome comment and closes issue on successful token probe,
// or posts a "token invalid" retry prompt on failure.
// Env vars: REPO_OWNER, REPO_NAME, ISSUE_NUMBER, INVOKER_USERNAME, TEST_PASSED, QUOTA_EXCEEDED

module.exports = async ({ github, core }) => {
  const owner         = process.env.REPO_OWNER;
  const repo          = process.env.REPO_NAME;
  const issueNum      = parseInt(process.env.ISSUE_NUMBER, 10);
  const username      = process.env.INVOKER_USERNAME;
  const testPassed    = process.env.TEST_PASSED    === 'true';
  const quotaExceeded = process.env.QUOTA_EXCEEDED === 'true';
  const envName       = `invoker/${username}`;

  core.info(`[finalize-invoker] username=${username} testPassed=${testPassed} quotaExceeded=${quotaExceeded}`);

  if (!testPassed) {
    const envUrl = `https://github.com/${owner}/${repo}/settings/environments`;
    await github.rest.issues.createComment({
      owner, repo, issue_number: issueNum,
      body: [
        `The token probe failed for \`${envName}\`.`,
        ``,
        `The \`CLAUDE_CODE_OAUTH_TOKEN\` value is incorrect, expired, or was not generated via \`claude setup-token\`.`,
        ``,
        `**To retry:**`,
        `1. Run \`claude setup-token\` again locally`,
        `2. Open [Settings → Environments](${envUrl}) → \`${envName}\``,
        `3. Delete the existing \`CLAUDE_CODE_OAUTH_TOKEN\` secret and re-add it with the new value`,
        `4. Reply \`ready\` again`,
        ``,
        `— [Hall-Master | Old Major] · the token does not answer — replace it`,
      ].join('\n'),
    });
    return;
  }

  // Token is valid — apply active-invoker label always (token itself is good)
  try {
    await github.rest.issues.addLabels({
      owner, repo, issue_number: issueNum, labels: ['hall:active-invoker'],
    });
  } catch { /* label may not exist yet; non-fatal */ }

  if (quotaExceeded) {
    // Token validated but weekly quota is exhausted — invoker is queued.
    // hall:invoker-queued signals the weekly-reset workflow to unqueue on Monday.
    try {
      await github.rest.issues.addLabels({
        owner, repo, issue_number: issueNum, labels: ['hall:invoker-queued'],
      });
    } catch { /* non-fatal */ }

    await github.rest.issues.createComment({
      owner, repo, issue_number: issueNum,
      body: [
        `@${username} **multiclassed — invoker.** Token validated.`,
        ``,
        `Your weekly quota is currently exhausted. You are **queued** — dispatch will activate automatically when the cap resets on Monday (UTC).`,
        ``,
        `No action needed on your part.`,
        ``,
        `— [Hall-Master | Old Major] · the Hall recognises you; quota resets at dawn`,
      ].join('\n'),
    });
  } else {
    await github.rest.issues.createComment({
      owner, repo, issue_number: issueNum,
      body: [
        `@${username} **multiclassed — invoker.**`,
        ``,
        `Token validated. Dispatch any registered automaton by applying a \`hall:<agent>\` label to an issue in the Hall repo, or by mentioning \`@hall-of-automata[bot] <agent>\` in a comment.`,
        ``,
        `— [Hall-Master | Old Major] · the Hall recognises you; spend quota with intent`,
      ].join('\n'),
    });
  }

  await github.rest.issues.update({ owner, repo, issue_number: issueNum, state: 'closed' });
};
