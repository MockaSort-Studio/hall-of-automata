# Board Spec — GraphQL Query Templates

All `gh api graphql` operations for Projects v2 board integration. Companion to [`board-spec.md`](board-spec.md).

Run via: `gh api graphql -f query='<query>' -F var=value`

---

## Node ID Patterns

| Object | ID prefix | How obtained |
|---|---|---|
| Project | `PVT_kw...` | `GetProjectMeta` below |
| Item | `PVTI_lA...` | Listed in `ListItems` |
| Field | `PVTF_lA...` | Listed in `GetProjectMeta` |
| Single-select field | `PVTSSF_lA...` | Listed in `GetProjectMeta` |
| Option | opaque string | Listed in `GetProjectMeta` under field |
| Issue | `I_kw...` | From `item.content.id` in `ListItems` |

Owner type: use `organization` for org-owned repos; substitute `user` for personal repos.

---

## 1. GetProjectMeta

Resolves the project node ID plus all field IDs and option IDs. Run once at `hall:init-board` and at `hall:open` if `board-meta.json` is absent.

```graphql
query GetProjectMeta($owner: String!, $number: Int!) {
  organization(login: $owner) {
    projectV2(number: $number) {
      id
      title
      fields(first: 50) {
        nodes {
          ... on ProjectV2Field {
            id
            name
            dataType
          }
          ... on ProjectV2SingleSelectField {
            id
            name
            options {
              id
              name
            }
          }
          ... on ProjectV2IterationField {
            id
            name
          }
        }
      }
    }
  }
}
```

Variables: `{ "owner": "MockaSort-Studio", "number": 1 }`

Persist response to `.hall-cache/session/board-meta.json` as described in board-spec.md §5.

---

## 2. ListItems (paginated)

Fetches all items with current field values. Page through until `pageInfo.hasNextPage` is false. Persist full result to `.hall-cache/session/board.json`.

```graphql
query ListItems($projectId: ID!, $cursor: String) {
  node(id: $projectId) {
    ... on ProjectV2 {
      items(first: 100, after: $cursor) {
        pageInfo {
          hasNextPage
          endCursor
        }
        nodes {
          id
          content {
            ... on Issue {
              id
              number
              title
              state
              url
              assignees(first: 5) {
                nodes { login }
              }
              labels(first: 10) {
                nodes { name }
              }
            }
          }
          fieldValues(first: 20) {
            nodes {
              ... on ProjectV2ItemFieldSingleSelectValue {
                name
                field { ... on ProjectV2SingleSelectField { name } }
              }
              ... on ProjectV2ItemFieldTextValue {
                text
                field { ... on ProjectV2Field { name } }
              }
              ... on ProjectV2ItemFieldDateValue {
                date
                field { ... on ProjectV2Field { name } }
              }
            }
          }
        }
      }
    }
  }
}
```

Variables: `{ "projectId": "<project node ID>", "cursor": null }` — set `cursor` to `endCursor` on subsequent pages.

**Client-side filtering:** Projects v2 has no server-side field-value filter. Filter the cached `board.json` items array in the MCP server. Never issue a separate query per filter condition.

---

## 3. UpdateField

Updates one field on one item. Only call on items where `Invoker` field matches current session login (enforced by MCP server before calling).

```graphql
mutation UpdateField(
  $projectId: ID!
  $itemId: ID!
  $fieldId: ID!
  $value: ProjectV2FieldValue!
) {
  updateProjectV2ItemFieldValue(input: {
    projectId: $projectId
    itemId: $itemId
    fieldId: $fieldId
    value: $value
  }) {
    projectV2Item {
      id
    }
  }
}
```

`$value` shapes by field type:

| Field type | Value shape |
|---|---|
| Single-select | `{ "singleSelectOptionId": "<option node ID>" }` |
| Text | `{ "text": "alice" }` |
| Date | `{ "date": "2026-05-19" }` |
| Number | `{ "number": 3 }` |

Resolve option node IDs from `board-meta.json`; never hardcode them.

---

## 4. AddComment

Posts a comment on a linked issue. The only write permitted on items owned by foreign invokers.

```graphql
mutation AddComment($issueId: ID!, $body: String!) {
  addComment(input: {
    subjectId: $issueId
    body: $body
  }) {
    commentEdge {
      node {
        id
        url
      }
    }
  }
}
```

Variables: `{ "issueId": "<issue node ID from item.content.id>", "body": "<markdown string>" }`

For cross-invoker messages, `body` must include the `hall-board-msg` fenced block defined in board-spec.md §3, plus human-readable text outside the fence.

---

## 5. Error Handling

| HTTP / GraphQL error | Action |
|---|---|
| `RATE_LIMITED` | Back off 60 s; retry once; then set outcome `quota_exceeded` |
| `NOT_FOUND` on project | Abort; log to `.hall-cache/session/board-errors.log`; post issue comment naming the missing resource |
| `FORBIDDEN` on field write | Item is owned by another invoker; fall back to `AddComment` |
| `UNPROCESSABLE` on option ID | `board-meta.json` is stale; re-run `GetProjectMeta` and retry once |
| Network timeout | Retry once after 10 s; on second failure, skip board write and log |

All errors are non-fatal for the primary dispatch flow. Board sync failures must not block issue filing or PR creation.
// Tomashco 🛹 — every query here maps to one and only one MCP server tool call
