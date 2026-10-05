# Resolving a rebase conflict in this repository

You are running inside a `git rebase` that has stopped on conflicts, in a
checkout of a caos client repo (read `README.md` and `AGENTS.md` if you need
the layout). Edit the conflicted files listed at the end of this message so
that each one is a correct merge of both sides, and leave no conflict markers
(`<<<<<<<`, `=======`, `>>>>>>>`, `|||||||`) anywhere.

What the two sides are:

- **HEAD / "ours" in the markers** is the upstream repository's branch, plus
  whichever of our own commits have already been replayed on top of it.
- **REBASE_HEAD / "theirs" in the markers** is one of this fork's own commits,
  being replayed onto upstream.

Keep the intent of both. Upstream's changes are to be adopted; this fork's
changes are to survive, re-expressed on top of upstream's version where the
two touch the same lines. `git show :1:<path>`, `:2:<path>` and `:3:<path>`
print the base, upstream and our versions of a file; `git log -1 REBASE_HEAD`
says what our commit meant to do.

Rules specific to this repository:

- `flake.lock` is machine-generated. On a conflict in it, take upstream's
  version whole (`git show :2:flake.lock`); never hand-merge JSON.
- Every `rev=` in the root `.caos-expr` must equal the `rev` that `flake.lock`
  locks for the `caos` input, or the whole tree stops evaluating. After
  resolving either file, make them agree, using the value from `flake.lock`.
- The root `.caos-expr`'s directives are each ONE line; never wrap one.
- `CLAUDE.md` is a symlink to `AGENTS.md`; do not replace it with a copy.
- Keep both sides' additions under `caos-tools/`: upstream's new tools and
  this fork's.

Do only this. Do not stage, commit, or continue the rebase, do not touch files
that are not conflicted, and do not run anything but the read-only git
commands named above. If a file cannot be merged faithfully, leave its markers
in place and explain why in your final message; the driver will abort the
rebase rather than push a guess.
