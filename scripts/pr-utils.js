// Agent PR utilities — find and cleanup hall-labeled PRs.
// Env vars: ACTION (find | cleanup)
//
// find: AGENT, REPO_OWNER, REPO_NAME, ISSUE_NUMBER
//   Finds the PR the agent opened, preferring the agent's own declared result
//   over API-based discovery.
//   Outputs: pr-number, branch, outcome
//
// cleanup: REPO_OWNER, REPO_NAME, PR_NUMBER, ISSUE_NUMBER, AGENT, MERGED
//   Post-close cleanup: removes hall:{agent} label from PR, removes
//   hall:awaiting-input from linked issue (if any), posts merge summary.
const fs = require('fs');

const find = async ({ github, core }) => {
  // Primary: agent-declared result written at end of its turn
  const resultPath = '.hall/dispatch-result.json';
  if (fs.existsSync(resultPath)) {
    const result = JSON.parse(fs.readFileSync(resultPath, 'utf8'));
    core.setOutput('pr-number', result.pr_number || '');
    core.setOutput('branch',    result.branch    || '');
    core.setOutput('outcome',   result.outcome   || '');
    return;
  }

  // Fallback: query GitHub API using the branch naming convention.
  // Used when running against agents that pre-date the output file contract.
  const branch = `hall/${process.env.AGENT}/issue-${process.env.ISSUE_NUMBER}`;
  const prs = await github.rest.pulls.list({
    owner: process.env.REPO_OWNER,
    repo:  process.env.REPO_NAME,
    head:  `${process.env.REPO_OWNER}:${branch}`,
    state: 'open'
  });
  const pr = prs.data[0];
  core.setOutput('pr-number', pr ? String(pr.number) : '');
  core.setOutput('branch',    branch);
  core.setOutput('outcome',   '');
};

const cleanup = async ({ github, core }) => {
  const owner       = process.env.REPO_OWNER;
  const repo        = process.env.REPO_NAME;
  const prNum       = Number(process.env.PR_NUMBER);
  const issueNumber = process.env.ISSUE_NUMBER ? Number(process.env.ISSUE_NUMBER) : null;
  const agent       = process.env.AGENT;
  const merged      = process.env.MERGED === 'true';

  // Remove hall:{agent} label from PR
  try {
    await github.rest.issues.removeLabel({
      owner, repo, issue_number: prNum, name: `hall:${agent}`,
    });
  } catch { /* label may already be gone — not an error */ }

  if (issueNumber) {
    // Remove hall:awaiting-input from linked issue
    try {
      await github.rest.issues.removeLabel({
        owner, repo, issue_number: issueNumber, name: 'hall:awaiting-input',
      });
    } catch { /* label may not exist — not an error */ }

    // Post merge summary on linked issue
    if (merged) {
      await github.rest.issues.createComment({
        owner, repo, issue_number: issueNumber,
        body: `${agent} — PR #${prNum} merged. Task complete.`,
      });
    }
  }

  core.info(`[pr-utils] cleanup complete for ${owner}/${repo}#${prNum} (merged=${merged})`);
};

module.exports = async ({ github, core }) => {
  const action = process.env.ACTION;
  if (action === 'find')    return await find({ github, core });
  if (action === 'cleanup') return await cleanup({ github, core });
  throw new Error(`pr-utils: unknown ACTION=${action}`);
};
