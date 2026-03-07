// Applies or removes the hall:awaiting-input label on an issue.
// Required env: MODE (apply | remove), REPO_OWNER, REPO_NAME, ISSUE_NUMBER
const LABEL = 'hall:awaiting-input';

module.exports = async ({ github, core }) => {
  const owner       = process.env.REPO_OWNER;
  const repo        = process.env.REPO_NAME;
  const issueNumber = Number(process.env.ISSUE_NUMBER);

  if (process.env.MODE === 'apply') {
    // Ensure label exists
    try {
      await github.rest.issues.getLabel({ owner, repo, name: LABEL });
    } catch {
      await github.rest.issues.createLabel({ owner, repo, name: LABEL, color: '6366f1' });
    }
    await github.rest.issues.addLabels({ owner, repo, issue_number: issueNumber, labels: [LABEL] });

  } else {
    try {
      await github.rest.issues.removeLabel({ owner, repo, issue_number: issueNumber, name: LABEL });
    } catch {
      // Label may already be gone — not an error
    }
  }
};
