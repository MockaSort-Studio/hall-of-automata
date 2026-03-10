// Checks if a user is an active member of a GitHub team.
// Env vars: ORG, TEAM_SLUG, USERNAME
// Output: result = 'true' | 'false' (string, for result-encoding: string compatibility)

module.exports = async ({ github, core }) => {
  const org      = process.env.ORG;
  const teamSlug = process.env.TEAM_SLUG;
  const username = process.env.USERNAME;

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
