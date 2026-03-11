// Checks if a user is an active member of a GitHub team.
// Env vars: ORG, TEAM_SLUG, USERNAME
// Output: result = 'true' | 'false' (string, for result-encoding: string compatibility)

module.exports = async ({ github, core }) => {
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
    core.info(`[check-team-membership] ${username} is the Hall bot — bypassing team check`);
    return 'true';
  }

  try {
    const res = await github.rest.teams.getMembershipForUserInOrg({
      org, team_slug: teamSlug, username,
    });
    const isMember = res.data.state === 'active';
    core.info(`[check-team-membership] ${username} in ${org}/${teamSlug}: ${isMember}`);
    return String(isMember);
  } catch {
    core.info(`[check-team-membership] ${username} not found in ${org}/${teamSlug}`);
    return 'false';
  }
};
