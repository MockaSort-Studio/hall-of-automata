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

  // Parse target repository from issue body when not overridden by workflow inputs.
  // Matches the "### Target repository" field in the automaton-task issue template.
  // Expected format: "owner/repo". Blank or "_No response_" falls back to Hall repo.
  const parseTargetRepo = (body) => {
    if (!body) return;
    const m = body.match(/###\s*Target repository\s*\n+([^\n]+)/i);
    if (!m) return;
    const field = m[1].trim();
    if (!field || field === '_No response_') return;
    const parts = field.split('/');
    if (parts.length === 2 && parts[0].trim() && parts[1].trim()) {
      return { owner: parts[0].trim(), name: parts[1].trim() };
    }
  };

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
    // hall:dispatch-automaton — standard invocation path; routes to Old Major for triage
    if (label === 'hall:dispatch-automaton') {
      agent = 'old-major';
    } else {
      agent = label.replace('hall:', '');
    }
    issueNumber  = String(payload.issue.number);
    // If the label was applied by the Hall bot (e.g. Old Major delegating to an agent),
    // inherit the issue author so the original invoker's authz carries through.
    actor        = payload.sender?.type === 'Bot'
                     ? (payload.issue?.user?.login || context.actor)
                     : payload.sender.login;
    triggerEvent = 'issue_labeled';
    // Extract target repo from issue body when not provided via workflow inputs.
    if (!process.env.INPUT_REPO_OWNER && !process.env.INPUT_REPO_NAME) {
      const parsed = parseTargetRepo(payload.issue?.body);
      if (parsed) { repoOwner = parsed.owner; repoName = parsed.name; }
    }

  } else if (event === 'issue_comment') {
    // Never process bot comments — prevents rejection comment feedback loops
    const senderType = payload.sender?.type || '';
    core.info(`[detect] event=issue_comment sender=${payload.sender?.login} senderType=${senderType}`);
    if (senderType === 'Bot') { core.setOutput('agent', ''); return; }

    // Reply while awaiting input: non-bot comment on an issue carrying a
    // hall:{agent} label re-dispatches that agent. hall:awaiting-input is not
    // required — it may not yet be applied when the invoker replies quickly
    // (race condition between post-dispatch label application and the comment).
    // hall:dispatch-automaton is a valid label here and routes to old-major.
    const labels     = payload.issue?.labels || [];
    core.info(`[detect] labels=${JSON.stringify(labels.map(l => l.name))}`);
    const hallLabel  = labels.find(l => l.name.startsWith('hall:') && !SYSTEM_LABELS.includes(l.name));
    core.info(`[detect] hallLabel=${hallLabel?.name}`);
    if (!hallLabel)  { core.setOutput('agent', ''); return; }
    agent = hallLabel.name === 'hall:dispatch-automaton' ? 'old-major' : hallLabel.name.replace('hall:', '');
    issueNumber  = String(payload.issue.number);
    actor        = payload.sender.login;
    triggerEvent = 'issue_comment';
    // Extract target repo from issue body when not provided via workflow inputs.
    if (!process.env.INPUT_REPO_OWNER && !process.env.INPUT_REPO_NAME) {
      const parsed = parseTargetRepo(payload.issue?.body);
      if (parsed) { repoOwner = parsed.owner; repoName = parsed.name; }
    }

  } else if (event === 'pull_request_review') {
    const body    = payload.review?.body || '';
    const mention = body.match(/@hall-of-automata(?:\[bot\])?/i);
    // @mention is required — prevents any reviewer on an agent-owned PR from accidentally
    // triggering dispatch. If @mention present but no agent name, fall back to PR label.
    if (!mention) { core.setOutput('agent', ''); return; }
    const nameMatch = body.match(/@hall-of-automata(?:\[bot\])?\s+(?:agent:\s*)?(\w[\w-]*)/i);
    if (nameMatch) {
      agent = nameMatch[1];
    } else {
      // Fall back to the bound hall:<agent> label on the PR
      const prLabels = (payload.pull_request?.labels || []).map(l => l.name);
      const bound    = prLabels.find(l => l.startsWith('hall:') && !SYSTEM_LABELS.includes(l));
      if (!bound) { core.setOutput('agent', ''); return; }
      agent = bound.replace('hall:', '');
    }
    issueNumber  = String(payload.pull_request.number);
    actor        = payload.sender.login;
    triggerEvent = 'pr_review';
    core.setOutput('pr-number',   issueNumber);
    core.setOutput('review-body', body);

  } else if (event === 'workflow_call' || event === 'workflow_dispatch') {
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

    // Read routing.fallback from routing.yml to determine cap-exceeded behaviour.
    // 'queue' (default): set empty invoker — the notify-queued job handles it.
    // 'fail': call core.setFailed() immediately.
    let fallback = 'queue';
    try {
      const { data } = await github.rest.repos.getContent({ owner: hallOwner, repo: hallRepo, path: 'routing.yml' });
      const content = Buffer.from(data.content, 'base64').toString('utf8');
      for (const line of content.split('\n')) {
        const m = line.match(/^\s+fallback:\s*(\S+)/);
        if (m) { fallback = m[1]; break; }
      }
      core.info(`[detect] routing.fallback=${fallback}`);
    } catch (err) {
      core.warning(`[detect] could not read routing.yml (${err.message}) — defaulting fallback to queue`);
    }

    // Paginate through all environments and collect invoker/* ones
    let envs = [];
    let page = 1;
    while (true) {
      const res = await github.request('GET /repos/{owner}/{repo}/environments', {
        owner: hallOwner, repo: hallRepo, per_page: 100, page
      });
      // TODO: remove keeper/ filter once all keeper/* envs are migrated to invoker/*
      const batch = (res.data.environments || []).filter(e => e.name.startsWith('invoker/') || e.name.startsWith('keeper/'));
      envs = envs.concat(batch);
      if ((res.data.environments || []).length < 100) break;
      page++;
    }
    core.info(`[detect] found ${envs.length} invoker/keeper environment(s) (keeper/* is legacy, pending migration to invoker/*)`);

    const candidates = [];
    for (const env of envs) {
      let count = 0;
      let cap   = 25;
      try {
        const r = await github.request(
          'GET /repos/{owner}/{repo}/environments/{environment_name}/variables/{variable_name}',
          { owner: hallOwner, repo: hallRepo, environment_name: env.name, variable_name: 'HALL_USAGE_COUNT' }
        );
        count = parseInt(r.data.value || '0', 10);
      } catch (_) { /* not set yet — default 0 */ }
      try {
        const r = await github.request(
          'GET /repos/{owner}/{repo}/environments/{environment_name}/variables/{variable_name}',
          { owner: hallOwner, repo: hallRepo, environment_name: env.name, variable_name: 'HALL_WEEKLY_CAP' }
        );
        cap = parseInt(r.data.value || '25', 10);
      } catch (_) { /* not set yet — default 25 */ }
      core.info(`[detect] ${env.name}: count=${count} cap=${cap}`);
      if (count < cap) {
        // Strip either prefix to get the bare handle
        const handle = env.name.replace(/^(?:invoker|keeper)\//, '');
        candidates.push({ handle, count });
      }
    }

    if (candidates.length > 0) {
      candidates.sort((a, b) => a.count - b.count || Math.random() - 0.5);
      invoker      = candidates[0].handle;
      invokerCount = candidates[0].count;
      core.info(`[detect] selected invoker=${invoker} (count=${invokerCount})`);
    } else {
      core.info(`[detect] no invoker available — all at cap (fallback=${fallback})`);
      if (fallback === 'fail') {
        core.setFailed('[detect] all invokers are at cap and routing.fallback is set to fail.');
        return;
      }
      // fallback === 'queue': leave invoker empty — the notify-queued job handles it
    }
  }

  // ── Parse dispatch mode from issue body ──────────────────────────────────
  let mode = 'doing';
  const issueBody = payload.issue?.body || payload.pull_request?.body || '';
  const modeMatch = issueBody.match(/###\s*Mode\s+(\S+)/i);
  if (modeMatch) {
    const raw = modeMatch[1].toLowerCase();
    if (raw === 'advising') mode = 'advising';
    else if (raw === 'researching') mode = 'researching';
    else mode = 'doing';
  }

  core.setOutput('actor',         actor);
  core.setOutput('agent',         agent);
  core.setOutput('issue-number',  issueNumber);
  core.setOutput('invoker',       invoker);
  core.setOutput('invoker-count', String(invokerCount));
  core.setOutput('trigger-event', triggerEvent);
  core.setOutput('repo-owner',    repoOwner);
  core.setOutput('repo-name',     repoName);
  core.setOutput('mode',          mode);
};
