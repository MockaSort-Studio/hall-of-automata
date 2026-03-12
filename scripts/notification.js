// Capacity and queue notification utilities.
// Env vars: ACTION (cap | pool-exhausted | quota-queued | escalate)
//
// cap: REPO_OWNER, REPO_NAME, ISSUE_NUMBER, AGENT, CAP
//   Posts a cap-exceeded comment on the triggering issue.
//
// pool-exhausted: REPO_OWNER, REPO_NAME, ISSUE_NUMBER, AGENT
//   Posts a "pool exhausted" comment and applies the hall:invoker-queued label.
//
// quota-queued: REPO_OWNER, REPO_NAME, ISSUE_NUMBER, AGENT
//   Posts a "quota hit — queuing task" comment and applies the hall:queued label.
//
// escalate: REPO_OWNER, REPO_NAME, PR_NUMBER, invoker, RETRY_COUNT, CI_FAILURES
//   Posts an escalation comment on the PR mentioning the invoker.

const cap = async ({ github }) => {
  await github.rest.issues.createComment({
    owner:        process.env.REPO_OWNER,
    repo:         process.env.REPO_NAME,
    issue_number: Number(process.env.ISSUE_NUMBER),
    body: `**${process.env.AGENT}** has reached its weekly invocation cap (${process.env.CAP}). The request has been queued.`,
  });
};

const poolExhausted = async ({ github, core }) => {
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

  core.info(`[notification] pool-exhausted comment posted on ${owner}/${repo}#${number}`);
};

const quotaQueued = async ({ github, core }) => {
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

  core.info(`[notification] quota-queued comment posted on ${owner}/${repo}#${number}`);
};

const escalate = async ({ github }) => {
  await github.rest.issues.createComment({
    owner:        process.env.REPO_OWNER,
    repo:         process.env.REPO_NAME,
    issue_number: Number(process.env.PR_NUMBER),
    body: [
      `@${process.env.invoker} — retries exhausted`,
      `after ${process.env.RETRY_COUNT} attempts.`,
      `Last CI failures: \`${process.env.CI_FAILURES}\`.`,
      'Manual review required.'
    ].join(' '),
  });
};

module.exports = async ({ github, core }) => {
  const action = process.env.ACTION;
  if (action === 'cap')            return await cap({ github });
  if (action === 'pool-exhausted') return await poolExhausted({ github, core });
  if (action === 'quota-queued')   return await quotaQueued({ github, core });
  if (action === 'escalate')       return await escalate({ github });
  throw new Error(`notification: unknown ACTION=${action}`);
};
