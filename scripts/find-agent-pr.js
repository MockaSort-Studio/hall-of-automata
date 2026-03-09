// Finds the PR the agent opened, preferring the agent's own declared result
// over API-based discovery. This eliminates the implicit branch-naming contract
// between prose instructions and this script.
//
// Required env: AGENT, REPO_OWNER, REPO_NAME, ISSUE_NUMBER
// Outputs: pr-number, branch, outcome
const fs = require('fs');

module.exports = async ({ github, core }) => {
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
