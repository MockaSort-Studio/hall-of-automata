// Context detection utilities for secondary workflows.
// Env vars: ACTION (ci | cleanup)
//
// ci: resolves agent context from a check_suite event for hall-ci-loop.yml.
//   Outputs: agent, pr-number, issue-number, repo-owner, repo-name, ci-failures
//
// cleanup: extracts hall label, agent slug, PR metadata, and linked issue number
//   from a PR close event (reads from context.payload — no additional env vars).
//   Outputs: agent, pr-number, merged, issue-number

const ci = async ({ github, context, core }) => {
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

const cleanup = async ({ context, core }) => {
  const labels    = context.payload.pull_request.labels;
  const hallLabel = labels.find(l => l.name.startsWith('hall:'));
  if (!hallLabel) {
    core.setOutput('agent', '');
    return;
  }

  const agent = hallLabel.name.replace('hall:', '');
  const body  = context.payload.pull_request.body || '';
  const issueMatch = body.match(/(?:closes|fixes|resolves)\s+#(\d+)/i);

  core.setOutput('agent',        agent);
  core.setOutput('pr-number',    String(context.payload.pull_request.number));
  core.setOutput('merged',       String(context.payload.pull_request.merged));
  core.setOutput('issue-number', issueMatch ? issueMatch[1] : '');
};

module.exports = async ({ github, context, core }) => {
  const action = process.env.ACTION;
  if (action === 'ci')      return await ci({ github, context, core });
  if (action === 'cleanup') return await cleanup({ context, core });
  throw new Error(`detect-context: unknown ACTION=${action}`);
};
