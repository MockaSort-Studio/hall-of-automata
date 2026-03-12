// Selects the least-used invoker from the invoker/* environment pool.
// Queries all invoker/* (and legacy invoker/*) environments, reads HALL_USAGE_COUNT
// and HALL_WEEKLY_CAP for each, filters out at-cap members, and picks the least-used.
// Env vars:
//   FAIL_FAST    — if 'true', calls core.setFailed() when no invoker is available
//   FAIL_MESSAGE — custom setFailed message (defaults to generic message)
// Outputs: invoker (bare handle, e.g. 'mksetaro'; empty string if none available)
//          invoker-count (current HALL_USAGE_COUNT for the selected invoker)

module.exports = async ({ github, context, core }) => {
  const failFast = process.env.FAIL_FAST    === 'true';
  const failMsg  = process.env.FAIL_MESSAGE || 'No invoker available — all at cap.';

  const owner = context.repo.owner;
  const repo  = context.repo.repo;

  // Read routing.yml from the Hall repo to get the configured selection strategy.
  // Falls back to 'least_used' if the file cannot be read.
  let strategy = 'least_used';
  try {
    const { data } = await github.rest.repos.getContent({ owner, repo, path: 'routing.yml' });
    const content = Buffer.from(data.content, 'base64').toString('utf8');
    for (const line of content.split('\n')) {
      const m = line.match(/^\s+strategy:\s*(\S+)/);
      if (m) { strategy = m[1]; break; }
    }
    core.info(`[select-invoker] routing.strategy=${strategy}`);
  } catch (err) {
    core.warning(`[select-invoker] could not read routing.yml (${err.message}) — defaulting strategy to least_used`);
  }

  if (strategy !== 'least_used') {
    core.setFailed(`[select-invoker] unrecognised routing.strategy: '${strategy}'. Only 'least_used' is supported.`);
    return;
  }

  // Paginate through all environments and collect invoker/* and invoker/* ones
  let envs = [], page = 1;
  while (true) {
    const res = await github.request('GET /repos/{owner}/{repo}/environments',
      { owner, repo, per_page: 100, page });
    // TODO: remove invoker/ filter once all invoker/* envs are migrated to invoker/*
    const batch = (res.data.environments || [])
      .filter(e => e.name.startsWith('invoker/') || e.name.startsWith('invoker/'));
    envs = envs.concat(batch);
    if ((res.data.environments || []).length < 100) break;
    page++;
  }
  core.info(`[select-invoker] found ${envs.length} invoker/invoker environment(s)`);

  const candidates = [];
  for (const env of envs) {
    let count = 0, cap = 25;
    try {
      count = parseInt((await github.request(
        'GET /repos/{owner}/{repo}/environments/{environment_name}/variables/{variable_name}',
        { owner, repo, environment_name: env.name, variable_name: 'HALL_USAGE_COUNT' }
      )).data.value || '0', 10);
    } catch (_) { /* not set — default 0 */ }
    try {
      cap = parseInt((await github.request(
        'GET /repos/{owner}/{repo}/environments/{environment_name}/variables/{variable_name}',
        { owner, repo, environment_name: env.name, variable_name: 'HALL_WEEKLY_CAP' }
      )).data.value || '25', 10);
    } catch (_) { /* not set — default 25 */ }
    core.info(`[select-invoker] ${env.name}: count=${count} cap=${cap}`);
    const handle = env.name.replace(/^(?:invoker|invoker)\//, '');
    if (count < cap) {
      candidates.push({ handle, count });
    }
  }

  if (candidates.length === 0) {
    if (failFast) core.setFailed(failMsg);
    core.setOutput('invoker', '');
    return;
  }

  // strategy === 'least_used': sort ascending by count, break ties randomly
  candidates.sort((a, b) => a.count - b.count || Math.random() - 0.5);
  const selected = candidates[0];
  core.info(`[select-invoker] selected invoker=${selected.handle} (count=${selected.count})`);
  core.setOutput('invoker',       selected.handle);
  core.setOutput('invoker-count', String(selected.count));
};
