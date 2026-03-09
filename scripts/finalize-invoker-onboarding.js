// Posts welcome comment and closes issue on successful token test,
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
        `The token validation invocation failed for \`${envName}\`.`,
        ``,
        `This means the \`CLAUDE_CODE_OAUTH_TOKEN\` value is likely incorrect, expired, or was not generated via \`claude setup-token\`.`,
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

  // Test passed — apply active-invoker label, welcome, close
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
      `Token validated. Dispatch any registered automaton by applying a \`hall:<agent>\` label to an issue or PR in a target repository.`,
      ``,
      `— [Hall-Master | Old Major] · the Hall recognises you; spend quota with intent`,
    ].join('\n'),
  });

  await github.rest.issues.update({ owner, repo, issue_number: issueNum, state: 'closed' });
};
