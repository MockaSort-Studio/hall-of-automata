// Checks if a user is an active member of a GitHub team.
// Env vars: ORG, TEAM_SLUG, USERNAME
// Output: result = 'true' | 'false' (string, for result-encoding: string compatibility)

module.exports = async ({ github, core }) => {
  const org      = process.env.ORG;
  const teamSlug = process.env.TEAM_SLUG;
  const username = process.env.USERNAME;

  // GitHub bot accounts always end with [bot] and cannot be team members.
  // The Hall bot acting on its own orchestration (creating issues, applying
  // routing labels) is inherently authorized — skip the membership check.
  if (username.endsWith('[bot]')) {
    core.info(`[check-team-membership] ${username} is a bot — bypassing team check`);
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
