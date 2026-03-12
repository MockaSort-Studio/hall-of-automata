// Invoker onboarding flow utilities.
// Env vars: ACTION (parse | create-env | verify | finalize)
//
// parse: ISSUE_BODY, ISSUE_LOGIN
//   Parses a GitHub issue form body into named outputs.
//   Outputs: invoker-username, weekly-cap-hours, slug, display-name
//
// create-env: REPO_OWNER, REPO_NAME, INVOKER_USERNAME, WEEKLY_CAP_HOURS, ISSUE_NUMBER
//   Creates the invoker/<username> GitHub Environment, sets HALL_WEEKLY_CAP,
//   and posts onboarding instructions.
//   Outputs: env-name, weekly-cap-turns
//
// verify: REPO_OWNER, REPO_NAME, ISSUE_NUMBER, INVOKER_USERNAME
//   Checks that CLAUDE_CODE_OAUTH_TOKEN secret name is registered in invoker/<username> env.
//   Outputs: secret-found (true/false)
//
// finalize: REPO_OWNER, REPO_NAME, ISSUE_NUMBER, INVOKER_USERNAME, TEST_PASSED
//   Posts welcome comment and closes issue on successful token validation,
//   or posts a "token invalid" retry prompt on failure.

const parse = async ({ core }) => {
  const body  = process.env.ISSUE_BODY  || '';
  const login = process.env.ISSUE_LOGIN || '';

  const fields = {};
  const sections = body.split(/\n(?=###\s)/);
  for (const section of sections) {
    const nl = section.indexOf('\n');
    if (nl === -1) continue;
    const rawLabel = section.slice(0, nl).replace(/^###\s+/, '').trim();
    const value    = section.slice(nl).trim().replace(/^_No response_$/im, '');
    // Normalise label: lowercase, strip parenthetical annotations, collapse spaces
    const key = rawLabel.toLowerCase()
      .replace(/\s*\(.*?\)\s*/g, '')
      .trim()
      .replace(/\s+/g, '-')
      .replace(/[^a-z0-9-]/g, '');
    if (key && value) fields[key] = value;
  }

  const username    = fields['github-handle'] || login;
  const capRaw      = fields['weekly-cap'] || fields['weekly-cap-hours'] || '5';
  const capHours    = parseInt(capRaw.match(/\d+/)?.[0] || '5', 10);
  const slug        = (fields['slug'] || '')
    .toLowerCase().replace(/[^a-z0-9-]/g, '-').replace(/-+/g, '-').replace(/^-|-$/g, '');
  const displayName = fields['display-name'] || slug;

  core.info(`[invoker-onboarding] username=${username} cap=${capHours}h slug=${slug}`);
  core.setOutput('invoker-username', username);
  core.setOutput('weekly-cap-hours', String(capHours));
  core.setOutput('slug',             slug);
  core.setOutput('display-name',     displayName);
};

const createEnv = async ({ github, core }) => {
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

  await upsertVar('HALL_WEEKLY_CAP',  capTurns);
  await upsertVar('HALL_USAGE_COUNT', '0');

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

const verify = async ({ github, core }) => {
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

  core.info(`[invoker-onboarding] env=${envName} secrets=${secretNames.join(',')}`);

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

const finalize = async ({ github, core }) => {
  const owner      = process.env.REPO_OWNER;
  const repo       = process.env.REPO_NAME;
  const issueNum   = parseInt(process.env.ISSUE_NUMBER, 10);
  const username   = process.env.INVOKER_USERNAME;
  const testPassed = process.env.TEST_PASSED === 'true';
  const envName    = `invoker/${username}`;

  core.info(`[invoker-onboarding] username=${username} testPassed=${testPassed}`);

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
      `Token validated. Apply the \`hall:dispatch-automaton\` label on any issue to invoke the Hall — Old Major will triage and route to the right agent. To target a specific agent directly, apply \`hall:<agent>\` instead.`,
      ``,
      `— [Hall-Master | Old Major] · the Hall recognises you; spend quota with intent`,
    ].join('\n'),
  });

  await github.rest.issues.update({ owner, repo, issue_number: issueNum, state: 'closed' });
};

module.exports = async ({ github, core }) => {
  const action = process.env.ACTION;
  if (action === 'parse')      return await parse({ core });
  if (action === 'create-env') return await createEnv({ github, core });
  if (action === 'verify')     return await verify({ github, core });
  if (action === 'finalize')   return await finalize({ github, core });
  throw new Error(`invoker-onboarding: unknown ACTION=${action}`);
};
