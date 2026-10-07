#!/usr/bin/env bash
# SessionStart hook (daveey/caos-session fork): put long-term memory into the
# model's context before the first prompt, so recalling it needs no tool call.
# Fetches daveey/caos-memory with whatever GitHub access the container has
# (CAOS_MEMORY_TOKEN env var if set, else git's own credentials). If that
# fails, falls back to telling the model to import it with caos tools.
# Never fails the session: every path exits 0.
dir=$(mktemp -d)
url=https://github.com/daveey/caos-memory.git
[ -n "${CAOS_MEMORY_TOKEN:-}" ] && url="https://x-access-token:${CAOS_MEMORY_TOKEN}@github.com/daveey/caos-memory.git"
T=; command -v timeout >/dev/null && T="timeout 20"
if GIT_TERMINAL_PROMPT=0 $T git clone -q --depth 1 "$url" "$dir/m" 2>/dev/null && [ -f "$dir/m/MEMORY.md" ]; then
  echo "LONG-TERM MEMORY (daveey/caos-memory @ $(git -C "$dir/m" rev-parse --short HEAD), loaded at session start)."
  echo "Answer 'what do you remember' questions from this. To ADD or CHANGE a memory you"
  echo "still need import_source + publish_source; see FORK.md."
  echo
  echo "===== MEMORY.md"; cat "$dir/m/MEMORY.md"
  total=0
  for f in "$dir"/m/memories/*.md; do
    [ -f "$f" ] || continue
    n=$(wc -c < "$f"); total=$((total + n))
    if [ "$total" -gt 40000 ]; then echo; echo "(more memory files not inlined; import the repo to read them)"; break; fi
    echo; echo "===== memories/$(basename "$f")"; cat "$f"
  done
else
  cat "$CLAUDE_PROJECT_DIR/.claude/session-start.md"
fi
rm -rf "${dir:?}"
exit 0
