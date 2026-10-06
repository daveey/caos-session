# This fork: daveey/caos-session

Everything in `AGENTS.md` still applies. This file adds what is specific to
this fork. It never conflicts with upstream, so fork-only instructions go here,
not in `AGENTS.md`.

## Memory

Long-lived memory lives in the private repo `daveey/caos-memory`. Its
`README.md` has the file format and rules.

**At session start**, before other work:

```
import_source(source="https://github.com/daveey/caos-memory.git", into="memory")
read(file-path="memory/MEMORY.md")
```

Read individual `memory/memories/<slug>.md` files when their index line is
relevant to the task. Treat a memory as what was true when it was written:
verify a named file, flag or tool still exists before relying on it.

**When you learn something worth keeping** (a preference or correction from the
user, a non-obvious fact about a project, where something lives), write or
update `memory/memories/<slug>.md` and its line in `memory/MEMORY.md`, then
publish:

```
publish_source(source_tree="memory", repository="https://github.com/daveey/caos-memory.git", branch="main")
```

Publish right after each change, not at the end of the session, so nothing is
lost if it ends early. The push is fast-forward only. If it is rejected because
another session published first, `import_source` the repo again into a fresh
path, `merge` your commit into it, and publish that. Never pass `force`.

## Tools

This fork's own tools are under `caos-tools/` (see `AGENTS.md`, "This repo's
own tools", and `README.md`, "Your own tools").
