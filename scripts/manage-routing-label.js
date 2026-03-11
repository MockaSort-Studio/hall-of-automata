// Manages routing labels on an issue when a dispatch starts.
// If AGENT == 'old-major': removes hall:dispatch-automaton, applies hall:old-major.
// If AGENT != 'old-major' (a specialist): removes hall:old-major (if present).
// Required env: AGENT, REPO_OWNER, REPO_NAME, ISSUE_NUMBER

module.exports = async ({ github, core }) => {
  const owner       = process.env.REPO_OWNER;
  const repo        = process.env.REPO_NAME;
  const issueNumber = Number(process.env.ISSUE_NUMBER);
  const agent       = process.env.AGENT;

  const removeLabel = async (name) => {
    try {
      await github.rest.issues.removeLabel({ owner, repo, issue_number: issueNumber, name });
    } catch {
      // Label may already be absent — not an error
    }
  };

  const ensureAndApplyLabel = async (name, color) => {
    try {
      await github.rest.issues.getLabel({ owner, repo, name });
    } catch {
      await github.rest.issues.createLabel({ owner, repo, name, color });
    }
    await github.rest.issues.addLabels({ owner, repo, issue_number: issueNumber, labels: [name] });
  };

  if (agent === 'old-major') {
    await removeLabel('hall:dispatch-automaton');
    await ensureAndApplyLabel('hall:old-major', 'd4a017');
    core.info('[routing-label] swapped hall:dispatch-automaton → hall:old-major');
  } else {
    await removeLabel('hall:old-major');
    core.info(`[routing-label] removed hall:old-major (dispatching to ${agent})`);
  }
};
