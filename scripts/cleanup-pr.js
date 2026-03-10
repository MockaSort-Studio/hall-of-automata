// Post-close cleanup for a hall-labeled PR.
// Removes the hall:{agent} label from the PR, removes hall:awaiting-input from the
// linked issue (if any), and posts a merge summary comment (if merged and linked).
// Env vars: REPO_OWNER, REPO_NAME, PR_NUMBER, ISSUE_NUMBER, AGENT, MERGED

module.exports = async ({ github, core }) => {
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

  core.info(`[cleanup-pr] cleanup complete for ${owner}/${repo}#${prNum} (merged=${merged})`);
};
