// Posts welcome comment and closes issue on successful token validation,
// or posts a "token invalid" retry prompt on failure.
// Env vars: REPO_OWNER, REPO_NAME, ISSUE_NUMBER, INVOKER_USERNAME, TEST_PASSED

module.exports = async ({ github, core }) => {
  const owner      = process.env.REPO_OWNER;
  const repo       = process.env.REPO_NAME;
  const issueNum   = parseInt(process.env.ISSUE_NUMBER, 10);
  const username   = process.env.INVOKER_USERNAME;
  const testPassed = process.env.TEST_PASSED === 'true';
  const envName    = `invoker/${username}`;

  core.info(`[finalize-invoker] username=${username} testPassed=${testPassed}`);

  if (!testPassed) {
    const envUrl = `https://github.com/${owner}/${repo}/settings/environments`;
    await github.rest.issues.createComment({
      owner, repo, issue_number: issueNum,
      body: [
        `The token probe failed for \`${envName}\`.`,
        ``,
        `This usually means the \`CLAUDE_CODE_OAUTH_TOKEN\` value is incorrect, expired, or was not generated via \`claude setup-token\`. It can also happen if the Anthropic API was transiently unreachable during the check.`,
        ``,
        `**To retry:**`,
        `1. Confirm your token is still valid by running \`claude\` locally`,
        `2. If the token is stale: run \`claude setup-token\` again locally`,
        `3. Open [Settings → Environments](${envUrl}) → \`${envName}\``,
        `4. Delete the existing \`CLAUDE_CODE_OAUTH_TOKEN\` secret and re-add it with the current value`,
        `5. Reply \`ready\` again`,
        ``,
        `If the token is correct and you're retrying after a transient failure, simply reply \`ready\` — no need to replace the secret.`,
        ``,
        `— [Hall-Master | Old Major] · the token does not answer — verify it, then retry`,
      ].join('\n'),
    });
    return;
  }

  // Token is valid — apply active-invoker label
  try {
    await github.rest.issues.addLabels({
      owner, repo, issue_number: issueNum, labels: ['hall:active-invoker'],
    });
  } catch { /* label may not exist yet; non-fatal */ }

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

  await github.rest.issues.update({ owner, repo, issue_number: issueNum, state: 'closed' });
};
