#!/usr/bin/env bash
# Read-only helper for the catchup-to-prod skill. It never modifies the repo:
# no fetch, merge, checkout, commit or push. Run from the web2025 repo root.
#
#   catchup.sh analyze           Preflight safety checks + file-by-file plan
#   catchup.sh conflict <file>   (mid-merge) TAKE-PROD | KEEP-STAGING | ASK
#   catchup.sh resurrected       (mid-merge) Files the merge would bring back
#                                after staging deliberately deleted them
#
# Exit codes: 0 = ok / nothing blocking, 1 = STOP condition found, 2 = error.
# Overrides (testing only): CATCHUP_PROD_REF, CATCHUP_ORIGIN_REF.
set -u

PROD_REMOTE=prod
PROD_URL=https://github.com/onesteplicensing/web2023.git
BRANCH=gh-pages
PROD_REF=${CATCHUP_PROD_REF:-$PROD_REMOTE/$BRANCH}
ORIGIN_REF=${CATCHUP_ORIGIN_REF:-origin/$BRANCH}

die() { echo "ERROR: $*" >&2; exit 2; }
has() { git cat-file -e "$1:$2" 2>/dev/null; }
changed() { ! git diff --quiet "$1" "$2" -- "$3"; }

# 0 if staging's blob for <file> equals the file's content in any prod commit.
in_prod_history() {
  local file=$1 blob=$2 c
  for c in $(git rev-list "$PROD_REF" -- "$file"); do
    [ "$(git rev-parse -q --verify "$c:$file" 2>/dev/null)" = "$blob" ] && return 0
  done
  return 1
}

# 0 if prod's blob for <file> equals the file's content in any staging commit.
in_staging_history() {
  local file=$1 blob=$2 c
  for c in $(git rev-list HEAD -- "$file"); do
    [ "$(git rev-parse -q --verify "$c:$file" 2>/dev/null)" = "$blob" ] && return 0
  done
  return 1
}

# For a file both sides changed and both still have: TAKE-PROD, KEEP-STAGING or ASK.
#   TAKE-PROD    staging's copy is already on prod; prod's newer copy loses nothing
#   KEEP-STAGING prod's copy is just an older staging copy; staging's loses nothing
#   ASK          neither (or both, e.g. a revert): a real decision for the user
both_changed_hint() {
  local f=$1 s=1 p=1
  in_prod_history "$f" "$(git rev-parse "HEAD:$f")" && s=0
  in_staging_history "$f" "$(git rev-parse "$PROD_REF:$f")" && p=0
  if [ $s -eq 0 ] && [ $p -ne 0 ]; then echo TAKE-PROD
  elif [ $p -eq 0 ] && [ $s -ne 0 ]; then echo KEEP-STAGING
  else echo ASK; fi
}

# Prints "<sha> <date> <subject>" of the staging commit that deleted <file>.
deleted_in_staging() {
  git log -1 --format='%h %ad %s' --date=short --diff-filter=D HEAD -- "$1"
}

need_refs() {
  git rev-parse --show-toplevel >/dev/null 2>&1 || die "not inside a git repo"
  if ! git remote get-url "$PROD_REMOTE" >/dev/null 2>&1 && [ -z "${CATCHUP_PROD_REF:-}" ]; then
    echo "STOP: no '$PROD_REMOTE' remote. Add it with:"
    echo "  git remote add $PROD_REMOTE $PROD_URL && git fetch $PROD_REMOTE $BRANCH"
    exit 1
  fi
  for r in "$PROD_REF" "$ORIGIN_REF"; do
    git rev-parse -q --verify "$r^{commit}" >/dev/null || die "missing ref $r (run: git fetch origin && git fetch $PROD_REMOTE)"
  done
}

cmd_analyze() {
  need_refs
  local stops=0 branch tracked untracked collide f counts behind ahead

  echo "== Branch"
  branch=$(git symbolic-ref --short -q HEAD || echo "(detached)")
  if [ "$branch" != "$BRANCH" ]; then
    echo "STOP: on '$branch', not '$BRANCH'"; stops=$((stops+1))
  else
    echo "ok: on $BRANCH"
  fi
  if [ -f "$(git rev-parse --git-path MERGE_HEAD)" ]; then
    echo "STOP: a merge is already in progress (finish it or 'git merge --abort')"; stops=$((stops+1))
  fi

  echo; echo "== Working tree"
  tracked=$(git status --porcelain --untracked-files=no)
  if [ -n "$tracked" ]; then
    echo "STOP: uncommitted changes to tracked files:"; echo "$tracked" | sed 's/^/  /'
    stops=$((stops+1))
  else
    echo "ok: no uncommitted changes to tracked files"
  fi
  untracked=$(git -c core.quotePath=false ls-files --others --exclude-standard)
  collide=$(printf '%s\n' "$untracked" | while IFS= read -r f; do
    [ -n "$f" ] || continue
    if has "$PROD_REF" "$f" || has "$ORIGIN_REF" "$f"; then echo "  $f"; fi
  done)
  if [ -n "$collide" ]; then
    echo "STOP: untracked files that the sync would overwrite (they exist on prod or origin):"
    echo "$collide"
    stops=$((stops+1))
  fi
  if [ -n "$untracked" ]; then
    echo "info: untracked files present ($(echo "$untracked" | wc -l | tr -d ' ')); not touched by the sync unless listed above"
  fi

  echo; echo "== Local $BRANCH vs $ORIGIN_REF"
  counts=$(git rev-list --left-right --count "$ORIGIN_REF...HEAD")
  behind=${counts%%[[:space:]]*}; ahead=${counts##*[[:space:]]}
  if [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
    echo "STOP: diverged from $ORIGIN_REF ($ahead local-only, $behind remote-only commits)"
    stops=$((stops+1))
  elif [ "$ahead" -gt 0 ]; then
    echo "STOP: $ahead local commit(s) not pushed to $ORIGIN_REF:"
    git log --format='  %h %ad %s' --date=short "$ORIGIN_REF..HEAD"
    stops=$((stops+1))
  elif [ "$behind" -gt 0 ]; then
    echo "STOP: $behind commit(s) behind $ORIGIN_REF. Fast-forward first (safe), then re-run analyze:"
    echo "  git merge --ff-only $ORIGIN_REF"
    stops=$((stops+1))
  else
    echo "ok: in sync with $ORIGIN_REF"
  fi

  echo; echo "== Prod ($PROD_REF @ $(git rev-parse --short "$PROD_REF"))"
  if git merge-base --is-ancestor "$PROD_REF" HEAD; then
    echo "UP TO DATE: staging already contains prod's head. Nothing to sync."
    echo; echo "RESULT: $stops stop(s)"
    [ "$stops" -eq 0 ] && return 0 || return 1
  fi
  echo "Incoming prod commits:"
  git log --format='  %h %ad %s' --date=short "HEAD..$PROD_REF"
  if git merge-base --is-ancestor HEAD "$PROD_REF" && git diff --quiet HEAD "$PROD_REF" -- CNAME; then
    echo "FAST-FORWARD: staging has nothing prod lacks. 'git merge --ff-only $PROD_REF' makes"
    echo "  staging identical to prod with no new merge commit (preferred over a merge)."
  fi

  local base in_h in_p sc pc d line status label
  base=$(git merge-base HEAD "$PROD_REF")
  echo; echo "== File-by-file (staging HEAD vs prod; merge base $(git rev-parse --short "$base"))"
  git -c core.quotePath=false diff --name-status --no-renames HEAD "$PROD_REF" | while IFS="$(printf '\t')" read -r status f; do
    in_h=0; in_p=0; sc=0; pc=0
    has HEAD "$f" && in_h=1
    has "$PROD_REF" "$f" && in_p=1
    changed "$base" HEAD "$f" && sc=1
    changed "$base" "$PROD_REF" "$f" && pc=1
    if [ "$f" = "CNAME" ]; then
      label="CNAME      $f  (staging's version, or its absence, is always kept)"
    elif [ $in_h -eq 0 ] && [ $in_p -eq 1 ]; then
      if [ $pc -eq 0 ]; then
        label="KEEP       $f  (deleted on staging; prod hasn't touched it, so it stays deleted)"
      elif d=$(deleted_in_staging "$f") && [ -n "$d" ]; then
        label="RESURRECT  $f  (staging deleted it in: $d; merge would bring it back)"
      else
        label="INCOMING   $f  (new file from prod)"
      fi
    elif [ $in_h -eq 1 ] && [ $in_p -eq 0 ]; then
      if [ $sc -eq 0 ]; then
        label="INCOMING   $f  (prod deleted it; staging hasn't changed it)"
      elif [ $pc -eq 1 ]; then
        label="OVERLAP    $f  (staging changed it, prod deleted it)"
      else
        label="KEEP       $f  (staging-only file, not shipped yet)"
      fi
    elif [ $pc -eq 1 ] && [ $sc -eq 0 ]; then
      label="INCOMING   $f  (prod edit; staging untouched)"
    elif [ $sc -eq 1 ] && [ $pc -eq 0 ]; then
      label="KEEP       $f  (staging work not shipped yet)"
    else
      case $(both_changed_hint "$f") in
        TAKE-PROD)    label="INCOMING*  $f  (staging's copy already shipped to prod; prod's newer version is safe to take)" ;;
        KEEP-STAGING) label="KEEP*      $f  (prod's copy is an older staging copy; keeping staging's is safe, confirm with user)" ;;
        *)            label="OVERLAP    $f  (both sides made their own changes; user must decide)" ;;
      esac
    fi
    echo "$label"
  done

  echo; echo "RESULT: $stops stop(s)"
  [ "$stops" -eq 0 ] && return 0 || return 1
}

cmd_conflict() {
  [ $# -eq 1 ] || die "usage: catchup.sh conflict <file>"
  need_refs
  local f=$1 d
  if ! has HEAD "$f"; then
    d=$(deleted_in_staging "$f")
    echo "ASK $f  (not on staging${d:+; deleted in: $d})"
  elif ! has "$PROD_REF" "$f"; then
    echo "ASK $f  (prod deleted it; staging changed it)"
  else
    echo "$(both_changed_hint "$f") $f"
  fi
}

cmd_resurrected() {
  need_refs
  [ -f "$(git rev-parse --git-path MERGE_HEAD)" ] || die "no merge in progress"
  local out
  out=$({ git -c core.quotePath=false diff --cached --name-only --diff-filter=A HEAD
          git -c core.quotePath=false diff --name-only --diff-filter=U; } | sort -u |
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      d=$(deleted_in_staging "$f")
      [ -n "$d" ] && echo "RESURRECTED $f  (staging deleted it in: $d)"
    done)
  if [ -n "$out" ]; then echo "$out"; else echo "none"; fi
  return 0
}

case "${1:-}" in
  analyze) shift; cmd_analyze "$@" ;;
  conflict) shift; cmd_conflict "$@" ;;
  resurrected) shift; cmd_resurrected "$@" ;;
  *) echo "usage: catchup.sh analyze | conflict <file> | resurrected" >&2; exit 2 ;;
esac
