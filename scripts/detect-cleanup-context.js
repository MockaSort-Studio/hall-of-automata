// Extracts hall label, agent slug, PR metadata, and linked issue number from a PR close event.
// Reads from context.payload — no env vars required.
// Outputs: agent, pr-number, merged, issue-number

module.exports = async ({ context, core }) => {
  const labels    = context.payload.pull_request.labels;
  const hallLabel = labels.find(l => l.name.startsWith('hall:'));
  if (!hallLabel) {
    core.setOutput('agent', '');
    return;
  }

  const agent = hallLabel.name.replace('hall:', '');
  const body  = context.payload.pull_request.body || '';
  const issueMatch = body.match(/(?:closes|fixes|resolves)\s+#(\d+)/i);

  core.setOutput('agent',        agent);
  core.setOutput('pr-number',    String(context.payload.pull_request.number));
  core.setOutput('merged',       String(context.payload.pull_request.merged));
  core.setOutput('issue-number', issueMatch ? issueMatch[1] : '');
};
