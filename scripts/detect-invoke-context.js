// Resolves invocation context from any trigger that can fire invoke.yml.
// Inputs come from env vars set by the workflow step.
// Outputs: agent, issue-number, invoker, trigger-event, repo-owner, repo-name,
//          pr-number (pr_review only), review-body (pr_review only).

module.exports = async ({ context, core }) => {
  const event   = context.eventName;
  const payload = context.payload;

  let agent        = process.env.INPUT_AGENT        || '';
  let issueNumber  = process.env.INPUT_ISSUE_NUMBER || '';
  let invoker      = context.actor;
  let triggerEvent = event;
  let repoOwner    = process.env.INPUT_REPO_OWNER || context.repo.owner;
  let repoName     = process.env.INPUT_REPO_NAME  || context.repo.repo;

  const SYSTEM_LABELS = ['hall:awaiting-input', 'hall:queued'];

  if (event === 'issues' && payload.action === 'labeled') {
    const label = payload.label?.name || '';
    if (!label.startsWith('hall:')) { core.setOutput('agent', ''); return; }
    // Ignore system labels — they are applied by the Hall itself, not invokers
    if (SYSTEM_LABELS.includes(label)) { core.setOutput('agent', ''); return; }
    agent        = label.replace('hall:', '');
    issueNumber  = String(payload.issue.number);
    invoker      = payload.sender.login;
    triggerEvent = 'issue_labeled';

  } else if (event === 'issue_comment') {
    // Never process bot comments — prevents rejection comment feedback loops
    const senderType = payload.sender?.type || '';
    core.info(`[detect] event=issue_comment sender=${payload.sender?.login} senderType=${senderType}`);
    if (senderType === 'Bot') { core.setOutput('agent', ''); return; }

    const body  = payload.comment?.body || '';
    // Path A — explicit @mention: @hall-of-automata[bot] <agent>
    const mentionMatch = body.match(/@hall-of-automata\[bot\]\s+(?:agent:\s*)?(\w+)/i);
    if (mentionMatch) {
      core.info(`[detect] path=A mentionMatch=${mentionMatch[1]}`);
      agent = mentionMatch[1];
    } else {
      // Path B — human reply while awaiting input: non-bot comment on a
      // hall:awaiting-input labeled issue that also has a hall:{agent} label.
      const labels     = payload.issue?.labels || [];
      core.info(`[detect] path=B labels=${JSON.stringify(labels.map(l => l.name))}`);
      const awaitLabel = labels.find(l => l.name === 'hall:awaiting-input');
      core.info(`[detect] awaitLabel=${!!awaitLabel}`);
      if (!awaitLabel) { core.setOutput('agent', ''); return; }
      const hallLabel  = labels.find(l => l.name.startsWith('hall:') && !SYSTEM_LABELS.includes(l.name));
      core.info(`[detect] hallLabel=${hallLabel?.name}`);
      if (!hallLabel)  { core.setOutput('agent', ''); return; }
      agent = hallLabel.name.replace('hall:', '');
    }
    issueNumber  = String(payload.issue.number);
    invoker      = payload.sender.login;
    triggerEvent = 'issue_comment';

  } else if (event === 'pull_request_review') {
    const body  = payload.review?.body || '';
    const match = body.match(/@hall-of-automata\[bot\]\s+(?:agent:\s*)?(\w+)/i);
    if (!match) { core.setOutput('agent', ''); return; }
    agent        = match[1];
    issueNumber  = String(payload.pull_request.number);
    invoker      = payload.sender.login;
    triggerEvent = 'pr_review';
    core.setOutput('pr-number',   issueNumber);
    core.setOutput('review-body', body);

  } else if (event === 'workflow_call') {
    triggerEvent = 'workflow_call';

  } else {
    core.setOutput('agent', '');
    return;
  }

  core.setOutput('agent',         agent);
  core.setOutput('issue-number',  issueNumber);
  core.setOutput('invoker',       invoker);
  core.setOutput('trigger-event', triggerEvent);
  core.setOutput('repo-owner',    repoOwner);
  core.setOutput('repo-name',     repoName);
};
