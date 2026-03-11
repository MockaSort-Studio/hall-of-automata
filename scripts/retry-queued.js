// Finds all open issues labeled hall:queued and re-triggers dispatch
// by removing hall:queued and cycling the agent label (remove + re-add)
// to fire the issues:labeled event on invoke.yml.
//
// If the retry dispatch also hits quota, the agent will write quota_exceeded
// again, the dispatch job will re-apply hall:queued, and the next nightly
// run will pick it up. No loop — each nightly run is one retry attempt.

const SYSTEM_LABELS = [
  'hall:awaiting-input',
  'hall:queued',
  'hall:invoker-queued',
  'hall:onboard-invoker',
  'hall:onboard-automaton',
  'hall:active-invoker',
  'hall:dispatch-automaton',
];

module.exports = async ({ github, context, core }) => {
  const owner = context.repo.owner;
  const repo  = context.repo.repo;

  const issues = await github.paginate(github.rest.issues.listForRepo, {
    owner, repo,
    state:    'open',
    labels:   'hall:queued',
    per_page: 100,
  });

  core.info(`[retry-queued] found ${issues.length} queued issue(s)`);

  for (const issue of issues) {
    const labels    = issue.labels.map(l => l.name);
    const agentLabel = labels.find(l => l.startsWith('hall:') && !SYSTEM_LABELS.includes(l));

    if (!agentLabel) {
      core.info(`[retry-queued] #${issue.number}: no agent label found — skipping`);
      continue;
    }

    core.info(`[retry-queued] #${issue.number}: retrying (agent=${agentLabel})`);

    // Remove hall:queued first so the re-label event reads a clean label state.
    await github.rest.issues.removeLabel({
      owner, repo,
      issue_number: issue.number,
      name: 'hall:queued',
    });

    // Cycle the agent label: remove then re-add to fire issues:labeled on invoke.yml.
    await github.rest.issues.removeLabel({
      owner, repo,
      issue_number: issue.number,
      name: agentLabel,
    });

    await github.rest.issues.addLabels({
      owner, repo,
      issue_number: issue.number,
      labels: [agentLabel],
    });

    core.info(`[retry-queued] #${issue.number}: re-triggered`);
  }
};
