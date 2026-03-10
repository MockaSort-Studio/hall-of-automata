// Creates the invoker/<username> GitHub Environment, sets HALL_WEEKLY_CAP,
// and posts onboarding instructions with a link to the environment secrets page.
// Env vars: REPO_OWNER, REPO_NAME, INVOKER_USERNAME, WEEKLY_CAP_HOURS, ISSUE_NUMBER

module.exports = async ({ github, core }) => {
  const owner    = process.env.REPO_OWNER;
  const repo     = process.env.REPO_NAME;
  const username = process.env.INVOKER_USERNAME;
  const capHours = parseInt(process.env.WEEKLY_CAP_HOURS || '5', 10);
  const issueNum = parseInt(process.env.ISSUE_NUMBER, 10);
  const envName  = `invoker/${username}`;
  const capTurns = String(capHours * 3); // 1 hour ≈ 3 turns

  // Create or update the environment
  await github.request('PUT /repos/{owner}/{repo}/environments/{environment_name}', {
    owner, repo, environment_name: envName,
  });

  // Set HALL_WEEKLY_CAP and initialise HALL_USAGE_COUNT=0 — try create, fall back to update
  async function upsertVar(name, value) {
    const payload = { owner, repo, environment_name: envName, name, value };
    try {
      await github.request(
        'POST /repos/{owner}/{repo}/environments/{environment_name}/variables',
        payload
      );
    } catch {
      await github.request(
        'PATCH /repos/{owner}/{repo}/environments/{environment_name}/variables/{name}',
        payload
      );
    }
  }

  await upsertVar('HALL_WEEKLY_CAP',   capTurns);
  await upsertVar('HALL_USAGE_COUNT',  '0');

  const envUrl = `https://github.com/${owner}/${repo}/settings/environments`;
  const body   = [
    `**Environment \`${envName}\` provisioned** — weekly cap set to **${capTurns} turns** (${capHours}h × 3).`,
    ``,
    `**One step remaining — add your Claude OAuth token:**`,
    `1. Run \`claude setup-token\` locally if you haven't already`,
    `2. Open **[Settings → Environments](${envUrl})**, select \`${envName}\``,
    `3. Add secret \`CLAUDE_CODE_OAUTH_TOKEN\` and paste your token`,
    ``,
    `**Prerequisites checklist** (confirm before replying):`,
    `- [ ] Member of \`automata-invokers\` GitHub team`,
    `- [ ] \`claude setup-token\` completed locally`,
    `- [ ] \`CLAUDE_CODE_OAUTH_TOKEN\` secret added to \`${envName}\``,
    ``,
    `Reply \`ready\` when all three are checked.`,
    ``,
    `— [Hall-Master | Old Major] · the gate is set; the key is yours to place`,
  ].join('\n');

  await github.rest.issues.createComment({ owner, repo, issue_number: issueNum, body });

  core.setOutput('env-name',         envName);
  core.setOutput('weekly-cap-turns', capTurns);
};
