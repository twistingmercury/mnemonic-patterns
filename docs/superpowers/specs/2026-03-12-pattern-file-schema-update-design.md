# Design: Update `docs/pattern-file-schema.md` for Decorator-Based Chunking

**Date:** 2026-03-12
**Status:** Approved

## Problem

`docs/pattern-file-schema.md` is outdated in four ways:

1. **Intro paragraph** states "Each H2 section is stored as a separate searchable chunk" — wrong under the decorator model.
2. **Body Structure** describes the old H2-boundary chunking model in detail. This is wrong — the system now uses explicit `[//]: pattern` decorators.
3. **Validation Rules** still reference "at least one H2 section", not decorators.
4. **Frontmatter enums** (`language`, `domain`) are stale. `validate.sh` has grown significantly and is the authoritative source.

Additionally, `validate.sh` itself still enforces the old H2 rule (line 193: `grep -q '^## '`) and must be updated to check for `[//]: pattern` decorators instead.

## Approach

Surgical edits plus a new dedicated `## Chunking` section (Option C). The decorator system is non-obvious enough — empty-body dropping, undecorated content discarded, `## Overview` intentionally bare — that a dedicated section with examples will prevent author errors better than a patched-in paragraph.

## Changes

### 1. Frontmatter Enums (updated values only)

Pull `language` and `domain` values directly from `validate.sh` constants:

- `VALID_LANGUAGES` (40 values): `agnostic bash c cpp csharp cql cypher dart delphi docker elixir erlang go json java javascript kotlin lua markdown matlab mql objective-c perl php plsql powershell python r react ruby rust scala shell sql swift toml tsql typescript visual-basic yaml zig`
  - Note: `dotnet` is removed — it was in the old schema doc but does not exist in `validate.sh`
- `VALID_DOMAINS` (14 values): `api-design backend frontend testing devops cli data-design documentation data-access security shell-scripting configuration observability source-management`

### 2. Intro Paragraph (updated)

Update the opening paragraph of `pattern-file-schema.md` to remove the statement "Each H2 section is stored as a separate searchable chunk in Mnemonic." Replace with a brief description of the decorator model: only sections preceded by `[//]: pattern` are indexed.

### 3. Body Structure (rewritten)

Replace the current description. Key points:
- `## Overview` is required and must NOT be decorated — it is never indexed
- All sections intended for search must be preceded by `[//]: pattern` on its own line, immediately before the heading
- Sections without a decorator are silently discarded by the chunker
- H3 headings are supported the same as H2

Remove the recommended sections table (it describes an old convention that no longer maps to the chunking model).

Remove the note: "A file with no H2 headings will produce no chunks and fail validation." — this is no longer how validation works.

### 4. New `## Chunking` Section (after Body Structure)

Cover:
- **Syntax:** exact string `[//]: pattern`, no trailing whitespace, placed immediately before a heading (any level `#`–`######`)
- **Scope:** everything from that heading to the next decorator or EOF becomes the chunk body
- **Discarded content:** lines outside decorated sections are never indexed (intro prose, `## Overview`, etc.)
- **Empty body rule:** decorated sections with no body content after trimming are dropped silently
- **`## Overview` rule:** never decorate it — it is intentionally excluded from the index
- **Short example:** a file excerpt showing mixed decorated/undecorated sections

### 5. Complete Example (updated)

Add `[//]: pattern` decorators to the existing example. `## Overview` stays bare. All substantive sections (`## Implementation`, `## Example`, `## Key Patterns`) get the decorator.

### 6. Validation Rules (rule 9 updated)

Change rule 9 from:
> At least one H2 section is present in the body.

To:
> At least one `[//]: pattern` decorator is present in the body.

Rule 10 (`## Overview` present) is unchanged.

### 7. `validate.sh` (body structure check updated)

Replace the H2 body-structure check (lines 191–196) with a decorator check:

Old:
```bash
if ! grep -q '^## ' "${file}"; then
    print::error "No H2 sections (## ) found in ${file}: at least one is required"
```

New:
```bash
if ! grep -qF '[//]: pattern' "${file}"; then
    print::error "No '[//]: pattern' decorators found in ${file}: at least one decorated section is required"
```

The `## Overview` check (line 199) is unchanged.

**Known limitation:** the grep check matches the string anywhere in the file, including inside fenced code blocks. This is the same trade-off as the old H2 check. `pattern-file-schema.md` is in `SKIP_FILES` so the schema doc's own code examples do not trigger false positives. This is an accepted limitation.

## Known Pre-Existing Inconsistency (out of scope)

`validate.sh` checks for field *presence* but not non-empty values (the `jq -e ".${field}"` call returns true for empty strings). The schema doc's rule 8 claims `description` is validated as non-empty. This inconsistency pre-dates this work and is not introduced by these changes. Fixing it is out of scope.

## Files Changed

- `docs/pattern-file-schema.md` — in-place update, no file renames or moves
- `scripts/validate.sh` — body structure check updated (one grep replacement)

## Out of Scope

- `docs/authoring-patterns.md` — separate follow-up task
- Changes to pattern files themselves — all ~65 files were already decorated in March 2026
