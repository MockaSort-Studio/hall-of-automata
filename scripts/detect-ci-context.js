// Resolves agent context from a check_suite event for hall-ci-loop.yml.
// Outputs: agent, pr-number, issue-number, repo-owner, repo-name, ci-failures
module.exports = async ({ github, context, core }) => {
  const suite = context.payload.check_suite;
  const owner = context.repo.owner;
  const repo  = context.repo.repo;

  if (suite.conclusion !== 'failure') { core.setOutput('agent', ''); return; }

  const branch = suite.head_branch || '';
  if (!branch.startsWith('hall/')) { core.setOutput('agent', ''); return; }

  const prs = await github.rest.pulls.list({
    owner, repo,
    head:  `${owner}:${branch}`,
    state: 'open'
  });
  if (!prs.data.length) { core.setOutput('agent', ''); return; }
  const pr = prs.data[0];

  const hallLabel = pr.labels.find(l => l.name.startsWith('hall:'));
  if (!hallLabel) { core.setOutput('agent', ''); return; }
  const agent = hallLabel.name.replace('hall:', '');

  // Extract issue number from branch: hall/{agent}/issue-{N}
  const issueMatch = branch.match(/\/issue-(\d+)$/);
  const issueNumber = issueMatch ? issueMatch[1] : '';

  // Collect failed check run names
  const runs = await github.rest.checks.listForSuite({
    owner, repo,
    check_suite_id: suite.id,
    per_page: 50
  });
  const failures = runs.data.check_runs
    .filter(r => r.conclusion === 'failure')
    .map(r => r.name)
    .join(', ');

  core.setOutput('agent',        agent);
  core.setOutput('pr-number',    String(pr.number));
  core.setOutput('issue-number', issueNumber);
  core.setOutput('repo-owner',   owner);
  core.setOutput('repo-name',    repo);
  core.setOutput('ci-failures',  failures);
};
