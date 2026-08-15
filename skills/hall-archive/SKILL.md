---
name: hall-archive
description: Detect and archive stale closed OKRs to the wiki appendix. Preview mode (default) lists candidates; --write commits entries idempotently.
---

# Skill: hall-archive

## Trigger

Invoked as `/hall:archive` (preview) or `/hall:archive --write` (write). This skill activates on both forms. Never run in write mode without explicit `--write`.

## Purpose

Find OKR-type issues closed more than 90 days ago that are absent from the archive wiki page, and — in write mode — append one row per eligible OKR without touching existing rows.

---

## Step 1 — Fetch OKR candidates

Search the target repository for issues with `label:hall:okr is:issue is:closed`.

Filter in memory: keep only those where `closed_at` is more than 90 days before today's date.

---

## Step 2 — Fetch wiki appendix and derive already-archived set

Read the wiki page `OKR-Archive.md`. If the page does not exist, the already-archived set is empty.

Parse it: collect every OKR issue number already present in the page. Match on the pattern `OKR #N` or a bare link to an OKR issue URL. Collect issue numbers only — do not match on title, which may have changed since archiving.

---

## Step 3 — Idempotency filter

For each candidate from Step 1: drop it if its issue number is in the already-archived set.

The remaining set is **eligible**.

Idempotency is keyed on issue number, not on title. An OKR whose title was edited after being archived is still recognised as already present.

---

## Step 4 — Fetch linked KRs and Items for each eligible OKR

For each eligible OKR, fetch its sub-issues via the GitHub sub-issues API.

Classify sub-issues by label:
- `hall:kr` → KR
- `hall:item` → Item

Collect the issue numbers of each class. If there are no sub-issues, both lists are empty.

---

## Preview mode (default — no `--write` flag)

Emit exactly this block and stop. Write nothing to the wiki.

```
## /hall:archive preview — <YYYY-MM-DD>

Eligible (<N>):
  - OKR #<issue_number> — <title> (closed <YYYY-MM-DD>)  KRs: <#X, #Y or "none">  Items: <#Z or "none">

Already archived (<M>): <comma-separated issue numbers, or "none">
Not yet eligible (<P>): <count only — no individual listing>
```

If N = 0, the "Eligible" line reads: `Eligible (0): none`.

Do not list individual not-yet-eligible OKRs — count only. Never include ineligible or already-archived OKRs in the Eligible section.

---

## Write mode (`--write`)

For each eligible OKR in ascending issue-number order:

1. Append one row to `OKR-Archive.md` in the wiki.
2. Do not reorder, reformat, or modify any existing row.
3. After all rows are appended, commit the updated page with message:
   `archive: add <N> OKR(s) via /hall:archive`

### Row format

```
| [OKR #<N> — <title>](<issue_url>) | <closed_at YYYY-MM-DD> | KRs: <#X, #Y — or "—"> · Items: <#Z — or "—"> |
```

- Strip the `OKR:` prefix from the title if present.
- `closed_at` is the UTC date only (no time component).
- The KRs/Items column uses `—` when the respective list is empty.

### Wiki page initialisation

If `OKR-Archive.md` does not exist, create it with this skeleton before appending:

```markdown
# OKR Archive

Managed by `/hall:archive`. Do not edit rows by hand — append only.

| OKR | Closed | Linked KRs / Items |
|-----|--------|-------------------|
```

Append rows immediately after the table header (or after the last existing data row). Never insert rows above existing rows.

---

## Verification (after write run)

1. Row count appended equals the N from the eligible list.
2. Re-run in preview mode: confirm `Eligible (0): none` (idempotency check).
3. Diff the wiki page: confirm no existing row was modified — additions only.

If verification step 2 fails, do not mark the task complete. Investigate the idempotency filter before retrying.

---

## Code quality constraint

When implementing supporting utilities for this skill:
- ~200 lines hard ceiling per file
- No duplicated logic across files
- Prefer many small focused files
- The write path must not execute without an explicit `--write` flag

---

// Snowball 🐷 — issue-number keying is what makes idempotency durable across OKR renames
