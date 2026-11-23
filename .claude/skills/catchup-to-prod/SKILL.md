---
name: catchup-to-prod
description: >-
  Catch the staging site (onesteplicensing/web2025, branch gh-pages) up to
  prod's head (onesteplicensing/web2023, branch gh-pages) by merging edits made
  directly on prod back into staging, with safety checks so no staging work is
  overwritten. Use when the user says "catch up to prod", "catch staging up",
  "sync staging with prod", "pull prod's changes into staging", "bring prod
  edits back", or types /catchup-to-prod. Only syncs prod → staging; it never
  opens or merges a staging → prod PR (the user does that themselves).
---

# Catch staging up to prod

Staging is this repo (`origin` = web2025). Prod is `prod` = web2023. Both
publish from their `gh-pages` branch. Changes normally flow staging → prod via
a PR **the user opens and merges themselves**. Sometimes the user edits prod
directly. This skill brings those edits back so the next PR doesn't undo them.

## Hard rules

- **Never** force-push, `git reset --hard`, rebase, `git clean`, or delete
  untracked files. Never delete or overwrite anything the user hasn't approved.
- **Never** open, update or merge a PR to prod, and never push to `prod`.
- **Never** push to `origin` without the user's explicit yes in this run.
- **CNAME:** staging keeps its own `CNAME` exactly as it is: its content, or
  its absence if staging has none. Never take prod's.
- Resolve a conflict automatically **only** when the helper says `TAKE-PROD`.
  Everything else is the user's decision (see step 5).
- If anything unexpected happens mid-merge, run `git merge --abort`. The branch
  returns to exactly where it was, and tell the user what happened.

Helper (read-only, never changes the repo), run from the repo root:
`bash .claude/skills/catchup-to-prod/scripts/catchup.sh <analyze|conflict <file>|resurrected>`

## Steps

### 1. Fetch
Make sure the `prod` remote exists, then fetch both sides:
```bash
git remote get-url prod || git remote add prod https://github.com/onesteplicensing/web2023.git
git fetch origin && git fetch prod
```

### 2. Preflight: `catchup.sh analyze`
It prints `STOP:` lines for anything that needs the user first. For each STOP,
show the user exactly what was found and ask how to proceed. Never pick for
them:
- **Not on gh-pages / merge in progress:** ask; only switch branches if the
  working tree is clean.
- **Uncommitted changes to tracked files:** offer: commit them first (show the
  diff), stash them (`git stash push -m "before catchup-to-prod"`), or stop.
- **Untracked files the sync would overwrite:** compare each with the incoming
  version (`git show prod/gh-pages:<path>` / `origin/gh-pages:<path>`) and
  tell the user whether it's identical, older or newer. Offer to move it to a
  backup location they approve. Never delete it.
- **Unpushed local commits / diverged from origin:** list the commits. Ask:
  push them first, include them in the sync as-is, or stop. Never rebase or
  reset.
- **Behind origin only:** this is safe. With the user's OK run
  `git merge --ff-only origin/gh-pages`, then re-run `analyze`.

If it says `UP TO DATE`, tell the user staging already has prod's head and stop.

### 3. Show the plan and get a go-ahead
Summarize the incoming prod commits and the file list from `analyze`:
| Label | Meaning | What happens |
|---|---|---|
| `INCOMING` | Only prod changed it | Taken from prod |
| `INCOMING*` | Both changed, but staging's copy is already on prod | Prod's newer copy is taken (safe) |
| `KEEP` | Staging work not on prod yet (or prod didn't touch it) | Staging's copy is kept |
| `KEEP*` | Both changed, but prod's copy is just an older staging copy | Recommend keeping staging's; **confirm with user** |
| `OVERLAP` | Both made their own changes | **User decides** per file |
| `RESURRECT` | Staging deleted it on purpose; prod still has it | Recommend keeping it deleted; **confirm with user** |
| `CNAME` | Domain file | Staging's kept |

Ask the user to confirm before changing anything.

### 4. Backup, then merge
```bash
BACKUP=backup/gh-pages-$(date +%Y-%m-%d-%H%M)
git branch "$BACKUP"                       # local only, never pushed
```
**If `analyze` printed `FAST-FORWARD`**, run `git merge --ff-only prod/gh-pages`
and skip to step 8. Staging then matches prod exactly and there is nothing to
commit. This is the normal case right after the user merges a staging → prod PR
with a merge commit. Don't make a `--no-ff` merge here: that would put an empty
merge commit on staging, which the next PR carries to prod, and so on forever.

Otherwise merge without committing:
```bash
git merge --no-ff --no-commit prod/gh-pages
```
Then restore staging's CNAME state:
- staging has CNAME: `git checkout HEAD -- CNAME`
- staging has no CNAME but the merge added it: `git rm -q -f CNAME`

### 5. Resolve conflicts
For every file in `git diff --name-only --diff-filter=U`, run
`catchup.sh conflict <file>`:
- `TAKE-PROD`: `git checkout --theirs -- <file> && git add <file>`. Report it.
- `KEEP-STAGING`: collect these and ask the user once for the whole batch
  (recommend keeping staging's). On yes, run `git checkout --ours -- <file> && git add <file>`.
- `ASK`: show both versions (`git show HEAD:<file>` vs
  `git show prod/gh-pages:<file>`, or the conflict hunks) and let the user
  choose: keep staging's, take prod's, or combine. When combining, write the
  result, show it, and get an OK before `git add`.

Files git merged cleanly where **both** sides had changes (`KEEP*`/`OVERLAP`
files with no conflict): show the merged diff so the user can sanity-check it.
YAML can merge cleanly and still be wrong.

### 6. Check for resurrected deletions
Run `catchup.sh resurrected`. For each file it lists, ask the user. The default
is to keep it deleted (`git rm -q -f <file>`). Never let one slip back in silently.

### 7. Verify, then commit
```bash
git diff --cached --stat HEAD                       # what changes on staging
git diff --cached --stat prod/gh-pages -- . ':!CNAME'  # what staging still has that prod doesn't
```
The second diff should contain only staging's unshipped work (`KEEP` files) and
the decisions the user made. Anything else is a red flag: stop and explain.
Then commit with a message naming the prod commit:
`Catch staging up to prod (web2023 gh-pages <short sha>)`, listing the files
taken from prod and any decisions in the body.

### 8. Ask before pushing
Show the summary and ask: "Push to origin/gh-pages? This redeploys the staging
site." On yes: `git push origin gh-pages` (plain push, never `--force`). If
it's rejected because origin moved, stop and tell the user; don't retry with force.

### 9. Wrap up the backup
After a successful sync, tell the user the backup branch name and offer to
delete it (`git branch -D <backup>`), or give them that command to run later.
If the sync was abandoned, keep the backup and explain how to restore it:
- not pushed yet: `git reset --hard <backup>` (their call, they run it)
- already pushed: `git revert -m 1 <merge-commit>` and push (no force-push)

## Reminder for the user's own staging → prod PRs
When they open the PR from `web2025:gh-pages` to `web2023:gh-pages`, merge it
with **"Create a merge commit"**, not squash. Squash merges break the shared
history. That causes false conflicts on the next catch-up, and it's how
deleted files came back in Nov 2025.
