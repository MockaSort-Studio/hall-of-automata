// Authorization utilities — team membership check and unauthorized-invoker rejection.
// Env vars: ACTION (check-membership | reject)
//
// check-membership: ORG, TEAM_SLUG, USERNAME, HALL_BOT_LOGIN
//   Returns string 'true' | 'false' (result-encoding: string compatible)
//
// reject: ORG, REPO_OWNER, REPO_NAME, ISSUE_NUMBER,
//         TRIGGER_EVENT, LABEL_NAME, USERNAME, AGENT_NAME

const checkMembership = async ({ github, core }) => {
  const org      = process.env.ORG;
  const teamSlug = process.env.TEAM_SLUG;
  const username = process.env.USERNAME;

  // The Hall bot (hall-of-automata[bot]) acts on its own orchestration — creating
  // sub-issues, applying routing labels — and is inherently authorized.
  // We check the exact login rather than endsWith('[bot]') to prevent other bots
  // (Dependabot, Renovate, third-party apps) from bypassing the team check.
  // HALL_BOT_LOGIN is set by the workflow from the app-token owner.
  const hallBotLogin = process.env.HALL_BOT_LOGIN || 'hall-of-automata[bot]';
  if (username === hallBotLogin) {
    core.info(`[auth-utils] ${username} is the Hall bot — bypassing team check`);
    return 'true';
  }

  try {
    const res = await github.rest.teams.getMembershipForUserInOrg({
      org, team_slug: teamSlug, username,
    });
    const isMember = res.data.state === 'active';
    core.info(`[auth-utils] ${username} in ${org}/${teamSlug}: ${isMember}`);
    return String(isMember);
  } catch {
    core.info(`[auth-utils] ${username} not found in ${org}/${teamSlug}`);
    return 'false';
  }
};

const reject = async ({ github, core }) => {
  const org         = process.env.ORG;
  const owner       = process.env.REPO_OWNER;
  const repo        = process.env.REPO_NAME;
  const issueNumber = Number(process.env.ISSUE_NUMBER);
  const triggerEvent = process.env.TRIGGER_EVENT;
  const labelName   = process.env.LABEL_NAME;
  const username    = process.env.USERNAME;
  const agentName   = process.env.AGENT_NAME;

  // Remove trigger label so it can be reapplied once the invoker is authorized
  if (triggerEvent === 'issue_labeled' && labelName) {
    try {
      await github.rest.issues.removeLabel({
        owner, repo, issue_number: issueNumber, name: labelName,
      });
    } catch { /* label may already be gone */ }
  }

  await github.rest.issues.createComment({
    owner, repo, issue_number: issueNumber,
    body: `@${username} is not authorized to invoke **${agentName}**.\n\nMembership of @${org}/automata-invokers is required. Contact an org admin to request access.`,
  });

  core.setFailed(`Invoker @${username} is not a member of ${org}/automata-invokers — dispatch blocked.`);
};

module.exports = async ({ github, core }) => {
  const action = process.env.ACTION;
  if (action === 'check-membership') return await checkMembership({ github, core });
  if (action === 'reject')           return await reject({ github, core });
  throw new Error(`auth-utils: unknown ACTION=${action}`);
};
