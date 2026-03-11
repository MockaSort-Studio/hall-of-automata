// Posts a "quota hit — queuing task" comment and applies the hall:queued label.
// Called when the agent reports quota_exceeded in dispatch-result.json.
// Env vars: REPO_OWNER, REPO_NAME, ISSUE_NUMBER, AGENT

module.exports = async ({ github, core }) => {
  const owner  = process.env.REPO_OWNER;
  const repo   = process.env.REPO_NAME;
  const number = Number(process.env.ISSUE_NUMBER);
  const agent  = process.env.AGENT;

  await github.rest.issues.createComment({
    owner, repo, issue_number: number,
    body: `**${agent}** hit Claude API quota — queuing task. A nightly job will retry this automatically when quota resets.`,
  });

  await github.rest.issues.addLabels({
    owner, repo, issue_number: number,
    labels: ['hall:queued'],
  });

  core.info(`[post-quota-queued] queued comment posted on ${owner}/${repo}#${number}`);
};
