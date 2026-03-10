// Ensures the hall:{agent} label exists in the repo and applies it to a PR.
// Env vars: REPO_OWNER, REPO_NAME, PR_NUMBER, AGENT

module.exports = async ({ github, core }) => {
  const owner  = process.env.REPO_OWNER;
  const repo   = process.env.REPO_NAME;
  const prNum  = Number(process.env.PR_NUMBER);
  const agent  = process.env.AGENT;
  const label  = `hall:${agent}`;

  // Ensure label exists in the repo (create if missing)
  try {
    await github.rest.issues.getLabel({ owner, repo, name: label });
  } catch {
    await github.rest.issues.createLabel({ owner, repo, name: label, color: 'f97316' });
  }

  await github.rest.issues.addLabels({ owner, repo, issue_number: prNum, labels: [label] });
  core.info(`[apply-hall-label] applied ${label} to ${owner}/${repo}#${prNum}`);
};
