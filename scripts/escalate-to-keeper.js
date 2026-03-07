// Posts an escalation comment on the PR mentioning the keeper.
// Required env: REPO_OWNER, REPO_NAME, PR_NUMBER, KEEPER, RETRY_COUNT, CI_FAILURES
module.exports = async ({ github, core }) => {
  await github.rest.issues.createComment({
    owner:        process.env.REPO_OWNER,
    repo:         process.env.REPO_NAME,
    issue_number: Number(process.env.PR_NUMBER),
    body: [
      `@${process.env.KEEPER} — retries exhausted`,
      `after ${process.env.RETRY_COUNT} attempts.`,
      `Last CI failures: \`${process.env.CI_FAILURES}\`.`,
      'Manual review required.'
    ].join(' ')
  });
};
