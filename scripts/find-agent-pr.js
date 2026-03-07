// Finds the open PR the agent opened on its working branch.
// Required env: AGENT, REPO_OWNER, REPO_NAME, ISSUE_NUMBER
// Outputs: pr-number, branch
module.exports = async ({ github, core }) => {
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
};
