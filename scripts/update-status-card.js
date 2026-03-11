// Creates or updates the Hall status card comment on an issue or PR.
// The card is identified by the <!-- hall-status --> HTML marker. If no card exists,
// one is created. If one exists, it is edited in-place.
// Env vars: REPO_OWNER, REPO_NAME, ISSUE_NUMBER, AGENT, STAGE,
//           BRANCH, PR_NUMBER, EXTRA, DISPATCHED_AT

module.exports = async ({ github, context, core }) => {
  const owner   = process.env.REPO_OWNER;
  const repo    = process.env.REPO_NAME;
  const issueNo = Number(process.env.ISSUE_NUMBER);
  const agent   = process.env.AGENT;
  const stage   = process.env.STAGE;
  const branch  = process.env.BRANCH  || '—';
  const pr      = process.env.PR_NUMBER ? `#${process.env.PR_NUMBER}` : '—';
  const extra   = process.env.EXTRA    || '';

  const stageLabel = {
    'dispatching':    'Dispatching agent...',
    'assigning':      'Old Major is Assigning the Quest',
    'analyzing':      'Analyzing...',
    'awaiting-input': 'Awaiting context — question posted',
    'queued':         'Queued — weekly quota reached',
    'working':        `Working — \`${branch}\``,
    'pr-opened':      `PR opened — ${pr}`,
    'ci-fix':         `CI fix in progress${extra ? ` (${extra})` : ''}`,
    'escalated':      'Escalated — keeper notified',
    'failed':         'Failed — see comments',
    'done':           process.env.PR_NUMBER ? `Done — ${pr} merged` : 'Done — response posted',
  }[stage] ?? stage;

  const dispatched = process.env.DISPATCHED_AT
    || new Date().toISOString().replace('T', ' ').slice(0, 19) + ' UTC';
  const runUrl  = `${context.serverUrl}/${context.repo.owner}/${context.repo.repo}/actions/runs/${context.runId}`;
  const runLink = `[Run #${context.runId}](${runUrl})`;

  const body = [
    '<!-- hall-status -->',
    `### Hall \u2014 ${agent}`,
    '',
    '| | |',
    '|---|---|',
    `| **Stage** | ${stageLabel} |`,
    `| **Dispatched** | ${dispatched} |`,
    `| **Branch** | \`${branch}\` |`,
    `| **PR** | ${pr} |`,
    `| **Run** | ${runLink} |`,
  ].join('\n');

  // Search for an existing status card in the thread
  let existingId = null;
  for await (const page of github.paginate.iterator(
    github.rest.issues.listComments,
    { owner, repo, issue_number: issueNo, per_page: 100 }
  )) {
    for (const c of page.data) {
      if (c.body && c.body.startsWith('<!-- hall-status -->')) {
        existingId = c.id;
        break;
      }
    }
    if (existingId) break;
  }

  let commentId;
  if (existingId) {
    await github.rest.issues.updateComment({ owner, repo, comment_id: existingId, body });
    commentId = existingId;
  } else {
    const res = await github.rest.issues.createComment({ owner, repo, issue_number: issueNo, body });
    commentId = res.data.id;
  }

  core.setOutput('comment-id', String(commentId));
};
