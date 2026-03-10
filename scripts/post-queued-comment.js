// Posts a "pool exhausted" comment and applies the hall:invoker-queued label.
// Env vars: REPO_OWNER, REPO_NAME, ISSUE_NUMBER, AGENT

module.exports = async ({ github, core }) => {
  const owner  = process.env.REPO_OWNER;
  const repo   = process.env.REPO_NAME;
  const number = Number(process.env.ISSUE_NUMBER);
  const agent  = process.env.AGENT;

  await github.rest.issues.createComment({
    owner, repo, issue_number: number,
    body: `**${agent}** request received, but all invokers are currently at their weekly capacity. The request has been queued — it will be retried when capacity is available.`,
  });

  await github.rest.issues.addLabels({
    owner, repo, issue_number: number,
    labels: ['hall:invoker-queued'],
  });

  core.info(`[post-queued-comment] queued comment posted on ${owner}/${repo}#${number}`);
};
