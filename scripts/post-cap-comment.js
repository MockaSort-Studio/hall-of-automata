// Posts a cap-exceeded comment on the triggering issue.
// Required env: REPO_OWNER, REPO_NAME, ISSUE_NUMBER, AGENT, CAP
module.exports = async ({ github, core }) => {
  await github.rest.issues.createComment({
    owner:        process.env.REPO_OWNER,
    repo:         process.env.REPO_NAME,
    issue_number: Number(process.env.ISSUE_NUMBER),
    body: `**${process.env.AGENT}** has reached its weekly invocation cap (${process.env.CAP}). The request has been queued.`
  });
};
