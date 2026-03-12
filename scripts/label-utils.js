// Hall label management utilities.
// Env vars: ACTION (apply-agent | awaiting | routing)
//
// apply-agent: REPO_OWNER, REPO_NAME, PR_NUMBER, AGENT
//   Ensures hall:{agent} label exists and applies it to a PR.
//
// awaiting: MODE (apply | remove), REPO_OWNER, REPO_NAME, ISSUE_NUMBER
//   Applies or removes the hall:awaiting-input label on an issue.
//
// routing: AGENT, REPO_OWNER, REPO_NAME, ISSUE_NUMBER
//   Manages routing labels when a dispatch starts.
//   old-major: removes hall:dispatch-automaton, applies hall:old-major.
//   specialist: removes hall:old-major (if present).

const applyAgent = async ({ github, core }) => {
  const owner  = process.env.REPO_OWNER;
  const repo   = process.env.REPO_NAME;
  const prNum  = Number(process.env.PR_NUMBER);
  const agent  = process.env.AGENT;
  const label  = `hall:${agent}`;

  // Ensure label exists in the repo (create if missing)
  try {
    await github.rest.issues.getLabel({ owner, repo, name: label });
  } catch {
    await github.rest.issues.createLabel({ owner, repo, name: label, color: 'f97316' });
  }

  await github.rest.issues.addLabels({ owner, repo, issue_number: prNum, labels: [label] });
  core.info(`[label-utils] applied ${label} to ${owner}/${repo}#${prNum}`);
};

const AWAITING_LABEL = 'hall:awaiting-input';

const awaiting = async ({ github, core }) => {
  const owner       = process.env.REPO_OWNER;
  const repo        = process.env.REPO_NAME;
  const issueNumber = Number(process.env.ISSUE_NUMBER);

  if (process.env.MODE === 'apply') {
    // Ensure label exists
    try {
      await github.rest.issues.getLabel({ owner, repo, name: AWAITING_LABEL });
    } catch {
      await github.rest.issues.createLabel({ owner, repo, name: AWAITING_LABEL, color: '6366f1' });
    }
    await github.rest.issues.addLabels({ owner, repo, issue_number: issueNumber, labels: [AWAITING_LABEL] });
  } else {
    try {
      await github.rest.issues.removeLabel({ owner, repo, issue_number: issueNumber, name: AWAITING_LABEL });
    } catch {
      // Label may already be gone — not an error
    }
  }
};

const routing = async ({ github, core }) => {
  const owner       = process.env.REPO_OWNER;
  const repo        = process.env.REPO_NAME;
  const issueNumber = Number(process.env.ISSUE_NUMBER);
  const agent       = process.env.AGENT;

  const removeLabel = async (name) => {
    try {
      await github.rest.issues.removeLabel({ owner, repo, issue_number: issueNumber, name });
    } catch {
      // Label may already be absent — not an error
    }
  };

  const ensureAndApplyLabel = async (name, color) => {
    try {
      await github.rest.issues.getLabel({ owner, repo, name });
    } catch {
      await github.rest.issues.createLabel({ owner, repo, name, color });
    }
    await github.rest.issues.addLabels({ owner, repo, issue_number: issueNumber, labels: [name] });
  };

  if (agent === 'old-major') {
    await removeLabel('hall:dispatch-automaton');
    await ensureAndApplyLabel('hall:old-major', 'd4a017');
    core.info('[label-utils] swapped hall:dispatch-automaton → hall:old-major');
  } else {
    await removeLabel('hall:old-major');
    core.info(`[label-utils] removed hall:old-major (dispatching to ${agent})`);
  }
};

module.exports = async ({ github, core }) => {
  const action = process.env.ACTION;
  if (action === 'apply-agent') return await applyAgent({ github, core });
  if (action === 'awaiting')    return await awaiting({ github, core });
  if (action === 'routing')     return await routing({ github, core });
  throw new Error(`label-utils: unknown ACTION=${action}`);
};
