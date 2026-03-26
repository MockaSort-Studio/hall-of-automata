// Canonical set of Hall labels seeded into every org repo on installation
// and into new repos as they are created. Keep in sync with invoke.yml label references.

export const HALL_LABELS = [
  { name: 'hall:onboard-invoker',    color: '7057ff', description: 'Trigger invoker registration' },
  { name: 'hall:onboard-automaton',  color: '7057ff', description: 'Trigger automaton provisioning' },
  { name: 'hall:active-invoker',     color: '0e8a16', description: 'Confirmed invoker' },
  { name: 'hall:awaiting-input',     color: 'e4e669', description: 'Hall waiting on human reply' },
  { name: 'hall:queued',             color: 'd93f0b', description: 'Request queued — cap reached' },
  { name: 'hall:invoker-queued',     color: 'd93f0b', description: 'No invoker available' },
  { name: 'hall:dispatch-automaton', color: '5319e7', description: 'Routes to old-major for triage' },
  { name: 'hall:post-mortem',        color: 'b60205', description: 'Trigger post-mortem analysis' },
]
