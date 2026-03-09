// Resolves invocation context from any trigger that can fire invoke.yml.
// Inputs come from env vars set by the workflow step.
// Outputs: actor, agent, issue-number, invoker, invoker-count, trigger-event,
//          repo-owner, repo-name, pr-number (pr_review only),
//          review-body (pr_review only).
//
// Pool selection: after resolving the trigger event, the script queries all
// invoker/* environments in the Hall repo, reads HALL_USAGE_COUNT and
// HALL_WEEKLY_CAP for each via REST API (app token used so any env is readable),
// filters out at-cap members, sorts ascending by usage, and picks the least-used.
// 'invoker' output is empty when all members are at cap — the notify-queued job
// handles that path. 'actor' is always the trigger user (used for authz only).

module.exports = async ({ github, context, core }) => {
  const event   = context.eventName;
  const payload = context.payload;

  let agent        = process.env.INPUT_AGENT        || '';
  let issueNumber  = process.env.INPUT_ISSUE_NUMBER || '';
  let actor        = context.actor;   // person who triggered the event (for authz)
  let triggerEvent = event;
  let repoOwner    = process.env.INPUT_REPO_OWNER || context.repo.owner;
  let repoName     = process.env.INPUT_REPO_NAME  || context.repo.repo;

  const SYSTEM_LABELS = [
    'hall:awaiting-input',
    'hall:queued',
    'hall:invoker-queued',
    'hall:onboard-invoker',
    'hall:onboard-automaton',
    'hall:active-invoker',
  ];

  if (event === 'issues' && payload.action === 'labeled') {
    const label = payload.label?.name || '';
    if (!label.startsWith('hall:')) { core.setOutput('agent', ''); return; }
    // Ignore system labels — they are applied by the Hall itself, not invokers
    if (SYSTEM_LABELS.includes(label)) { core.setOutput('agent', ''); return; }
    agent        = label.replace('hall:', '');
    issueNumber  = String(payload.issue.number);
    actor        = payload.sender.login;
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
    actor        = payload.sender.login;
    triggerEvent = 'issue_comment';

  } else if (event === 'pull_request_review') {
    const body  = payload.review?.body || '';
    const match = body.match(/@hall-of-automata\[bot\]\s+(?:agent:\s*)?(\w+)/i);
    if (!match) { core.setOutput('agent', ''); return; }
    agent        = match[1];
    issueNumber  = String(payload.pull_request.number);
    actor        = payload.sender.login;
    triggerEvent = 'pr_review';
    core.setOutput('pr-number',   issueNumber);
    core.setOutput('review-body', body);

  } else if (event === 'workflow_call') {
    triggerEvent = 'workflow_call';
    // actor stays as context.actor

  } else {
    core.setOutput('agent', '');
    return;
  }

  // ── Pool-select the least-used invoker under cap ──────────────────────────
  // Query all invoker/* environments in the Hall repo, read usage vars via
  // REST API (app token provided so we can read any env's variables), filter
  // out at-cap members, sort ascending by count, pick first.
  let invoker      = '';
  let invokerCount = 0;

  if (agent) {
    const hallOwner = context.repo.owner;
    const hallRepo  = context.repo.repo;

    // Paginate through all environments and collect invoker/* ones
    let envs = [];
    let page = 1;
    while (true) {
      const res = await github.request('GET /repos/{owner}/{repo}/environments', {
        owner: hallOwner, repo: hallRepo, per_page: 100, page
      });
      const batch = (res.data.environments || []).filter(e => e.name.startsWith('invoker/'));
      envs = envs.concat(batch);
      if ((res.data.environments || []).length < 100) break;
      page++;
    }
    core.info(`[detect] found ${envs.length} invoker environment(s)`);

    const candidates = [];
    for (const env of envs) {
      // Environment names with slashes must be percent-encoded in the API path.
      // encodeURIComponent('invoker/alice') → 'invoker%2Falice'
      const encodedName = encodeURIComponent(env.name);
      let count = 0;
      let cap   = 25;
      try {
        const r = await github.request(
          'GET /repos/{owner}/{repo}/environments/{environment_name}/variables/{variable_name}',
          { owner: hallOwner, repo: hallRepo, environment_name: encodedName, variable_name: 'HALL_USAGE_COUNT' }
        );
        count = parseInt(r.data.value || '0', 10);
      } catch (_) { /* not set yet — default 0 */ }
      try {
        const r = await github.request(
          'GET /repos/{owner}/{repo}/environments/{environment_name}/variables/{variable_name}',
          { owner: hallOwner, repo: hallRepo, environment_name: encodedName, variable_name: 'HALL_WEEKLY_CAP' }
        );
        cap = parseInt(r.data.value || '25', 10);
      } catch (_) { /* not set yet — default 25 */ }
      core.info(`[detect] ${env.name}: count=${count} cap=${cap}`);
      if (count < cap) {
        candidates.push({ handle: env.name.replace('invoker/', ''), count });
      }
    }

    if (candidates.length > 0) {
      candidates.sort((a, b) => a.count - b.count);
      invoker      = candidates[0].handle;
      invokerCount = candidates[0].count;
      core.info(`[detect] selected invoker=${invoker} (count=${invokerCount})`);
    } else {
      core.info('[detect] no invoker available — all at cap');
    }
  }

  core.setOutput('actor',         actor);
  core.setOutput('agent',         agent);
  core.setOutput('issue-number',  issueNumber);
  core.setOutput('invoker',       invoker);
  core.setOutput('invoker-count', String(invokerCount));
  core.setOutput('trigger-event', triggerEvent);
  core.setOutput('repo-owner',    repoOwner);
  core.setOutput('repo-name',     repoName);
};
