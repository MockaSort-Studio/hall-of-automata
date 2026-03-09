// Checks that CLAUDE_CODE_OAUTH_TOKEN secret NAME is registered in invoker/<username> env.
// This is a fast-fail pre-check only — it does NOT validate the token value.
// Token validity is confirmed by a live invocation in the test-token job.
// Env vars: REPO_OWNER, REPO_NAME, ISSUE_NUMBER, INVOKER_USERNAME
// Outputs: secret-found (true/false)

module.exports = async ({ github, core }) => {
  const owner    = process.env.REPO_OWNER;
  const repo     = process.env.REPO_NAME;
  const issueNum = parseInt(process.env.ISSUE_NUMBER, 10);
  const username = process.env.INVOKER_USERNAME;
  const envName  = `invoker/${username}`;

  let secretNames = [];
  try {
    const res = await github.request(
      'GET /repos/{owner}/{repo}/environments/{environment_name}/secrets',
      { owner, repo, environment_name: envName }
    );
    secretNames = (res.data.secrets || []).map(s => s.name);
  } catch (err) {
    core.warning(`Could not list secrets for ${envName}: ${err.message}`);
  }

  core.info(`[verify-invoker] env=${envName} secrets=${secretNames.join(',')}`);

  if (!secretNames.includes('CLAUDE_CODE_OAUTH_TOKEN')) {
    const envUrl = `https://github.com/${owner}/${repo}/settings/environments`;
    await github.rest.issues.createComment({
      owner, repo, issue_number: issueNum,
      body: [
        `\`CLAUDE_CODE_OAUTH_TOKEN\` is not yet visible in \`${envName}\`.`,
        ``,
        `Add the secret in [Settings → Environments](${envUrl}), then reply \`ready\` again.`,
        ``,
        `— [Hall-Master | Old Major] · the gate holds until the key is placed`,
      ].join('\n'),
    });
    core.setOutput('secret-found', 'false');
    return;
  }

  core.setOutput('secret-found', 'true');
};
