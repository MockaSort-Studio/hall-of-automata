---
name: hall-init-board
description: Provision the Hall of Automata Projects v2 board, custom fields, and labels on the current target repo — idempotent
argument-hint: [--force]
allowed-tools: [Bash]
---

# /hall:init-board

Provisions the GitHub Projects v2 board for Hall cross-invoker coordination. Safe to re-run — skips anything that already exists. Pass `--force` to bypass the cached board number and re-run creation.

State flows through `.hall-cache/session/.board-init-state.json`. Hard-stop on any unhandled error.

## Code quality

All files produced by this skill must stay under 200 lines. Prefer many small, focused files. No duplicated logic.

## Execution sequence

### Step 1: Resolve repo and owner type

```bash
set -euo pipefail
REPO=$(git remote get-url origin | sed 's|.*github.com[:/]||;s|\.git$||')
OWNER=$(echo "$REPO" | cut -d/ -f1)
OWNER_TYPE=$(gh api "repos/${REPO}" --jq '.owner.type')
mkdir -p .hall-cache/session
python3 -c "
import json
json.dump({'owner':'${OWNER}','owner_type':'${OWNER_TYPE}','repo':'${REPO}'},
  open('.hall-cache/session/.board-init-state.json','w'), indent=2)
"
echo "Resolved: OWNER=${OWNER} OWNER_TYPE=${OWNER_TYPE}"
```

### Step 2: Check for existing board

```bash
BOARD_NUM=$(python3 -c \
  "import json; print(json.load(open('.hall-cache/session/config.json')).get('board_project_number',''))" \
  2>/dev/null || echo "")
if [ -n "$BOARD_NUM" ]; then
  echo "Board #${BOARD_NUM} already provisioned — skipping Step 3."
  python3 -c "
import json
s = json.load(open('.hall-cache/session/.board-init-state.json'))
s['board_was_created'] = False
json.dump(s, open('.hall-cache/session/.board-init-state.json','w'), indent=2)
"
else
  echo "No board cached — will create."
fi
```

If `BOARD_NUM` is non-empty and `--force` was not passed, skip Step 3 and continue to Step 4.

### Step 3: Create Projects v2 board

Skip if `BOARD_NUM` is set (from Step 2) and `--force` was not passed.

```bash
set -euo pipefail
OWNER=$(python3 -c "import json; print(json.load(open('.hall-cache/session/.board-init-state.json'))['owner'])")
OWNER_TYPE=$(python3 -c "import json; print(json.load(open('.hall-cache/session/.board-init-state.json'))['owner_type'])")
REPO=$(python3 -c "import json; print(json.load(open('.hall-cache/session/.board-init-state.json'))['repo'])")
REPO_NAME=$(echo "$REPO" | cut -d/ -f2)

if [ "$OWNER_TYPE" = "Organization" ]; then
  OWNER_ID=$(gh api graphql -f query='query($l:String!){organization(login:$l){id}}' \
    -F l="$OWNER" --jq '.data.organization.id')
else
  OWNER_ID=$(gh api graphql -f query='query($l:String!){user(login:$l){id}}' \
    -F l="$OWNER" --jq '.data.user.id')
fi

RESULT=$(gh api graphql \
  -f query='mutation($o:ID!,$t:String!){createProjectV2(input:{ownerId:$o,title:$t}){projectV2{id number}}}' \
  -F o="$OWNER_ID" -F t="$REPO_NAME")
PROJECT_ID=$(echo "$RESULT" | jq -r '.data.createProjectV2.projectV2.id')
PROJECT_NUM=$(echo "$RESULT" | jq -r '.data.createProjectV2.projectV2.number')

REPO_ID=$(gh api graphql \
  -f query='query($o:String!,$r:String!){repository(owner:$o,name:$r){id}}' \
  -F o="$OWNER" -F r="$REPO_NAME" --jq '.data.repository.id')
gh api graphql \
  -f query='mutation($p:ID!,$r:ID!){linkProjectV2ToRepository(input:{projectId:$p,repositoryId:$r}){repository{name}}}' \
  -F p="$PROJECT_ID" -F r="$REPO_ID" --jq '.data.linkProjectV2ToRepository.repository.name'
echo "Board linked to repository ${REPO}."

python3 -c "
import json
s = json.load(open('.hall-cache/session/.board-init-state.json'))
s['project_id'] = '${PROJECT_ID}'
s['project_num'] = ${PROJECT_NUM}
s['board_was_created'] = True
json.dump(s, open('.hall-cache/session/.board-init-state.json','w'), indent=2)
"
echo "Created ${REPO_NAME} board #${PROJECT_NUM} (${PROJECT_ID})"
```

### Step 4: Create custom fields

Read `project_id` from state or `config.json`, then source the lib script.

```bash
set -euo pipefail
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT must be set}"

export PROJECT_ID=$(python3 -c "
import json, os
s = json.load(open('.hall-cache/session/.board-init-state.json'))
cfg_path = '.hall-cache/session/config.json'
cfg = json.load(open(cfg_path)) if os.path.exists(cfg_path) else {}
print(s.get('project_id') or cfg.get('board_project_id',''))
")

# shellcheck source=skills/hall-init-board/lib/create-fields.sh
source "${PLUGIN_ROOT}/skills/hall-init-board/lib/create-fields.sh"
create_fields
```

### Step 5: Create labels

```bash
export REPO=$(python3 -c "import json; print(json.load(open('.hall-cache/session/.board-init-state.json'))['repo'])")
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT must be set}"

# shellcheck source=skills/hall-init-board/lib/create-labels.sh
source "${PLUGIN_ROOT}/skills/hall-init-board/lib/create-labels.sh"
create_labels
```

### Step 6: Run GetProjectMeta and persist

```bash
set -euo pipefail
OWNER=$(python3 -c "import json; print(json.load(open('.hall-cache/session/.board-init-state.json'))['owner'])")
OWNER_TYPE=$(python3 -c "import json; print(json.load(open('.hall-cache/session/.board-init-state.json'))['owner_type'])")
PROJECT_NUM=$(python3 -c "
import json, os
s = json.load(open('.hall-cache/session/.board-init-state.json'))
cfg_path = '.hall-cache/session/config.json'
cfg = json.load(open(cfg_path)) if os.path.exists(cfg_path) else {}
print(s.get('project_num') or cfg.get('board_project_number',''))
")

FIELDS_FRAG='fields(first:50){nodes{...on ProjectV2Field{id name}...on ProjectV2SingleSelectField{id name options{id name}}}}'
if [ "$OWNER_TYPE" = "Organization" ]; then
  gh api graphql \
    -f query="query(\$o:String!,\$n:Int!){organization(login:\$o){projectV2(number:\$n){id number ${FIELDS_FRAG}}}}" \
    -F o="$OWNER" -F n="$PROJECT_NUM" --jq '.data.organization.projectV2' \
    > .hall-cache/session/.meta-raw.json
else
  gh api graphql \
    -f query="query(\$o:String!,\$n:Int!){user(login:\$o){projectV2(number:\$n){id number ${FIELDS_FRAG}}}}" \
    -F o="$OWNER" -F n="$PROJECT_NUM" --jq '.data.user.projectV2' \
    > .hall-cache/session/.meta-raw.json
fi

python3 << 'PYEOF'
import json, os

meta = json.load(open('.hall-cache/session/.meta-raw.json'))
if not meta or 'id' not in meta:
    raise SystemExit('ERROR: GetProjectMeta returned empty — check project number and owner type')

fields_out = {}
for node in meta.get('fields', {}).get('nodes', []):
    if not node or 'id' not in node:
        continue
    entry = {'id': node['id']}
    if 'options' in node:
        entry['options'] = {o['name']: o['id'] for o in node['options']}
    fields_out[node['name']] = entry

json.dump({'project_id': meta['id'], 'fields': fields_out},
          open('.hall-cache/session/board-meta.json', 'w'), indent=2)

cfg_path = '.hall-cache/session/config.json'
cfg = json.load(open(cfg_path)) if os.path.exists(cfg_path) else {}
cfg['board_project_number'] = str(meta.get('number', ''))
cfg['board_project_id'] = meta['id']
json.dump(cfg, open(cfg_path, 'w'), indent=2)
print(f"Resolved {len(fields_out)} fields. Persisted board-meta.json and config.json.")
PYEOF
```

### Step 6.5: Create Roadmap view

```bash
PROJECT_ID=$(python3 -c "import json; print(json.load(open('.hall-cache/session/board-meta.json'))['project_id'])")

# Check for existing Roadmap view
EXISTING=$(gh api graphql \
  -f query='query($p:ID!){node(id:$p){...on ProjectV2{views(first:20){nodes{name}}}}}' \
  -F p="$PROJECT_ID" \
  --jq '[.data.node.views.nodes[].name] | contains(["Roadmap"])' 2>/dev/null || echo "false")

if [ "$EXISTING" = "true" ]; then
  echo "Roadmap view already exists — skipping."
else
  gh api graphql \
    -f query='mutation($p:ID!,$n:String!,$l:ProjectV2ViewLayout!){createProjectV2View(input:{projectId:$p,name:$n,layout:$l}){projectV2View{id name}}}' \
    -F p="$PROJECT_ID" -F n="Roadmap" -F l="ROADMAP_LAYOUT" \
    --jq '.data.createProjectV2View.projectV2View.name' 2>/dev/null \
    && echo "Roadmap view created." \
    || echo "WARN: Roadmap view creation failed (layout may not be available on this plan) — continuing."
fi
```

### Step 7: Confirm

```bash
python3 -c "
import json
meta = json.load(open('.hall-cache/session/board-meta.json'))
cfg = json.load(open('.hall-cache/session/config.json'))
print(f\"Hall Board #{cfg.get('board_project_number','?')} ready — {len(meta.get('fields',{}))} fields resolved, labels provisioned.\")
"
```
