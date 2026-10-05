#!/usr/bin/env bash
# Rebase the checked-out branch onto an upstream branch, letting Claude resolve
# every conflict the rebase stops on. Driven by
# .github/workflows/sync-upstream.yml; runnable by hand from a checkout too:
#
#   .github/sync-upstream/rebase.sh https://github.com/Metta-AI/caos-session.git main
#
# Needs git, and — only once a conflict occurs — the `claude` CLI with
# ANTHROPIC_API_KEY in the environment. Nothing is pushed: on success the
# branch is rebased in the working copy (or was already up to date), and the
# line `changed=true|false` goes to $GITHUB_OUTPUT when that is set. On
# failure the rebase is aborted, the branch is left as it was, and the exit
# status is non-zero.
#
# The shape: `git rebase` replays our commits one at a time. Each time it stops
# with conflicts, the conflicted files (and nothing else) are handed to the
# model with .github/sync-upstream/PROMPT.md, which edits them in place. The
# script, not the model, checks that no conflict markers remain, stages the
# files and continues; a commit that resolves to no change is skipped, as git
# itself would offer. SYNC_MAX_ROUNDS (default 20) bounds the number of
# conflicted commits one run will work through.
set -euo pipefail

UPSTREAM_URL=${1:?usage: rebase.sh <upstream-url> [upstream-branch]}
UPSTREAM_BRANCH=${2:-main}
MAX_ROUNDS=${SYNC_MAX_ROUNDS:-20}
CLAUDE=${CLAUDE_BIN:-claude}
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
OUT=${GITHUB_OUTPUT:-/dev/null}

say() { printf '%s\n' "$*" >&2; }

fail() {
  say "sync-upstream: $*"
  git rebase --abort 2>/dev/null || true
  exit 1
}

in_rebase() {
  [ -d "$(git rev-parse --git-path rebase-merge)" ] || [ -d "$(git rev-parse --git-path rebase-apply)" ]
}

# Lines beginning with a conflict marker, printed as file:line: text; true if
# any. `git diff --check` catches these too but also flags whitespace, so the
# check is spelled out — in bash alone, so it needs nothing the image may lack.
has_markers() {
  local re='^(<{7}|={7}|>{7}|\|{7})( |$)' f line n found=1
  for f in "$@"; do
    [ -f "$f" ] || continue # a side deleted it: nothing to scan
    n=0
    while IFS= read -r line || [ -n "$line" ]; do
      n=$((n + 1))
      if [[ $line =~ $re ]]; then
        say "$f:$n: $line"
        found=0
      fi
    done < "$f"
  done
  return $found
}

resolve_with_claude() {
  # $@: the conflicted paths.
  command -v "$CLAUDE" >/dev/null || fail "a conflict needs the \`$CLAUDE\` CLI, which is not installed"
  [ -n "${ANTHROPIC_API_KEY:-}" ] || fail "a conflict needs ANTHROPIC_API_KEY, which is not set"

  local theirs ours files prompt
  theirs=$(git log -1 --format='%h %s' REBASE_HEAD 2>/dev/null || echo '(unknown)')
  ours=$(git log -1 --format='%h %s' HEAD)
  files=$(printf -- '- %s\n' "$@")
  prompt=$(cat "$HERE/PROMPT.md")
  prompt+=$'\n\n## This conflict\n\n'
  prompt+="Rebasing onto upstream branch \`$UPSTREAM_BRANCH\`. Upstream side (HEAD, what the rebase has built so far): $ours. "
  prompt+="Our commit being replayed (REBASE_HEAD): $theirs."$'\n\n'
  prompt+="Files with conflict markers, each to be left with none:"$'\n'"$files"

  say "sync-upstream: asking $CLAUDE to resolve: $*"
  "$CLAUDE" -p "$prompt" \
    --output-format text \
    --max-turns 60 \
    --allowedTools 'Read,Edit,Write,MultiEdit,Glob,Grep,Bash(git diff:*),Bash(git show:*),Bash(git log:*),Bash(git ls-files:*)' \
    || fail "the model's run failed on: $*"
}

git remote remove upstream 2>/dev/null || true
git remote add upstream "$UPSTREAM_URL"
git fetch --no-tags upstream "$UPSTREAM_BRANCH"

if git merge-base --is-ancestor "upstream/$UPSTREAM_BRANCH" HEAD; then
  say "sync-upstream: already contains upstream/$UPSTREAM_BRANCH; nothing to do"
  echo "changed=false" >> "$OUT"
  exit 0
fi

before=$(git rev-parse HEAD)
export GIT_EDITOR=true

if ! git rebase "upstream/$UPSTREAM_BRANCH"; then
  round=0
  while in_rebase; do
    round=$((round + 1))
    [ "$round" -le "$MAX_ROUNDS" ] || fail "gave up after $MAX_ROUNDS conflicted commits"

    # shellcheck disable=SC2207
    conflicted=($(git diff --name-only --diff-filter=U))
    if [ "${#conflicted[@]}" -gt 0 ]; then
      resolve_with_claude "${conflicted[@]}"
      if has_markers "${conflicted[@]}"; then
        fail "conflict markers remain after the model's edit (above)"
      fi
      git add --all -- "${conflicted[@]}"
      if [ -n "$(git diff --name-only --diff-filter=U)" ]; then
        fail "still unmerged after staging: $(git diff --name-only --diff-filter=U | tr '\n' ' ')"
      fi
    fi

    # Both verbs exit non-zero when the NEXT commit conflicts, which is the
    # loop's business, not a failure; a verb that made no progress is caught
    # by MAX_ROUNDS.
    if git diff --cached --quiet; then
      # Our commit is already in upstream in substance: nothing left to commit.
      say "sync-upstream: commit resolves to no change; skipping it"
      git rebase --skip || true
    else
      git rebase --continue || true
    fi
  done
fi

in_rebase && fail "rebase did not finish"
say "sync-upstream: rebased $before -> $(git rev-parse HEAD)"
echo "changed=true" >> "$OUT"
