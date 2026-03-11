// Finds all open issues labeled hall:queued across all org repos and
// re-triggers dispatch by removing hall:queued and cycling the agent label
// (remove + re-add) to fire the issues:labeled event.
//
// For hall-of-automata issues, issues:labeled fires invoke.yml directly.
// For cross-repo issues, the App webhook → relay → workflow_dispatch picks it up.
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
  const org = context.repo.owner;

  // Search across all org repos for open issues with hall:queued
  const results = await github.paginate(github.rest.search.issuesAndPullRequests, {
    q:        `is:issue is:open label:hall:queued org:${org}`,
    per_page: 100,
  });

  core.info(`[retry-queued] found ${results.length} queued issue(s) across org`);

  for (const issue of results) {
    // issue.repository_url = "https://api.github.com/repos/owner/repo"
    const [issueOwner, issueRepo] = issue.repository_url.replace('https://api.github.com/repos/', '').split('/');

    const labels     = issue.labels.map(l => l.name);
    const agentLabel = labels.find(l => l.startsWith('hall:') && !SYSTEM_LABELS.includes(l));

    if (!agentLabel) {
      core.info(`[retry-queued] ${issueOwner}/${issueRepo}#${issue.number}: no agent label — skipping`);
      continue;
    }

    core.info(`[retry-queued] ${issueOwner}/${issueRepo}#${issue.number}: retrying (agent=${agentLabel})`);

    // Remove hall:queued first so the re-label event reads a clean label state.
    await github.rest.issues.removeLabel({
      owner: issueOwner, repo: issueRepo,
      issue_number: issue.number,
      name: 'hall:queued',
    });

    // Cycle the agent label: remove then re-add to fire issues:labeled.
    await github.rest.issues.removeLabel({
      owner: issueOwner, repo: issueRepo,
      issue_number: issue.number,
      name: agentLabel,
    });

    await github.rest.issues.addLabels({
      owner: issueOwner, repo: issueRepo,
      issue_number: issue.number,
      labels: [agentLabel],
    });

    core.info(`[retry-queued] ${issueOwner}/${issueRepo}#${issue.number}: re-triggered`);
  }
};
