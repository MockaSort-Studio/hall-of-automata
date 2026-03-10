// Rejects an unauthorized dispatch: removes the trigger label (if label-triggered),
// posts a rejection comment, and calls core.setFailed() to hard-stop the job.
// Env vars: ORG, REPO_OWNER, REPO_NAME, ISSUE_NUMBER,
//           TRIGGER_EVENT, LABEL_NAME, USERNAME, AGENT_NAME

module.exports = async ({ github, core }) => {
  const org         = process.env.ORG;
  const owner       = process.env.REPO_OWNER;
  const repo        = process.env.REPO_NAME;
  const issueNumber = Number(process.env.ISSUE_NUMBER);
  const triggerEvent = process.env.TRIGGER_EVENT;
  const labelName   = process.env.LABEL_NAME;
  const username    = process.env.USERNAME;
  const agentName   = process.env.AGENT_NAME;

  // Remove trigger label so it can be reapplied once the invoker is authorized
  if (triggerEvent === 'issue_labeled' && labelName) {
    try {
      await github.rest.issues.removeLabel({
        owner, repo, issue_number: issueNumber, name: labelName,
      });
    } catch { /* label may already be gone */ }
  }

  await github.rest.issues.createComment({
    owner, repo, issue_number: issueNumber,
    body: `@${username} is not authorized to invoke **${agentName}**.\n\nMembership of @${org}/automata-invokers is required. Contact an org admin to request access.`,
  });

  core.setFailed(`Invoker @${username} is not a member of ${org}/automata-invokers — dispatch blocked.`);
};
