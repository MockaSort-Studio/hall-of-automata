// Parses a GitHub issue form body into named outputs.
// GitHub forms render as "### Label\n\nvalue" sections.
// Env vars: ISSUE_BODY, ISSUE_LOGIN
// Outputs: invoker-username, weekly-cap-hours, slug, display-name

module.exports = async ({ core }) => {
  const body  = process.env.ISSUE_BODY  || '';
  const login = process.env.ISSUE_LOGIN || '';

  const fields = {};
  const sections = body.split(/\n(?=###\s)/);
  for (const section of sections) {
    const nl = section.indexOf('\n');
    if (nl === -1) continue;
    const rawLabel = section.slice(0, nl).replace(/^###\s+/, '').trim();
    const value    = section.slice(nl).trim().replace(/^_No response_$/im, '');
    // Normalise label: lowercase, strip parenthetical annotations, collapse spaces
    const key = rawLabel.toLowerCase()
      .replace(/\s*\(.*?\)\s*/g, '')
      .trim()
      .replace(/\s+/g, '-')
      .replace(/[^a-z0-9-]/g, '');
    if (key && value) fields[key] = value;
  }

  const username    = fields['github-handle'] || login;
  const capRaw      = fields['weekly-cap'] || fields['weekly-cap-hours'] || '5';
  const capHours    = parseInt(capRaw.match(/\d+/)?.[0] || '5', 10);
  const slug        = (fields['slug'] || '')
    .toLowerCase().replace(/[^a-z0-9-]/g, '-').replace(/-+/g, '-').replace(/^-|-$/g, '');
  const displayName = fields['display-name'] || slug;

  core.info(`[parse-issue-fields] username=${username} cap=${capHours}h slug=${slug}`);
  core.setOutput('invoker-username', username);
  core.setOutput('weekly-cap-hours', String(capHours));
  core.setOutput('slug',             slug);
  core.setOutput('display-name',     displayName);
};
